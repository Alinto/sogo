/* MAPIStoreMailMessage.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
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
#import <NGExtensions/NSObject+Logs.h>
#import <NGImap4/NGImap4Client.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4EnvelopeAddress.h>
#import <NGMail/NGMailAddress.h>
#import <NGMail/NGMailAddressParser.h>
#import <NGCards/iCalCalendar.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUserManager.h>
#import <Mailer/NSData+Mail.h>
#import <Mailer/SOGoMailBodyPart.h>
#import <Mailer/SOGoMailObject.h>

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
#import "MAPIStoreTypes.h"

#import "MAPIStoreMailMessage.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

@class iCalCalendar, iCalEvent;

static Class NSExceptionK;

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
}

- (id) init
{
  if ((self = [super init]))
    {
      mimeKey = nil;
      mailIsEvent = NO;
      headerCharset = nil;
      headerEncoding = nil;
      headerMimeType = nil;
      headerSetup = NO;
      bodyContent = nil;
      bodySetup = NO;
      appointmentWrapper = nil;
    }

  return self;
}

- (void) dealloc
{
  [mimeKey release];
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
  NSMutableArray *keys;
  NSArray *acceptedTypes;
  NSDictionary *messageData, *partHeaderData, *parameters;

  acceptedTypes = [NSArray arrayWithObjects: @"text/calendar",
                           @"application/ics",
                           @"text/html",
                           @"text/plain", nil];
  keys = [NSMutableArray array];
  [sogoObject addRequiredKeysOfStructure: [sogoObject bodyStructure]
                                    path: @"" toArray: keys
                           acceptedTypes: acceptedTypes
                                withPeek: YES];
  [keys sortUsingFunction: _compareBodyKeysByPriority context: acceptedTypes];
  if ([keys count] > 0)
    {
      messageData = [keys objectAtIndex: 0];
      ASSIGN (mimeKey, [messageData objectForKey: @"key"]);
      ASSIGN (headerMimeType, [messageData objectForKey: @"mimeType"]);
      partHeaderData
        = [sogoObject lookupInfoForBodyPart: [mimeKey _strippedBodyKey]];
      ASSIGN (headerEncoding, [partHeaderData objectForKey: @"encoding"]);
      parameters = [partHeaderData objectForKey: @"parameterList"];
      ASSIGN (headerCharset, [parameters objectForKey: @"charset"]);
      if ([headerMimeType isEqualToString: @"text/calendar"]
          || [headerMimeType isEqualToString: @"application/ics"])
        mailIsEvent = YES;
    }

  headerSetup = YES;
}

- (void) _fetchBodyData
{
  NSData *rawContent;
  NSString *resultKey;
  id result;

  if (!headerSetup)
    [self _fetchHeaderData];

  if (mimeKey)
    {
      result = [sogoObject fetchParts: [NSArray arrayWithObject: mimeKey]];
      result = [[result valueForKey: @"RawResponse"] objectForKey: @"fetch"];
      if ([mimeKey hasPrefix: @"body.peek"])
        resultKey = [NSString stringWithFormat: @"body[%@]",
                              [mimeKey _strippedBodyKey]];
      else
        resultKey = mimeKey;
      rawContent = [[result objectForKey: resultKey] objectForKey: @"data"];
      ASSIGN (bodyContent, [rawContent bodyDataFromEncoding: headerEncoding]);
    }

  bodySetup = YES;
}

- (MAPIStoreAppointmentWrapper *) _appointmentWrapper
{
  NSArray *events, *from;
  iCalCalendar *calendar;
  iCalEvent *event;
  NSString *stringValue, *senderEmail;
  MAPIStoreContext *context;

  if (!appointmentWrapper)
    {
      if (!bodySetup)
        [self _fetchBodyData];

      stringValue = [bodyContent bodyStringFromCharset: headerCharset];
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
                                           inTimeZone: [self ownerTimeZone]
                                   withConnectionInfo: [context connectionInfo]];
          [appointmentWrapper retain];
        }
    }

  return appointmentWrapper;
}

- (int) getPidTagChangeKey: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;
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

- (int) getPidTagPredecessorChangeList: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;
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
  NSNumber *uid, *changeNumber;

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
              [self errorWithFormat: @"still nothing. We crash!"];
              abort();
            }
        }
      version = [changeNumber unsignedLongLongValue] >> 16;
    }
  else
    abort();

  return version;
}

- (int) getPidTagIconIndex: (void **) data
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

- (int) getPidLidResponseStatus: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidImapDeleted: (void **) data
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

- (int) getPidTagSubject: (void **) data
                inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [self subject];
  if (!stringValue)
    stringValue = @"";
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagSubjectPrefix: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *subject;
  NSUInteger colIdx;
  NSString *stringValue;

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

- (int) getPidTagNormalizedSubject: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *subject;
  NSUInteger colIdx;
  NSString *stringValue;

  subject = [self subject];
  colIdx = [subject rangeOfString: @":"].location;
  if (colIdx != NSNotFound && colIdx < 4)
    stringValue = [[subject substringFromIndex: colIdx + 1]
                    stringByTrimmingLeadSpaces];
  else
    stringValue = subject;
  if (!stringValue)
    stringValue = @"";
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidFInvited: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getYes: data inMemCtx: memCtx];
}

- (int) getPidTagMessageClass: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  if (mailIsEvent)
    [[self _appointmentWrapper] getPidTagMessageClass: data
                                             inMemCtx: memCtx];
  else
    *data = talloc_strdup (memCtx, "IPM.Note");

  return MAPISTORE_SUCCESS;
}

/* Note: this applies to regular mails... */
// - (int) getPidTagReplyRequested: (void **) data // TODO
//                    inMemCtx: (TALLOC_CTX *) memCtx
// {
//   if (!headerSetup)
//     [self _fetchHeaderData];

