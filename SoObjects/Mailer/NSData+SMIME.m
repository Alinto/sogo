/* NSData+SMIME.m - this file is part of SOGo
 *
 * Copyright (C) 2017-2022 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <Foundation/NSValue.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NGQuotedPrintableCoding.h>
#import <NGExtensions/NSString+Encoding.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGMime/NGMimeType.h>
#import <NGMail/NGMimeMessageParser.h>

#if defined(HAVE_OPENSSL) || defined(HAVE_GNUTLS)
#include <openssl/bio.h>
#include <openssl/err.h>
#include <openssl/cms.h>
#include <openssl/x509.h>
#include <openssl/x509v3.h>
#include <openssl/pkcs12.h>
#include <openssl/pem.h>
#endif

#import <SOGo/NSString+Utilities.h>
#import "NSData+SMIME.h"

@implementation NSData (SOGoMailSMIME)

- (void) logSSLError: (NSString *) message
{
  NSString *error;
  const char* sslError;
  int err;

  err = ERR_get_error();
  sslError = ERR_reason_error_string(err);
  error = [NSString stringWithUTF8String: sslError];
  NSLog(@"%@: %@", message, error);
}

//
//
//
- (NSData *) signUsingCertificateAndKey: (NSData *) theData
{
  NSData *output = NULL;

  BIO *tbio = NULL, *sbio = NULL, *obio = NULL;
  X509 *scert = NULL;
  X509 *link = NULL;
  STACK_OF(X509) *chain = NULL;
  EVP_PKEY *skey = NULL;
  CMS_ContentInfo *cms = NULL;
  BUF_MEM *bptr;

  unsigned int len, slen;
  const char* bytes;
  const char* sbytes;

  int flags = CMS_STREAM | CMS_DETACHED | CMS_CRLFEOL;

  OpenSSL_add_all_algorithms();
  ERR_load_crypto_strings();

  bytes = [theData bytes];
  len = [theData length];
  tbio = BIO_new_mem_buf((void *)bytes, len);

  scert = PEM_read_bio_X509(tbio, NULL, 0, NULL);

  if (!scert)
    {
      [self logSSLError: @"FATAL: failed to read certificate for signing"];
      goto cleanup;
    }

  chain = sk_X509_new_null();
  while ((link = PEM_read_bio_X509_AUX(tbio, NULL, 0, NULL)))
    sk_X509_unshift(chain, link);

  BIO_reset(tbio);

  skey = PEM_read_bio_PrivateKey(tbio, NULL, 0, NULL);

  if (!skey)
    {
      [self logSSLError: @"FATAL: failed to read private key for signing"];
      goto cleanup;
    }

  // We sign
  sbytes = [self bytes];
  slen = [self length];
  sbio = BIO_new_mem_buf((void *)sbytes, slen);
  cms = CMS_sign(scert, skey, (sk_X509_num(chain) > 0) ? chain : NULL, sbio, flags);

  if (!cms)
    {
      [self logSSLError: @"FATAL: failed to sign message"];
      goto cleanup;
    }

  // We output
  obio = BIO_new(BIO_s_mem());
  SMIME_write_CMS(obio, cms, sbio, flags);
  BIO_get_mem_ptr(obio, &bptr);

  output = [NSData dataWithBytes: bptr->data  length: bptr->length];

 cleanup:
  CMS_ContentInfo_free(cms);
  sk_X509_pop_free(chain, X509_free);
  X509_free(scert);
  BIO_free(tbio);
  BIO_free(sbio);
  BIO_free(obio);

  return output;
}

//
//
//
- (NSData *) encryptUsingCertificate: (NSData *) theData
                            andAlgos: (NSArray *) theAlgos
{
  NSData *output = NULL;

  BUF_MEM *bptr = NULL;
  BIO *tbio = NULL, *sbio = NULL, *obio = NULL;
  X509 *rcert = NULL;
  CMS_ContentInfo *cms = NULL;
  STACK_OF(X509) *recips = NULL;

  int i;
  const EVP_CIPHER *cipher = NULL;

  unsigned int len, slen;
  const char* bytes;
  const char* sbytes;

  int flags = CMS_STREAM;

  OpenSSL_add_all_algorithms();
  ERR_load_crypto_strings();

  bytes = [theData bytes];
  len = [theData length];
  tbio = BIO_new_mem_buf((void *)bytes, len);
  if (!tbio)
    {
      [self logSSLError: @"FATAL: unable to allocate BIO memory"];
      goto cleanup;
    }

  // Grab the last certificate in case it's chained
  rcert = NULL;
  while (PEM_read_bio_X509(tbio, &rcert, 0, NULL) != NULL);

  if (!rcert)
    {
      [self logSSLError: @"FATAL: unable to read certificate for encryption"];
      goto cleanup;
    }

  recips = sk_X509_new_null();

  if (!recips || !sk_X509_push(recips, rcert))
    {
      [self logSSLError: @"FATAL: unable to push certificate into stack"];
      goto cleanup;
    }

  rcert = NULL;

  if (theAlgos)
    {
      // pick first supported cipher suggested by peer
      for (i = 0; cipher == NULL && i < [theAlgos count]; i++)
        {
          int nid = [[theAlgos objectAtIndex: i] intValue];
          switch (nid)
            {
              // ciphers from RFC8551
              //No support for AuthEnvelopedData in OpenSSL yet
              //case NID_chacha20_poly1305:
              //case NID_aes_256_gcm:
              //case NID_aes_128_gcm:
#ifdef NID_aes_128_cbc
              case NID_aes_128_cbc:
#endif
              // plus ciphers from RFC5751
#ifdef NID_aes_192_cbc
              case NID_aes_192_cbc:
#endif
#ifdef NID_aes_256_cbc
              case NID_aes_256_cbc:
#endif
#ifdef NID_des_ede3_cbc
              case NID_des_ede3_cbc:
#endif
                  cipher = EVP_get_cipherbynid(nid);
                  break;
              default:
                  break;
            }
        }

      // no matching cipher - use default cipher
      if (cipher == NULL)
#ifndef OPENSSL_NO_AES
          cipher = EVP_aes_128_cbc();
#elif !defined(OPENSSL_NO_DES)
          cipher = EVP_des_ede3_cbc();
#else
#error "Neither AES nor 3DES available"
#endif
    }
  else
    {
      // ATM theAlgos == NULL means we're storing a draft with the writer's own key
#ifndef OPENSSL_NO_AES
      cipher = EVP_aes_128_cbc();
#elif !defined(OPENSSL_NO_DES)
      cipher = EVP_des_ede3_cbc();
#else
#error "Neither AES nor 3DES available"
#endif
    }

  // Get the bytes to encrypt
  sbytes = [self bytes];
  slen = [self length];
  sbio = BIO_new_mem_buf((void *)sbytes, slen);

  // Encrypt
  cms = CMS_encrypt(recips, sbio, cipher, flags);

  if (!cms)
    {
      [self logSSLError: @"FATAL: unable to encrypt message"];
      goto cleanup;
    }

  // We output the S/MIME encrypted message
  obio = BIO_new(BIO_s_mem());
  if (!SMIME_write_CMS(obio, cms, sbio, flags))
    {
      [self logSSLError: @"FATAL: unable to write CMS output"];
      goto cleanup;
    }

  BIO_get_mem_ptr(obio, &bptr);

  output = [NSData dataWithBytes: bptr->data  length: bptr->length];

 cleanup:
  CMS_ContentInfo_free(cms);
  X509_free(rcert);
  BIO_free(tbio);
  BIO_free(sbio);
  BIO_free(obio);

  return output;
}

//
//
//
- (NSData *) decryptUsingCertificate: (NSData *) theData
{
  NSData *output = NULL;

  BIO *tbio, *sbio = NULL, *obio = NULL;
  BUF_MEM *bptr;
  X509 *scert = NULL;
  EVP_PKEY *skey = NULL;
  CMS_ContentInfo *cms = NULL;

  unsigned int len, slen;
  const char* bytes;
  const char* sbytes;

  OpenSSL_add_all_algorithms();
  ERR_load_crypto_strings();

  bytes = [theData bytes];
  len = [theData length];
  tbio = BIO_new_mem_buf((void *)bytes, len);

  // Grab the last certificate in case it's chained
  scert = NULL;
  while (PEM_read_bio_X509(tbio, &scert, 0, NULL) != NULL);

  if (!scert)
    {
      [self logSSLError: @"FATAL: could not read certificate for decryption"];
      goto cleanup;
    }

  BIO_reset(tbio);

  skey = PEM_read_bio_PrivateKey(tbio, NULL, 0, NULL);

  if (!skey)
    {
      [self logSSLError: @"FATAL: could not read private key for decryption"];
      goto cleanup;
    }

  sbytes = [self bytes];
  slen = [self length];
  sbio = BIO_new_mem_buf((void *)sbytes, slen);

  cms = SMIME_read_CMS(sbio, NULL);

  if (!cms)
    {
      [self logSSLError: @"FATAL: could not read the content to be decrypted"];
      goto cleanup;
    }

  // We output the S/MIME encrypted message
  obio = BIO_new(BIO_s_mem());

  if (!CMS_decrypt(cms, skey, scert, NULL, obio, 0))
    {
      [self logSSLError: @"FATAL: could not decrypt content"];
      goto cleanup;
    }

  BIO_get_mem_ptr(obio, &bptr);

  output = [NSData dataWithBytes: bptr->data  length: bptr->length];

 cleanup:
  CMS_ContentInfo_free(cms);
  X509_free(scert);
  BIO_free(sbio);
  BIO_free(tbio);
  BIO_free(obio);

  return output;
}

//
//
//
- (NGMimeMessage *) messageFromEncryptedDataAndCertificate: (NSData *) theCertificate
{
  NGMimeMessageParser *parser;
  NGMimeMessage *message;
  NSData *decryptedData;
  NGMimeType *contentType;
  NSString *type, *subtype, *smimetype;

  decryptedData = [self decryptUsingCertificate: theCertificate];
  parser = [[NGMimeMessageParser alloc] init];
  message = [parser parsePartFromData: decryptedData];

  // Extract contents if the encrypted messages contains opaque signed data
  contentType = [message contentType];
  type = [[contentType type] lowercaseString];
  subtype = [[contentType subType] lowercaseString];
  if ([type isEqualToString: @"application"])
    {
      if ([subtype isEqualToString: @"x-pkcs7-mime"] ||
          [subtype isEqualToString: @"pkcs7-mime"])
	{
	  smimetype = [[contentType valueOfParameter: @"smime-type"] lowercaseString];
	  if ([smimetype isEqualToString: @"signed-data"])
	    {
	      message = [decryptedData messageFromOpaqueSignedData];
	    }
	}
    }

  RELEASE(parser);

  return message;
}

- (NSData *) embeddedContent
{
  NSData *output = NULL;

  BIO *sbio, *obio = NULL;
  BUF_MEM *bptr;
  CMS_ContentInfo *cms = NULL;

  sbio = BIO_new_mem_buf((void *)[self bytes], [self length]);

  cms = SMIME_read_CMS(sbio, NULL);

  if (!cms)
    {
      [self logSSLError: @"FATAL: could not read the signature"];
      goto cleanup;
    }

  // We output the S/MIME encrypted message
  obio = BIO_new(BIO_s_mem());

  if (!CMS_verify(cms, NULL, NULL, NULL, obio, CMS_NOVERIFY|CMS_NOSIGS))
    {
      [self logSSLError: @"FATAL: could not extract content"];
      goto cleanup;
    }

  BIO_get_mem_ptr(obio, &bptr);

  output = [NSData dataWithBytes: bptr->data  length: bptr->length];

 cleanup:
  CMS_ContentInfo_free(cms);
  BIO_free(sbio);
  BIO_free(obio);

  return output;
}

//
//
//
- (NGMimeMessage *) messageFromOpaqueSignedData
{
  NGMimeMessageParser *parser;
  NGMimeMessage *message;
  NSData *extractedData;

  extractedData = [self embeddedContent];
  parser = [[NGMimeMessageParser alloc] init];
  message = [parser parsePartFromData: extractedData];
  RELEASE(parser);

  return message;
}

//
//
//
- (NSData *) convertPKCS12ToPEMUsingPassword: (NSString *) thePassword
{
  NSData *output = NULL;

  BIO *ibio, *obio = NULL;
  EVP_PKEY *pkey;
  BUF_MEM *bptr;
  PKCS12 *p12;
  X509 *cert;

  const char* bytes;
  int i, len;

  STACK_OF(X509) *ca = NULL;

  OpenSSL_add_all_algorithms();
  ERR_load_crypto_strings();

  bytes = [self bytes];
  len = [self length];
  ibio = BIO_new_mem_buf((void *)bytes, len);

  p12 = d2i_PKCS12_bio(ibio, NULL);

  if (!p12)
    {
      [self logSSLError: @"FATAL: could not read PKCS12 content"];
      goto cleanup;
    }

  if (!PKCS12_parse(p12, [thePassword UTF8String], &pkey, &cert, &ca))
    {
      [self logSSLError: @"FATAL: could not parse PKCS12 certificate with provided password"];
      return nil;
    }

  // We output everything in PEM
  obio = BIO_new(BIO_s_mem());

  // TODO: support protecting the private key with a PEM passphrase
  if (pkey)
    {
      PEM_write_bio_PrivateKey(obio, pkey, NULL, NULL, 0, NULL, NULL);
    }

  if (cert)
    {
      PEM_write_bio_X509(obio, cert);
    }

  if (ca && sk_X509_num(ca))
    {
      for (i = 0; i < sk_X509_num(ca); i++)
        PEM_write_bio_X509_AUX(obio, sk_X509_value(ca, i));
    }

  BIO_get_mem_ptr(obio, &bptr);

  output = [NSData dataWithBytes: bptr->data  length: bptr->length];

 cleanup:
  PKCS12_free(p12);
  BIO_free(ibio);
  BIO_free(obio);

  return output;
}

//
//
//
- (NSData *) signersFromCMS
{
  NSData *output = NULL;

  STACK_OF(X509) *certs = NULL;
  BIO *ibio, *obio = NULL, *dummybio = NULL;
  BUF_MEM *bptr;
  CMS_ContentInfo *cms;

  const char* bytes;
  int i, len;

  OpenSSL_add_all_algorithms();
  ERR_load_crypto_strings();

  bytes = [self bytes];
  len = [self length];
  ibio = BIO_new_mem_buf((void *)bytes, len);

  cms = d2i_CMS_bio(ibio, NULL);

  if (!cms)
    {
      [self logSSLError: @"FATAL: could not read CMS content"];
      goto cleanup;
    }

  // before calling CMS_get0_signers(), CMS_verify() must be called
  dummybio = BIO_new(BIO_s_mem());
  CMS_verify(cms, NULL, NULL, dummybio, NULL, CMS_NO_SIGNER_CERT_VERIFY | CMS_NO_ATTR_VERIFY | CMS_NO_CONTENT_VERIFY);
  ERR_clear_error();

  // We output everything in PEM
  obio = BIO_new(BIO_s_mem());
  certs = CMS_get0_signers(cms);
  if (certs != NULL)
    {
      X509 *x;

      for (i = 0; i < sk_X509_num(certs); i++)
        {
          x = sk_X509_value(certs, i);
          PEM_write_bio_X509(obio, x);
          BIO_puts(obio, "\n");
        }
    }

  BIO_get_mem_ptr(obio, &bptr);

  output = [NSData dataWithBytes: bptr->data  length: bptr->length];

 cleanup:
  CMS_ContentInfo_free(cms);
  BIO_free(dummybio);
  BIO_free(ibio);
  BIO_free(obio);

  return output;
}

// Implementation based on "STACK_OF(X509_ALGOR) *PKCS7_get_smimecap(PKCS7_SIGNER_INFO *si)"
STACK_OF(X509_ALGOR) *CMS_get_smimecap(CMS_SignerInfo *si)
{
    X509_ATTRIBUTE *attr;
    ASN1_TYPE *cap;
    const unsigned char *p;

    attr = CMS_signed_get_attr(si, CMS_signed_get_attr_by_NID(si, NID_SMIMECapabilities, -1));
    if (!attr)
        return NULL;
    cap = X509_ATTRIBUTE_get0_type(attr, 0);
    if (!cap || (cap->type != V_ASN1_SEQUENCE))
       return NULL;
    p = cap->value.sequence->data;
    return (STACK_OF(X509_ALGOR) *)
        ASN1_item_d2i(NULL, &p, cap->value.sequence->length,
                      ASN1_ITEM_rptr(X509_ALGORS));
}

- (NSArray *) algosFromCMS
{
  NSMutableArray *algos = [[NSMutableArray alloc] initWithCapacity: 10];

  STACK_OF(CMS_SignerInfo) *signerinfos;
  BIO *ibio;
  CMS_ContentInfo *cms;

  const ASN1_OBJECT *paobj;
  int pptype;
  int nid;

  const char* bytes;
  int i, j, len;

  OpenSSL_add_all_algorithms();
  ERR_load_crypto_strings();

  bytes = [self bytes];
  len = [self length];
  ibio = BIO_new_mem_buf((void *)bytes, len);

  cms = d2i_CMS_bio(ibio, NULL);

  if (!cms)
    {
      [self logSSLError: @"FATAL: could not read CMS content"];
      goto cleanup;
    }

  signerinfos = CMS_get0_SignerInfos(cms);
  if (signerinfos != NULL)
    {
      for (i = 0; i < sk_CMS_SignerInfo_num(signerinfos); i++)
        {
          CMS_SignerInfo *si = sk_CMS_SignerInfo_value(signerinfos, i);
          STACK_OF(X509_ALGOR) *smimecap = CMS_get_smimecap(si);

          if (smimecap != NULL)
            {
              for (j = 0; j < sk_X509_ALGOR_num(smimecap); j++)
                {
                  X509_ALGOR_get0(&paobj, &pptype, NULL, sk_X509_ALGOR_value(smimecap, j));
                  nid = OBJ_obj2nid(paobj);
                  // Of all ciphers commonly used for S/MIME only RC2 has a keylength parameter
                  // As RC2 is outdated it's ok to ignore all ciphers with parameter
                  if (nid != NID_undef && pptype == V_ASN1_UNDEF)
                      [algos addObject: [NSNumber numberWithInt: nid]];
                }
            }
        }
    }

 cleanup:
  CMS_ContentInfo_free(cms);
  BIO_free(ibio);

  return algos;
}

/**
 * Extract usefull information from PEM certificate
 */
