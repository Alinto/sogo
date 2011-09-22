/* MAPIStoreMemMailMessage.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <NGExtensions/NSString+Encoding.h>
#import <NGExtensions/NGHashMap.h>
#import <NGMail/NGMimeMessage.h>
#import <NGMail/NGMimeMessageGenerator.h>
#import <NGImap4/NGImap4Client.h>
#import <NGImap4/NGImap4Connection.h>
#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/NSString+Utilities.h>
#import <Mailer/SOGoMailFolder.h>
#import <Mailer/NSString+Mail.h>

#import "MAPIStoreMapping.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreTypes.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "SOGoMemMessage.h"

#import "MAPIStoreMemMailMessage.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

Class NSNumberK;

@implementation MAPIStoreMemMailMessage

+ (void) initialize
{
  NSNumberK = [NSNumber class];
}

- (int) setProperties: (struct SRow *) aRow
{
  int rc;

  rc = [super setProperties: aRow];
  if (rc == MAPISTORE_SUCCESS)
    {
      [sogoObject appendProperties: newProperties];
      [newProperties removeAllObjects];
    }

 return rc;
}

- (int) getProperty: (void **) data
            withTag: (enum MAPITAGS) propTag
           inMemCtx: (TALLOC_CTX *) memCtx
{
  id value;
  int rc;
 
  value = [[sogoObject properties] objectForKey: MAPIPropertyKey (propTag)];
  if (value)
    rc = [value getMAPIValue: data forTag: propTag inMemCtx: memCtx];
  else
    rc = [super getProperty: data withTag: propTag inMemCtx: memCtx];

  return rc;
}

- (int) getPrMessageClass: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"IPM.Note" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getAvailableProperties: (struct SPropTagArray **) propertiesP
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  NSArray *keys;
  NSUInteger count, max;
  NSString *key;
  struct SPropTagArray *properties;

  keys = [[sogoObject properties] allKeys];
  max = [keys count];

  properties = talloc_zero (NULL, struct SPropTagArray);
  properties->cValues = max;
  properties->aulPropTag = talloc_array (properties, enum MAPITAGS, max);
  for (count = 0; count < max; count++)
    {
      key = [keys objectAtIndex: count];
      if ([key isKindOfClass: NSNumberK])
        {
#if (GS_SIZEOF_LONG == 4)
          properties->aulPropTag[count] = [[keys objectAtIndex: count] unsignedLongValue];
#elif (GS_SIZEOF_INT == 4)
          properties->aulPropTag[count] = [[keys objectAtIndex: count] unsignedIntValue];
#endif
        }
    }

  *propertiesP = properties;

  return MAPISTORE_SUCCESS;  
}

- (NSArray *) attachmentsKeysMatchingQualifier: (EOQualifier *) qualifier
                              andSortOrderings: (NSArray *) sortOrderings
{
  NSDictionary *attachments;
  NSArray *keys;
  NSString *key, *newKey;
  NSUInteger count, max, aid;
  MAPIStoreAttachment *attachment;

  attachments = [[sogoObject properties] objectForKey: @"attachments"];
  keys = [attachments allKeys];
  max = [keys count];
  if (max > 0)
    {
      aid = [keys count];
      for (count = 0; count < max; count++)
        {
          key = [keys objectAtIndex: count];
          attachment = [attachments objectForKey: key];
          newKey = [NSString stringWithFormat: @"%ul", (aid + count)];
          [attachmentParts setObject: attachment forKey: newKey];
        }
    }

  return [super attachmentKeysMatchingQualifier: qualifier
                               andSortOrderings: sortOrderings];
}

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


- (void) save
{
  NSDictionary *properties;
  NSString *from, *to, *messageId, *subject, *body, *folderName, *flag,
    *newIdString, *charset;
  NSNumber *codePage;
  NSCalendarDate *date;
  NGMimeMessage *message;  
  NGMutableHashMap *map;
  NGMimeMessageGenerator *generator;
  NSData *htmlData, *messageData;
  NGImap4Connection *connection;
  NGImap4Client *client;
  SOGoMailFolder *containerFolder;
  NSDictionary *result, *responseResult;
  MAPIStoreMapping *mapping;
  uint64_t mid;

  properties = [sogoObject properties];

  /* headers */
  from = [self _quoteSpecials: [properties objectForKey: MAPIPropertyKey (PR_SENT_REPRESENTING_EMAIL_ADDRESS_UNICODE)]];
  to = [self _quoteSpecials: [properties objectForKey: MAPIPropertyKey (PR_DISPLAY_TO_UNICODE)]];
  subject = [properties objectForKey: MAPIPropertyKey (PR_SUBJECT_UNICODE)];
  date = [properties objectForKey: MAPIPropertyKey (PR_CLIENT_SUBMIT_TIME)];
  messageId = [properties objectForKey: MAPIPropertyKey (PR_INTERNET_MESSAGE_ID_UNICODE)];

  map = [[[NGMutableHashMap alloc] initWithCapacity:16] autorelease];
  if ([to length])
    [map setObject: to forKey: @"to"];
  if ([from length])
    [map setObject: from forKey: @"from"];
  if ([subject length])
    [map setObject: [subject asQPSubjectString: @"utf-8"]
            forKey: @"subject"];
  if ([messageId length])
    [map setObject: messageId forKey: @"message-id"];
  if (date)
    [map addObject: [date rfc822DateString] forKey: @"date"];
  [map addObject: @"1.0" forKey: @"MIME-Version"];

  message = [[[NGMimeMessage alloc] initWithHeader: map] autorelease];

  /* body */
  htmlData = [properties objectForKey: MAPIPropertyKey (PR_HTML)];
  if (htmlData)
    {
      /* charset */
      charset = @"us-ascii";
      codePage = [properties objectForKey: MAPIPropertyKey (PR_INTERNET_CPID)];
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

      body = [NSString stringWithData: htmlData
                   usingEncodingNamed: charset];
      [map setObject: [NSString stringWithFormat: @"text/html; charset=%@",
                                charset]
              forKey: @"content-type"];
      [message setBody: body];
    }
  else
    {
      body = [properties objectForKey: MAPIPropertyKey (PR_BODY_UNICODE)];
      if (body)
        {
          [map setObject: @"text/plain; charset=utf-8"
               forKey: @"content-type"];
          [message setBody: body];
        }
    }

  /* mime message generation */
  generator = [NGMimeMessageGenerator new];
  messageData = [generator generateMimeFromPart: message];
  [generator release];

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
}

@end
