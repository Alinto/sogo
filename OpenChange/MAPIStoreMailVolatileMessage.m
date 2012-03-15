/* MAPIStoreMailVolatileMessage.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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

/* TODO:
   - calendar invitations
   - merge some code in a common module with SOGoDraftObject
*/

#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <NGExtensions/NGHashMap.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+Encoding.h>
#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMail/NGMimeMessage.h>
#import <NGMail/NGMimeMessageGenerator.h>
#import <NGImap4/NGImap4Client.h>
#import <NGImap4/NGImap4Connection.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoMailer.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserManager.h>
#import <Mailer/SOGoMailFolder.h>
#import <Mailer/NSString+Mail.h>

#import "MAPIStoreAttachment.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreMailFolder.h"
#import "MAPIStoreMIME.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreSamDBUtils.h"
#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "SOGoMAPIVolatileMessage.h"

#import "MAPIStoreMailVolatileMessage.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

static NSString *recTypes[] = { @"orig", @"to", @"cc", @"bcc" };

//
// Useful extension that comes from Pantomime which is also
// released under the LGPL. We should eventually merge
// this with the same category found in SOPE's NGSmtpClient.m
// or simply drop sope-mime in favor of Pantomime
//
@interface NSMutableData (DataCleanupExtension)

- (NSRange) rangeOfCString: (const char *) theCString;
- (NSRange) rangeOfCString: (const char *) theCString
		  options: (unsigned int) theOptions
		    range: (NSRange) theRange;
@end

@implementation NSMutableData (DataCleanupExtension)

- (NSRange) rangeOfCString: (const char *) theCString
{
  return [self rangeOfCString: theCString
	       options: 0
	       range: NSMakeRange(0,[self length])];
}

-(NSRange) rangeOfCString: (const char *) theCString
		  options: (unsigned int) theOptions
		    range: (NSRange) theRange
{
  const char *b, *bytes;
  int i, len, slen;
  
  if (!theCString)
    {
      return NSMakeRange(NSNotFound,0);
    }
  
  bytes = [self bytes];
  len = [self length];
  slen = strlen(theCString);
  
  b = bytes;
  
  if (len > theRange.location + theRange.length)
    {
      len = theRange.location + theRange.length;
    }

  if (theOptions == NSCaseInsensitiveSearch)
    {
      i = theRange.location;
      b += i;
      
      for (; i <= len-slen; i++, b++)
	{
	  if (!strncasecmp(theCString,b,slen))
	    {
	      return NSMakeRange(i,slen);
	    }
	}
    }
  else
    {
      i = theRange.location;
      b += i;
      
      for (; i <= len-slen; i++, b++)
	{
	  if (!memcmp(theCString,b,slen))
	    {
	      return NSMakeRange(i,slen);
	    }
	}
    }
  
  return NSMakeRange(NSNotFound,0);
}

@end

@interface MAPIStoreAttachment (MAPIStoreMIME)

- (BOOL) hasContentId;
- (NGMimeBodyPart *) asMIMEBodyPart;

@end

@implementation MAPIStoreAttachment (MAPIStoreMIME)

- (BOOL) hasContentId
{
  return ([properties
            objectForKey: MAPIPropertyKey (PR_ATTACH_CONTENT_ID_UNICODE)]
          != nil);
}