- (NSDictionary *) certificateDescription
{
  NSDictionary *data;
  BIO *bio;
  X509 *x;

  data = nil;
  OpenSSL_add_all_algorithms();
  bio = BIO_new_mem_buf((void *) [self bytes], [self length]);

  // Grab the last certificate in case it's chained
  x = NULL;
  while (PEM_read_bio_X509(bio, &x, 0, NULL) != NULL);

  if (x)
    {
      NSString *subject, *issuer;
      NSMutableArray *emails;
      int j;
      STACK_OF(OPENSSL_STRING) *emlst;
      char p[1024];
      BIO *buf;

      emails = [NSMutableArray array];
      emlst = X509_get1_email(x);
      for (j = 0; j < sk_OPENSSL_STRING_num(emlst); j++)
          [emails addObject: [[NSString stringWithUTF8String: sk_OPENSSL_STRING_value(emlst, j)] lowercaseString]];
      X509_email_free(emlst);

      memset(p, 0, 1024);
      buf = BIO_new(BIO_s_mem());
      X509_NAME_print_ex(buf, X509_get_subject_name(x), 0,
                         ASN1_STRFLGS_ESC_CTRL | ASN1_STRFLGS_UTF8_CONVERT | XN_FLAG_SEP_MULTILINE | XN_FLAG_FN_LN);
      BIO_read(buf, p, 1024);
      subject = [NSString stringWithUTF8String: p];
      BIO_free(buf);

      memset(p, 0, 1024);
      buf = BIO_new(BIO_s_mem());
      X509_NAME_print_ex(buf, X509_get_issuer_name(x), 0,
                             ASN1_STRFLGS_ESC_CTRL | ASN1_STRFLGS_UTF8_CONVERT | XN_FLAG_SEP_MULTILINE | XN_FLAG_FN_LN);
      BIO_read(buf, p, 1024);
      issuer = [NSString stringWithUTF8String: p];
      BIO_free(buf);

      data = [NSDictionary dictionaryWithObjectsAndKeys:
                             [subject componentsFromMultilineDN], @"subject",
                           [issuer componentsFromMultilineDN], @"issuer",
                           emails, @"emails",
                           nil];
    }
  else
    {
      [self logSSLError: @"FATAL: failed to read certificate"];
    }

  return data;
}

@end
