/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSException+misc.h>
#import <NGExtensions/NGHashMap.h>
#import <NGExtensions/NSString+misc.h>

#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMail/NGMimeMessage.h>
#import <NGMail/NGMimeMessageGenerator.h>

#import <NGImap4/NGImap4Client.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4Envelope.h>
#import <NGImap4/NGImap4EnvelopeAddress.h>

#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoBuild.h>
#import <SOGo/SOGoMailer.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserManager.h>
#import <Mailer/SOGoMailObject.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailFolder.h>
#import <SOGoUI/UIxComponent.h>
#import <MailPartViewers/UIxMailRenderingContext.h> // cyclic

#import "WOContext+UIxMailer.h"

@interface UIxMailView : UIxComponent
{
  id currentAddress;
  NSString *shouldAskReceipt;
  NSString *matchingIdentityEMail;
}

@end

@implementation UIxMailView

static NSString *mailETag = nil;

+ (void) initialize
{
  mailETag = [[NSString alloc] initWithFormat:@"\"imap4url_%d_%d_%03d\"",
                               SOGO_MAJOR_VERSION,
                               SOGO_MINOR_VERSION,
                               SOGO_SUBMINOR_VERSION];
  NSLog (@"Note: using constant etag for mail viewer: '%@'", mailETag);
}

- (void) dealloc
{
  [matchingIdentityEMail release];
  [super dealloc];
}

/* accessors */

- (void) setCurrentAddress: (id) _addr
{
  currentAddress = _addr;
}

- (id) currentAddress
{
  return currentAddress;
}

- (NSString *) messageSubject
{
  NSString *subject;

  subject = [[self clientObject] decodedSubject];

  return subject;
}

- (NSString *) panelTitle
{
  return [NSString stringWithFormat: @"%@: %@",
                   [self labelForKey: @"View Mail"],
                   [self messageSubject]];
}

/* links (DUP to UIxMailPartViewer!) */

- (NSString *) linkToEnvelopeAddress: (NGImap4EnvelopeAddress *) _address
{
  // TODO: make some web-link, eg open a new compose panel?
  return [NSString stringWithFormat: @"mailto: %@", [_address baseEMail]];
}

- (NSString *) currentAddressLink
{
  return [self linkToEnvelopeAddress:[self currentAddress]];
}

/* fetching */

- (id) message
{
  return [[self clientObject] fetchCoreInfos];
}

- (BOOL) hasCC
{
  return [[[self clientObject] ccEnvelopeAddresses] count] > 0 ? YES : NO;
}

- (BOOL) hasBCC
{
  return [[[self clientObject] bccEnvelopeAddresses] count] > 0 ? YES : NO;
}

- (BOOL) hasReplyTo
{
  return [[[self clientObject] replyToEnvelopeAddresses] count] > 0 ? YES : NO;
}

/* viewers */

- (id) contentViewerComponent
{
  // TODO: I would prefer to flatten the body structure prior rendering,
  //       using some delegate to decide which parts to select for alternative.
  id info;
  
  info = [[self clientObject] bodyStructure];

  return [[context mailRenderingContext] viewerForBodyInfo:info];
}

/* actions */

- (id) defaultAction
{
  WOResponse *response;
  NSString *s;

  /* check etag to see whether we really must rerender */
  /*
    Note: There is one thing which *can* change for an existing message,
    those are the IMAP4 flags (and annotations, which we do not use).
    Since we don't render the flags, it should be OK, if this changes
    we must embed the flagging into the etag.
  */
  s = [[context request] headerForKey: @"if-none-match"];
  if (s)
    {
      if ([s rangeOfString:mailETag].length > 0) /* not perfectly correct */
        { 
          /* client already has the proper entity */
          // [self logWithFormat:@"MATCH: %@ (tag %@)", s, mailETag];
	  
          if (![[self clientObject] doesMailExist]) {
            return [NSException exceptionWithHTTPStatus:404 /* Not Found */
                                                 reason:@"message got deleted"];
          }
          
          response = [context response];
          [response setStatus: 304 /* Not Modified */];

          return response;
        }
    }
  
  if (![self message]) // TODO: redirect to proper error
    return [NSException exceptionWithHTTPStatus:404 /* Not Found */
			reason:@"did not find specified message!"];

  return self;
}

