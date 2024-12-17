/* UIxMailAccountActions.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2020 Inverse inc.
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
#include <openssl/pem.h>
#include <openssl/x509.h>
#endif

#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSAutoreleasePool.h>

#import <NGHttp/NGHttpRequest.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#define COMPILING_NGOBJWEB 1 /* httpRequest is needed in importCertificateAction */
#import <NGObjWeb/WORequest.h>
#undef COMPILING_NGOBJWEB
#import <NGObjWeb/WOResponse.h>

#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeHeaderFields.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMime/NGMimeType.h>

#import <NGImap4/NSString+Imap4.h>
#import <NGExtensions/NSString+misc.h>

#import <Mailer/NSData+SMIME.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoDraftObject.h>
#import <Mailer/SOGoDraftsFolder.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUser.h>

#import "UIxMailAccountActions.h"

@implementation UIxMailAccountActions

- (NSArray *)sortChildrenRecursively: (NSArray *)children {
    NSInteger i, j;
    NSMutableArray *sortedArray;
    NSArray *unsortedChildren, *sortedChildren;
    NSDictionary *child;
    NSMutableDictionary *mutableChild;
    NSString *name1, *name2;

    if (nil == children || 0 == [children count]) {
        return children;
    }

    sortedArray = [NSMutableArray array];

    for (child in children) {
        unsortedChildren = [child objectForKey:@"children"];
        sortedChildren = [self sortChildrenRecursively:unsortedChildren];
        mutableChild = [child mutableCopy];
        [mutableChild setObject:sortedChildren forKey:@"children"];
        [sortedArray addObject:mutableChild];
    }

    for (i = 0; i < [sortedArray count] - 1; i++) {
        for (j = i + 1; j < [sortedArray count]; j++) {
            name1 = [[sortedArray objectAtIndex:i] objectForKey:@"name"];
            name2 = [[sortedArray objectAtIndex:j] objectForKey:@"name"];
            if ([name1 compare:name2 options:NSCaseInsensitiveSearch] == NSOrderedDescending) {
                [sortedArray exchangeObjectAtIndex:i withObjectAtIndex:j];
            }
        }
    }

    return sortedArray;
}

- (NSDictionary *)sortMailboxesRecursively: (NSDictionary *)data {
    NSArray *mailboxes, *mailboxChildren, *sortedMailboxChildren;
    NSMutableDictionary *sortedData, *mutableMailbox;
    NSMutableArray *sortedMailboxes;
    NSDictionary *mailbox;

    mailboxes = [data objectForKey:@"mailboxes"];
    sortedData = [data mutableCopy];
    
    sortedMailboxes = [NSMutableArray array];
    for (mailbox in mailboxes) {
        mutableMailbox = [mailbox mutableCopy];
        
        mailboxChildren = [mailbox objectForKey:@"children"];
        sortedMailboxChildren = [self sortChildrenRecursively:mailboxChildren];
        
        [mutableMailbox setObject:sortedMailboxChildren forKey:@"children"];
        [sortedMailboxes addObject:mutableMailbox];
    }
    
    [sortedData setObject:sortedMailboxes forKey:@"mailboxes"];
    
    return sortedData;
}

- (WOResponse *) listMailboxesAction
{
  SOGoMailAccount *co;
  NSArray *folders;
  NSDictionary *data;
  NSAutoreleasePool *pool;

  co = [self clientObject];

  folders = [co allFoldersMetadata: SOGoMailStandardListing];

  data = [NSDictionary dictionaryWithObjectsAndKeys:
                         folders, @"mailboxes",
                       [co getInboxQuota], @"quotas",
                       nil];
  pool = [[NSAutoreleasePool alloc] init];
  data = [self sortMailboxesRecursively: data];
  DESTROY(pool);

  return [self responseWithStatus: 200
	    andJSONRepresentation: data];
}

- (WOResponse *) listAllMailboxesAction
{
  SOGoMailAccount *co;
  NSArray *folders;
  NSDictionary *data;

  co = [self clientObject];

  folders = [co allFoldersMetadata: SOGoMailSubscriptionsManagementListing];

  data = [NSDictionary dictionaryWithObjectsAndKeys:
                         folders, @"mailboxes",
                       nil];

  return [self responseWithStatus: 200
	    andJSONRepresentation: data];
}

/* compose */

- (NSString *) _emailFromIdentity: (NSDictionary *) identity
{
  NSString *fullName, *format;

  fullName = [identity objectForKey: @"fullName"];
  if ([fullName length])
    format = @"%{fullName} <%{email}>";
  else
    format = @"%{email}";

  return [identity keysWithFormat: format];
}