//   return (mailIsEvent
//           ? [self getYes: data inMemCtx: memCtx]
//           : [self getNo: data inMemCtx: memCtx]);
// }

/* ... while this applies to invitations. */
- (int) getPidTagResponseRequested: (void **) data // TODO
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [self getNo: data inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidTagLatestDeliveryTime: (void **) data // DOUBT
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagCreationTime: data inMemCtx: memCtx];
}

- (int) getPidTagOriginalSubmitTime: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagCreationTime: data inMemCtx: memCtx];
}

- (int) getPidTagClientSubmitTime: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagCreationTime: data inMemCtx: memCtx];
}

- (int) getPidTagMessageDeliveryTime: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagCreationTime: data inMemCtx: memCtx];
}

- (int) getPidTagMessageFlags: (void **) data // TODO
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

- (int) getPidTagFlagStatus: (void **) data
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

- (int) getPidTagFollowupIcon: (void **) data
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

- (int) getPidTagSensitivity: (void **) data // TODO
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPidTagOriginalSensitivity: (void **) data // TODO
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagSensitivity: data inMemCtx: memCtx];
}

- (int) getPidTagSentRepresentingAddressType: (void **) data
                                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getSMTPAddrType: data inMemCtx: memCtx];
}

- (int) getPidTagReceivedRepresentingAddressType: (void **) data
                                        inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getSMTPAddrType: data inMemCtx: memCtx];
}

- (int) getPidTagReceivedByAddressType: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getSMTPAddrType: data inMemCtx: memCtx];
}

- (int) getPidTagSenderAddressType: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getSMTPAddrType: data inMemCtx: memCtx];
}

- (int) _getEmailAddressFromEmail: (NSString *) fullMail
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

- (int) _getCNFromEmail: (NSString *) fullMail
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
    cn = [ngAddress address];
  else
    cn = @"";

  *data = [cn asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) _getEntryIdFromEmail: (NSString *) fullMail
                      inData: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *username, *cn, *email;
  SOGoUserManager *mgr;
  NSDictionary *contactInfos;
  NGMailAddress *ngAddress;
  NSData *entryId;
  struct ldb_context *samCtx;
  int rc;

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
          username = [contactInfos objectForKey: @"c_uid"];
          samCtx = [[self context] connectionInfo]->sam_ctx;
          entryId = MAPIStoreInternalEntryId (samCtx, username);
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

- (int) getPidTagSenderEmailAddress: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getEmailAddressFromEmail: [sogoObject from]
                                  inData: data
                                inMemCtx: memCtx];
}

- (int) getPidTagSenderName: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getCNFromEmail: [sogoObject from]
                        inData: data
                      inMemCtx: memCtx];
}

- (int) getPidTagSenderEntryId: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getEntryIdFromEmail: [sogoObject from]
                             inData: data
                           inMemCtx: memCtx];
}

- (int) getPidTagOriginalAuthorName: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagSenderEmailAddress: data inMemCtx: memCtx];
}

- (int) getPidTagSentRepresentingEmailAddress: (void **) data
                                     inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagSenderEmailAddress: data inMemCtx: memCtx];
}

- (int) getPidTagSentRepresentingName: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagSenderName: data inMemCtx: memCtx];
}

- (int) getPidTagSentRepresentingEntryId: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagSenderEntryId: data inMemCtx: memCtx];
}