- (NGMimeBodyPart *) asMIMEBodyPart
{
  NGMimeBodyPart *bodyPart = nil;
  NSString *filename, *mimeType, *baseDisposition, *contentType,
    *contentDisposition, *contentId;
  NSData *content;
  struct mapistore_connection_info *connInfo;
  SOGoDomainDefaults *dd;
  SOGoUser *activeUser;
  NGMutableHashMap *map;

  content = [properties objectForKey: MAPIPropertyKey (PR_ATTACH_DATA_BIN)];
  if (content)
    {
      filename
        = [properties
            objectForKey: MAPIPropertyKey (PR_ATTACH_LONG_FILENAME_UNICODE)];
      if (![filename length])
        filename
          = [properties
            objectForKey: MAPIPropertyKey (PR_ATTACH_FILENAME_UNICODE)];
      
      mimeType = [properties
                   objectForKey: MAPIPropertyKey (PR_ATTACH_MIME_TAG_UNICODE)];
      if (!mimeType && [filename length])
        mimeType = [[MAPIStoreMIME sharedMAPIStoreMIME]
                     mimeTypeForExtension: [filename pathExtension]];
      if (!mimeType)
        mimeType = @"application/octet-stream";
      
      if ([mimeType hasPrefix: @"text/"])
        {
          connInfo = [[self context] connectionInfo];
          activeUser = [SOGoUser userWithLogin: [NSString stringWithUTF8String: connInfo->username]];
          dd = [activeUser domainDefaults];
          baseDisposition = ([dd mailAttachTextDocumentsInline]
                             ? @"inline" : @"attachment");
        }
      else if ([mimeType hasPrefix: @"image/"] || [mimeType hasPrefix: @"message"])
        baseDisposition = @"inline";
      else
        baseDisposition = @"attachment";
      
      if ([filename length] > 0)
        {
          contentType = [NSString stringWithFormat: @"%@; name=\"%@\"",
                                  mimeType, filename];
          contentDisposition = [NSString stringWithFormat: @"%@; filename=\"%@\"",
                                         baseDisposition, filename];
        }
      else
        {
          contentType = mimeType;
          contentDisposition = baseDisposition;
        }
      
      map = [[NGMutableHashMap alloc] initWithCapacity: 16];
      [map addObject: contentType forKey: @"content-type"];
      [map addObject: contentDisposition forKey: @"content-disposition"];
      contentId = [properties
                     objectForKey: MAPIPropertyKey (PR_ATTACH_CONTENT_ID_UNICODE)];
      if (contentId)
        [map setObject: [NSString stringWithFormat: @"<%@>", contentId]
                forKey: @"content-id"];
      bodyPart = [NGMimeBodyPart bodyPartWithHeader: map];
      [bodyPart setBody: content];
      [map release];
    }
  else
    [self errorWithFormat: @"no content for attachment"];

  return bodyPart;
}

@end

@implementation MAPIStoreMailVolatileMessage