- (WOResponse *) composeAction
{
  BOOL save, isHTML;
  NSDictionary *data, *identity;
  NSMutableDictionary *headers;
  NSString *accountName, *mailboxName, *messageName;
  NSString *value, *signature, *nl, *space;
  SOGoDraftObject *newDraftMessage;
  SOGoDraftsFolder *drafts;
  SOGoMailAccount *co;
  SOGoUserDefaults *ud;
  id mailTo;

  co = [self clientObject];
  drafts = [co draftsFolderInContext: context];
  newDraftMessage = [drafts newDraft];
  headers = [NSMutableDictionary dictionary];

  save = NO;

  value = [[self request] formValueForKey: @"mailto"];
  if ([value length] > 0)
    {
      mailTo = [[value stringByUnescapingURL] objectFromJSONString];
      if (mailTo && [mailTo isKindOfClass: [NSArray class]])
        {
          [headers setObject: (NSArray *) mailTo forKey: @"to"];
          save = YES;
        }
    }

  value = [[self request] formValueForKey: @"subject"];
  if ([value length] > 0)
    {
      [headers setObject: [value stringByUnescapingURL] forKey: @"subject"];
      save = YES;
    }

  identity = [co defaultIdentity];
  if (identity)
    {
      [headers setObject: [self _emailFromIdentity: identity] forKey: @"from"];
      signature = [identity objectForKey: @"signature"];
      ud = [[context activeUser] userDefaults];
      if ([signature length] && [ud mailUseSignatureOnNew])
        {
          [newDraftMessage setIsHTML: [[ud mailComposeMessageType] isEqualToString: @"html"]];
          isHTML = [newDraftMessage isHTML];
          nl = (isHTML? @"<br />" : @"\n");
          space = (isHTML ? @"&nbsp;" : @" ");
          [newDraftMessage setText: [NSString stringWithFormat: @"%@%@--%@%@%@", nl, nl, space, nl, signature]];
        }
      save = YES;
    }

  if (save)
    {
      [newDraftMessage setHeaders: headers];
      [newDraftMessage storeInfo];
    }

  accountName = [co nameInContainer];
  mailboxName = [drafts absoluteImap4Name]; // Ex: /INBOX/Drafts/
  mailboxName = [mailboxName substringWithRange: NSMakeRange(1, [mailboxName length] -2)];
  messageName = [newDraftMessage nameInContainer];
  data = [NSDictionary dictionaryWithObjectsAndKeys:
                         accountName, @"accountId",
                       mailboxName, @"mailboxPath",
                       messageName, @"draftId", nil];

  return [self responseWithStatus: 201
                        andString: [data jsonRepresentation]];
}

- (WOResponse *) _performDelegationAction: (SEL) action
{
  SOGoMailAccount *co;
  WOResponse *response;
  NSString *uid;

  co = [self clientObject];
  if ([[co nameInContainer] isEqualToString: @"0"])
    {
      uid = [[context request] formValueForKey: @"uid"];
      if ([uid length] > 0)
        {
          [co performSelector: action
                   withObject: [NSArray arrayWithObject: uid]];
          response = [self responseWith204];
        }
      else
        response = [self responseWithStatus: 500
                                  andString: @"Missing 'uid' parameter."];
    }
  else
    response = [self responseWithStatus: 403
                              andString: @"This action cannot be performed on secondary accounts."];

  return response;
}

- (WOResponse *) addDelegateAction
{
  return [self _performDelegationAction: @selector (addDelegates:)];
}

- (WOResponse *) removeDelegateAction
{
  return [self _performDelegationAction: @selector (removeDelegates:)];
}

- (WOResponse *) certificateAction
{
  NSData *pem;
  NSDictionary *data;
  WOResponse *response;

  pem = [[self clientObject] certificate];

  if (pem)
    {
      data = [pem certificateDescription];
      if (data)
        {
          response = [self responseWithStatus: 200  andJSONRepresentation: data];
        }
      else
        {
          data = [NSDictionary
                   dictionaryWithObject: [self labelForKey: @"Error reading the certificate. Please install a new certificate."]
                                 forKey: @"message"];
          response = [self responseWithStatus: 500  andJSONRepresentation: data];
        }
    }
  else
    {
      data = [NSDictionary
               dictionaryWithObject: [self labelForKey: @"No certificate associated to account."]
                             forKey: @"message"];
      response = [self responseWithStatus: 404  andJSONRepresentation: data];
    }

  return response;
}

- (WOResponse *) importCertificateAction
{
  NSArray *parts;
  NGMimeBodyPart *part;
  NGMimeContentDispositionHeaderField *header;
  NSData *pkcs12;
  NSString *mimeType, *name, *password;
  WOResponse *response;
  id data;

  unsigned int count, max;

  password = nil;
  pkcs12 = nil;
  response = [self responseWithStatus: 507];

  data = [[[context request] httpRequest] body];

  if (![data isKindOfClass: [NSException class]])
    {
      parts = [data parts];
      max = [parts count];
      for (count = 0; count < max; count++)
        {
          part = [parts objectAtIndex: count];
          header = (NGMimeContentDispositionHeaderField *)[part headerForKey: @"content-disposition"];
          name = [header name];
          if ([name isEqualToString: @"password"])
            {
              password = [part body];
            }
          else if ([name isEqualToString: @"file"])
            {
              mimeType = [(NGMimeType *)[part headerForKey: @"content-type"] stringValue];
              if ([mimeType hasSuffix: @"pkcs12"])
                {
                  pkcs12 = [part body];
                }
              else
                {
                  response = [self responseWithStatus: 507];
                }
            }
        }
    }

  if (password && pkcs12)
    {
      NSData *certificate;
      NSDictionary *description;

      certificate = [pkcs12 convertPKCS12ToPEMUsingPassword: password];

      if (!certificate)
        return [self responseWithStatus: 507];

      [[self clientObject] setCertificate: certificate];

      description = [certificate certificateDescription];
      if (description)
        {
          response = [self responseWithStatus: 200  andJSONRepresentation: description];
        }
      else
        {
          description = [NSDictionary
                          dictionaryWithObject: [self labelForKey: @"Error reading the certificate. Please install a new certificate."]
                                        forKey: @"message"];
          response = [self responseWithStatus: 500  andJSONRepresentation: description];
        }
    }

  return response;
}

- (WOResponse *) removeCertificateAction
{
  [[self clientObject] setCertificate: nil];

  return [self responseWith204];
}

@end
