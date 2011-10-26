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
   - proper handling of multipart/alternative and multipart/related mime
   body types
   - calendar invitations
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
#import <Mailer/SOGoMailFolder.h>
#import <Mailer/NSString+Mail.h>

#import "MAPIStoreAttachment.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreMailFolder.h"
#import "MAPIStoreMIME.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreTypes.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "SOGoMAPIMemMessage.h"

#import "MAPIStoreMailVolatileMessage.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

static NSString *recIds[] = { @"to", @"cc", @"bcc" };

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

- (NGMimeBodyPart *) asMIMEBodyPart;

@end

@implementation MAPIStoreAttachment (MAPIStoreMIME)

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

/* FIXME: copied from SOGoDraftMessage... */
- (NSString *) _quoteSpecials: (NSString *) address
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

- (NSArray *) _attachmentBodyParts
{
  NSMutableArray *attachmentBodyParts;
  NSArray *keys;
  MAPIStoreAttachment *attachment;
  NSUInteger count, max;
  NGMimeBodyPart *mimePart;

  keys = [attachmentParts allKeys];
  max = [keys count];
  attachmentBodyParts = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      attachment = [attachmentParts
                     objectForKey: [keys objectAtIndex: count]];
      mimePart = [attachment asMIMEBodyPart];
      if (mimePart)
        [attachmentBodyParts addObject: mimePart];
    }

  return attachmentBodyParts;
}

- (NSData *) _generateMailData
{
  NSDictionary *mailProperties;
  NSMutableString *subject;
  NSString *from, *recId, *messageId, *subjectData, *charset,
    *mailContentType, *textContentType;
  NSData *textData, *messageData;
  NSArray *list, *attParts;
  NSNumber *codePage;
  NSCalendarDate *date;
  NSDictionary *recipients;
  NGMimeMessage *message;  
  NGMutableHashMap *map, *textMap;
  NGMimeBodyPart *textBodyPart;
  NGMimeMultipartBody *multiPart;
  NGMimeMessageGenerator *generator;
  NSUInteger count, max;
  struct mapistore_connection_info *connInfo;
  SOGoUser *activeUser;

  mailProperties = [sogoObject properties];

  /* headers */
  map = [[NGMutableHashMap alloc] initWithCapacity: 16];

  connInfo = [[self context] connectionInfo];
  activeUser
    = [SOGoUser
        userWithLogin: [NSString stringWithUTF8String: connInfo->username]];

  from = [NSString stringWithFormat: @"%@ <%@>",
                   [activeUser cn], [[activeUser allEmails] objectAtIndex: 0]];
  [map setObject: [self _quoteSpecials: from] forKey: @"from"];

  /* save the recipients */
  recipients = [mailProperties objectForKey: @"recipients"];
  if (recipients)
    {
      for (count = 0; count < 3; count++)
	{
	  recId = recIds[count];
	  list = [recipients objectForKey: recId];
	  if ([list count] > 0)
	    [map setObjects: [list keysWithFormat: @"%{fullName} <%{email}>"]
                     forKey: recId];
	}
    }
  else
    [self errorWithFormat: @"message without recipients"];

  subject = [NSMutableString stringWithCapacity: 128];
  subjectData = [mailProperties objectForKey: MAPIPropertyKey (PR_SUBJECT_PREFIX_UNICODE)];
  if (subjectData)
    [subject appendString: subjectData];
  subjectData = [mailProperties objectForKey: MAPIPropertyKey (PR_NORMALIZED_SUBJECT_UNICODE)];
  if (subjectData)
    [subject appendString: subjectData];
  [map setObject: [subject asQPSubjectString: @"utf-8"] forKey: @"subject"];

  messageId = [mailProperties objectForKey: MAPIPropertyKey (PR_INTERNET_MESSAGE_ID_UNICODE)];
  if ([messageId length])
    [map setObject: messageId forKey: @"message-id"];

  date = [mailProperties objectForKey: MAPIPropertyKey (PR_CLIENT_SUBMIT_TIME)];
  if (date)
    [map addObject: [date rfc822DateString] forKey: @"date"];
  [map addObject: @"1.0" forKey: @"MIME-Version"];

  message = [[[NGMimeMessage alloc] initWithHeader: map] autorelease];
  [map release];

  textData = [mailProperties objectForKey: MAPIPropertyKey (PR_HTML)];
  if (textData)
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
      textContentType = [NSString stringWithFormat: @"text/html; charset=%@",
                                  charset];
    }
  else
    {
      textContentType = @"text/plain; charset=utf-8";
      textData = [[mailProperties
                    objectForKey: MAPIPropertyKey (PR_BODY_UNICODE)]
                   dataUsingEncoding: NSUTF8StringEncoding];
    }

  attParts = [self _attachmentBodyParts];
  max = [attParts count];
  if (max > 0)
    {
      mailContentType = @"multipart/mixed";
      multiPart = [[NGMimeMultipartBody alloc] initWithPart: message];

      /* text part */
      textMap = [[NGMutableHashMap alloc] initWithCapacity: 1];
      [textMap setObject: textContentType forKey: @"content-type"];
      textBodyPart = [NGMimeBodyPart bodyPartWithHeader: textMap];
      [textBodyPart setBody: textData];
      [textMap release];

      [multiPart addBodyPart: textBodyPart];
      for (count = 0; count < max; count++)
        [multiPart addBodyPart: [attParts objectAtIndex: count]];

      [message setBody: multiPart];
      [multiPart release];
    }
  else
    {
      mailContentType = textContentType;
      [message setBody: textData];
    }
  [map setObject: mailContentType forKey: @"content-type"];

  /* mime message generation */
  generator = [NGMimeMessageGenerator new];
  messageData = [generator generateMimeFromPart: message];
  [generator release];
  [messageData writeToFile: @"/tmp/mimegen.eml" atomically: NO];

  return messageData;
}

