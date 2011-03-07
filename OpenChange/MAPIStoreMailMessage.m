/* MAPIStoreMailMessage.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <NGExtensions/NSObject+Logs.h>
#import <SOGo/NSArray+Utilities.h>
#import <NGImap4/NGImap4EnvelopeAddress.h>
#import <Mailer/NSData+Mail.h>
#import <Mailer/SOGoMailBodyPart.h>
#import <Mailer/SOGoMailObject.h>

#import "NSCalendarDate+MAPIStore.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreFolder.h"
#import "MAPIStoreTypes.h"
#import "MAPIStoreMailAttachment.h"

#import "MAPIStoreMailMessage.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
#include <mapistore/mapistore_nameid.h>

static Class NSExceptionK;

@interface NSString (MAPIStoreMIME)

- (NSString *) _strippedBodyKey;

@end

@implementation NSString (MAPIStoreMIME)

- (NSString *) _strippedBodyKey
{
  NSRange bodyRange;
  NSString *strippedKey;

  bodyRange = [self rangeOfString: @"body["];
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

@implementation MAPIStoreMailMessage

+ (void) initialize
{
  NSExceptionK = [NSException class];
}

- (MAPIStoreAttachmentTable *) attachmentTable
{
  return [MAPIStoreAttachmentTable tableForContainer: self];
}

- (enum MAPISTATUS) getProperty: (void **) data
                        withTag: (enum MAPITAGS) propTag
{
  NSString *subject, *stringValue;
  NSInteger colIdx;
  uint32_t intValue;
  enum MAPISTATUS rc;

  rc = MAPISTORE_SUCCESS;
  switch (propTag)
    {
    case PR_ICON_INDEX:
      /* see http://msdn.microsoft.com/en-us/library/cc815472.aspx */
      if ([sogoObject isNewMail])
        intValue = 0xffffffff;
      else if ([sogoObject replied])
        intValue = 0x105;
      else if ([sogoObject forwarded])
        intValue = 0x106;
      else if ([sogoObject read])
        intValue = 0x100;
      else
        intValue = 0x101;
      *data = MAPILongValue (memCtx, intValue);
      break;
    case PidLidImapDeleted:
      if ([sogoObject deleted])
        intValue = 1;
      else
        intValue = 0;
      *data = MAPILongValue (memCtx, intValue);
      break;
    case PR_SUBJECT_UNICODE:
      stringValue = [sogoObject decodedSubject];
      if (!stringValue)
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_SUBJECT_PREFIX_UNICODE:
      subject = [sogoObject decodedSubject];
      colIdx = [subject rangeOfString: @":"].location;
      if (colIdx != NSNotFound && colIdx < 4)
        stringValue = [NSString stringWithFormat: @"%@: ",
                                [subject substringToIndex: colIdx]];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_NORMALIZED_SUBJECT_UNICODE:
      subject = [sogoObject decodedSubject];
      colIdx = [subject rangeOfString: @":"].location;
      if (colIdx != NSNotFound && colIdx < 4)
        stringValue = [[subject substringFromIndex: colIdx + 1]
                        stringByTrimmingLeadSpaces];
      else
        stringValue = subject;
      if (!stringValue)
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    case PR_MESSAGE_CLASS_UNICODE:
    case PR_ORIG_MESSAGE_CLASS_UNICODE:
      *data = talloc_strdup (memCtx, "IPM.Note");
      break;
    // case PidLidRemoteAttachment: // TODO
    case PR_REPLY_REQUESTED: // TODO
    case PR_RESPONSE_REQUESTED: // TODO
      *data = MAPIBoolValue (memCtx, NO);
      break;
    // case PidLidHeaderItem:
    //   *data = MAPILongValue (memCtx, 0x00000001);
    //   break;
    // case PidLidRemoteTransferSize:
    //   rc = [self getChildProperty: data
    // 			   forKey: childKey
    // 			  withTag: PR_MESSAGE_SIZE];
    //   break;
    case PR_CREATION_TIME: // DOUBT
    case PR_LAST_MODIFICATION_TIME: // DOUBT
    case PR_LATEST_DELIVERY_TIME: // DOUBT
    case PR_ORIGINAL_SUBMIT_TIME:
    case PR_CLIENT_SUBMIT_TIME:
    case PR_MESSAGE_DELIVERY_TIME:
      // offsetDate = [[sogoObject date] addYear: -1 month: 0 day: 0
      //                               hour: 0 minute: 0 second: 0];
      // *data = [offsetDate asFileTimeInMemCtx: memCtx];
      *data = [[sogoObject date] asFileTimeInMemCtx: memCtx];
      break;
    case PR_MESSAGE_FLAGS: // TODO
      {
	NSDictionary *coreInfos;
	NSArray *flags;
	unsigned int v;

	coreInfos = [sogoObject fetchCoreInfos];

	flags = [coreInfos objectForKey: @"flags"];
	v = MSGFLAG_FROMME;
	
	if ([flags containsObject: @"seen"])
	  v |= MSGFLAG_READ;

	*data = MAPILongValue (memCtx, v);
      }
      break;

    case PR_FLAG_STATUS:
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
      }
      break;

    case PR_FOLLOWUP_ICON:
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
      }
      break;

    case PR_HASATTACH:
      *data = MAPIBoolValue (memCtx,
                             [[self childKeysMatchingQualifier: nil
                                    andSortOrderings: nil] count] > 0);
      break;

    case PR_SENSITIVITY: // TODO
    case PR_ORIGINAL_SENSITIVITY: // TODO
      *data = MAPILongValue (memCtx, 0);
      break;

    case PR_EXPIRY_TIME: // TODO
    case PR_REPLY_TIME:
      *data = [[NSCalendarDate date] asFileTimeInMemCtx: memCtx];
      break;

    case PR_SENT_REPRESENTING_ADDRTYPE_UNICODE:
    case PR_RCVD_REPRESENTING_ADDRTYPE_UNICODE:
    case PR_RECEIVED_BY_ADDRTYPE_UNICODE:
    case PR_SENDER_ADDRTYPE_UNICODE:
      *data = [@"SMTP" asUnicodeInMemCtx: memCtx];
      break;
    case PR_ORIGINAL_AUTHOR_NAME_UNICODE:
    case PR_SENDER_NAME_UNICODE:
    case PR_SENDER_EMAIL_ADDRESS_UNICODE:
    case PR_SENT_REPRESENTING_EMAIL_ADDRESS_UNICODE:
    case PR_SENT_REPRESENTING_NAME_UNICODE:
      *data = [[sogoObject from] asUnicodeInMemCtx: memCtx];
      break;

      /* TODO: some of the following are supposed to be display names, separated by a semicolumn */
    case PR_RECEIVED_BY_NAME_UNICODE:
    case PR_RECEIVED_BY_EMAIL_ADDRESS_UNICODE:
    case PR_RCVD_REPRESENTING_NAME_UNICODE:
    case PR_RCVD_REPRESENTING_EMAIL_ADDRESS_UNICODE:
    case PR_DISPLAY_TO_UNICODE:
    case PR_ORIGINAL_DISPLAY_TO_UNICODE:
      stringValue = [sogoObject to];
      if (!stringValue)
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_DISPLAY_CC_UNICODE:
    case PR_ORIGINAL_DISPLAY_CC_UNICODE:
      stringValue = [sogoObject cc];
      if (!stringValue)
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_DISPLAY_BCC_UNICODE:
    case PR_ORIGINAL_DISPLAY_BCC_UNICODE:
      stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    case PidNameContentType:
      *data = [@"message/rfc822" asUnicodeInMemCtx: memCtx];
      break;
      
      
    //
    // TODO: Merge with the code in UI/MailerUI/UIxMailListActions.m: -messagePriority
    //       to avoid the duplication of the logic
    //
    case PR_IMPORTANCE:
      {
	unsigned int v;
	NSString *s;

	s = [[sogoObject mailHeaders] objectForKey: @"x-priority"];
	v = 0x1;
	
	
	if ([s hasPrefix: @"1"]) v = 0x2;
	else if ([s hasPrefix: @"2"]) v = 0x2;
	else if ([s hasPrefix: @"4"]) v = 0x0;
	else if ([s hasPrefix: @"5"]) v = 0x0;
	
	*data = MAPILongValue (memCtx, v);
      }
      break;

    case PR_BODY_UNICODE:
      {
        NSMutableArray *keys;

        keys = [NSMutableArray array];
        [sogoObject addRequiredKeysOfStructure: [sogoObject bodyStructure]
                                     path: @"" toArray: keys
                            acceptedTypes: [NSArray arrayWithObject:
                                                      @"text/html"]];
        if ([keys count] > 0)
          {
            *data = NULL;
            rc = MAPISTORE_ERR_NOT_FOUND;
          }
        else
          {
            [keys removeAllObjects];
            [sogoObject addRequiredKeysOfStructure: [sogoObject bodyStructure]
                                         path: @"" toArray: keys
                                acceptedTypes: [NSArray arrayWithObject:
                                                          @"text/plain"]];
            if ([keys count] > 0)
              {
                id result;
                NSData *content;
                NSDictionary *partHeaderData;
                NSString *partKey, *encoding, *charset;
 
                result = [sogoObject fetchParts: [keys objectsForKey: @"key"
                                                 notFoundMarker: nil]];
                result = [[result valueForKey: @"RawResponse"] objectForKey: @"fetch"];
                partKey = [[keys objectAtIndex: 0] objectForKey: @"key"];
                content = [[result objectForKey: partKey] objectForKey: @"data"];

                partHeaderData
                  = [sogoObject lookupInfoForBodyPart: [partKey _strippedBodyKey]];
                encoding = [partHeaderData objectForKey: @"encoding"];
                charset = [[partHeaderData objectForKey: @"parameterList"]
                            objectForKey: @"charset"];
                stringValue = [[content bodyDataFromEncoding: encoding]
                                bodyStringFromCharset: charset];

                *data = [stringValue asUnicodeInMemCtx: memCtx];
                if (strlen (*data) > 16384)
                  {
                    /* TODO: currently a hack to transfer properties as
                       streams */
                    [newProperties setObject: stringValue
                                      forKey: MAPIPropertyKey (propTag)];
                    *data = NULL;
                    rc = MAPI_E_NOT_ENOUGH_MEMORY;
                    [self logWithFormat: @"PR_BODY data too wide"];
                  }
              }
            else
	      rc = MAPISTORE_ERR_NOT_FOUND;
          }
      }
      break;
      
    case PR_INTERNET_CPID:
      /* ref:
         http://msdn.microsoft.com/en-us/library/dd317756%28v=vs.85%29.aspx

         minimal list that should be handled:
         us-ascii: 20127
         iso-8859-1: 28591
         iso-8859-15: 28605
         utf-8: 65001 */
      *data = MAPILongValue(memCtx, 65001);
      break;
      
    case PR_HTML:
      {
        NSMutableArray *keys;
        NSArray *acceptedTypes;

        acceptedTypes = [NSArray arrayWithObject: @"text/html"];
        keys = [NSMutableArray array];
        [sogoObject addRequiredKeysOfStructure: [sogoObject bodyStructure]
                                    path: @"" toArray: keys acceptedTypes: acceptedTypes];
        if ([keys count] > 0)
          {
            id result;
            NSData *content;
            NSDictionary *partHeaderData;
            NSString *key, *encoding;
            char *oldBytes, *newBytes;
            NSUInteger c, newC, max, newMax;
            
            result = [sogoObject fetchParts: [keys objectsForKey: @"key"
                                            notFoundMarker: nil]];
            result = [[result valueForKey: @"RawResponse"] objectForKey:
                                            @"fetch"];
            key = [[keys objectAtIndex: 0] objectForKey: @"key"];
            content = [[result objectForKey: key] objectForKey: @"data"];

            max = [content length];
            newMax = max;
            oldBytes = malloc (max);
            newBytes = malloc (max * 2);
            [content getBytes: oldBytes];
            newC = 0;
            for (c = 0; c < max; c++)
              {
                if (*(oldBytes + c) == '\n')
                  {
                    *(newBytes + newC) = '\r';
                    newC++;
                    newMax++;
                  }
                *(newBytes + newC) = *(oldBytes + c);
                newC++;
              }
            content = [[NSData alloc] initWithBytesNoCopy: newBytes
                                      length: newMax];;
            [content autorelease];

            partHeaderData
              = [sogoObject lookupInfoForBodyPart: [key _strippedBodyKey]];
            encoding = [partHeaderData objectForKey: @"encoding"];
            content = [content bodyDataFromEncoding: encoding];
                                      
            if ([content length] > 16384)
              {
                /* TODO: currently a hack to transfer properties as
                   streams */
                [newProperties setObject: content
                                  forKey: MAPIPropertyKey (propTag)];
                *data = NULL;
                rc = MAPI_E_NOT_ENOUGH_MEMORY;
                [self logWithFormat: @"PR_HTML data too wide"];
              }
            else
              *data = [content asBinaryInMemCtx: memCtx];
          }
        else
          {
            *data = NULL;
            rc = MAPISTORE_ERR_NOT_FOUND;
          }
      }
      break;

      /* We don't handle any RTF content. */
    case PR_RTF_COMPRESSED:
      *data = NULL;
      rc = MAPISTORE_ERR_NOT_FOUND;
      break;
    case PR_RTF_IN_SYNC:
      *data = MAPIBoolValue (memCtx, NO);
      break;
    case PR_INTERNET_MESSAGE_ID_UNICODE:
      *data = [[sogoObject messageId] asUnicodeInMemCtx: memCtx];
      break;
    case PR_READ_RECEIPT_REQUESTED: // TODO
    case PR_DELETE_AFTER_SUBMIT: // TODO
      *data = MAPIBoolValue (memCtx, NO);
      break;
    case PidLidPrivate:
      *data = MAPIBoolValue (memCtx, NO);
      break;

    case PR_MSG_EDITOR_FORMAT:
      {
        NSMutableArray *keys;
        NSArray *acceptedTypes;
        uint32_t format;

        format = 0; /* EDITOR_FORMAT_DONTKNOW */

        acceptedTypes = [NSArray arrayWithObject: @"text/plain"];
        keys = [NSMutableArray array];
        [sogoObject addRequiredKeysOfStructure: [sogoObject bodyStructure]
                                     path: @"" toArray: keys
                            acceptedTypes: acceptedTypes];
        if ([keys count] == 1)
          format = EDITOR_FORMAT_PLAINTEXT;

        acceptedTypes = [NSArray arrayWithObject: @"text/html"];
        [keys removeAllObjects];
        [sogoObject addRequiredKeysOfStructure: [sogoObject bodyStructure]
                                     path: @"" toArray: keys
                            acceptedTypes: acceptedTypes];
        if ([keys count] == 1)
          format = EDITOR_FORMAT_HTML;

        *data = MAPILongValue (memCtx, format);
      }
      break;

    case PidLidReminderSet: // TODO
    case PidLidUseTnef: // TODO
      *data = MAPIBoolValue (memCtx, NO);
      break;
    case PidLidRemoteStatus: // TODO
      *data = MAPILongValue (memCtx, 0);
      break;
    // case PidLidSmartNoAttach: // TODO
    case PidLidAgingDontAgeMe: // TODO
      *data = MAPIBoolValue (memCtx, YES);
      break;