- (void) getMessageData: (struct mapistore_message **) dataPtr
               inMemCtx: (TALLOC_CTX *) memCtx
{
  NSArray *recipients;
  NSUInteger count, max, recipientsMax, p, current;
  NSString *username, *cn, *email;
  NSData *entryId;
  NSDictionary *allRecipients, *dict, *contactInfos;
  SOGoUserManager *mgr;
  struct ldb_context *samCtx;
  struct mapistore_message *msgData;
  struct mapistore_message_recipient *recipient;
  enum ulRecipClass type;

  samCtx = [[self context] connectionInfo]->sam_ctx;

  [super getMessageData: &msgData inMemCtx: memCtx];

  allRecipients = [[sogoObject properties] objectForKey: @"recipients"];
  msgData->columns = set_SPropTagArray (msgData, 9,
                                        PR_OBJECT_TYPE,
                                        PR_DISPLAY_TYPE,
                                        PR_7BIT_DISPLAY_NAME_UNICODE,
                                        PR_SMTP_ADDRESS_UNICODE,
                                        PR_SEND_INTERNET_ENCODING,
                                        PR_RECIPIENT_DISPLAY_NAME_UNICODE,
                                        PR_RECIPIENT_FLAGS,
                                        PR_RECIPIENT_ENTRYID,
                                        PR_RECIPIENT_TRACKSTATUS);
  
  /* Retrieve recipients from the message */
  max = ([[allRecipients objectForKey: @"orig"] count]
         + [[allRecipients objectForKey: @"to"] count]
         + [[allRecipients objectForKey: @"cc"] count]
         + [[allRecipients objectForKey: @"bcc"] count]);

  mgr = [SOGoUserManager sharedUserManager];
  msgData->recipients_count = max;
  msgData->recipients = talloc_array (msgData, struct mapistore_message_recipient, max);
  current = 0;
  for (type = 0; type < 4; type++)
    {
      recipients = [allRecipients objectForKey: recTypes[type]];
      recipientsMax = [recipients count];
      for (count = 0; count < recipientsMax; count++)
        {
          recipient = msgData->recipients + current;
          recipient->type = type;

          dict = [recipients objectAtIndex: count];
          cn = [dict objectForKey: @"fullName"];
          email = [dict objectForKey: @"email"];

          contactInfos = [mgr contactInfosForUserWithUIDorEmail: email];
          if (contactInfos)
            {
              username = [contactInfos objectForKey: @"c_uid"];
              recipient->username = [username asUnicodeInMemCtx: msgData];
              entryId = MAPIStoreInternalEntryId (samCtx, username);
            }
          else
            {
              recipient->username = NULL;
              entryId = MAPIStoreExternalEntryId (cn, email);
            }

          /* properties */
          p = 0;
          recipient->data = talloc_array (msgData, void *, msgData->columns->cValues);
          memset (recipient->data, 0, msgData->columns->cValues * sizeof (void *));

          // PR_OBJECT_TYPE = MAPI_MAILUSER (see MAPI_OBJTYPE)
          recipient->data[p] = MAPILongValue (msgData, MAPI_MAILUSER);
          p++;

          // PR_DISPLAY_TYPE = DT_MAILUSER (see MS-NSPI)
          recipient->data[p] = MAPILongValue (msgData, 0);
          p++;

          // PR_7BIT_DISPLAY_NAME_UNICODE
          recipient->data[p] = [cn asUnicodeInMemCtx: msgData];
          p++;

          // PR_SMTP_ADDRESS_UNICODE
          recipient->data[p] = [email asUnicodeInMemCtx: msgData];
          p++;

          // PR_SEND_INTERNET_ENCODING = 0x00060000 (plain text, see OXCMAIL)
          recipient->data[p] = MAPILongValue (msgData, 0x00060000);
          p++;

          // PR_RECIPIENT_DISPLAY_NAME_UNICODE
          recipient->data[p] = [cn asUnicodeInMemCtx: msgData];
          p++;

          // PR_RECIPIENT_FLAGS
          recipient->data[p] = MAPILongValue (msgData, 0x01);
          p++;

          // PR_RECIPIENT_ENTRYID
          recipient->data[p] = [entryId asBinaryInMemCtx: msgData];
          p++;

          // PR_RECIPIENT_TRACKSTATUS
          recipient->data[p] = MAPILongValue (msgData, 0x00);
          p++;

          current++;
        }
    }
  *dataPtr = msgData;
}

static inline NSString *
MakeRecipientString (NSDictionary *recipient)
{
  NSString *fullName, *email, *fullEmail;

  fullName = [recipient objectForKey: @"fullName"];
  email = [recipient objectForKey: @"email"];
  if ([email length] > 0)
    {
      if ([fullName length] > 0)
        fullEmail = [NSString stringWithFormat: @"%@ <%@>", fullName, email];
      else
        fullEmail = email;
    }
  else
    {
      NSLog (@"recipient not generated from record: %@", recipient);
      fullEmail = nil;
    }

  return fullEmail;
}

static inline NSArray *
MakeRecipientsList (NSArray *recipients)
{
  NSMutableArray *list;
  NSUInteger count, max;
  NSString *recipient;

  max = [recipients count];
  list = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      recipient = MakeRecipientString ([recipients objectAtIndex: count]);
      if (recipient)
        [list addObject: recipient];
    }

  return list;
}

