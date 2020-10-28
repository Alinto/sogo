/* NSData+SMIME.m - this file is part of SOGo
 *
 * Copyright (C) 2017-2019 Inverse inc.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NGQuotedPrintableCoding.h>
#import <NGExtensions/NSString+Encoding.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGMail/NGMimeMessageParser.h>

#if defined(HAVE_OPENSSL) || defined(HAVE_GNUTLS)
#include <openssl/bio.h>
#include <openssl/err.h>
#include <openssl/pkcs7.h>
#include <openssl/pkcs12.h>
#include <openssl/pem.h>
#endif

#import <SOGo/NSString+Utilities.h>
#import "NSData+SMIME.h"

@implementation NSData (SOGoMailSMIME)

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
  PKCS7 *p7 = NULL;
  BUF_MEM *bptr;
  
  unsigned int len, slen;
  const char* bytes;
  const char* sbytes;

  int flags = PKCS7_STREAM | PKCS7_DETACHED | PKCS7_CRLFEOL;
  
  OpenSSL_add_all_algorithms();
  ERR_load_crypto_strings();
  
  bytes = [theData bytes];
  len = [theData length];
  tbio = BIO_new_mem_buf((void *)bytes, len);

  scert = PEM_read_bio_X509(tbio, NULL, 0, NULL);

  if (!scert)
    {
      NSLog(@"FATAL: failed to read certificate for signing.");
      goto cleanup;
    }
  
  chain = sk_X509_new_null();
  while (link = PEM_read_bio_X509_AUX(tbio, NULL, 0, NULL))
    sk_X509_unshift(chain, link);

  BIO_reset(tbio);
  
  skey = PEM_read_bio_PrivateKey(tbio, NULL, 0, NULL);

  if (!skey)
    {
      NSLog(@"FATAL: failed to read private key for signing.");
      goto cleanup;
    }
  
  // We sign
  sbytes = [self bytes];
  slen = [self length];
  sbio = BIO_new_mem_buf((void *)sbytes, slen);
  p7 = PKCS7_sign(scert, skey, (sk_X509_num(chain) > 0) ? chain : NULL, sbio, flags);

  if (!p7)
    {
      NSLog(@"FATAL: failed to sign message.");
      goto cleanup;
    }
  
  // We output
  obio = BIO_new(BIO_s_mem());
  SMIME_write_PKCS7(obio, p7, sbio, flags);
  BIO_get_mem_ptr(obio, &bptr);

  output = [NSData dataWithBytes: bptr->data  length: bptr->length];

 cleanup:
  PKCS7_free(p7);
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
{
  NSData *output = NULL;

  BUF_MEM *bptr = NULL;
  BIO *tbio = NULL, *sbio = NULL, *obio = NULL;
  X509 *rcert = NULL;
  PKCS7 *p7 = NULL;
  STACK_OF(X509) *recips = NULL;
  
  unsigned int len, slen;
  const char* bytes;
  const char* sbytes;

  int flags = PKCS7_STREAM;
  
  OpenSSL_add_all_algorithms();
  ERR_load_crypto_strings();

  bytes = [theData bytes];
  len = [theData length];
  tbio = BIO_new_mem_buf((void *)bytes, len);
  if (!tbio)
    {
      NSLog(@"FATAL: unable to allocate BIO memory");
      goto cleanup;
    }

  // Grab the last certificate in case it's chained
  rcert = NULL;
  while (PEM_read_bio_X509(tbio, &rcert, 0, NULL) != NULL);

  if (!rcert)
    {
      NSLog(@"FATAL: unable to read certificate for encryption");
      goto cleanup;
    }
  
  recips = sk_X509_new_null();
  
  if (!recips || !sk_X509_push(recips, rcert))
    {
      NSLog(@"FATAL: unable to push certificate into stack");
      goto cleanup;
    }

  rcert = NULL;

  // Get the bytes to encrypt
  sbytes = [self bytes];
  slen = [self length];
  sbio = BIO_new_mem_buf((void *)sbytes, slen);

  // Encrypt
  p7 = PKCS7_encrypt(recips, sbio, EVP_des_ede3_cbc(), flags);

  if (!p7)
    {
      NSLog(@"FATAL: unable to encrypt message");
      goto cleanup;
    }

  // We output the S/MIME encrypted message
  obio = BIO_new(BIO_s_mem());
  if (!SMIME_write_PKCS7(obio, p7, sbio, flags))
    {
      NSLog(@"FATAL: unable to write PKCS7 output");
      goto cleanup;
    }

  BIO_get_mem_ptr(obio, &bptr);
  
  output = [NSData dataWithBytes: bptr->data  length: bptr->length];

 cleanup:
  PKCS7_free(p7);
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

  BIO *tbio, *sbio, *obio;
  BUF_MEM *bptr;
  X509 *scert = NULL;
  EVP_PKEY *skey = NULL;
  PKCS7 *p7 = NULL;
  
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
      NSLog(@"FATAL: could not read certificate for decryption");
      goto cleanup;
    } 
  
  BIO_reset(tbio);

  skey = PEM_read_bio_PrivateKey(tbio, NULL, 0, NULL);

  if (!skey)
    {
      NSLog(@"FATAL: could not read private key for decryption");
      goto cleanup;
    } 
  
  sbytes = [self bytes];
  slen = [self length];
  sbio = BIO_new_mem_buf((void *)sbytes, slen);

  p7 = SMIME_read_PKCS7(sbio, NULL);

  if (!p7)
    {
      NSLog(@"FATAL: could not read the content to be decrypted");
      goto cleanup;
    }

  // We output the S/MIME encrypted message
  obio = BIO_new(BIO_s_mem());
  
  if (!PKCS7_decrypt(p7, skey, scert, obio, 0))
    {
      NSLog(@"FATAL: could not decrypt content");
      goto cleanup;
    }
  
  BIO_get_mem_ptr(obio, &bptr);
  
  output = [NSData dataWithBytes: bptr->data  length: bptr->length];

 cleanup:
  PKCS7_free(p7);
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

  BIO *sbio, *obio;
  BUF_MEM *bptr;
  PKCS7 *p7 = NULL;

  sbio = BIO_new_mem_buf((void *)[self bytes], [self length]);

  p7 = SMIME_read_PKCS7(sbio, NULL);

  if (!p7)
    {
      NSLog(@"FATAL: could not read the signature");
      goto cleanup;
    }

  // We output the S/MIME encrypted message
  obio = BIO_new(BIO_s_mem());

  if (!PKCS7_verify(p7, NULL, NULL, NULL, obio, PKCS7_NOVERIFY|PKCS7_NOSIGS))
    {
      NSLog(@"FATAL: could not extract content");
      goto cleanup;
    }

  BIO_get_mem_ptr(obio, &bptr);

  output = [NSData dataWithBytes: bptr->data  length: bptr->length];

 cleanup:
  PKCS7_free(p7);
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

  BIO *ibio, *obio;
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
      NSLog(@"FATAL: could not read PKCS12 content");
      goto cleanup;
    }

  if (!PKCS12_parse(p12, [thePassword UTF8String], &pkey, &cert, &ca))
    {
      NSLog(@"FATAL: could not parse PKCS12 certificate with provided password");
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
- (NSData *) signersFromPKCS7
{
  NSData *output = NULL;

  STACK_OF(X509) *certs = NULL;
  BIO *ibio, *obio;
  BUF_MEM *bptr;
  PKCS7 *p7;

  const char* bytes;
  int i, len;
  
  OpenSSL_add_all_algorithms();
  ERR_load_crypto_strings();

  bytes = [self bytes];
  len = [self length];
  ibio = BIO_new_mem_buf((void *)bytes, len);
  
  p7 = d2i_PKCS7_bio(ibio, NULL);

  if (!p7)
    {
      NSLog(@"FATAL: could not read PKCS7 content");
      goto cleanup;
    }
  
  // We output everything in PEM
  obio = BIO_new(BIO_s_mem());

  certs = PKCS7_get0_signers(p7, NULL, 0);
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
  PKCS7_free(p7);
  BIO_free(ibio);  
  BIO_free(obio);  
  
  return output;
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
      char p[1024];
      BIO *buf;

      memset(p, 0, 1024);
      buf = BIO_new(BIO_s_mem());
      X509_NAME_print_ex(buf, X509_get_subject_name(x), 0,
                         ASN1_STRFLGS_ESC_CTRL | XN_FLAG_SEP_MULTILINE | XN_FLAG_FN_LN);
      BIO_read(buf, p, 1024);
      subject = [NSString stringWithUTF8String: p];
      BIO_free(buf);

      memset(p, 0, 1024);
      buf = BIO_new(BIO_s_mem());
      X509_NAME_print_ex(buf, X509_get_issuer_name(x), 0,
                             ASN1_STRFLGS_ESC_CTRL | XN_FLAG_SEP_MULTILINE | XN_FLAG_FN_LN);
      BIO_read(buf, p, 1024);
      issuer = [NSString stringWithUTF8String: p];
      BIO_free(buf);

      data = [NSDictionary dictionaryWithObjectsAndKeys:
                             [subject componentsFromMultilineDN], @"subject",
                           [issuer componentsFromMultilineDN], @"issuer",
                           nil];
    }
  else
    {
      NSString *error;
      const char* sslError;
      int err;

      err = ERR_get_error();
      ERR_load_crypto_strings();
      sslError = ERR_reason_error_string(err);
      error = [NSString stringWithUTF8String: sslError];
      NSLog(@"FATAL: failed to read certificate: %@", error);
    }

  return data;
}

@end