// PidLidFlagRequest
// PidLidBillingInformation
// PidLidMileage
// PidLidCommonEnd
// PidLidCommonStart
// PidLidNonSendableBcc
// PidLidNonSendableCc
// PidLidNonSendtableTo
// PidLidNonSendBccTrackStatus
// PidLidNonSendCcTrackStatus
// PidLidNonSendToTrackStatus
// PidLidReminderDelta
// PidLidReminderFileParameter
// PidLidReminderSignalTime
// PidLidReminderOverride
// PidLidReminderPlaySound
// PidLidReminderTime
// PidLidReminderType
// PidLidSmartNoAttach
// PidLidTaskGlobalId
// PidLidTaskMode
// PidLidVerbResponse
// PidLidVerbStream
// PidLidInternetAccountName
// PidLidInternetAccountStamp
// PidLidContactLinkName
// PidLidContactLinkEntry
// PidLidContactLinkSearchKey
// PidLidSpamOriginalFolder

    default:
      rc = [super getProperty: data withTag: propTag];
    }

  return rc;
}

- (void) openMessage: (struct mapistore_message *) msg
{
  struct SRowSet *recipients;
  NSArray *to;
  NSInteger count, max;
  NGImap4EnvelopeAddress *currentAddress;
  NSString *name;

  [super openMessage: msg];
  /* Retrieve recipients from the message */
  to = [sogoObject toEnvelopeAddresses];
  max = [to count];
  recipients = talloc_zero (memCtx, struct SRowSet);
  recipients->cRows = max;
  recipients->aRow = talloc_array (recipients, struct SRow, max);
  for (count = 0; count < max; count++)
    {
      recipients->aRow[count].ulAdrEntryPad = 0;
      recipients->aRow[count].cValues = 2;
      recipients->aRow[count].lpProps = talloc_array (recipients->aRow,
                                                      struct SPropValue,
                                                      2);

      // TODO (0x01 = primary recipient)
      set_SPropValue_proptag (&(recipients->aRow[count].lpProps[0]),
                              PR_RECIPIENT_TYPE,
                              MAPILongValue (memCtx, 0x01));
      
      currentAddress = [to objectAtIndex: count];
      // name = [currentAddress personalName];
      // if (![name length])
      name = [currentAddress baseEMail];
      if (!name)
        name = @"";
      set_SPropValue_proptag (&(recipients->aRow[count].lpProps[1]),
                              PR_DISPLAY_NAME,
                              [name asUnicodeInMemCtx: recipients->aRow[count].lpProps]);
    }
  msg->recipients = recipients;
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
      [attachmentKeys addObject: keyPrefix];
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

- (NSArray *) childKeysMatchingQualifier: (EOQualifier *) qualifier
                        andSortOrderings: (NSArray *) sortOrderings
{
  if (!attachmentKeys)
    {
      attachmentKeys = [NSMutableArray new];
      attachmentParts = [NSMutableDictionary new];
      [self _fetchAttachmentPartsInBodyInfo: [sogoObject bodyStructure]
                                 withPrefix: @""];
    }

  return attachmentKeys;
}

- (id) lookupChild: (NSString *) childKey
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
          [attachment setAID: [attachmentKeys indexOfObject: childKey]];
        }
    }

  return attachment;
}

- (void) save
{
  NSNumber *value;

  value = [newProperties objectForKey: MAPIPropertyKey (PR_FLAG_STATUS)];
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