- (int) getPidTagReceivedByEmailAddress: (void **) data
                               inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getEmailAddressFromEmail: [sogoObject to]
                                  inData: data
                                inMemCtx: memCtx];
}

- (int) getPidTagReceivedByName: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getCNFromEmail: [sogoObject to]
                        inData: data
                      inMemCtx: memCtx];
}

- (int) getPidTagReceivedByEntryId: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getEntryIdFromEmail: [sogoObject to]
                             inData: data
                           inMemCtx: memCtx];
}

- (int) getPidTagReceivedRepresentingName: (void **) data
                                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagReceivedByName: data inMemCtx: memCtx];
}

- (int) getPidTagReceivedRepresentingEmailAddress: (void **) data
                                         inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagReceivedByEmailAddress: data inMemCtx: memCtx];
}

- (int) getPidTagReceivedRepresentingEntryId: (void **) data
                                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagReceivedByEntryId: data inMemCtx: memCtx];
}

- (int) getPidTagDisplayTo: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[sogoObject to] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagOriginalDisplayTo: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagDisplayTo: data inMemCtx: memCtx];
}

- (int) getPidTagDisplayCc: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [sogoObject cc];
  if (!stringValue)
    stringValue = @"";

  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagOriginalDisplayCc: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagDisplayCc: data inMemCtx: memCtx];
}

- (int) getPidTagDisplayBcc: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getEmptyString: data inMemCtx: memCtx];
}

- (int) getPidTagOriginalDisplayBcc: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagDisplayBcc: data inMemCtx: memCtx];
}

- (int) getPidNameContentType: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"message/rfc822" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagImportance: (void **) data
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

- (int) getPidTagInternetCodepage: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  /* ref:
     http://msdn.microsoft.com/en-us/library/dd317756%28v=vs.85%29.aspx
  
     minimal list that should be handled:
     us-ascii: 20127
     iso-8859-1: 28591
     iso-8859-15: 28605
     utf-8: 65001 */
  *data = MAPILongValue(memCtx, 65001);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagBody: (void **) data
             inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;
  int rc = MAPISTORE_SUCCESS;

  if (!bodySetup)
    [self _fetchBodyData];

  if ([headerMimeType isEqualToString: @"text/plain"])
    {
      stringValue = [bodyContent bodyStringFromCharset: headerCharset];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
    }
  else if (mailIsEvent)
    rc = [[self _appointmentWrapper] getPidTagBody: data
                                          inMemCtx: memCtx];
  else
    {
      *data = NULL;
      rc = MAPISTORE_ERR_NOT_FOUND;
    }

  return rc;
}

- (int) getPidTagHtml: (void **) data
             inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;

  if (!bodySetup)
    [self _fetchBodyData];

  if ([headerMimeType isEqualToString: @"text/html"])
    *data = [bodyContent asBinaryInMemCtx: memCtx];
  else
    {
      *data = NULL;
      rc = MAPISTORE_ERR_NOT_FOUND;
    }

  return rc;
}

- (int) getPidTagRtfCompressed: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = NULL;

  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidTagRtfInSync: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (int) getPidTagInternetMessageId: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[sogoObject messageId] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagReadReceiptRequested: (void **) data // TODO
                             inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (int) getPidTagDeleteAfterSubmit: (void **) data // TODO
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (int) getPidLidGlobalObjectId: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidGlobalObjectId: data
                                                       inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidLidCleanGlobalObjectId: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidCleanGlobalObjectId: data
                                                            inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidLidServerProcessed: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidServerProcessed: data
                                                        inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidLidServerProcessingActions: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidServerProcessingActions: data
                                                                inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidTagProcessed: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc;

  if (!headerSetup)
    [self _fetchHeaderData];

  if (mailIsEvent)
    rc = [self getYes: data inMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

// - (int) getPidLidServerProcessed: (void **) data
//                         inMemCtx: (TALLOC_CTX *) memCtx
// {
//   if (!headerSetup)
//     [self _fetchHeaderData];

//   return (mailIsEvent
//           ? [[self _appointmentWrapper] getPidLidServerProcessed: data
//                                                         inMemCtx: memCtx]
//           : MAPISTORE_ERR_NOT_FOUND);
// }

- (int) getPidLidPrivate: (void **) data
                inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidPrivate: data
                                                inMemCtx: memCtx]
          :  [self getNo: data inMemCtx: memCtx]);
}

- (int) getPidTagMessageEditorFormat: (void **) data
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

- (int) getPidLidReminderSet: (void **) data // TODO
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (int) getPidLidUseTnef: (void **) data // TODO
                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (int) getPidLidRemoteStatus: (void **) data // TODO
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPidLidAgingDontAgeMe: (void **) data // TODO
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getYes: data inMemCtx: memCtx];
}

