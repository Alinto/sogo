/* MAPIStoreMailMessage.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Ludovic Marcotte <lmarcotte@inverse.ca>
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
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSValue.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSObject+Values.h>
#import <NGExtensions/NSString+Encoding.h>
#import <NGImap4/NGImap4Client.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4EnvelopeAddress.h>
#import <NGMail/NGMailAddress.h>
#import <NGMail/NGMailAddressParser.h>
#import <NGMail/NGMimeMessageGenerator.h>
#import <NGCards/iCalCalendar.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUserManager.h>
#import <Mailer/NSData+Mail.h>
#import <Mailer/SOGoMailBodyPart.h>
#import <Mailer/SOGoMailObject.h>
#import <Mailer/NSDictionary+Mail.h>
#import <Mailer/NSString+Mail.h>

#import "Codepages.h"
#import "NSData+MAPIStore.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "MAPIStoreAppointmentWrapper.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreFolder.h"
#import "MAPIStoreMailAttachment.h"
#import "MAPIStoreMailFolder.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreSamDBUtils.h"
#import "MAPIStoreSharingMessage.h"
#import "MAPIStoreTypes.h"
#import "MAPIStoreUserContext.h"

#import "MAPIStoreMailMessage.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

#define BODY_CONTENT_TEXT 0
#define BODY_CONTENT_HTML 1

@class iCalCalendar, iCalEvent;

static Class NSExceptionK, MAPIStoreSharingMessageK;
static NSArray *acceptedMimeTypes;

@interface NSString (MAPIStoreMIME)

- (NSString *) _strippedBodyKey;

@end

@implementation NSString (MAPIStoreMIME)

- (NSString *) _strippedBodyKey
{
  NSRange bodyRange;
  NSString *strippedKey;

  bodyRange = [self rangeOfString: @"body.peek["];
  if (bodyRange.length > 0)
    {
      strippedKey = [self substringFromIndex: NSMaxRange (bodyRange)];
      strippedKey = [strippedKey substringToIndex: [strippedKey length] - 1];
    }
  else
    strippedKey = nil;

  return strippedKey;
}

@end

@implementation SOGoMailObject (MAPIStoreExtension)

- (Class) mapistoreMessageClass
{
  return [MAPIStoreMailMessage class];
}

@end

@implementation MAPIStoreMailMessage

+ (void) initialize
{
  NSExceptionK = [NSException class];
  MAPIStoreSharingMessageK = [MAPIStoreSharingMessage class];
  acceptedMimeTypes = [[NSArray alloc] initWithObjects: @"text/calendar",
                                                        @"application/ics",
                                                        @"text/html",
                                                        @"text/plain",
                                                        nil];
}

- (id) init
{
  if ((self = [super init]))
    {
      bodyContentKeys = nil;
      bodyPartsEncodings = nil;
      bodyPartsCharsets = nil;
      bodyPartsMimeTypes = nil;
      bodyPartsMixed = nil;

      headerSetup = NO;
      bodySetup = NO;
      bodyContent = nil;
      
      mailIsEvent = NO;
      mailIsMeetingRequest = NO;
      mailIsSharingObject = NO;
      headerCharset = nil;
      headerMimeType = nil;

      appointmentWrapper = nil;
    }

  return self;
}

- (void) dealloc
{
  [bodyContentKeys release];
  [bodyPartsEncodings release];
  [bodyPartsCharsets release];
  [bodyPartsMimeTypes release];
  [bodyPartsMixed release];
  
  [bodyContent release];
  
  [headerMimeType release];
  [headerCharset release];
  [appointmentWrapper release];
  [super dealloc];
}

- (NSString *) subject
{
  return [sogoObject decodedSubject];
}

- (NSDate *) creationTime
{
  return [sogoObject date];
}

- (NSDate *) lastModificationTime
{
  return [sogoObject date];
}

- (enum mapistore_error) getAvailableProperties: (struct SPropTagArray **) propertiesP
                                       inMemCtx: (TALLOC_CTX *) memCtx
{
  BOOL listedProperties[65536];
  NSUInteger count;
  uint16_t propId;

  if (mailIsSharingObject)
    {
      memset (listedProperties, NO, 65536 * sizeof (BOOL));
      [super getAvailableProperties: propertiesP inMemCtx: memCtx];
      for (count = 0; count < (*propertiesP)->cValues; count++)
        {
          propId = ((*propertiesP)->aulPropTag[count] >> 16) & 0xffff;
          listedProperties[propId] = YES;
        }
      [MAPIStoreSharingMessage fillAvailableProperties: *propertiesP
                                        withExclusions: listedProperties];
      return MAPISTORE_SUCCESS;
    }
  else
    return [super getAvailableProperties: propertiesP inMemCtx: memCtx];
}

static NSComparisonResult
_compareBodyKeysByPriority (id entry1, id entry2, void *data)
{
  NSComparisonResult result;
  NSArray *keys;
  NSString *data1, *data2;
  NSUInteger count1, count2;

  keys = data;

  data1 = [entry1 objectForKey: @"mimeType"];
  count1 = [keys indexOfObject: data1];
  data2 = [entry2 objectForKey: @"mimeType"];
  count2 = [keys indexOfObject: data2];

  if (count1 == count2)
    {
      data1 = [entry1 objectForKey: @"key"];
      count1 = [data1 countOccurrencesOfString: @"."];
      data2 = [entry2 objectForKey: @"key"];
      count2 = [data2 countOccurrencesOfString: @"."];
      if (count1 == count2)
        {
          data1 = [data1 _strippedBodyKey];
          count1 = [data1 intValue];
          data2 = [data2 _strippedBodyKey];
          count2 = [data2 intValue];
          if (count1 == count2)
            result = NSOrderedSame;
          else if (count1 < count2)
            result = NSOrderedAscending;
          else
            result = NSOrderedDescending;
        }
      else if (count1 < count2)
        result = NSOrderedAscending;
      else
        result = NSOrderedDescending;
    }
  else if (count1 < count2)
    result = NSOrderedAscending;
  else
    result = NSOrderedDescending;

  return result;
}

- (void) _fetchHeaderData
{
  MAPIStoreSharingMessage *sharingMessage;
  NSMutableArray *keys;
  NSUInteger keysCount;
  NSDictionary *partHeaderData, *parameters;
  NSString *sharingHeader;

  keys = [NSMutableArray array];
  [sogoObject addRequiredKeysOfStructure: [sogoObject bodyStructure]
                                    path: @""
                                 toArray: keys
                           acceptedTypes: acceptedMimeTypes
                                withPeek: YES];
  [keys sortUsingFunction: _compareBodyKeysByPriority context: acceptedMimeTypes];
  keysCount = [keys count];
  if (keysCount > 0)
    {
      NSUInteger i;
      BOOL hasHtml = NO;
      BOOL hasText = NO;
      
      bodyContentKeys = [[NSMutableArray alloc] initWithCapacity: keysCount];
      bodyPartsEncodings = [[NSMutableDictionary alloc] initWithCapacity: keysCount];
      bodyPartsCharsets = [[NSMutableDictionary alloc] initWithCapacity: keysCount];
      bodyPartsMimeTypes = [[NSMutableDictionary alloc] initWithCapacity: keysCount];
      bodyPartsMixed = [[NSMutableDictionary alloc] initWithCapacity: keysCount];
      
      for (i = 0; i < keysCount; i++)
        {
          NSDictionary *bodyStructureKey;
          NSString *key;
          NSString *mimeType;
          BOOL      mixedPart;
          NSString *strippedKey;
          NSString *encoding;
          NSString *charset;
          NSDictionary *partParameters;
          NSString *multipart;

          bodyStructureKey = [keys objectAtIndex: i];
          key = [bodyStructureKey objectForKey: @"key"];
          if (key == nil)
            continue;
          
          [bodyContentKeys addObject: key];

          strippedKey =  [key _strippedBodyKey];
          partHeaderData = [sogoObject lookupInfoForBodyPart: strippedKey];

          partParameters = [partHeaderData objectForKey: @"parameterList"];
          encoding = [partHeaderData objectForKey: @"encoding"];
          charset = [partParameters objectForKey: @"charset"];
          mimeType = [bodyStructureKey objectForKey: @"mimeType"];

          /* multipart/mixed is the default type.
             multipart/alternative is the only other type of multipart supported now.
          */
          multipart = [bodyStructureKey objectForKey: @"multipart"];
          if ([multipart isEqualToString: @""])
            {
              mixedPart = NO;
            }
          else
            {
              mixedPart = !([multipart isEqualToString: @"multipart/alternative"] ||
                            [multipart isEqualToString: @"multipart/related"]);
            }

          if (encoding)
            [bodyPartsEncodings setObject: encoding forKey: key];
          if (charset)
            [bodyPartsCharsets setObject: charset forKey: key];
          if (mimeType)
            {
              [bodyPartsMimeTypes setObject: mimeType forKey: key];
              if ([mimeType isEqualToString: @"text/plain"])
                hasText = YES;
              else if ([mimeType isEqualToString: @"text/html"])
                hasHtml = YES;
            }
          [bodyPartsMixed setObject: [NSNumber numberWithBool: mixedPart] forKey: key];

          if (i == 0)
             {
               ASSIGN (headerMimeType, mimeType);
               parameters = partParameters;
             }

          if (charset)
            {
              if (headerCharset == nil)
                {
                  ASSIGN (headerCharset, charset);
                }
              else if (![headerCharset isEqualToString: charset])
                {
                  /* Because we have different charsets we will encode all in UTF-8 */
                  ASSIGN (headerCharset, @"utf-8");
                }
            }

        }

      if (!hasHtml || !hasText)
        {
          NSArray *bodyPartsMixedKeys = [bodyPartsMixed allKeys];
          for (i = 0; i < [keys count]; i++)
            {
              NSString *key = [bodyPartsMixedKeys objectAtIndex: i];
              [bodyPartsMixed setObject: [NSNumber numberWithBool: NO] forKey: key];
            }
        }


      if ([headerMimeType isEqualToString: @"text/calendar"]
          || [headerMimeType isEqualToString: @"application/ics"])
      {
        mailIsEvent = YES;
        if ([[parameters objectForKey: @"method"] isEqualToString: @"REQUEST"])
          mailIsMeetingRequest = YES;
      }
      else
        {
          sharingHeader = [[sogoObject mailHeaders] objectForKey: @"x-ms-sharing-localtype"];
          if (sharingHeader)
            {
              mailIsSharingObject = YES;
              /* It is difficult to subclass this in folder class, that's why
                 a sharing object is a proxy in a mail message */
              sharingMessage = [[MAPIStoreSharingMessage alloc]
                                 initWithMailHeaders: [sogoObject mailHeaders]
                                   andConnectionInfo: [[self context] connectionInfo]
                                         fromMessage: self];
              [self addProxy: sharingMessage];
              [sharingMessage release];
            }
        }
    }

  headerSetup = YES;
}

