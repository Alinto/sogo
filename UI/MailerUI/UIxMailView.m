/*
  Copyright (C) 2005-2019 Inverse inc.

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

#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WORequest.h>
#import <NGExtensions/NSException+misc.h>
#import <NGExtensions/NGHashMap.h>
#import <NGExtensions/NSString+misc.h>

#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMail/NGMailAddress.h>
#import <NGMail/NGMailAddressParser.h>
#import <NGMail/NGMimeMessage.h>
#import <NGMail/NGMimeMessageGenerator.h>

#import <NGImap4/NGImap4EnvelopeAddress.h>

#import <NGCards/NGVCard.h>

#import <Contacts/SOGoContactGCSEntry.h>
#import <Contacts/SOGoContactFolders.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoBuild.h>
#import <SOGo/SOGoMailer.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserFolder.h>
#import <Mailer/SOGoMailBodyPart.h>
#import <Mailer/SOGoMailObject.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailFolder.h>
#import <MailPartViewers/UIxMailRenderingContext.h> // cyclic
#import <MailPartViewers/UIxMailSizeFormatter.h>
#import <MailPartViewers/UIxMailPartViewer.h>

#import "WOContext+UIxMailer.h"
#import "UIxMailFormatter.h"

@interface UIxMailView : UIxComponent
{
  id currentAddress;
  NSNumber *shouldAskReceipt;
  NSString *matchingIdentityEMail;
  NSDictionary *attachment;
  NSArray *attachmentAttrs;
}

- (BOOL) mailIsDraft;
- (BOOL) mailIsTemplate;
- (NSNumber *) shouldAskReceipt;
- (NSString *) formattedDate;
- (NSString *) _matchingIdentityEMailOrDefault: (BOOL) useDefault;

@end

@implementation UIxMailView

static NSString *mailETag = nil;

+ (void) initialize
{
  mailETag = [[NSString alloc] initWithFormat:@"\"imap4url_%@_%@_%@\"",
                               SOGO_MAJOR_VERSION,
                               SOGO_MINOR_VERSION,
                               SOGO_SUBMINOR_VERSION];
  //NSLog (@"Note: using constant etag for mail viewer: '%@'", mailETag);
}

- (void) dealloc
{
  [matchingIdentityEMail release];
  [attachment release];
  [attachmentAttrs release];
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

- (void) setAttachment: (NSDictionary *) newAttachment
{
  ASSIGN (attachment, newAttachment);
}

- (NSDictionary *) attachment
{
  return attachment;
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

/* attachment helper */

- (NSArray *) attachmentAttrs
{
  if (!attachmentAttrs)
  {
    ASSIGN (attachmentAttrs, [[self clientObject] fetchFileAttachmentKeys]);
  }

  return attachmentAttrs;
}

- (NSFormatter *) sizeFormatter
{
  return [UIxMailSizeFormatter sharedMailSizeFormatter];
}

- (NSString *) formattedDate
{
  NSFormatter *formatter;

  formatter = [[self context] mailDateFormatter];

  return [formatter stringForObjectValue: [[self clientObject] date]];
}

/* viewers */

//
// TODO: I would prefer to flatten the body structure prior rendering,
//       using some delegate to decide which parts to select for alternative.
//
- (id) contentViewerComponent
{
  NSMutableDictionary *attachmentIds;
  NSString *filename, *from;
  NSDictionary *attributes;
  id info, viewer;

  unsigned int count, max;

  info = [[self clientObject] bodyStructure];

  viewer = [[context mailRenderingContext] viewerForBodyInfo: info];
  [viewer setBodyInfo: info];

  if (![[self clientObject] isEncrypted])
    {
      max = [[self attachmentAttrs] count];
      attachmentIds = [NSMutableDictionary dictionaryWithCapacity: max];
      for (count = 0; count < max; count++)
        {
          attributes = [[self attachmentAttrs] objectAtIndex: count];

          // Don't allow XML inline attachments
          if (![[attributes objectForKey: @"mimetype"] hasSuffix: @"xml"] &&
              ![[[attributes objectForKey: @"filename"] lowercaseString] hasSuffix: @"svg"])
            {
              filename = [NSString stringWithFormat: @"<%@>", [attributes objectForKey: @"filename"]];
              [attachmentIds setObject: [attributes objectForKey: @"url"]
                                forKey: filename];
              if ([[attributes objectForKey: @"bodyId"] length])
                [attachmentIds setObject: [attributes objectForKey: @"url"]
                                  forKey: [attributes objectForKey: @"bodyId"]];
            }
        }
      // Attachment IDs will be decoded in UIxMailPartEncryptedViewer for
      // S/MIME encrypted emails with file attachments.
      [viewer setAttachmentIds: attachmentIds];
    }
  else
    [viewer setAttachmentIds: [NSMutableDictionary dictionary]];

  // If we are looking at a S/MIME signed mail which wasn't sent
  // by our actual active user, we update the certificate of that
  // sender in the user's address book
  from = [[[[self clientObject] fromEnvelopeAddresses] lastObject] baseEMail];

  if (![[context activeUser] hasEmail: from] &&
      [[self clientObject] isSigned])
    {
      SOGoContactFolders *contactFolders;
      NSData *p7s;
      id card;

      // FIXME: it might not always be part #2
      p7s = [[[self clientObject] lookupImap4BodyPartKey: @"2" inContext: context] fetchBLOB];
      contactFolders = [[[context activeUser] homeFolderInContext: context]
                                  lookupName: @"Contacts"
                                   inContext: context
                                     acquire: NO];
      card = [contactFolders contactForEmail: from];
      if ([card isKindOfClass: [SOGoContactGCSEntry class]])
        {
          [[card vCard] setCertificate: p7s];
          [card save];
        }
    }

  return viewer;
}