/* event getters */
- (int) getPidTagStartDate: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidTagStartDate: data inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidLidAppointmentMessageClass: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;

  if (!headerSetup)
    [self _fetchHeaderData];

  if (mailIsEvent)
    *data = talloc_strdup (memCtx, "IPM.Appointment");
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidLidAppointmentStartWhole: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidAppointmentStartWhole: data
                                                              inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidLidCommonStart: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidCommonStart: data
                                                    inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidTagEndDate: (void **) data
                inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidTagEndDate: data inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidLidAppointmentEndWhole: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidAppointmentEndWhole: data
                                                            inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidLidCommonEnd: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidCommonEnd: data
                                                  inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidLidAppointmentDuration: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidAppointmentDuration: data
                                                            inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidLidAppointmentSubType: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidAppointmentSubType: data
                                                           inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidLidBusyStatus: (void **) data // TODO
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidBusyStatus: data
                                                   inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidLidLocation: (void **) data // LOCATION
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidLocation: data
                                                 inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidLidIsRecurring: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidIsRecurring: data
                                                    inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidLidRecurring: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidRecurring: data
                                                  inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidLidAppointmentRecur: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidAppointmentRecur: data
                                                         inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidTagOwnerAppointmentId: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidTagOwnerAppointmentId: data
                                                           inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidLidMeetingType: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!headerSetup)
    [self _fetchHeaderData];

  return (mailIsEvent
          ? [[self _appointmentWrapper] getPidLidMeetingType: data
                                                    inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (void) getMessageData: (struct mapistore_message **) dataPtr
               inMemCtx: (TALLOC_CTX *) memCtx
{
  NSArray *to;
  NSInteger count, max, p;
  NGImap4EnvelopeAddress *currentAddress;
  NSString *username, *cn, *email;
  NSData *entryId;
  NSDictionary *contactInfos;
  SOGoUserManager *mgr;
  struct ldb_context *samCtx;
  struct mapistore_message *msgData;
  struct mapistore_message_recipient *recipient;

  samCtx = [[self context] connectionInfo]->sam_ctx;
  [super getMessageData: &msgData inMemCtx: memCtx];

  if (!headerSetup)
    [self _fetchHeaderData];

  if (mailIsEvent)
    [[self _appointmentWrapper] fillMessageData: msgData
                                       inMemCtx: memCtx];
  else
    {
      /* Retrieve recipients from the message */
      to = [sogoObject toEnvelopeAddresses];
      max = [to count];

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

      if (max > 0)
        {
          mgr = [SOGoUserManager sharedUserManager];
          msgData->recipients_count = max;
          msgData->recipients = talloc_array (msgData, struct mapistore_message_recipient, max);
          for (count = 0; count < max; count++)
            {
              recipient = msgData->recipients + count;

              currentAddress = [to objectAtIndex: count];
              cn = [currentAddress personalName];
              email = [currentAddress baseEMail];
              if ([cn length] == 0)
                cn = email;
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
              recipient->type = MAPI_TO;

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
            }
        }
    }
  *dataPtr = msgData;
}

- (void) _fetchAttachmentPartsInBodyInfo: (NSDictionary *) bodyInfo
                              withPrefix: (NSString *) keyPrefix
{
  NSArray *parts;
  NSDictionary *parameters;
  NSUInteger count, max;

  parameters = [[bodyInfo objectForKey: @"disposition"]
                 objectForKey: @"parameterList"];
  if ([[parameters objectForKey: @"filename"] length] > 0)
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
                         mapiStoreObjectWithSOGoObject: currentPart
                                           inContainer: self];
          [attachment setBodyInfo: [attachmentParts objectForKey: childKey]];
          [attachment setAID: [[self attachmentKeys] indexOfObject: childKey]];
        }
    }

  return attachment;
}

- (int) setReadFlag: (uint8_t) flag
{
  NSString *imapFlag = @"\\Seen";

  /* TODO: notifications should probably be emitted from here */
  if (flag & CLEAR_READ_FLAG)
    [sogoObject removeFlags: imapFlag];
  else
    [sogoObject addFlags: imapFlag];

  return MAPISTORE_SUCCESS;
}

- (void) save
{
  NSNumber *value;

  value = [properties objectForKey: MAPIPropertyKey (PR_FLAG_STATUS)];
  if (value)
    {
      /* We don't handle the concept of "Follow Up" */
      if ([value intValue] == 2)
        [sogoObject addFlags: @"\\Flagged"];
      else /* 0: unflagged, 1: follow up complete */
        [sogoObject removeFlags: @"\\Flagged"];
    }
}

@end
