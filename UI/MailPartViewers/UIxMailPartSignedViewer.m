/* UIxMailPartSignedViewer.m - this file is part of SOGo
 *
 * Copyright (C) 2009-2021 Inverse inc.
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

#if defined(HAVE_OPENSSL) || defined(HAVE_GNUTLS)
#include <openssl/bio.h>
#include <openssl/err.h>
#include <openssl/cms.h>
#include <openssl/x509.h>
#include <openssl/x509v3.h>
#endif

#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSObject+Logs.h>

#import <NGImap4/NGImap4EnvelopeAddress.h>
#import <NGMime/NGMimeMultipartBody.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>

#import <Mailer/SOGoMailObject.h>

#import "UIxMailRenderingContext.h"
#import "UIxMailPartSignedViewer.h"

@implementation UIxMailPartSignedViewer : UIxMailPartMixedViewer


#if defined(HAVE_OPENSSL) || defined(HAVE_GNUTLS)
- (BOOL) supportsSMIME
{
  return YES;
}

- (X509_STORE *) _setupVerify
{
  X509_STORE *store;
  X509_LOOKUP *lookup;
  BOOL success;

  success = NO;

  store = X509_STORE_new();
  OpenSSL_add_all_algorithms();

  if (store)
    {
      lookup = X509_STORE_add_lookup(store, X509_LOOKUP_file());
      if (lookup)
        {
          X509_LOOKUP_load_file(lookup, NULL, X509_FILETYPE_DEFAULT);
          lookup = X509_STORE_add_lookup(store, X509_LOOKUP_hash_dir());
          if (lookup)
            {
              X509_LOOKUP_add_dir(lookup, NULL, X509_FILETYPE_DEFAULT);
              ERR_clear_error();
              success = YES;
            }
        }
    }

  if (!success)
    {
      if (store)
        {
          X509_STORE_free(store);
          store = NULL;
        }
    }

  return store;
}

- (void) _processMessage
{
  NSData *signedData;
  NSMutableArray *emails;
  
  STACK_OF(X509) *certs;
  X509_STORE *x509Store;
  BIO *msgBio, *inData;
  CMS_ContentInfo *cms;
  int err, i;
 
  ERR_clear_error();

  if ([[self decodedFlatContent] isKindOfClass: [NGMimeMultipartBody class]])
    signedData = [self flatContent];
  else
    signedData = [[self clientObject] content];

  msgBio = BIO_new_mem_buf ((void *) [signedData bytes], [signedData length]);

  inData = NULL;
  cms = SMIME_read_CMS(msgBio, &inData);

  certs = NULL;
  certificates = [NSMutableArray array];
  emails = [NSMutableArray array];
  validationMessage = nil;

  if (cms)
    {
      if (OBJ_obj2nid(CMS_get0_type(cms)) == NID_pkcs7_signed)
	{
          NSString *subject, *issuer;
	  X509 *x;
	  
	  BIO *dummybio = BIO_new(BIO_s_mem());
	  CMS_verify(cms, NULL, NULL, dummybio, NULL, CMS_NO_SIGNER_CERT_VERIFY | CMS_NO_ATTR_VERIFY | CMS_NO_CONTENT_VERIFY);
	  ERR_clear_error();
	  BIO_free(dummybio);
	  certs = CMS_get0_signers(cms);

          for (i = 0; i < sk_X509_num(certs); i++)
            {
	      BIO *buf;
	      char p[1024];
	      int j;
	      STACK_OF(OPENSSL_STRING) *emlst;

	      x = sk_X509_value(certs, i);

	      emlst = X509_get1_email(x);
	      for (j = 0; j < sk_OPENSSL_STRING_num(emlst); j++)
	          [emails addObject: [[NSString stringWithUTF8String: sk_OPENSSL_STRING_value(emlst, j)] lowercaseString]];
	      X509_email_free(emlst);

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

              [certificates addObject: [self certificateForSubject: subject
                                                         andIssuer: issuer
                                                        withEmails: emails]];
	    }
	}
      
      err = ERR_get_error();
      if (err)
	{
	  validSignature = NO;
	}
      else
	{
	  x509Store = [self _setupVerify];
	  validSignature = (CMS_verify(cms, NULL, x509Store, inData,
					 NULL, PKCS7_DETACHED) == 1);
	  
	  err = ERR_get_error();
	  
	  if (x509Store)
	    X509_STORE_free (x509Store);
	}

      if (err)
        {
#ifdef HAVE_GNUTLS
          const char* sslError;
	  ERR_load_crypto_strings();
          SSL_load_error_strings();
          sslError = ERR_reason_error_string(err);
          validationMessage = [[self labelForKey: sslError ? [NSString stringWithUTF8String: sslError] : @"Digital signature is not valid"] retain];
#elif OPENSSL_VERSION_NUMBER < 0x10100000L
          const char* sslError;
	  ERR_load_crypto_strings();
          SSL_load_error_strings();
          sslError = ERR_reason_error_string(err);
          validationMessage = [[self labelForKey: sslError ? [NSString stringWithUTF8String: sslError] : @"Digital signature is not valid"] retain];
#else
          const char* sslError;
          ERR_load_ERR_strings();
          sslError = ERR_reason_error_string(err);
          validationMessage = [[self labelForKey: sslError ? [NSString stringWithUTF8String: sslError] : @"Digital signature is not valid"] retain];
#endif /* HAVE_GNUTLS */
      }
    }

  
  CMS_ContentInfo_free(cms);
  BIO_free (msgBio);
  if (inData)
    BIO_free (inData);

  
  if (validSignature)
    {
      NSString *senderAddress;

      // See https://datatracker.ietf.org/doc/html/rfc8550#section-3
      // See https://datatracker.ietf.org/doc/html/rfc8550#section-4.4.3
      validationMessage = [self labelForKey: @"Message is signed"];
      senderAddress = [[[[[self clientObject] fromEnvelopeAddresses] lastObject] baseEMail] lowercaseString];
      if (![emails containsObject: senderAddress])
        {
          validationMessage = [self labelForKey: @"Message is signed but the certificate doesn't match the sender email address"];
        }
    }
  else if (!validationMessage)
    {
      validationMessage = [NSString stringWithString: [self labelForKey: @"Digital signature is not valid"]];
    }

  processed = YES;
}

