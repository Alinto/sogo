/* MAPIStoreMessage.m - this file is part of SOGo
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

@interface SOGoObject (MAPIStoreProtocol)

- (NSString *) davEntityTag;
- (NSString *) davContentLength;

@end

@implementation MAPIStoreMessage

- (id) init
{
  if ((self = [super init]))
    {
      attachmentKeys = [NSMutableArray new];
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
  static enum MAPITAGS tags[] = { PR_SUBJECT_PREFIX_UNICODE,
                                  PR_NORMALIZED_SUBJECT_UNICODE };
  struct SRowSet *recipients;
  struct SRow *properties;
  NSInteger count, max;
  const char *propName;
  void *propValue;
  struct mapistore_message *msgData;

  // [self logWithFormat: @"INCOMPLETE METHOD '%s' (%d): no recipient handling",
  //       __FUNCTION__, __LINE__];

  msgData = talloc_zero (memCtx, struct mapistore_message);

  recipients = talloc_zero (msgData, struct SRowSet);
  recipients->cRows = 0;
  recipients->aRow = NULL;
  msgData->recipients = recipients;

  max = 2;
  properties = talloc_zero (msgData, struct SRow);
  properties->cValues = 0;
  properties->ulAdrEntryPad = 0;
  properties->lpProps = talloc_array (properties, struct SPropValue, max);
  for (count = 0; count < max; count++)
    {
      if ([self getProperty: &propValue withTag: tags[count] inMemCtx: msgData]
          == MAPISTORE_SUCCESS)
	{
	  if (propValue == NULL)
	    {
	      propName = get_proptag_name (tags[count]);
	      if (!propName)
		propName = "<unknown>";
	      [self errorWithFormat: @"both 'success' and NULL data"
		    @" returned for proptag %s(0x%.8x)",
		    propName, tags[count]];
	    }
	  else
	    {
	      set_SPropValue_proptag (properties->lpProps + properties->cValues,
				      tags[count],
				      propValue);
	      properties->cValues++;
	    }
	}
    }
  msgData->properties = properties;
  *dataPtr = msgData;
}

- (NSDictionary *) _convertRecipientFromRow: (struct RecipientRow *) row
{
  NSMutableDictionary *recipient;
  NSString *value;
  SOGoUser *recipientUser;

  recipient = [NSMutableDictionary dictionaryWithCapacity: 5];

  if ((row->RecipientFlags & 0x07) == 1)
    {
      value = [NSString stringWithUTF8String: row->X500DN.recipient_x500name];
      [recipient setObject: value forKey: @"x500dn"];

      recipientUser = [SOGoUser userWithLogin: [value lowercaseString]];
      if (recipientUser)
        {
          value = [recipientUser cn];
          if ([value length] > 0)
            [recipient setObject: value forKey: @"fullName"];
          value = [[recipientUser allEmails] objectAtIndex: 0];
          if ([value length] > 0)
            [recipient setObject: value forKey: @"email"];
        }
    }
  else
    {
      switch ((row->RecipientFlags & 0x208))
        {
        case 0x08:
          // TODO: we cheat
          value = [NSString stringWithUTF8String: row->EmailAddress.lpszA];
          break;
        case 0x208:
          value = [NSString stringWithUTF8String: row->EmailAddress.lpszW];
          break;
        default:
          value = nil;
        }
      if (value)
        [recipient setObject: value forKey: @"email"];
      
      switch ((row->RecipientFlags & 0x210))
        {
        case 0x10:
          // TODO: we cheat
          value = [NSString stringWithUTF8String: row->DisplayName.lpszA];
          break;
        case 0x210:
          value = [NSString stringWithUTF8String: row->DisplayName.lpszW];
          break;
        default:
          value = nil;
        }
      if (value)
        [recipient setObject: value forKey: @"fullName"];
    }

  return recipient;
}

- (int) modifyRecipientsWithRows: (struct ModifyRecipientRow *) rows
                        andCount: (NSUInteger) max
{
  static NSString *recTypes[] = { @"orig", @"to", @"cc", @"bcc" };
  NSDictionary *recipientProperties;
  NSMutableDictionary *recipients;
  NSMutableArray *list;
  NSString *recType;
  struct ModifyRecipientRow *currentRow;
  NSUInteger count;

  [self logWithFormat: @"METHOD '%s'", __FUNCTION__];

  recipients = [NSMutableDictionary new];
  recipientProperties = [NSDictionary dictionaryWithObject: recipients
                                                    forKey: @"recipients"];
  [recipients release];

  for (count = 0; count < max; count++)
    {
      currentRow = rows + count;

      if (currentRow->RecipClass >= MAPI_ORIG
          && currentRow->RecipClass < MAPI_BCC)
        {
          recType = recTypes[currentRow->RecipClass];
          list = [recipients objectForKey: recType];
          if (!list)
            {
              list = [NSMutableArray new];
              [recipients setObject: list forKey: recType];
              [list release];
            }
          [list addObject: [self _convertRecipientFromRow:
                                   &(currentRow->RecipientRow)]];
        }
    }
  [self addNewProperties: recipientProperties];

  return MAPISTORE_SUCCESS;
}

- (MAPIStoreAttachment *) createAttachment
{
  MAPIStoreAttachment *newAttachment;
  uint32_t newAid;
  NSString *newKey;

  newAid = [attachmentKeys count];

  newAttachment = [MAPIStoreAttachment
                    mapiStoreObjectWithSOGoObject: nil
                                      inContainer: self];
  [newAttachment setIsNew: YES];
  [newAttachment setAID: newAid];
  newKey = [NSString stringWithFormat: @"%ul", newAid];
  [attachmentParts setObject: newAttachment
                      forKey: newKey];
  [attachmentKeys addObject: newKey];

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

  keys = [self childKeysMatchingQualifier: nil
                         andSortOrderings: nil];
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
      *countPtr = [[self childKeysMatchingQualifier: nil
                         andSortOrderings: nil]
                    count];
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
  [self resetNewProperties];
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
                         [[self childKeysMatchingQualifier: nil
                                          andSortOrderings: nil] count] > 0);

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

- (NSArray *) childKeysMatchingQualifier: (EOQualifier *) qualifier
                        andSortOrderings: (NSArray *) sortOrderings
{
  if (qualifier)
    [self errorWithFormat: @"qualifier is not used for attachments"];
  if (sortOrderings)
    [self errorWithFormat: @"sort orderings are not used for attachments"];
  
  return attachmentKeys;
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