- (void) _fetchBodyData
{
  if (!headerSetup)
    [self _fetchHeaderData];

  if (!bodyContent && bodyContentKeys)
    {
      id result;      
      NSString *key;
      NSEnumerator *enumerator;
      NSMutableData *htmlContent;
      NSMutableData *textContent;
      NSStringEncoding headerEncoding;
      
      result = [sogoObject fetchParts: bodyContentKeys];
      result = [[result valueForKey: @"RawResponse"] objectForKey: @"fetch"];

      htmlContent = [[NSMutableData alloc] initWithCapacity: 0];
      textContent = [[NSMutableData alloc] initWithCapacity: 0];

      headerEncoding = [NSString stringEncodingForEncodingNamed: headerCharset];
      
      enumerator = [bodyContentKeys objectEnumerator];
      while ((key = [enumerator nextObject]))
        {
          NSString *noPeekKey = [key stringByReplacingOccurrencesOfString: @"body.peek"
                                                               withString: @"body"];          
          
          NSData *content = [[result objectForKey: noPeekKey] objectForKey: @"data"];
          if (content == nil)
            continue;
          NSString *mimeType = [bodyPartsMimeTypes objectForKey: key];
          if (mimeType == nil)
            continue;          
          NSString *contentEncoding = [bodyPartsEncodings objectForKey: key];
          if (contentEncoding == nil)
            contentEncoding = @"7-bit";

          /* We should provide a case for each of the types in acceptedMimeTypes */
          if (!mailIsEvent)
            {
              NSString *charset;
              NSStringEncoding charsetEncoding;
              NSString *stringValue; 
              BOOL html;
              BOOL mixed = [[bodyPartsMixed objectForKey: key] boolValue];
              if ([mimeType isEqualToString: @"text/html"])
                {
                  html = YES;
                }
              else if ([mimeType isEqualToString: @"text/plain"])
                {
                  html = NO;
                }
              else
                {
                  [self warnWithFormat: @"Unsupported MIME type for non-event body part: %@.",
                        mimeType];
                  continue;
                }
                          
              content = [content bodyDataFromEncoding: contentEncoding];
              charset = [bodyPartsCharsets objectForKey: key];

              stringValue = nil;
              if (charset)
                {
                  charsetEncoding = [NSString stringEncodingForEncodingNamed: charset];
                  if ((charsetEncoding == headerEncoding) || !headerEncoding)
                    {
                      if (html)
                        [htmlContent appendData: content];
                      else
                        [textContent appendData: content];
                    }
                  else
                    {
                      stringValue = [content bodyStringFromCharset: charset];
                      if (html)
                        [htmlContent appendData: [stringValue dataUsingEncoding: headerEncoding]];
                      else
                        [textContent appendData: [stringValue dataUsingEncoding: headerEncoding]];
                    }                  

                  if (mixed)
                    {
                      // We must add it also to the other mail representation
                      if (html)
                        {
                          // TODO: html conversion to text
                          if (stringValue && headerEncoding)
                            [textContent appendData: [stringValue dataUsingEncoding: headerEncoding]];
                          else
                            [textContent appendData: content];
                        }
                      else
                        {
                          if (headerEncoding)
                            {
                              if (stringValue == nil)
                                stringValue = [content bodyStringFromCharset: charset];

                              stringValue = [stringValue stringByReplacingOccurrencesOfString: @"\n"            
                                                                                   withString: @"<br/>"];
                              [htmlContent appendData: [stringValue dataUsingEncoding: headerEncoding]];
                            }
                          else
                            {
                              [htmlContent appendData: content];
                            }
                        }
                    }
                }
              else
                {
                  /* Without charset we cannot mangle the text, so we add as it stands */
                  if (html || mixed)
                    [htmlContent appendData: content];
                  if (!html || mixed)
                    [textContent appendData: content];
                }

            }
          else if ([mimeType isEqualToString: @"text/calendar"] ||
                   [mimeType isEqualToString: @"application/ics"])
            {
              content = [content bodyDataFromEncoding: contentEncoding];
              [textContent appendData: content];
            }
          else
            {
              [self warnWithFormat: @"Unsupported combination for event body part. MIME type: %@",
                    mimeType];
            }
        }

      NSArray *newBodyContent = [[NSArray alloc] initWithObjects: textContent, htmlContent, nil];
      ASSIGN (bodyContent, newBodyContent);
    }

  bodySetup = YES;
}