/* actions */

- (id <WOActionResults>) defaultAction
{
  return [self view: NO];
}

- (id <WOActionResults>) viewRawAction
{
  return [self view: YES];
}

- (id <WOActionResults>) view: (BOOL)raw
{
  WOResponse *response;
  NSMutableDictionary *data;
  NSArray *addresses;
  SOGoMailObject *co;
  SOGoUserDefaults *ud;
  UIxEnvelopeAddressFormatter *addressFormatter;
  UIxMailRenderingContext *mctx;
  id viewer, renderedPart;

  co = [self clientObject];
  ud = [[context activeUser] userDefaults];
  addressFormatter = [context mailEnvelopeAddressFormatter];

  mctx = [[UIxMailRenderingContext alloc] initWithViewer: self context: context];
  [context pushMailRenderingContext: mctx];
  [mctx release];

  /* check etag to see whether we really must rerender */
  /*
    Note: There is one thing which *can* change for an existing message,
    those are the IMAP4 flags (and annotations, which we do not use).
    Since we don't render the flags, it should be OK, if this changes
    we must embed the flagging into the etag.

    2015-12-09: We disable caching for now. Let's do this right soon
    by taking into account IMAP flags and the Accepted/Declined/etc.
    state of an even with an IMIP invitation. We should perhaps even
    store the state as an IMAP flag.
  */
  //s = [[context request] headerForKey: @"if-none-match"];
  //if (s)
  // if (0)
  //   {
  //     if ([s rangeOfString:mailETag].length > 0) /* not perfectly correct */
  //       {
  //         /* client already has the proper entity */
  //         // [self logWithFormat:@"MATCH: %@ (tag %@)", s, mailETag];
	  
  //         if (![co doesMailExist])
  //           {
  //             data = [NSDictionary dictionaryWithObject: [self labelForKey: @"Message got deleted"]
  //                                                forKey: @"message"];
  //             return [self responseWithStatus: 404 /* Not Found */
  //                       andJSONRepresentation: data];
  //           }
          
  //         response = [self responseWithStatus: 304];

  //         return response;
  //       }
  //   }
  
  if (![self message]) // TODO: redirect to proper error
    {
      data = [NSDictionary dictionaryWithObject: [self labelForKey: @"Did not find specified message"]
                                         forKey: @"message"];
      return [self responseWithStatus: 404 /* Not Found */
                andJSONRepresentation: data];
    }

  viewer = [self contentViewerComponent]; // set attachmentIds for common parts
  
  if (raw && ([viewer isKindOfClass: NSClassFromString(@"UIxMailPartHTMLViewer")]
      || [viewer isKindOfClass: NSClassFromString(@"UIxMailPartAlternativeViewer")])) {
    // In this case, disable html mail content modification by SOGo
    [viewer activateRawContent];
  }
  renderedPart = [viewer renderedPart];   // set attachmentIds for encrypted & TNEF parts

  data = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                       [self shouldAskReceipt], @"shouldAskReceipt",
                       [NSNumber numberWithBool: [self mailIsDraft]], @"isDraft",
                       [NSNumber numberWithBool: [self mailIsTemplate]], @"isTemplate",
                       renderedPart, @"parts",
                       nil];
  if ([self formattedDate])
    [data setObject: [self formattedDate] forKey: @"date"];
  if ([self messageSubject])
    [data setObject: [[self messageSubject] stringWithoutHTMLInjection: YES] forKey: @"subject"];
  if ((addresses = [addressFormatter dictionariesForArray: [co fromEnvelopeAddresses]]))
    [data setObject: addresses forKey: @"from"];
  if ((addresses = [addressFormatter dictionariesForArray: [co toEnvelopeAddresses]]))
    [data setObject: addresses forKey: @"to"];
  if ((addresses = [addressFormatter dictionariesForArray: [co ccEnvelopeAddresses]]))
    [data setObject: addresses forKey: @"cc"];
  if ((addresses = [addressFormatter dictionariesForArray: [co bccEnvelopeAddresses]]))
    [data setObject: addresses forKey: @"bcc"];
  if ((addresses = [addressFormatter dictionariesForArray: [co replyToEnvelopeAddresses]]))
    [data setObject: addresses forKey: @"reply-to"];

  if ([ud mailAutoMarkAsReadDelay] == 0)
    // Mark message as read
    [co addFlags: @"seen"];

  [data setObject: [NSNumber numberWithBool: [co read]] forKey: @"isRead"];

  response = [self responseWithStatus: 200
                andJSONRepresentation: data];

  [response setHeader: mailETag forKey: @"etag"];

  [[context popMailRenderingContext] reset];

  return response;
}