/* MDN */

- (BOOL) _userHasEMail: (NSString *) email
{
  NSArray *identities;
  NSString *identityEmail;
  SOGoMailAccount *account;
  int count, max;
  BOOL rc;

  rc = NO;

  account = [[self clientObject] mailAccountFolder];
  identities = [account identities];
  max = [identities count];
  for (count = 0; !rc && count < max; count++)
    {
      identityEmail = [[identities objectAtIndex: count]
                        objectForKey: @"email"];
      rc = [identityEmail isEqualToString: email];
    }

  return rc;
}

- (BOOL) _messageHasDraftOrMDNSentFlag
{
  NSArray *flags;
  NSDictionary *coreInfos;

  coreInfos = [[self clientObject] fetchCoreInfos];
  flags = [coreInfos objectForKey: @"flags"];

  return ([flags containsObject: @"draft"]
          || [flags containsObject: @"$mdnsent"]);
}

- (NSString *) _matchingIdentityEMail
{
  NSMutableArray *recipients;
  NSArray *headerRecipients;
  NSString *currentEMail;
  NGImap4EnvelopeAddress *address;
  NSInteger count, max;
  SOGoMailObject *co;

  if (!matchingIdentityEMail)
    {
      recipients = [NSMutableArray array];
      co = [self clientObject];
      headerRecipients = [co toEnvelopeAddresses];
      if ([headerRecipients count])
        [recipients addObjectsFromArray: headerRecipients];
      headerRecipients = [co ccEnvelopeAddresses];
      if ([headerRecipients count])
        [recipients addObjectsFromArray: headerRecipients];

      max = [recipients count];
      for (count = 0; !matchingIdentityEMail && count < max; count++)
        {
          address = [recipients objectAtIndex: count];
          currentEMail = [NSString stringWithFormat: @"%@@%@",
                                   [address mailbox],
                                   [address host]];
          if ([self _userHasEMail: currentEMail])
            {
              matchingIdentityEMail = currentEMail;
              [matchingIdentityEMail retain];
            }
        }
    }

  return matchingIdentityEMail;
}

- (NSString *) _domainFromEMail: (NSString *) email
{
  NSString *domain;
  NSRange separator;

  separator = [email rangeOfString: @"@"];
  if (separator.location != NSNotFound)
    domain = [email substringFromIndex: NSMaxRange (separator)];
  else
    domain = nil;

  return domain;
}

- (NSArray *) _userEMailDomains
{
  NSMutableArray *domains;
  NSArray *identities;
  NSString *email, *domain;
  SOGoMailAccount *account;
  NSInteger count, max;

  account = [[self clientObject] mailAccountFolder];
  identities = [account identities];
  max = [identities count];
  domains = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      email = [[identities objectAtIndex: count]
                objectForKey: @"email"];
      domain = [self _domainFromEMail: email];
      if (domain)
        [domains addObject: domain];
    }

  return domains;
}

- (BOOL) _senderIsInUserDomain: (NSDictionary *) headers
{
  NSString *sender, *senderDomain;
  BOOL rc;

  sender = [[headers objectForKey: @"from"] pureEMailAddress];
  senderDomain = [self _domainFromEMail: sender];
  if (senderDomain)
    rc = [[self _userEMailDomains] containsObject: senderDomain];
  else
    rc = NO;

  return rc;
}

- (NSString *) _receiptAction
{
  SOGoUserDefaults *ud;
  NSString *action;
  NSDictionary *headers;

  headers = [[self clientObject] mailHeaders];

  ud = [[context activeUser] userDefaults];
  if ([ud allowUserReceipt])
    {
      if ([self _matchingIdentityEMail])
        {
          if ([self _senderIsInUserDomain: headers])
            action = [ud userReceiptAnyAction];
          else
            action = [ud userReceiptOutsideDomainAction];
        }
      else
        action = [ud userReceiptNonRecipientAction];
    }
  else
    action = @"ignore";

  return action;
}

- (void) _flagMessageWithMDNSent
{
  [[self clientObject] addFlags: @"$MDNSent"];
}

