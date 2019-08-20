/*
  Copyright (C) 2017-2019 Inverse inc.

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#if defined(HAVE_OPENSSL) || defined(HAVE_GNUTLS)
#include <openssl/ssl.h>
#include <openssl/bio.h>
#include <openssl/err.h>
#include <openssl/pkcs7.h>
#include <openssl/x509.h>
#endif

#import <Foundation/NSDictionary.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSObject+Logs.h>
#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeHeaderFields.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMime/NGMimeType.h>
#import <NGMail/NGMimeMessageParser.h>

#import <SoObjects/Mailer/NSData+SMIME.h>
#import <SoObjects/Mailer/NSString+Mail.h>
#import <SoObjects/Mailer/SOGoMailAccount.h>
#import <SoObjects/Mailer/SOGoMailObject.h>
#import <UI/MailerUI/WOContext+UIxMailer.h>

#import <SOGo/NSString+Utilities.h>

#import "UIxMailRenderingContext.h"
#import "UIxMailPartEncryptedViewer.h"

@implementation UIxMailPartEncryptedViewer

#if defined(HAVE_OPENSSL) || defined(HAVE_GNUTLS)
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

- (NSData *) _processMessageWith: (NSData *) signedData
{
  NSData *output;

  STACK_OF(X509) *certs;
  X509_STORE *x509Store;
  BIO *msgBio, *obio;
  PKCS7 *p7;
  int err, i;

  ERR_clear_error();

  msgBio = BIO_new_mem_buf ((void *) [signedData bytes], [signedData length]);
  output = NULL;

  p7 = SMIME_read_PKCS7(msgBio, NULL);

  certs = NULL;
  certificates = [NSMutableArray array];
  validationMessage = nil;

  if (p7)
    {
      if (OBJ_obj2nid(p7->type) == NID_pkcs7_signed)
	{
          NSString *subject, *issuer;
	  X509 *x;

	  certs = p7->d.sign->cert;

          for (i = 0; i < sk_X509_num(certs); i++)
            {
	      BIO *buf;
	      char p[1024];

	      x = sk_X509_value(certs, i);

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
                                                         andIssuer: issuer]];
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
          obio = BIO_new(BIO_s_mem());

	  validSignature = (PKCS7_verify(p7, NULL, x509Store, NULL,
					 obio, 0) == 1);

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
          validationMessage = [[self labelForKey: [NSString stringWithUTF8String: sslError ? sslError : @"No error information available"]] retain];
#elif OPENSSL_VERSION_NUMBER < 0x10100000L
          const char* sslError;
	  ERR_load_crypto_strings();
          SSL_load_error_strings();
          sslError = ERR_reason_error_string(err);
          validationMessage = [[self labelForKey: [NSString stringWithUTF8String: sslError ? sslError : @"No error information available"]] retain];
#else
	  validationMessage = [[self labelForKey: @"No error information available"] retain];
#endif /* HAVE_GNUTLS */

           BUF_MEM *bptr; //DEL
           BIO_get_mem_ptr(obio, &bptr); //DEL
          // extract contents without validation
          output = [ signedData embeddedContent ];
        }
      else
        {
           BUF_MEM *bptr;
           BIO_get_mem_ptr(obio, &bptr);
           output = [NSData dataWithBytes: bptr->data  length: bptr->length];
        }
    }

  PKCS7_free(p7);
  BIO_free (msgBio);
  BIO_free (obio);

  if (validSignature)
    validationMessage = [NSString stringWithString: [self labelForKey: @"Message is signed"]];
  else if (!validationMessage)
    validationMessage = [NSString stringWithString: [self labelForKey: @"Digital signature is not valid"]];

  processed = YES;
  opaqueSigned = YES;
  return output;
}

- (BOOL) validSignature
{
  if (!processed)
    NSLog(@"ERROR: validSignature called but not processed yet");
    //[self _processMessage];

  return validSignature;
}

- (NSDictionary *) certificateForSubject: (NSString *) subject
                               andIssuer: (NSString *) issuer
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
                              [subject componentsFromMultilineDN], @"subject",
                              [issuer componentsFromMultilineDN], @"issuer",
                       nil];
}

- (NSArray *) smimeCertificates
{
  return certificates;
}

- (NSString *) validationMessage
{
  if (!processed)
    NSLog(@"ERROR: validationMessage called but not processed yet");
    //[self _processMessage];

  return validationMessage;
}
#else
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

- (void) _attachmentIdsFromBodyPart: (id) thePart
                           partPath: (NSString *) thePartPath
{
  // Small hack to avoid SOPE's stupid behavior to wrap a multipart
  // object in a NGMimeBodyPart.
   if ([thePart isKindOfClass: [NGMimeBodyPart class]] &&
       [[[thePart contentType] type] isEqualToString: @"multipart"])
     thePart = [thePart body];

  if ([thePart isKindOfClass: [NGMimeBodyPart class]])
    {
      NSString *filename, *mimeType;

      mimeType = [[thePart contentType] stringValue];
      filename = [(NGMimeContentDispositionHeaderField *)[thePart headerForKey: @"content-disposition"] filename];

      if (!filename)
        filename = [mimeType asPreferredFilenameUsingPath: nil];

      if (filename)
        {
          [(id)attachmentIds setObject: [NSString stringWithFormat: @"%@%@%@",
                                                  [[self clientObject] baseURLInContext: [self context]],
                                                  thePartPath,
                                                  filename]
                                forKey: [NSString stringWithFormat: @"<%@>", filename]];
        }
    }
  else if ([thePart isKindOfClass: [NGMimeMultipartBody class]])
    {
      int i;

      for (i = 0; i < [[thePart parts] count]; i++)
        {
          [self _attachmentIdsFromBodyPart: [[thePart parts] objectAtIndex: i]
                                  partPath: [NSString stringWithFormat: @"%@%d/", thePartPath, i+1]];
        }
    }
}

