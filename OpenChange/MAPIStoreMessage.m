/* MAPIStoreMessage.m - this file is part of SOGo
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
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <NGExtensions/NSObject+Logs.h>
#import <SOGo/SOGoObject.h>
#import <SOGo/SOGoUser.h>

#import "MAPIStoreActiveTables.h"
#import "MAPIStoreAttachment.h"
#import "MAPIStoreAttachmentTable.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreFolder.h"
#import "MAPIStorePropertySelectors.h"
#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreMessage.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
#include <mapistore/mapistore_nameid.h>

NSData *
MAPIStoreInternalEntryId (NSString *username)
{
  NSMutableData *entryId;
  static uint8_t providerUid[] = { 0xdc, 0xa7, 0x40, 0xc8,
                                   0xc0, 0x42, 0x10, 0x1a,
                                   0xb4, 0xb9, 0x08, 0x00,
                                   0x2b, 0x2f, 0xe1, 0x82 };
  NSString *x500dn;

  /* structure:
     flags: 32
     provideruid: 32 * 4
     version: 32
     type: 32
     X500DN: variable */

  entryId = [NSMutableData dataWithCapacity: 256];
  [entryId appendUInt32: 0]; // flags
  [entryId appendBytes: providerUid length: 16]; // provideruid
  [entryId appendUInt32: 1]; // version
  [entryId appendUInt32: 0]; // type (local mail user)

  /* X500DN */
  /* FIXME: the DN will likely work on DEMO installations for now but we
     really should get the dn prefix from the server */
  x500dn = [NSString stringWithFormat: @"/O=FIRST ORGANIZATION"
                     @"/OU=FIRST ADMINISTRATIVE GROUP"
                     @"/CN=RECIPIENTS/CN=%@", username];
  [entryId appendData: [x500dn dataUsingEncoding: NSISOLatin1StringEncoding]];
  [entryId appendUInt8: 0];

  return entryId;
}