static NSString *
QuoteSpecials (NSString *address)
{
  NSString *result, *part, *s2;
  int i, len;

  // We want to correctly send mails to recipients such as :
  // foo.bar
  // foo (bar) <foo@zot.com>
  // bar, foo <foo@zot.com>
  if ([address indexOf: '('] >= 0 || [address indexOf: ')'] >= 0
      || [address indexOf: '<'] >= 0 || [address indexOf: '>'] >= 0
      || [address indexOf: '@'] >= 0 || [address indexOf: ','] >= 0
      || [address indexOf: ';'] >= 0 || [address indexOf: ':'] >= 0
      || [address indexOf: '\\'] >= 0 || [address indexOf: '"'] >= 0
      || [address indexOf: '.'] >= 0
      || [address indexOf: '['] >= 0 || [address indexOf: ']'] >= 0)
    {
      // We search for the first instance of < from the end
      // and we quote what was before if we need to
      len = [address length];
      i = -1;
      while (len--)
        if ([address characterAtIndex: len] == '<')
          {
            i = len;
            break;
          }

      if (i > 0)
        {
          part = [address substringToIndex: i - 1];
          s2 = [[part stringByReplacingString: @"\\" withString: @"\\\\"]
                     stringByReplacingString: @"\"" withString: @"\\\""];
          result = [NSString stringWithFormat: @"\"%@\" %@", s2, [address substringFromIndex: i]];
        }
      else
        {
          s2 = [[address stringByReplacingString: @"\\" withString: @"\\\\"]
                     stringByReplacingString: @"\"" withString: @"\\\""];
          result = [NSString stringWithFormat: @"\"%@\"", s2];
        }
    }
  else
    result = address;

  return result;
}

static inline void
FillMessageHeadersFromProperties (NGMutableHashMap *headers,
                                  NSDictionary *mailProperties,
                                  struct mapistore_connection_info *connInfo)
{
  NSMutableString *subject;
  NSString *from, *recId, *messageId, *subjectData;
  NSArray *list;
  NSCalendarDate *date;
  NSDictionary *recipients;
  NSUInteger count;
  SOGoUser *activeUser;

  activeUser
    = [SOGoUser
        userWithLogin: [NSString stringWithUTF8String: connInfo->username]];

  from = [NSString stringWithFormat: @"%@ <%@>",
                   [activeUser cn], [[activeUser allEmails] objectAtIndex: 0]];
  [headers setObject: QuoteSpecials (from) forKey: @"from"];

  /* save the recipients */
  recipients = [mailProperties objectForKey: @"recipients"];
  if (recipients)
    {
      for (count = 1; count < 3; count++)
	{
	  recId = recTypes[count];
	  list = MakeRecipientsList ([recipients objectForKey: recId]);
          [headers setObjects: list forKey: recId];
	}
    }
  else
    NSLog (@"message without recipients");

  subject = [NSMutableString stringWithCapacity: 128];
  subjectData = [mailProperties objectForKey: MAPIPropertyKey (PR_SUBJECT_PREFIX_UNICODE)];
  if (subjectData)
    [subject appendString: subjectData];
  subjectData = [mailProperties objectForKey: MAPIPropertyKey (PR_NORMALIZED_SUBJECT_UNICODE)];
  if (subjectData)
    [subject appendString: subjectData];
  [headers setObject: [subject asQPSubjectString: @"utf-8"] forKey: @"subject"];

  messageId = [mailProperties objectForKey: MAPIPropertyKey (PR_INTERNET_MESSAGE_ID_UNICODE)];
  if ([messageId length])
    [headers setObject: messageId forKey: @"message-id"];

  date = [mailProperties objectForKey: MAPIPropertyKey (PR_CLIENT_SUBMIT_TIME)];
  if (date)
    [headers addObject: [date rfc822DateString] forKey: @"date"];
  [headers addObject: @"1.0" forKey: @"MIME-Version"];
}