- (void) _appendReceiptTextToBody: (NGMimeMultipartBody *) body
{
  NGMutableHashMap *map;
  NGMimeBodyPart *bodyPart;
  NSString *textPartFormat, *textPartMessage;

  map = [[NGMutableHashMap alloc] initWithCapacity: 1];
  [map setObject: @"text/plain; charset=utf-8; format=flowed"
          forKey: @"content-type"];

  bodyPart = [[NGMimeBodyPart alloc] initWithHeader: map];
  [map release];

  textPartFormat = [self labelForKey: @"This is a Return Receipt for the mail"
                         @" that you sent to %@.\n\nNote: This Return Receipt"
                         @" only acknowledges that the message was displayed"
                         @" on the recipient's computer. There is no"
                         @" guarantee that the recipient has read or"
                         @" understood the message contents."];
  textPartMessage = [NSString stringWithFormat: textPartFormat,
                              [self _matchingIdentityEMail]];
  [bodyPart setBody: [textPartMessage
                       dataUsingEncoding: NSUTF8StringEncoding]];
  [body addBodyPart: bodyPart];
  [bodyPart release];
}

- (void) _appendMDNToBody: (NGMimeMultipartBody *) body
{
  NGMutableHashMap *map;
  NGMimeBodyPart *bodyPart;
  NSString *messageId;
  NSMutableString *mdnPartMessage;

  map = [[NGMutableHashMap alloc] initWithCapacity: 3];
  [map addObject: @"message/disposition-notification; name=\"MDNPart2.txt\""
          forKey: @"content-type"];
  [map addObject: @"inline" forKey: @"content-disposition"];
  [map addObject: @"7bit" forKey: @"content-transfer-encoding"];

  bodyPart = [[NGMimeBodyPart alloc] initWithHeader: map];
  [map release];

  mdnPartMessage = [[NSMutableString alloc] initWithCapacity: 100];
  [mdnPartMessage appendFormat: @"Reporting-UA: SOGoMail %@\n", SOGoVersion];
  [mdnPartMessage appendFormat: @"Final-Recipient: rfc822;%@\n",
                  [self _matchingIdentityEMail]];
  messageId = [[self clientObject] messageId];
  [mdnPartMessage appendFormat: @"Original-Message-ID: %@\n",
                  messageId];
  [mdnPartMessage appendString: @"Disposition:"
                  @" manual-action/MDN-sent-manually; displayed"];
  [bodyPart setBody: [mdnPartMessage
                       dataUsingEncoding: NSASCIIStringEncoding]];
  [mdnPartMessage release];
  [body addBodyPart: bodyPart];
  [bodyPart release];
}

- (void) _appendHeadersToBody: (NGMimeMultipartBody *) body
{
  NGMutableHashMap *map;
  NGMimeBodyPart *bodyPart;
  NSDictionary *coreInfos;

  map = [[NGMutableHashMap alloc] initWithCapacity: 3];
  [map addObject: @"text/rfc822-headers; name=\"MDNPart3.txt\""
          forKey: @"content-type"];
  [map addObject: @"inline" forKey: @"content-disposition"];
  [map addObject: @"7bit" forKey: @"content-transfer-encoding"];

  bodyPart = [[NGMimeBodyPart alloc] initWithHeader: map];
  [map release];

  coreInfos = [[self clientObject] fetchCoreInfos];
  [bodyPart setBody: [coreInfos objectForKey: @"header"]];
  [body addBodyPart: bodyPart];
  [bodyPart release];
}

- (NGHashMap *) _receiptMessageHeaderTo: (NSString *) email
{
  NGMutableHashMap *map;
  NSString *subject;

  map = [[NGMutableHashMap alloc] initWithCapacity: 1];
  [map autorelease];
  [map setObject: email forKey: @"to"];
  [map setObject: [self _matchingIdentityEMail] forKey: @"from"];
  [map setObject: @"multipart/report; report-type=disposition-notification"
          forKey: @"content-type"];
  subject = [NSString stringWithFormat:
                     [self labelForKey: @"Return Receipt (displayed) - %@"],
                      [self messageSubject]];
  [map setObject: [subject asQPSubjectString: @"utf-8"]
          forKey: @"subject"];

  return map;
}