- (NSArray*) getBodyContent
{
  if (!bodySetup)
    [self _fetchBodyData];
  return bodyContent;
}

- (MAPIStoreAppointmentWrapper *) _appointmentWrapper
{
  NSData *textContent;
  NSArray *events, *from;
  iCalCalendar *calendar;
  iCalEvent *event;
  NSString *stringValue, *senderEmail;
  MAPIStoreContext *context;

  if (!appointmentWrapper)
    {
      if (!bodySetup)
        [self _fetchBodyData];

      textContent = [bodyContent objectAtIndex: BODY_CONTENT_TEXT];
      stringValue = [textContent bodyStringFromCharset: headerCharset];
      calendar = [iCalCalendar parseSingleFromSource: stringValue];
      events = [calendar events];
      if ([events count] > 0)
        {
          event = [events objectAtIndex: 0];
          from = [sogoObject fromEnvelopeAddresses];
          if ([from count] > 0)
            senderEmail = [[from objectAtIndex: 0] email];
          else
            senderEmail = nil;
          context = [self context];
          appointmentWrapper = [MAPIStoreAppointmentWrapper
                                 wrapperWithICalEvent: event
                                              andUser: [context activeUser]
                                       andSenderEmail: senderEmail
                                   withConnectionInfo: [context connectionInfo]];
          [appointmentWrapper retain];
        }
    }

  return appointmentWrapper;
}

- (enum mapistore_error) getPidTagChangeKey: (void **) data
                                   inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc = MAPISTORE_SUCCESS;
  NSData *changeKey;
  MAPIStoreMailFolder *parentFolder;
  NSString *nameInContainer;

  if (isNew)
    rc = MAPISTORE_ERR_NOT_FOUND;
  else
    {
      parentFolder = (MAPIStoreMailFolder *)[self container];
      nameInContainer = [self nameInContainer];
      changeKey = [parentFolder changeKeyForMessageWithKey: nameInContainer];
      if (!changeKey)
        {
          [self warnWithFormat: @"attempting to get change key"
                @" by synchronising folder..."];
          [(MAPIStoreMailFolder *) container synchroniseCache];
          [parentFolder synchroniseCache];
          changeKey = [parentFolder changeKeyForMessageWithKey: nameInContainer];
          if (changeKey)
            [self logWithFormat: @"got one"];
          else
            {
              [self errorWithFormat: @"still nothing. We crash!"];
              abort ();
            }
        }
      *data = [changeKey asBinaryInMemCtx: memCtx];
    }

  return rc;
}