- (int) submitWithFlags: (enum SubmitFlags) flags
{
  NSDictionary *mailProperties, *recipients;
  NSData *message;
  NSMutableData *cleanedMessage;
  NSMutableArray *recipientEmails;
  NSArray *list;
  NSString *recId;
  NSRange r1, r2;
  NSUInteger count;
  struct mapistore_connection_info *connInfo;
  SOGoUser *activeUser;
  NSString *from;
  // SOGoMailFolder *sentFolder;
  SOGoDomainDefaults *dd;
  NSException *error;
  MAPIStoreMapping *mapping;

  /* send mail */

  message = [self _generateMailData];
  cleanedMessage = [message mutableCopy];
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

  mailProperties = [sogoObject properties];
  recipientEmails = [NSMutableArray arrayWithCapacity: 32];
  recipients = [mailProperties objectForKey: @"recipients"];
  for (count = 0; count < 3; count++)
    {
      recId = recIds[count];
      list = [recipients objectForKey: recId];
      [recipientEmails
        addObjectsFromArray: [list objectsForKey: @"email"
                                  notFoundMarker: nil]];
    }

  connInfo = [[self context] connectionInfo];
  activeUser = [SOGoUser userWithLogin: [NSString stringWithUTF8String: connInfo->username]];

  [self logWithFormat: @"recipients: %@", recipientEmails];
  dd = [activeUser domainDefaults];
  from = [[activeUser allEmails] objectAtIndex: 0];
  error = [[SOGoMailer mailerWithDomainDefaults: dd]
                sendMailData: cleanedMessage
                toRecipients: recipientEmails
                      sender: from];
  if (error)
    [self logWithFormat: @"an error occurred: '%@'", error];

  mapping = [[self context] mapping];
  [mapping unregisterURLWithID: [self objectId]];
  [self setIsNew: NO];
  [self resetProperties];
  [[self container] cleanupCaches];

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

  messageData = [self _generateMailData];

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
      mapping = [[self context] mapping];
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