static NSArray *
MakeAttachmentParts (NSDictionary *attachmentParts, BOOL withContentId)
{
  NSMutableArray *attachmentMimeParts;
  NSArray *keys;
  MAPIStoreAttachment *attachment;
  NSUInteger count, max;
  NGMimeBodyPart *mimePart;

  keys = [attachmentParts allKeys];
  max = [keys count];
  attachmentMimeParts = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      attachment = [attachmentParts
                     objectForKey: [keys objectAtIndex: count]];
      if ([attachment hasContentId] == withContentId)
        {
          mimePart = [attachment asMIMEBodyPart];
          if (mimePart)
            [attachmentMimeParts addObject: mimePart];
        }
    }

  return attachmentMimeParts;
}

static inline id
MakeTextPlainBody (NSDictionary *mailProperties, NSString **contentType)
{
  id textPlainBody;

  textPlainBody = [[mailProperties
                      objectForKey: MAPIPropertyKey (PR_BODY_UNICODE)]
                    dataUsingEncoding: NSUTF8StringEncoding];
  *contentType = @"text/plain; charset=utf-8";

  return textPlainBody;
}

static inline id
MakeTextHtmlBody (NSDictionary *mailProperties, NSDictionary *attachmentParts,
                  NSString **contentType)
{
  id textHtmlBody;
  NSData *htmlBody;
  NSString *charset, *htmlContentType;
  NSArray *parts;
  NSNumber *codePage;
  NGMimeBodyPart *htmlBodyPart;
  NGMutableHashMap *headers;
  NSUInteger count, max;

  htmlBody = [mailProperties objectForKey: MAPIPropertyKey (PR_HTML)];
  if (htmlBody)
    {
      /* charset */
      codePage = [mailProperties objectForKey: MAPIPropertyKey (PR_INTERNET_CPID)];
      switch ([codePage intValue])
        {
        case 20127:
          charset = @"us-ascii";
          break;
        case 28605:
          charset = @"iso-8859-15";
          break;
        case 65001:
          charset = @"utf-8";
          break;
        case 28591:
        default:
          charset = @"iso-8859-1";
        }
      htmlContentType = [NSString stringWithFormat: @"text/html; charset=%@",
                                  charset];

      parts = MakeAttachmentParts (attachmentParts, YES);
      max = [parts count];
      if (max > 0)
        {
          textHtmlBody = [NGMimeMultipartBody new];
          [textHtmlBody autorelease];

          headers = [[NGMutableHashMap alloc] initWithCapacity: 1];
          [headers setObject: htmlContentType forKey: @"content-type"];
          htmlBodyPart = [NGMimeBodyPart bodyPartWithHeader: headers];
          [htmlBodyPart setBody: htmlBody];
          [headers release];
          [textHtmlBody addBodyPart: htmlBodyPart];

          for (count = 0; count < max; count++)
            [textHtmlBody addBodyPart: [parts objectAtIndex: count]];

          *contentType = @"multipart/related";
        }
      else
        {
          textHtmlBody = htmlBody;
          *contentType = htmlContentType;
        }
    }
  else
    textHtmlBody = nil;

  return textHtmlBody;
}

static inline id
MakeTextPartBody (NSDictionary *mailProperties, NSDictionary *attachmentParts,
                  NSString **contentType)
{
  id textBody, textPlainBody, textHtmlBody;
  NSString *textPlainContentType, *textHtmlContentType;
  NGMutableHashMap *headers;
  NGMimeBodyPart *bodyPart;

  textPlainBody = MakeTextPlainBody (mailProperties, &textPlainContentType);
  textHtmlBody = MakeTextHtmlBody (mailProperties, attachmentParts, &textHtmlContentType);
  if (textPlainBody)
    {
      if (textHtmlBody)
        {
          textBody = [NGMimeMultipartBody new];
          [textBody autorelease];

          headers = [[NGMutableHashMap alloc] initWithCapacity: 1];
          [headers setObject: textHtmlContentType forKey: @"content-type"];
          bodyPart = [NGMimeBodyPart bodyPartWithHeader: headers];
          [bodyPart setBody: textHtmlBody];
          [headers release];
          [textBody addBodyPart: bodyPart];

          headers = [[NGMutableHashMap alloc] initWithCapacity: 1];
          [headers setObject: textPlainContentType forKey: @"content-type"];
          bodyPart = [NGMimeBodyPart bodyPartWithHeader: headers];
          [bodyPart setBody: textPlainBody];
          [headers release];
          [textBody addBodyPart: bodyPart];

          *contentType = @"multipart/alternative";
        }
      else
        {
          textBody = textPlainBody;
          *contentType = textPlainContentType;
        }
    }
  else
    {
      textBody = textHtmlBody;
      *contentType = textHtmlContentType;
    }

  return textBody;
}