- (enum mapistore_error) getPidTagPredecessorChangeList: (void **) data
                                               inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc = MAPISTORE_SUCCESS;
  NSData *changeList;

  if (isNew)
    rc = MAPISTORE_ERR_NOT_FOUND;
  else
    {
      changeList = [(MAPIStoreMailFolder *)[self container]
                   predecessorChangeListForMessageWithKey: [self nameInContainer]];
      if (!changeList)
        {
          [self warnWithFormat: @"attempting to get predecessor change list"
                @" by synchronising folder..."];
          [(MAPIStoreMailFolder *) container synchroniseCache];
          changeList = [(MAPIStoreMailFolder *)[self container]
                       predecessorChangeListForMessageWithKey: [self nameInContainer]];
          if (changeList)
            [self logWithFormat: @"got one"];
          else
            {
              [self errorWithFormat: @"still nothing. We crash!"];
              abort ();
            }
        }
      *data = [changeList asBinaryInMemCtx: memCtx];
    }

  return rc;
}

- (uint64_t) objectVersion
{
  uint64_t version = ULLONG_MAX;
  NSString *uid, *changeNumber;
  BOOL synced;

  uid = [(MAPIStoreMailFolder *)
          container messageUIDFromMessageKey: [self nameInContainer]];
  if (uid)
    {
      changeNumber = [(MAPIStoreMailFolder *) container
                         changeNumberForMessageUID: uid];
      if (!changeNumber)
        {
          [self warnWithFormat: @"attempting to get change number"
                @" by synchronising folder..."];
          [(MAPIStoreMailFolder *) container synchroniseCache];
          changeNumber = [(MAPIStoreMailFolder *) container
                             changeNumberForMessageUID: uid];
          if (changeNumber)
            [self logWithFormat: @"got one"];
          else
            {
              [self warnWithFormat: @"attempting to get change number"
                    @" by synchronising this specific message..."];
              synced = [(MAPIStoreMailFolder *) container synchroniseCacheForUID: uid];
              if (synced)
                {
                  changeNumber = [(MAPIStoreMailFolder *) container
                                     changeNumberForMessageUID: uid];
                }
              else
                {
                  [self errorWithFormat: @"still nothing. We crash!"];
                  abort();
                }
            }
        }
      version = [changeNumber unsignedLongLongValue] >> 16;
    }
  else
    abort();

  return version;
}