NSData *
MAPIStoreExternalEntryId (NSString *cn, NSString *email)
{
  NSMutableData *entryId;
  static uint8_t providerUid[] = { 0x81, 0x2b, 0x1f, 0xa4,
                                   0xbe, 0xa3, 0x10, 0x19,
                                   0x9d, 0x6e, 0x00, 0xdd,
                                   0x01, 0x0f, 0x54, 0x02 };
  uint8_t flags21, flags22;

  /* structure:
     flags: 32
     provideruid: 32 * 4
     version: 16
     {
       PaD: 1
       MAE: 2
       Format: 4
       M: 1
       U: 1
       R: 2
       L: 1
       Pad: 4
     }
     DisplayName: variable
     AddressType: variable
     EmailAddress: variable */

  entryId = [NSMutableData dataWithCapacity: 256];
  [entryId appendUInt32: 0]; // flags
  [entryId appendBytes: providerUid length: 16]; // provideruid
  [entryId appendUInt16: 0]; // version

  flags21 = 0;          /* PaD, MAE, R, Pad = 0 */
  flags21 |= 0x16;      /* Format: text and HTML */
  flags21 |= 0x01;     /* M: mime format */

  flags22 = 0x90;      /* U: unicode, L: no lookup */
  [entryId appendUInt8: flags21];
  [entryId appendUInt8: flags22];

  /* DisplayName */
  if (!cn)
    cn = @"";
  [entryId
    appendData: [cn dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  [entryId appendUInt16: 0];

  /* AddressType */
  [entryId
    appendData: [@"SMTP" dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  [entryId appendUInt16: 0];

  /* EMailAddress */
  if (!email)
    email = @"";
  [entryId
    appendData: [email dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  [entryId appendUInt16: 0];

  return entryId;
}

@interface SOGoObject (MAPIStoreProtocol)

- (NSString *) davEntityTag;
- (NSString *) davContentLength;

@end

@implementation MAPIStoreMessage

- (id) init
{
  if ((self = [super init]))
    {
      attachmentParts = [NSMutableDictionary new];
      activeTables = [NSMutableArray new];
    }

  return self;
}

- (void) dealloc
{
  [attachmentKeys release];
  [attachmentParts release];
  [activeTables release];
  [super dealloc];
}

- (void) getMessageData: (struct mapistore_message **) dataPtr
               inMemCtx: (TALLOC_CTX *) memCtx
{
  void *propValue;
  struct mapistore_message *msgData;

  // [self logWithFormat: @"INCOMPLETE METHOD '%s' (%d): no recipient handling",
  //       __FUNCTION__, __LINE__];

  msgData = talloc_zero (memCtx, struct mapistore_message);

  if ([self getPrSubjectPrefix: &propValue
                      inMemCtx: msgData] == MAPISTORE_SUCCESS
      && propValue)
    msgData->subject_prefix = propValue;
  else
    msgData->subject_prefix = "";

  if ([self getPrNormalizedSubject: &propValue
                          inMemCtx: msgData] == MAPISTORE_SUCCESS
      && propValue)
    msgData->normalized_subject = propValue;
  else
    msgData->normalized_subject = "";

  msgData->columns = talloc_zero(msgData, struct SPropTagArray);
  msgData->recipients_count = 0;
  *dataPtr = msgData;
}

- (NSDictionary *) _convertRecipient: (struct mapistore_message_recipient *) recipient
                          andColumns: (struct SPropTagArray *) columns
{
  NSMutableDictionary *recipientProperties;
  SOGoUser *recipientUser;
  NSUInteger count;
  id value;

  recipientProperties = [NSMutableDictionary dictionaryWithCapacity: columns->cValues + 2];

  if (recipient->username)
    {
      value = [NSString stringWithUTF8String: recipient->username];
      [recipientProperties setObject: value forKey: @"x500dn"];

      recipientUser = [SOGoUser userWithLogin: [value lowercaseString]];
      if (recipientUser)
        {
          value = [recipientUser cn];
          if ([value length] > 0)
            [recipientProperties setObject: value forKey: @"fullName"];
          value = [[recipientUser allEmails] objectAtIndex: 0];
          if ([value length] > 0)
            [recipientProperties setObject: value forKey: @"email"];
        }
    }
  else
    {
      if (recipient->data[0])
        {
          value = [NSString stringWithUTF8String: recipient->data[0]];
          if ([value length] > 0)
            [recipientProperties setObject: value forKey: @"fullName"];
        }
      if (recipient->data[1])
        {
          value = [NSString stringWithUTF8String: recipient->data[1]];
          if ([value length] > 0)
            [recipientProperties setObject: value forKey: @"email"];
        }
    }

  for (count = 0; count < columns->cValues; count++)
    {
      if (recipient->data[count])
        {
          value = NSObjectFromValuePointer (columns->aulPropTag[count],
                                            recipient->data[count]);
          if (value)
            [recipientProperties setObject: value
                                    forKey: MAPIPropertyKey (columns->aulPropTag[count])];
        }
    }

  return recipientProperties;
}

- (int) modifyRecipientsWithRecipients: (struct mapistore_message_recipient *) newRecipients
                              andCount: (NSUInteger) max
                            andColumns: (struct SPropTagArray *) columns;
{
  static NSString *recTypes[] = { @"orig", @"to", @"cc", @"bcc" };
  NSDictionary *recipientProperties;
  NSMutableDictionary *recipients;
  NSMutableArray *list;
  NSString *recType;
  struct mapistore_message_recipient *recipient;
  NSUInteger count;

  [self logWithFormat: @"METHOD '%s'", __FUNCTION__];

  recipients = [NSMutableDictionary new];
  recipientProperties = [NSDictionary dictionaryWithObject: recipients
                                                    forKey: @"recipients"];
  [recipients release];

  for (count = 0; count < max; count++)
    {
      recipient = newRecipients + count;

      if (recipient->type >= MAPI_ORIG && recipient->type <= MAPI_BCC)
        {
          recType = recTypes[recipient->type];
          list = [recipients objectForKey: recType];
          if (!list)
            {
              list = [NSMutableArray new];
              [recipients setObject: list forKey: recType];
              [list release];
            }
          [list addObject:
                  [self _convertRecipient: recipient andColumns: columns]];
        }
    }
  [self addProperties: recipientProperties];

  return MAPISTORE_SUCCESS;
}

- (MAPIStoreAttachment *) createAttachment
{
  MAPIStoreAttachment *newAttachment;
  uint32_t newAid;
  NSString *newKey;

  newAid = [[self attachmentKeys] count];

  newAttachment = [MAPIStoreAttachment
                    mapiStoreObjectWithSOGoObject: nil
                                      inContainer: self];
  [newAttachment setIsNew: YES];
  [newAttachment setAID: newAid];
  newKey = [NSString stringWithFormat: @"%ul", newAid];
  [attachmentParts setObject: newAttachment
                      forKey: newKey];
  [attachmentKeys release];
  attachmentKeys = nil;

  return newAttachment;
}

- (int) createAttachment: (MAPIStoreAttachment **) attachmentPtr
                   inAID: (uint32_t *) aidPtr
{
  MAPIStoreAttachment *attachment;
  int rc = MAPISTORE_SUCCESS;

  attachment = [self createAttachment];
  if (attachment)
    {
      *attachmentPtr = attachment;
      *aidPtr = [attachment AID];
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (id) lookupAttachment: (NSString *) childKey
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (int) getAttachment: (MAPIStoreAttachment **) attachmentPtr
              withAID: (uint32_t) aid
{
  MAPIStoreAttachment *attachment;
  NSArray *keys;
  int rc = MAPISTORE_ERR_NOT_FOUND;

  keys = [self attachmentKeys];
  if (aid < [keys count])
    {
      attachment = [self lookupAttachment: [keys objectAtIndex: aid]];
      if (attachment)
        {
          *attachmentPtr = attachment;
          rc = MAPISTORE_SUCCESS;
        }
    }

  return rc;
}

- (int) getAttachmentTable: (MAPIStoreAttachmentTable **) tablePtr
               andRowCount: (uint32_t *) countPtr
{
  MAPIStoreAttachmentTable *attTable;
  int rc = MAPISTORE_SUCCESS;

  attTable = [self attachmentTable];
  if (attTable)
    {
      *tablePtr = attTable;
      *countPtr = [[attTable childKeys] count];
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (NSArray *) activeContainerMessageTables
{
  return [[MAPIStoreActiveTables activeTables]
             activeTablesForFMID: [container objectId]
                         andType: MAPISTORE_MESSAGE_TABLE];
}

- (int) saveMessage
{
  NSArray *containerTables;
  NSUInteger count, max;
  struct mapistore_object_notification_parameters *notif_parameters;
  uint64_t folderId;
  struct mapistore_context *mstoreCtx;

  /* notifications */
  folderId = [(MAPIStoreFolder *) container objectId];
  mstoreCtx = [[self context] connectionInfo]->mstore_ctx;

  /* folder modified */
  notif_parameters
    = talloc_zero(NULL, struct mapistore_object_notification_parameters);
  notif_parameters->object_id = folderId;
  if (isNew)
    {
      notif_parameters->tag_count = 3;
      notif_parameters->tags = talloc_array (notif_parameters,
                                             enum MAPITAGS, 3);
      notif_parameters->tags[0] = PR_CONTENT_COUNT;
      notif_parameters->tags[1] = PR_MESSAGE_SIZE;
      notif_parameters->tags[2] = PR_NORMAL_MESSAGE_SIZE;
      notif_parameters->new_message_count = true;
      notif_parameters->message_count
        = [[(MAPIStoreFolder *) container messageKeys] count] + 1;
    }
  mapistore_push_notification (mstoreCtx,
                               MAPISTORE_FOLDER, MAPISTORE_OBJECT_MODIFIED,
                               notif_parameters);
  talloc_free (notif_parameters);

  /* message created */
  if (isNew)
    {
      notif_parameters
        = talloc_zero(NULL,
                      struct mapistore_object_notification_parameters);
      notif_parameters->object_id = [self objectId];
      notif_parameters->folder_id = folderId;
      
      notif_parameters->tag_count = 0xffff;
      mapistore_push_notification (mstoreCtx,
                                   MAPISTORE_MESSAGE, MAPISTORE_OBJECT_CREATED,
                                   notif_parameters);
      talloc_free (notif_parameters);
    }

  /* we ensure the table caches are loaded so that old and new state
     can be compared */
  containerTables = [self activeContainerMessageTables];
  max = [containerTables count];
  for (count = 0; count < max; count++)
    [[containerTables objectAtIndex: count] restrictedChildKeys];
  
  [self save];

  /* table modified */
  for (count = 0; count < max; count++)
    [[containerTables objectAtIndex: count]
              notifyChangesForChild: self];
  [self setIsNew: NO];
  [self resetProperties];
  [container cleanupCaches];

  return MAPISTORE_SUCCESS;
}

/* helper getters */
- (int) getSMTPAddrType: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"SMTP" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

/* getters */
- (int) getPrInstId: (void **) data // TODO: DOUBT
           inMemCtx: (TALLOC_CTX *) memCtx
{
  /* we return a unique id based on the key */
  *data = MAPILongLongValue (memCtx, [[sogoObject nameInContainer] hash]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrInstanceNum: (void **) data // TODO: DOUBT
                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPrRowType: (void **) data // TODO: DOUBT
            inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, TBL_LEAF_ROW);

  return MAPISTORE_SUCCESS;
}

- (int) getPrDepth: (void **) data // TODO: DOUBT
          inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongLongValue (memCtx, 0);

  return MAPISTORE_SUCCESS;
}

- (int) getPrAccess: (void **) data // TODO
           inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0x03);

  return MAPISTORE_SUCCESS;
}

- (int) getPrAccessLevel: (void **) data // TODO
                inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0x01);

  return MAPISTORE_SUCCESS;
}

// - (int) getPrViewStyle: (void **) data
// {
//   return [self getLongZero: data inMemCtx: memCtx];
// }

// - (int) getPrViewMajorversion: (void **) data
// {
//   return [self getLongZero: data inMemCtx: memCtx];
// }

- (int) getPidLidSideEffects: (void **) data // TODO
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPidLidCurrentVersion: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 115608); // Outlook 11.5608

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidCurrentVersionName: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"11.0" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidAutoProcessState: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0x00000000);

  return MAPISTORE_SUCCESS;
}

- (int) getPidNameContentClass: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"Sharing" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrFid: (void **) data
        inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongLongValue (memCtx, [container objectId]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrMid: (void **) data
        inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongLongValue (memCtx, [self objectId]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageLocaleId: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0x0409);

  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageFlags: (void **) data // TODO
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, MSGFLAG_FROMME | MSGFLAG_READ | MSGFLAG_UNMODIFIED);

  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageSize: (void **) data // TODO
                inMemCtx: (TALLOC_CTX *) memCtx
{
  /* TODO: choose another name in SOGo for that method */
  *data = MAPILongValue (memCtx, [[sogoObject davContentLength] intValue]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrMsgStatus: (void **) data // TODO
              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPrImportance: (void **) data // TODO -> subclass?
               inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 1);

  return MAPISTORE_SUCCESS;
}

- (int) getPrPriority: (void **) data // TODO -> subclass?
             inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPrSensitivity: (void **) data // TODO -> subclass in calendar
                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPrSubject: (void **) data
            inMemCtx: (TALLOC_CTX *) memCtx
{
  [self subclassResponsibility: _cmd];

  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPrNormalizedSubject: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrSubject: data inMemCtx: memCtx];
}

- (int) getPrOriginalSubject: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrNormalizedSubject: data inMemCtx: memCtx];
}