- (void) _sendEMailReceiptTo: (NSString *) email
{
  NGMimeMultipartBody *body;
  NGMimeMessage *message;
  NGMimeMessageGenerator *generator;
  SOGoDomainDefaults *dd;

  message = [NGMimeMessage
              messageWithHeader: [self _receiptMessageHeaderTo: email]];
  body = [[NGMimeMultipartBody alloc] initWithPart: message];
  [self _appendReceiptTextToBody: body];
  [self _appendMDNToBody: body];
  [self _appendHeadersToBody: body];
  [message setBody: body];
  [body release];

  dd = [[context activeUser] domainDefaults];

  generator = [NGMimeMessageGenerator new];
  [generator autorelease];

  if (![[SOGoMailer mailerWithDomainDefaults: dd]
                sendMailData: [generator generateMimeFromPart: message]
                toRecipients: [NSArray arrayWithObject: email]
                      sender: [self _matchingIdentityEMail]
           withAuthenticator: [self authenticatorInContext: context]
                   inContext: context])
    [self _flagMessageWithMDNSent];
}

- (NSString *) shouldAskReceipt
{
  NSDictionary *mailHeaders;
  NSString *email, *action;

  if (!shouldAskReceipt)
    {
      shouldAskReceipt = @"false";
      mailHeaders = [[self clientObject] mailHeaders];
      email = [mailHeaders objectForKey: @"disposition-notification-to"];
      if (!email)
        {
          email = [mailHeaders objectForKey: @"x-confirm-reading-to"];
          if (!email)
            email = [mailHeaders objectForKey: @"return-receipt-to"];
        }

      if (email)
        {
          if (![self _userHasEMail: email]
              && ![self _messageHasDraftOrMDNSentFlag])
            {
              action = [self _receiptAction];
              if ([action isEqualToString: @"ask"])
                {
                  shouldAskReceipt = @"true";
                  [self _flagMessageWithMDNSent];
                }
              else if ([action isEqualToString: @"send"])
                [self _sendEMailReceiptTo: email];
            }
        }
    }

  return shouldAskReceipt;
}

- (WOResponse *) sendMDNAction
{
  WOResponse *response;
  NSDictionary *mailHeaders;
  NSString *email, *action;

  mailHeaders = [[self clientObject] mailHeaders];
  email = [mailHeaders objectForKey: @"disposition-notification-to"];
  if (!email)
    {
      email = [mailHeaders objectForKey: @"x-confirm-reading-to"];
      if (!email)
        email = [mailHeaders objectForKey: @"return-receipt-to"];
    }

  /* We perform most of the validation steps that were done in
     -shouldAskReceipt in order to enforce consistency. */
  if (email)
    {
      if ([self _userHasEMail: email])
        response = [self responseWithStatus: 403
                                  andString: (@"One cannot send an MDN to"
                                              @" oneself.")];
      else
        {
          action = [self _receiptAction];
          if ([action isEqualToString: @"ask"])
            {
              [self _sendEMailReceiptTo: email];
              response = [self responseWithStatus: 204];
            }
          else
            response = [self responseWithStatus: 403
                                      andString: (@"No notification header found in"
                                                  @" original message.")];
        }
    }
  else
    response = [self responseWithStatus: 403
                              andString: (@"No notification header found in"
                                          @" original message.")];
  
  return response;
}

/* /MDN */

- (BOOL) mailIsDraft
{
  return [[self clientObject] isInDraftsFolder];
}

- (id) redirectToParentFolder
{
  id url;
  
  url = [[[self clientObject] container] baseURLInContext: context];

  return [self redirectToLocation: url];
}

/* generating response */

- (void) appendToResponse: (WOResponse *) _response
		inContext: (WOContext *) _ctx
{
  UIxMailRenderingContext *mctx;
 
  [[_ctx response] setHeader:mailETag forKey:@"etag"];

  mctx = [[UIxMailRenderingContext alloc] initWithViewer: self
					  context: _ctx];
  [_ctx pushMailRenderingContext: mctx];
  [mctx release];

  [super appendToResponse: _response inContext: _ctx];
  
  [[_ctx popMailRenderingContext] reset];
}

@end /* UIxMailView */