- (id) contentViewerComponent
{
  id info;

  info = [self childInfo];
  return [[[self context] mailRenderingContext] viewerForBodyInfo: info];
}

- (id) renderedPart
{
  SOGoMailObject *mailObject;
  NSData *certificate, *decryptedData, *encryptedData;
  id info, viewer;

  mailObject = [[self clientObject] mailObject];
  if ([mailObject isEncrypted])
    {
      encrypted = YES;
      certificate = [[[self clientObject] mailAccountFolder] certificate];
      encryptedData = [[self clientObject] content];
      decryptedData = [encryptedData decryptUsingCertificate: certificate];

      if (decryptedData)
        {
          NGMimeMessageParser *parser;
          NGMimeMessage *message;
          NGMimeType *contentType;
          NSString *type, *subtype, *smimetype;
          id part;

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
                      NGMimeMessageParser *parser;
                      NSData *extractedData;

                      opaqueSigned = YES;
                      extractedData = [self _processMessageWith: decryptedData];
                      if (extractedData)
                        {
                          parser = [[NGMimeMessageParser alloc] init];
                          message = [parser parsePartFromData: extractedData];
                          decryptedData = extractedData;
                          RELEASE(parser);
                        }
                    }
                }
            }

          processed = YES;
	  part = [message retain];

          info = [NSDictionary dictionaryWithObjectsAndKeys: [[part contentType] type], @"type",
                               [[part contentType] subType], @"subtype",
                               [[part contentType] parametersAsDictionary], @"parameterList", nil];
          viewer = [[[self context] mailRenderingContext] viewerForBodyInfo: info];
          [viewer setBodyInfo: info];
          [viewer setFlatContent: decryptedData];
          [viewer setDecodedContent: [part body]];

          // attachmentIds is empty in an ecrypted email as the IMAP body structure
          // is of course not available for file attachments
          [self _attachmentIdsFromBodyPart: [part body]  partPath: @""];
          [viewer setAttachmentIds: attachmentIds];

          return [NSDictionary dictionaryWithObjectsAndKeys:
                                     [self className], @"type",
                                   [NSNumber numberWithBool: YES], @"encrypted",
                                   [NSNumber numberWithBool: YES], @"decrypted",
                                   [NSNumber numberWithBool: opaqueSigned], @"opaqueSigned",
                                   [NSNumber numberWithBool: [self validSignature]], @"valid",
                                   [NSArray arrayWithObject: [viewer renderedPart]], @"content",
                                   [self smimeCertificates], @"certificates",
                                   [self validationMessage], @"message",
                               nil];
        }
    }
  else if ([mailObject isOpaqueSigned])
    {
      NGMimeMessageParser *parser;
      NGMimeMessage *message;
      NSData *extractedData;
      id part;

      opaqueSigned = YES;
      encryptedData = [[self clientObject] content];
      extractedData = [self _processMessageWith: encryptedData];

      if (extractedData)
        {
          parser = [[NGMimeMessageParser alloc] init];
          message = [parser parsePartFromData: extractedData];
          RELEASE(parser);
        }

      processed = YES;
      part = [message retain];

      info = [NSDictionary dictionaryWithObjectsAndKeys: [[part contentType] type], @"type",
                           [[part contentType] subType], @"subtype",
                           [[part contentType] parametersAsDictionary], @"parameterList", nil];
      viewer = [[[self context] mailRenderingContext] viewerForBodyInfo: info];
      [viewer setBodyInfo: info];
      [viewer setFlatContent: extractedData];
      [viewer setDecodedContent: [part body]];

      // attachmentIds is empty in an ecrypted email as the IMAP body structure
      // is of course not available for file attachments
      [self _attachmentIdsFromBodyPart: [part body]  partPath: @""];
      [viewer setAttachmentIds: attachmentIds];

      return [NSDictionary dictionaryWithObjectsAndKeys:
                                 [self className], @"type",
                               [NSNumber numberWithBool: NO], @"encrypted",
                               [NSNumber numberWithBool: YES], @"opaqueSigned",
                               [NSNumber numberWithBool: [self validSignature]], @"valid",
                               [NSArray arrayWithObject: [viewer renderedPart]], @"content",
                               [self smimeCertificates], @"certificates",
                               [self validationMessage], @"message",
                           nil];
    }


  // Decryption failed, let's return something else...
  return [NSDictionary dictionaryWithObjectsAndKeys:
                         [self className], @"type",
                       [NSNumber numberWithBool: encrypted], @"encrypted",
                       [NSNumber numberWithBool: NO], @"decrypted",
                       [NSNumber numberWithBool: NO], @"opaqueSigned",
                       [NSArray array], @"content",
                       nil];
}

@end /* UIxMailPartAlternativeViewer */