static id
MakeMessageBody (NSDictionary *mailProperties, NSDictionary *attachmentParts,
                 NSString **contentType)
{
  id messageBody, textBody;
  NSString *textContentType;
  NSArray *parts;
  NGMimeBodyPart *textBodyPart;
  NGMutableHashMap *headers;
  NSUInteger count, max;

  textBody = MakeTextPartBody (mailProperties, attachmentParts,
                               &textContentType);

  parts = MakeAttachmentParts (attachmentParts, NO);
  max = [parts count];
  if (max > 0)
    {
      messageBody = [NGMimeMultipartBody new];
      [messageBody autorelease];

      if (textBody)
        {
          headers = [[NGMutableHashMap alloc] initWithCapacity: 1];
          [headers setObject: textContentType forKey: @"content-type"];
          textBodyPart = [NGMimeBodyPart bodyPartWithHeader: headers];
          [textBodyPart setBody: textBody];
          [headers release];
          [messageBody addBodyPart: textBodyPart];
        }

      for (count = 0; count < max; count++)
        [messageBody addBodyPart: [parts objectAtIndex: count]];

      *contentType = @"multipart/mixed";
    }
  else
    {
      messageBody = textBody;
      *contentType = textContentType;
    }

  return messageBody;
}

- (NGMimeMessage *) _generateMessage
{
  NSDictionary *mailProperties;
  NSString *contentType;
  NGMimeMessage *message;  
  NGMutableHashMap *headers;
  id messageBody;

  mailProperties = [sogoObject properties];

  headers = [[NGMutableHashMap alloc] initWithCapacity: 16];
  FillMessageHeadersFromProperties (headers, mailProperties,
                                    [[self context] connectionInfo]);
  message = [[NGMimeMessage alloc] initWithHeader: headers];
  [message autorelease];
  [headers release];

  messageBody = MakeMessageBody (mailProperties, attachmentParts, &contentType);
  if (messageBody)
    {
      [headers setObject: contentType forKey: @"content-type"];
      [message setBody: messageBody];
    }

  return message;
}

- (NSData *) _generateMailDataWithBcc: (BOOL) withBcc
{
  NGMimeMessage *message;
  NGMimeMessageGenerator *generator;
  NSData *messageData;
  NSMutableData *cleanedMessage;
  NSRange r1, r2;

  /* mime message generation */
  generator = [NGMimeMessageGenerator new];
  message = [self _generateMessage];
  messageData = [generator generateMimeFromPart: message];
  [generator release];

  if (!withBcc)
    {
      cleanedMessage = [messageData mutableCopy];
      [cleanedMessage autorelease];
      r1 = [cleanedMessage rangeOfCString: "\r\n\r\n"];
      r1 = [cleanedMessage rangeOfCString: "\r\nbcc: "
                                  options: 0
                                    range: NSMakeRange(0,r1.location-1)];
      if (r1.location != NSNotFound)
        {
          // We search for the first \r\n AFTER the Bcc: header and
          // replace the whole thing with \r\n.
          r2 = [cleanedMessage rangeOfCString: "\r\n"
                                      options: 0
                                        range: NSMakeRange(NSMaxRange(r1)+1,[cleanedMessage length]-NSMaxRange(r1)-1)];
          [cleanedMessage replaceBytesInRange: NSMakeRange(r1.location, NSMaxRange(r2)-r1.location)
                                    withBytes: "\r\n"
                                       length: 2];
        }
      messageData = cleanedMessage;
    }

  // [messageData writeToFile: @"/tmp/mimegen.eml" atomically: NO];

  return messageData;
}