- (id <WOActionResults>) archiveAttachmentsAction
{
  NSString *name;
  SOGoMailObject *co;

  co = [self clientObject];
  name = [NSString stringWithFormat: @"%@-%@.zip",
                  [self labelForKey: @"attachments"], [co nameInContainer]];

  return [co archiveAllFilesinArchiveNamed: name];
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
      rc = ([identityEmail caseInsensitiveCompare: email] == NSOrderedSame);
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
  return [self _matchingIdentityEMailOrDefault: YES];
}

- (NSString *) _matchingIdentityEMailOrDefault: (BOOL) useDefault
{
  NSMutableArray *recipients;
  NSArray *headerRecipients;
  NSString *currentEMail, *email;
  NGImap4EnvelopeAddress *address;
  NSInteger count, max;
  SOGoMailObject *co;

  email = nil;

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

  if (matchingIdentityEMail)
    {
      email = matchingIdentityEMail;
    }
  else if (useDefault)
    {
      // This can happen if we receive the message because we are
      // in the list of bcc. In this case, we take the first
      // identity associated with the account.
      email = [[[[[self clientObject] mailAccountFolder] identities] objectAtIndex: 0] objectForKey: @"email"];
    }

  return email;
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
      if ([self _matchingIdentityEMailOrDefault: NO])
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
  NSString *subject, *from;
  NGMutableHashMap *map;

  map = [[NGMutableHashMap alloc] initWithCapacity: 1];
  [map autorelease];
  [map setObject: email forKey: @"to"];

  from = [self _matchingIdentityEMail];
  
  if (from)
    [map setObject: from forKey: @"from"];
  
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
                   inContext: context
               systemMessage: YES])
    [self _flagMessageWithMDNSent];
}

- (NSNumber *) shouldAskReceipt
{
  NGMailAddress *mailAddress;
  NSDictionary *mailHeaders;
  NSString *email, *action;

  if (!shouldAskReceipt)
    {
      shouldAskReceipt = [NSNumber numberWithBool: NO];
      mailHeaders = [[self clientObject] mailHeaders];
      email = [mailHeaders objectForKey: @"disposition-notification-to"];
      if (!email)
        {
          email = [mailHeaders objectForKey: @"x-confirm-reading-to"];
          if (!email)
            email = [mailHeaders objectForKey: @"return-receipt-to"];
        }

      // email here can be "foo@bar.com" or "Foo Bar <foo@bar.com>"
      // we must extract the actual email address
      mailAddress = [[NGMailAddressParser mailAddressParserWithString: email] parse];
      
      if ([mailAddress isKindOfClass: [NGMailAddress class]])
        email = [mailAddress address];
      else
        email = nil;
      
      if (email)
        {
          if (![self _userHasEMail: email]
              && ![self _messageHasDraftOrMDNSentFlag])
            {
              action = [self _receiptAction];
              if ([action isEqualToString: @"ask"])
                {
                  shouldAskReceipt = [NSNumber numberWithBool: YES];
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
  NSDictionary *mailHeaders, *jsonResponse;
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
        {
          jsonResponse = [NSDictionary dictionaryWithObject: [self labelForKey: @"One cannot send an MDN to oneself."]
                                                     forKey: @"message"];
          response = [self responseWithStatus: 403 andJSONRepresentation: jsonResponse];
        }
      else
        {
          action = [self _receiptAction];
          if ([action isEqualToString: @"ask"])
            {
              [self _sendEMailReceiptTo: email];
              response = [self responseWithStatus: 204];
            }
          else
            {
              jsonResponse = [NSDictionary dictionaryWithObject: [self labelForKey: @"No notification header found in original message."]
                                                         forKey: @"message"];
              response = [self responseWithStatus: 403 andJSONRepresentation: jsonResponse];
            }
        }
    }
  else
    {
      jsonResponse = [NSDictionary dictionaryWithObject: [self labelForKey: @"No notification header found in original message."]
                                                 forKey: @"message"];
      response = [self responseWithStatus: 403 andJSONRepresentation: jsonResponse];
    }

  return response;
}

/* /MDN */

- (BOOL) mailIsDraft
{
  return [[self clientObject] isInDraftsFolder];
}

- (BOOL) mailIsTemplate
{
  return [[self clientObject] isInTemplatesFolder];
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