- (BOOL) validSignature
{
  if (!processed)
    [self _processMessage];

  return validSignature;
}

- (NSDictionary *) certificateForSubject: (NSString *) subject
                               andIssuer: (NSString *) issuer
                              withEmails: (NSArray *) emails
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
                         [subject componentsFromMultilineDN], @"subject",
                         [issuer componentsFromMultilineDN], @"issuer",
                         emails, @"emails",
                       nil];
}

- (NSArray *) smimeCertificates
{
  return certificates;
}

- (NSString *) validationMessage
{
  if (!processed)
    [self _processMessage];

  return validationMessage;
}
#else
- (BOOL) supportsSMIME
{
  return NO;
}

- (NSArray *) smimeCertificates
{
  return nil;
}

- (BOOL) validSignature
{
  return NO;
}

- (NSString *) validationMessage
{
  return nil;
}
#endif

- (id) renderedPart
{
  NSMutableArray *renderedParts;
  id info, viewer;
  NSArray *parts;

  NSUInteger i, max;

  if ([self decodedFlatContent])
    parts = [[self decodedFlatContent] parts];
  else
    parts = [[self bodyInfo] objectForKey: @"parts"];

  max = [parts count];
  renderedParts = [NSMutableArray arrayWithCapacity: max];

  for (i = 0; i < max; i++)
    {
      [self setChildIndex: i];

      if ([self decodedFlatContent])
        [self setChildInfo: [[parts objectAtIndex: i] bodyInfo]];
      else
        [self setChildInfo: [parts objectAtIndex: i]];

      info = [self childInfo];
      viewer = [[[self context] mailRenderingContext] viewerForBodyInfo: info];
      [viewer setBodyInfo: info];
      [viewer setPartPath: [self childPartPath]];

      if ([self decodedFlatContent])
        [viewer setDecodedContent: [[parts objectAtIndex: i] body]];

      [viewer setAttachmentIds: attachmentIds];
      [renderedParts addObject: [viewer renderedPart]];
    }

  if (!processed)
    [self _processMessage];

  return [NSDictionary dictionaryWithObjectsAndKeys:
                         [self className], @"type",
                       [NSNumber numberWithBool: [self supportsSMIME]], @"supports-smime",
                       [NSNumber numberWithBool: [self validSignature]], @"valid",
                       renderedParts, @"content",
                       [self smimeCertificates], @"certificates",
                       [self validationMessage], @"message",
                       nil];
}

@end