- (int) submitWithFlags: (enum SubmitFlags) flags
{
  NSDictionary *mailProperties, *recipients;
  NSData *messageData;
  NSMutableArray *recipientEmails;
  NSArray *list;
  NSString *recId, *from, *msgClass;
  NSUInteger count;
  SOGoUser *activeUser;
  // SOGoMailFolder *sentFolder;
  SOGoDomainDefaults *dd;
  NSException *error;
  MAPIStoreMapping *mapping;

  mailProperties = [sogoObject properties];
  msgClass = [mailProperties objectForKey: MAPIPropertyKey (PidTagMessageClass)];
  if ([msgClass isEqualToString: @"IPM.Note"]) /* we skip invitation replies */
    {
      /* send mail */

      messageData = [self _generateMailDataWithBcc: NO];
      
      mailProperties = [sogoObject properties];
      recipientEmails = [NSMutableArray arrayWithCapacity: 32];
      recipients = [mailProperties objectForKey: @"recipients"];
      for (count = 0; count < 3; count++)
        {
          recId = recTypes[count];
          list = [recipients objectForKey: recId];
          [recipientEmails
            addObjectsFromArray: [list objectsForKey: @"email"
                                      notFoundMarker: nil]];
        }

      activeUser = [[self context] activeUser];

      [self logWithFormat: @"recipients: %@", recipientEmails];
      dd = [activeUser domainDefaults];
      from = [[activeUser allEmails] objectAtIndex: 0];
      error = [[SOGoMailer mailerWithDomainDefaults: dd]
                sendMailData: messageData
                toRecipients: recipientEmails
                      sender: from];
      if (error)
        [self logWithFormat: @"an error occurred: '%@'", error];

      mapping = [self mapping];
      [mapping unregisterURLWithID: [self objectId]];
      [self setIsNew: NO];
      [properties removeAllObjects];
      [[self container] cleanupCaches];
    }
  else
    [self logWithFormat: @"skipping submit of message with class '%@'",
          msgClass];

  return MAPISTORE_SUCCESS;
}

- (void) save
{
  NSString *folderName, *flag, *newIdString;
  NSData *changeKey, *messageData;
  NGImap4Connection *connection;
  NGImap4Client *client;
  SOGoMailFolder *containerFolder;
  NSDictionary *result, *responseResult;
  MAPIStoreMapping *mapping;
  uint64_t mid;

  messageData = [self _generateMailDataWithBcc: YES];

  /* appending to imap folder */
  containerFolder = [container sogoObject];
  connection = [containerFolder imap4Connection];
  client = [connection client];
  folderName = [connection imap4FolderNameForURL: [containerFolder imap4URL]];
  result = [client append: messageData toFolder: folderName
                withFlags: [NSArray arrayWithObjects: @"seen", nil]];
  if ([[result objectForKey: @"result"] boolValue])
    {
      /* we reregister the new message URL with the id mapper */
      responseResult = [[result objectForKey: @"RawResponse"]
                         objectForKey: @"ResponseResult"];
      flag = [responseResult objectForKey: @"flag"];
      newIdString = [[flag componentsSeparatedByString: @" "]
                      objectAtIndex: 2];
      mid = [self objectId];
      mapping = [self mapping];
      [mapping unregisterURLWithID: mid];
      [sogoObject setNameInContainer: [NSString stringWithFormat: @"%@.eml", newIdString]];
      [mapping registerURL: [self url] withID: mid];
    }

  /* synchronise the cache and update the change key with the one provided by
     the client */
  [(MAPIStoreMailFolder *) container synchroniseCache];
  changeKey = [[sogoObject properties]
                objectForKey: MAPIPropertyKey (PR_CHANGE_KEY)];
  if (changeKey)
    [(MAPIStoreMailFolder *) container
        setChangeKey: changeKey forMessageWithKey: [self nameInContainer]];
}

@end