- (int) getPrConversationTopic: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrNormalizedSubject: data inMemCtx: memCtx];
}

- (int) getPrSubjectPrefix: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getEmptyString: data inMemCtx: memCtx];
}

- (int) getPrDisplayTo: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getEmptyString: data inMemCtx: memCtx];
}

- (int) getPrDisplayCc: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getEmptyString: data inMemCtx: memCtx];
}

- (int) getPrDisplayBcc: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getEmptyString: data inMemCtx: memCtx];
}

// - (int) getPrOriginalDisplayTo: (void **) data
// {
//   return [self getPrDisplayTo: data];
// }

// - (int) getPrOriginalDisplayCc: (void **) data
// {
//   return [self getPrDisplayCc: data];
// }

// - (int) getPrOriginalDisplayBcc: (void **) data
// {
//   return [self getPrDisplayBcc: data];
// }

- (int) getPrLastModifierName: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  NSURL *contextUrl;

  contextUrl = (NSURL *) [[self context] url];
  *data = [[contextUrl user] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageClass: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  [self subclassResponsibility: _cmd];

  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPrOrigMessageClass: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrMessageClass: data inMemCtx: memCtx];
}

- (int) getPrHasattach: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPIBoolValue (memCtx,
                         [[self attachmentKeys] count] > 0);

  return MAPISTORE_SUCCESS;
}

- (int) getPrAssociated: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];;
}

- (void) save
{
  [self subclassResponsibility: _cmd];
}

- (NSArray *) attachmentKeys
{
  if (!attachmentKeys)
    {
      attachmentKeys = [self attachmentKeysMatchingQualifier: nil
                                            andSortOrderings: nil];
      [attachmentKeys retain];
    }

  return attachmentKeys;
}

- (NSArray *) attachmentKeysMatchingQualifier: (EOQualifier *) qualifier
                             andSortOrderings: (NSArray *) sortOrderings
{
  if (qualifier)
    [self errorWithFormat: @"qualifier is not used for attachments"];
  if (sortOrderings)
    [self errorWithFormat: @"sort orderings are not used for attachments"];
  
  return [attachmentParts allKeys];
}

- (MAPIStoreAttachmentTable *) attachmentTable
{
  return [MAPIStoreAttachmentTable tableForContainer: self];
}

- (void) addActiveTable: (MAPIStoreTable *) activeTable
{
  [activeTables addObject: activeTable];
}

- (void) removeActiveTable: (MAPIStoreTable *) activeTable
{
  [activeTables removeObject: activeTable];
}

@end