- (enum mapistore_error) getPidTagIconIndex: (void **) data
                                   inMemCtx: (TALLOC_CTX *) memCtx
{
  uint32_t longValue;

  if (!headerSetup)
    [self _fetchHeaderData];

  if (mailIsEvent)
    [[self _appointmentWrapper] getPidTagIconIndex: data inMemCtx: memCtx];
  else
    {
      /* see http://msdn.microsoft.com/en-us/library/cc815472.aspx */
      if ([sogoObject isNewMail])
        longValue = 0xffffffff;
      else if ([sogoObject replied])
        longValue = 0x105;
      else if ([sogoObject forwarded])
        longValue = 0x106;
      else if ([sogoObject read])
        longValue = 0x100;
      else
        longValue = 0x101;
      *data = MAPILongValue (memCtx, longValue);
    }

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidLidResponseStatus: (void **) data
                                        inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0);

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidLidImapDeleted: (void **) data
                                     inMemCtx: (TALLOC_CTX *) memCtx
{
  uint32_t longValue;

  if ([sogoObject deleted])
    longValue = 1;
  else
    longValue = 0;
  *data = MAPILongValue (memCtx, longValue);

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagSubjectPrefix: (void **) data
                                       inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *subject;
  NSUInteger colIdx;
  NSString *stringValue;

  /* As specified in [MS-OXCMAIL] 2.2.3.2.6.1, if there are three
     or less characters followed by a colon at the beginning of
     the subject, we can assume that's the subject prefix */
  subject = [self subject];
  colIdx = [subject rangeOfString: @":"].location;
  if (colIdx != NSNotFound && colIdx < 4)
    stringValue = [NSString stringWithFormat: @"%@: ",
                   [subject substringToIndex: colIdx]];
  else
    stringValue = @"";
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagNormalizedSubject: (void **) data
                                           inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue, *subject;
  NSUInteger quoteStartIdx, quoteEndIdx, colIdx;
  NSRange quoteRange;

  if (!headerSetup)
    [self _fetchHeaderData];

  subject = [self subject];
  if (mailIsMeetingRequest)
    {

      /* SOGo "spices up" the invitation/update mail's subject, but
         the client uses it to name the attendee's event, so we keep
         only what's inside the quotes */
      quoteStartIdx = [subject rangeOfString: @"\""].location;
      quoteEndIdx = [subject rangeOfString: @"\""
                                   options: NSBackwardsSearch].location;
      if (quoteStartIdx != NSNotFound
          && quoteEndIdx != NSNotFound
          && quoteStartIdx != quoteEndIdx)
        {
            quoteRange = NSMakeRange(quoteStartIdx + 1, quoteEndIdx - quoteStartIdx - 1);
            stringValue = [subject substringWithRange: quoteRange];
        }
      else stringValue = subject;
    }
  else
    {

      /* As specified in [MS-OXCMAIL] 2.2.3.2.6.1, if there are three
         or less characters followed by a colon at the beginning of
         the subject, we can assume that's the subject prefix */
      colIdx = [subject rangeOfString: @":"].location;
      if (colIdx != NSNotFound && colIdx < 4)
        stringValue = [[subject substringFromIndex: colIdx + 1]
                       stringByTrimmingLeadSpaces];
      else
        stringValue = subject;
    }
  if (!stringValue)
    stringValue = @"";
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidLidFInvited: (void **) data
                                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getYes: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagMessageClass: (void **) data
                                      inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  if (mailIsEvent)
    [[self _appointmentWrapper] getPidTagMessageClass: data
                                             inMemCtx: memCtx];
  else if (mailIsSharingObject)
    *data = talloc_strdup (memCtx, "IPM.Sharing");
  else
    *data = talloc_strdup (memCtx, "IPM.Note");

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagReplyRequested: (void **) data
                                        inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsMeetingRequest
          ? [self getYes: data inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidTagResponseRequested: (void **) data
                                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagReplyRequested: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagLatestDeliveryTime: (void **) data // DOUBT
                                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagCreationTime: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagOriginalSubmitTime: (void **) data
                                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagCreationTime: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagClientSubmitTime: (void **) data
                                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagCreationTime: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagMessageDeliveryTime: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagCreationTime: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagMessageFlags: (void **) data // TODO
                                      inMemCtx: (TALLOC_CTX *) memCtx
{
  NSDictionary *coreInfos;
  NSArray *flags;
  unsigned int v = 0;

  coreInfos = [sogoObject fetchCoreInfos];
  flags = [coreInfos objectForKey: @"flags"];

  // if ([container isKindOfClass: MAPIStoreSentItemsFolderK]
  //     || [container isKindOfClass: MAPIStoreDraftsFolderK])
  //   v |= MSGFLAG_FROMME;
  if ([flags containsObject: @"seen"])
    v |= MSGFLAG_READ;
  if ([[self attachmentKeys]
        count] > 0)
    v |= MSGFLAG_HASATTACH;

  *data = MAPILongValue (memCtx, v);

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagFlagStatus: (void **) data
                                    inMemCtx: (TALLOC_CTX *) memCtx
{
  NSDictionary *coreInfos;
  NSArray *flags;
  unsigned int v;

  coreInfos = [sogoObject fetchCoreInfos];

  flags = [coreInfos objectForKey: @"flags"];
  if ([flags containsObject: @"flagged"])
    v = 2;
  else
    v = 0;

  *data = MAPILongValue (memCtx, v);

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagFollowupIcon: (void **) data
                                      inMemCtx: (TALLOC_CTX *) memCtx
{
  NSDictionary *coreInfos;
  NSArray *flags;
  unsigned int v;

  coreInfos = [sogoObject fetchCoreInfos];

  flags = [coreInfos objectForKey: @"flags"];
  if ([flags containsObject: @"flagged"])
    v = 6;
  else
    v = 0;

  *data = MAPILongValue (memCtx, v);

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagSensitivity: (void **) data // TODO
                                     inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagOriginalSensitivity: (void **) data // TODO
                                             inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagSensitivity: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagSentRepresentingAddressType: (void **) data
                                                     inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getSMTPAddrType: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagReceivedRepresentingAddressType: (void **) data
                                                         inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getSMTPAddrType: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagReceivedByAddressType: (void **) data
                                               inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getSMTPAddrType: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagSenderAddressType: (void **) data
                                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getSMTPAddrType: data inMemCtx: memCtx];
}

- (enum mapistore_error) _getEmailAddressFromEmail: (NSString *) fullMail
                                            inData: (void **) data
                                          inMemCtx: (TALLOC_CTX *) memCtx
{
  NGMailAddress *ngAddress;
  NSString *email;

  if (!fullMail)
    fullMail = @"";

  ngAddress = [[NGMailAddressParser mailAddressParserWithString: fullMail]
                parse];
  if ([ngAddress isKindOfClass: [NGMailAddress class]])
    email = [ngAddress address];
  else
    email = @"";

  *data = [email asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) _getCNFromEmail: (NSString *) fullMail
                                  inData: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx
{
  NGMailAddress *ngAddress;
  NSString *cn;

  if (!fullMail)
    fullMail = @"";

  ngAddress = [[NGMailAddressParser mailAddressParserWithString: fullMail]
                parse];
  if ([ngAddress isKindOfClass: [NGMailAddress class]])
    {
      cn = [ngAddress displayName];

      // If we don't have a displayName, we use the email address instead. This
      // avoid bug #2119 - where Outlook won't display anything in the "From" field,
      // nor in the recipient field if we reply to the email.
      if (![cn length])
	cn = [ngAddress address];
    }
  else
    cn = @"";

  *data = [cn asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) _getEntryIdFromEmail: (NSString *) fullMail
                                       inData: (void **) data
                                     inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *username, *cn, *email;
  SOGoUserManager *mgr;
  NSDictionary *contactInfos;
  NGMailAddress *ngAddress;
  NSData *entryId;
  enum mapistore_error rc;

  if (fullMail)
    {
      ngAddress = [[NGMailAddressParser mailAddressParserWithString: fullMail]
                    parse];
      if ([ngAddress isKindOfClass: [NGMailAddress class]])
        {
          email = [ngAddress address];
          cn = [ngAddress displayName];
        }
      else
        {
          email = fullMail;
          cn = @"";
        }

      mgr = [SOGoUserManager sharedUserManager];
      contactInfos = [mgr contactInfosForUserWithUIDorEmail: email];
      if (contactInfos)
        {
          username = [contactInfos objectForKey: @"sAMAccountName"];
          entryId = MAPIStoreInternalEntryId([[self context] connectionInfo], username);
        }
      else
        entryId = MAPIStoreExternalEntryId (cn, email);

      *data = [entryId asBinaryInMemCtx: memCtx];

      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (enum mapistore_error) getPidTagSenderEmailAddress: (void **) data
                                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getEmailAddressFromEmail: [sogoObject from]
                                  inData: data
                                inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagSenderName: (void **) data
                                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getCNFromEmail: [sogoObject from]
                        inData: data
                      inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagSenderEntryId: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getEntryIdFromEmail: [sogoObject from]
                             inData: data
                           inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagOriginalAuthorName: (void **) data
                                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagSenderEmailAddress: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagSentRepresentingEmailAddress: (void **) data
                                                      inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagSenderEmailAddress: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagSentRepresentingName: (void **) data
                                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagSenderName: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagSentRepresentingEntryId: (void **) data
                                                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagSenderEntryId: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagReceivedByEmailAddress: (void **) data
                                                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getEmailAddressFromEmail: [sogoObject to]
                                  inData: data
                                inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagReceivedByName: (void **) data
                                        inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getCNFromEmail: [sogoObject to]
                        inData: data
                      inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagReceivedByEntryId: (void **) data
                                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getEntryIdFromEmail: [sogoObject to]
                             inData: data
                           inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagReceivedRepresentingName: (void **) data
                                                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagReceivedByName: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagReceivedRepresentingEmailAddress: (void **) data
                                                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagReceivedByEmailAddress: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagReceivedRepresentingEntryId: (void **) data
                                                     inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagReceivedByEntryId: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagDisplayTo: (void **) data
                                   inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[sogoObject to] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagOriginalDisplayTo: (void **) data
                                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagDisplayTo: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagDisplayCc: (void **) data
                                   inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [sogoObject cc];
  if (!stringValue)
    stringValue = @"";

  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagOriginalDisplayCc: (void **) data
                                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagDisplayCc: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagDisplayBcc: (void **) data
                                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getEmptyString: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagOriginalDisplayBcc: (void **) data
                                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagDisplayBcc: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidNameContentType: (void **) data
                                      inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"message/rfc822" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagImportance: (void **) data
                                    inMemCtx: (TALLOC_CTX *) memCtx
{
  uint32_t v;
  NSString *s;

  s = [[sogoObject mailHeaders] objectForKey: @"x-priority"];
  v = 0x1;

  if ([s hasPrefix: @"1"]) v = 0x2;
  else if ([s hasPrefix: @"2"]) v = 0x2;
  else if ([s hasPrefix: @"4"]) v = 0x0;
  else if ([s hasPrefix: @"5"]) v = 0x0;

  *data = MAPILongValue (memCtx, v);

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagInternetCodepage: (void **) data
                                          inMemCtx: (TALLOC_CTX *) memCtx
{
  NSNumber *codepage;

  codepage = [Codepages getCodepageFromName: headerCharset];
  if (!codepage)
    {
      [self warnWithFormat: @"Couldn't find codepage from `%@`. "
                            @"Using UTF-8 by default", headerCharset];
      codepage = [Codepages getCodepageFromName: @"utf-8"];
    }

  *data = MAPILongValue(memCtx, [codepage intValue]);

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagBody: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  NSData *textContent;
  enum mapistore_error rc;

  if (!bodySetup)
    [self _fetchBodyData];

  if (!bodyContent)
    {
      *data = NULL;
      return MAPISTORE_ERR_NOT_FOUND;
    }

  if (mailIsEvent)
    {
      rc = [[self _appointmentWrapper] getPidTagBody: data
                                            inMemCtx: memCtx];
    }
  else
    {
      textContent = [bodyContent objectAtIndex: BODY_CONTENT_TEXT];
      if ([textContent length])
        {
          NSString *stringValue = [textContent bodyStringFromCharset: headerCharset];
          *data = [stringValue asUnicodeInMemCtx: memCtx];
          rc = MAPISTORE_SUCCESS;
        }
      else
        {
          *data = NULL;
          rc = MAPISTORE_ERR_NOT_FOUND;
        }
    }

  return rc;
}

- (enum mapistore_error) getPidTagHtml: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  NSData *htmlContent;
  enum mapistore_error rc;

  if (!bodySetup)
    [self _fetchBodyData];

  if (!bodyContent || mailIsEvent)
    {
      *data = NULL;
      return MAPISTORE_ERR_NOT_FOUND;
    }

  htmlContent = [bodyContent objectAtIndex: BODY_CONTENT_HTML] ;
  
  if ([htmlContent length])
    {
      *data = [htmlContent asBinaryInMemCtx: memCtx];
      rc = MAPISTORE_SUCCESS;
    }
  else
    {
      *data = NULL;
      rc = MAPISTORE_ERR_NOT_FOUND;
    }

  return rc;
}

- (enum mapistore_error) getPidTagRtfCompressed: (void **) data
                                       inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = NULL;

  return MAPISTORE_ERR_NOT_FOUND;
}

- (enum mapistore_error) getPidTagRtfInSync: (void **) data
                                   inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagInternetMessageId: (void **) data
                                           inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[sogoObject messageId] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagReadReceiptRequested: (void **) data // TODO
                                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidLidGlobalObjectId: (void **) data
                                        inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidGlobalObjectId: data
                                                       inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidLidCleanGlobalObjectId: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidCleanGlobalObjectId: data
                                                            inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidLidServerProcessed: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidServerProcessed: data
                                                        inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidLidServerProcessingActions: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidServerProcessingActions: data
                                                                inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidTagProcessed: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc;

  if (!headerSetup)
    [self _fetchHeaderData];

  if (mailIsEvent)
    rc = [self getYes: data inMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

// - (enum mapistore_error) getPidLidServerProcessed: (void **) data
//                         inMemCtx: (TALLOC_CTX *) memCtx
// {
//   if (!headerSetup)
//     [self _fetchHeaderData];

//   return (mailIsEvent
//           ? [[self _appointmentWrapper] getPidLidServerProcessed: data
//                                                         inMemCtx: memCtx]
//           : MAPISTORE_ERR_NOT_FOUND);
// }

- (enum mapistore_error) getPidLidPrivate: (void **) data
                                 inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidPrivate: data
                                                inMemCtx: memCtx]
          :  [self getNo: data inMemCtx: memCtx]);
}

- (enum mapistore_error) getPidTagMessageEditorFormat: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx
{
  uint32_t format;

  if (!headerSetup)
    [self _fetchHeaderData];

  if ([headerMimeType isEqualToString: @"text/plain"])
    format = EDITOR_FORMAT_PLAINTEXT;
  else if ([headerMimeType isEqualToString: @"text/html"])
    format = EDITOR_FORMAT_HTML;
  else
    format = 0; /* EDITOR_FORMAT_DONTKNOW */

  *data = MAPILongValue (memCtx, format);

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidLidReminderSet: (void **) data // TODO
                                     inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidLidUseTnef: (void **) data // TODO
                                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidLidRemoteStatus: (void **) data // TODO
                                      inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidLidAgingDontAgeMe: (void **) data // TODO
                                        inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getYes: data inMemCtx: memCtx];
}

/* event getters */
- (enum mapistore_error) getPidTagStartDate: (void **) data
                                   inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidTagStartDate: data inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidLidAppointmentMessageClass: (void **) data
                                                 inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc = MAPISTORE_SUCCESS;

  if (!headerSetup)
    [self _fetchHeaderData];

  if (mailIsEvent)
    *data = talloc_strdup (memCtx, "IPM.Appointment");
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (enum mapistore_error) getPidLidAppointmentStartWhole: (void **) data
                                               inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidAppointmentStartWhole: data
                                                              inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidLidCommonStart: (void **) data
                                     inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidCommonStart: data
                                                    inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidTagEndDate: (void **) data
                                 inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidTagEndDate: data inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidLidAppointmentEndWhole: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidAppointmentEndWhole: data
                                                            inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidLidCommonEnd: (void **) data
                                   inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidCommonEnd: data
                                                  inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidLidAppointmentDuration: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidAppointmentDuration: data
                                                            inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidLidAppointmentSubType: (void **) data
                                            inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidAppointmentSubType: data
                                                           inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidLidBusyStatus: (void **) data // TODO
                                    inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidBusyStatus: data
                                                   inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidLidLocation: (void **) data // LOCATION
                                  inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidLocation: data
                                                 inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidLidIsRecurring: (void **) data
                                     inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidIsRecurring: data
                                                    inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidLidRecurring: (void **) data
                                   inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidRecurring: data
                                                  inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidLidAppointmentRecur: (void **) data
                                          inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidAppointmentRecur: data
                                                         inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidTagOwnerAppointmentId: (void **) data
                                            inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidTagOwnerAppointmentId: data
                                                           inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidLidMeetingType: (void **) data
                                     inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidMeetingType: data
                                                    inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (enum mapistore_error) getPidTagTransportMessageHeaders: (void **) data
                                                 inMemCtx: (TALLOC_CTX *) memCtx
{
  NSDictionary *mailHeaders;
  NSEnumerator *keyEnumerator;
  NSMutableArray *headers;
  NGMimeMessageGenerator *g;
  NSString *headerKey, *fullHeader, *headerGenerated;
  id headerValue;
  NSData *headerData;

  /* Let's encode each mail header and put them on 'headers' array */
  mailHeaders = [sogoObject mailHeaders];
  headers = [NSMutableArray arrayWithCapacity: [mailHeaders count]];

  g = [[NGMimeMessageGenerator alloc] init];
  keyEnumerator = [mailHeaders keyEnumerator];
  while ((headerKey = [keyEnumerator nextObject]))
    {
      headerValue = [mailHeaders objectForKey: headerKey];

      headerData = [g generateDataForHeaderField: headerKey value: headerValue];
      headerGenerated = [[NSString alloc] initWithData: headerData encoding:NSUTF8StringEncoding];
      fullHeader = [NSString stringWithFormat:@"%@: %@", headerKey, headerGenerated];
      [headerGenerated release];

      [headers addObject: fullHeader];
    }
  [g release];

  *data = [[headers componentsJoinedByString:@"\n"] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (void) getMessageData: (struct mapistore_message **) dataPtr
               inMemCtx: (TALLOC_CTX *) memCtx
{
  NSArray *addresses;
  NSString *addressMethods[] = { @"fromEnvelopeAddresses",
                                 @"toEnvelopeAddresses",
                                 @"ccEnvelopeAddresses",
                                 @"bccEnvelopeAddresses" };
  enum ulRecipClass addressTypes[] = { MAPI_ORIG, MAPI_TO,
                                       MAPI_CC, MAPI_BCC };
  NSUInteger arrayCount, count, recipientStart, max, p;
  NGImap4EnvelopeAddress *currentAddress;
  NSString *username, *cn, *email;
  NSData *entryId;
  NSDictionary *contactInfos;
  SOGoUserManager *mgr;
  struct mapistore_message *msgData;
  struct mapistore_message_recipient *recipient;

  [super getMessageData: &msgData inMemCtx: memCtx];

  if (!headerSetup)
    [self _fetchHeaderData];

  if (mailIsEvent)
    [[self _appointmentWrapper] fillMessageData: msgData
                                       inMemCtx: memCtx];
  else
    {
      mgr = [SOGoUserManager sharedUserManager];

      /* Retrieve recipients from the message */

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

      msgData->recipients_count = 0;
      msgData->recipients = NULL;

      recipientStart = 0;

      for (arrayCount = 0; arrayCount < 4; arrayCount++)
        {
          addresses = [sogoObject performSelector: NSSelectorFromString (addressMethods[arrayCount])];
          max = [addresses count];
          if (max > 0)
            {
              msgData->recipients_count += max;
              msgData->recipients = talloc_realloc (msgData, msgData->recipients, struct mapistore_message_recipient, msgData->recipients_count);

              for (count = 0; count < max; count++)
                {
                  recipient = msgData->recipients + recipientStart;
                  currentAddress = [addresses objectAtIndex: count];
                  cn = [currentAddress personalName];
                  email = [currentAddress baseEMail];
                  if ([cn length] == 0)
                    cn = email;
                  contactInfos = [mgr contactInfosForUserWithUIDorEmail: email];

                  if (contactInfos)
                    {
                      username = [contactInfos objectForKey: @"sAMAccountName"];
                      recipient->username = [username asUnicodeInMemCtx: msgData];
                      entryId = MAPIStoreInternalEntryId ([[self context] connectionInfo], username);
                    }
                  else
                    {
                      recipient->username = NULL;
                      entryId = MAPIStoreExternalEntryId (cn, email);
                    }
                  recipient->type = addressTypes[arrayCount];

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

                  recipientStart++;
                }
            }
        }
    }
  *dataPtr = msgData;
}

- (void) _fetchAttachmentPartsInBodyInfo: (NSDictionary *) bodyInfo
                              withPrefix: (NSString *) keyPrefix
{
  NSArray *parts;
  NSUInteger count, max;

  if ([[bodyInfo filename] length] > 0)
    {
      if ([keyPrefix length] == 0)
        keyPrefix = @"0";
      [attachmentParts setObject: bodyInfo
                          forKey: keyPrefix];
    }
  else
    {
      if ([keyPrefix length] > 0)
        keyPrefix = [NSString stringWithFormat: @"%@/", keyPrefix];
      parts = [bodyInfo objectForKey: @"parts"];
      max = [parts count];
      for (count = 0; count < max; count++)
        [self _fetchAttachmentPartsInBodyInfo: [parts objectAtIndex: count]
                                   withPrefix: [NSString stringWithFormat: @"%@%d",
                                                         keyPrefix, count + 1]];
    }
}

- (NSArray *) attachmentKeysMatchingQualifier: (EOQualifier *) qualifier
                             andSortOrderings: (NSArray *) sortOrderings
{
  [self _fetchAttachmentPartsInBodyInfo: [sogoObject bodyStructure]
                             withPrefix: @""];

  return [super attachmentKeysMatchingQualifier: qualifier
                               andSortOrderings: sortOrderings];
}

- (id) lookupAttachment: (NSString *) childKey
{
  MAPIStoreMailAttachment *attachment;
  SOGoMailBodyPart *currentPart;
  NSArray *keyParts;
  NSUInteger count, max;

  attachment = nil;

  keyParts = [childKey componentsSeparatedByString: @"/"];
  max = [keyParts count];
  if (max > 0)
    {
      [[self userContext] activate];

      currentPart = [sogoObject lookupName: [keyParts objectAtIndex: 0]
                                 inContext: nil
                                   acquire: NO];
      if ([currentPart isKindOfClass: NSExceptionK])
        currentPart = nil;

      for (count = 1; currentPart && count < max; count++)
        {
          [parentContainersBag addObject: currentPart];
          currentPart = [currentPart lookupName: [keyParts objectAtIndex: count]
                                      inContext: nil
                                        acquire: NO];
          if ([currentPart isKindOfClass: NSExceptionK])
            currentPart = nil;
        }

      if (currentPart)
        {
          attachment = [MAPIStoreMailAttachment
                         mapiStoreObjectInContainer: self];
          [attachment setBodyPart: currentPart];
          [attachment setBodyInfo: [attachmentParts objectForKey: childKey]];
          [attachment setAID: [[self attachmentKeys] indexOfObject: childKey]];
        }
    }

  return attachment;
}

- (enum mapistore_error) setReadFlag: (uint8_t) flag
{
  /* TODO: notifications should probably be emitted from here */
  if (flag & CLEAR_READ_FLAG)
    [properties setObject: [NSNumber numberWithBool: NO] forKey: @"read_flag_set"];
  else
    [properties setObject: [NSNumber numberWithBool: YES] forKey: @"read_flag_set"];

  return MAPISTORE_SUCCESS;
}

- (void) setBodyContentFromRawData: (NSArray *) rawContent
{
  if (!headerSetup)
    [self _fetchHeaderData];

  ASSIGN (bodyContent, rawContent);
  bodySetup = YES;
}

- (MAPIStoreSharingMessage *) _sharingObject
{
  /* Get the sharing object if available */
  NSUInteger i, max;
  id proxy;

  max = [proxies count];
  for (i = 0; i < max; i++) {
    proxy = [proxies objectAtIndex: i];
    if ([proxy isKindOfClass: MAPIStoreSharingMessageK])
      return proxy;
  }
  return nil;
}

- (void) save: (TALLOC_CTX *) memCtx
{
  BOOL modified = NO;
  BOOL seen, storedSeenFlag;
  NSNumber *value;
  NSString *imapFlag = @"\\Seen";

  value = [properties objectForKey: MAPIPropertyKey (PR_FLAG_STATUS)];
  if (value)
    {
      /* We don't handle the concept of "Follow Up" */
      if ([value intValue] == 2)
        [sogoObject addFlags: @"\\Flagged"];
      else /* 0: unflagged, 1: follow up complete */
        [sogoObject removeFlags: @"\\Flagged"];

      modified = YES;
    }

  /* Manage seen flag on save */
  value = [properties objectForKey: @"read_flag_set"];
  if (value)
    {
      seen = [value boolValue];
      storedSeenFlag = [[[sogoObject fetchCoreInfos] objectForKey: @"flags"] containsObject: @"seen"];
      /* We modify the flags anyway to generate a new change number */
      if (seen)
        {
          if (storedSeenFlag)
            [sogoObject removeFlags: imapFlag];
          [sogoObject addFlags: imapFlag];
        }
      else
        {
          if (!storedSeenFlag)
            [sogoObject addFlags: imapFlag];
          [sogoObject removeFlags: imapFlag];
        }
      modified = YES;
    }

  if (modified)
    [(MAPIStoreMailFolder *)[self container] synchroniseCache];

  if (mailIsSharingObject)
    [[self _sharingObject] saveWithMessage: self
                             andSOGoObject: sogoObject];

}

@end
