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
#import <Foundation/NSBundle.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <NGExtensions/NSObject+Logs.h>
#import <SOGo/SOGoObject.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>

#import "MAPIStoreActiveTables.h"
#import "MAPIStoreAttachment.h"
#import "MAPIStoreAttachmentTable.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreFolder.h"
#import "MAPIStorePropertySelectors.h"
#import "MAPIStoreSamDBUtils.h"
#import "MAPIStoreTypes.h"
#import "MAPIStoreUserContext.h"
#import "NSData+MAPIStore.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreMessage.h"

#include <unrtf.h>

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

static NSString *resourcesDir = nil;

/* rtf conversion via unrtf */
static int
unrtf_data_output (void *data, const char *str, size_t str_len)
{
  NSMutableData *rtfData = data;

  [rtfData appendBytes: str length: str_len];

  return str_len;
}

static NSData *
uncompressRTF (NSData *compressedRTF)
{
  NSData *rtfData = nil;
  DATA_BLOB *rtf;
  TALLOC_CTX *mem_ctx;

  mem_ctx = talloc_zero (NULL, TALLOC_CTX);
  rtf = talloc_zero (mem_ctx, DATA_BLOB);

  if (uncompress_rtf (mem_ctx,
                      (uint8_t *) [compressedRTF bytes], [compressedRTF length],
                      rtf)
      == MAPI_E_SUCCESS)
    rtfData = [NSData dataWithBytes: rtf->data length: rtf->length];

  talloc_free (mem_ctx);

  return rtfData;
}

static NSData *
rtf2html (NSData *compressedRTF)
{
  NSData *rtf;
  NSMutableData *html = nil;
  int rc;
  struct unRTFOptions unrtfOptions;

  rtf = uncompressRTF (compressedRTF);
  if (rtf)
    {
      html = [NSMutableData data];
      memset (&unrtfOptions, 0, sizeof (struct unRTFOptions));
      unrtf_set_output_device (&unrtfOptions, unrtf_data_output, html);
      unrtfOptions.config_directory = [resourcesDir UTF8String];
      unrtfOptions.output_format = "html";
      unrtfOptions.nopict_mode = YES;
      rc = unrtf_convert_from_string (&unrtfOptions,
                                      [rtf bytes], [rtf length]);
      if (!rc)
        html = nil;
    }

  return html;
}

@interface SOGoObject (MAPIStoreProtocol)

- (NSString *) davEntityTag;
- (NSString *) davContentLength;

@end

@implementation MAPIStoreMessage

+ (void) initialize
{
  if (!resourcesDir)
    {
      resourcesDir = [[NSBundle bundleForClass: self] resourcePath];
      [resourcesDir retain];
    }
}

- (id) init
{
  if ((self = [super init]))
    {
      attachmentParts = [NSMutableDictionary new];
      activeTables = [NSMutableArray new];
      activeUserRoles = nil;
    }

  return self;
}

- (void) dealloc
{
  [activeUserRoles release];
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
  
  if ([self getPidTagSubjectPrefix: &propValue
                          inMemCtx: msgData] == MAPISTORE_SUCCESS
      && propValue)
    msgData->subject_prefix = propValue;
  else
    msgData->subject_prefix = "";

  if ([self getPidTagNormalizedSubject: &propValue
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

- (int) addPropertiesFromRow: (struct SRow *) aRow
{
  enum mapistore_error rc;
  MAPIStoreContext *context;
  SOGoUser *ownerUser;

  context = [self context];
  ownerUser = [[self userContext] sogoUser];
  if ([[context activeUser] isEqual: ownerUser]
      || [self subscriberCanModifyMessage])
    rc = [super addPropertiesFromRow: aRow];
  else
    rc = MAPISTORE_ERR_DENIED;

  return rc;
}

- (void) addProperties: (NSDictionary *) newNewProperties
{
  NSData *htmlData, *rtfData;
  static NSNumber *htmlKey = nil, *rtfKey = nil;

  [super addProperties: newNewProperties];

  if (!htmlKey)
    {
      htmlKey = MAPIPropertyKey (PR_HTML);
      [htmlKey retain];
    }

  if (!rtfKey)
    {
      rtfKey = MAPIPropertyKey (PR_RTF_COMPRESSED);
      [rtfKey retain];
    }

  if (![properties objectForKey: htmlKey])
    {
      rtfData = [properties objectForKey: rtfKey];
      if (rtfData)
        {
          htmlData = rtf2html (rtfData);
          [properties setObject: htmlData forKey: htmlKey];
          [properties removeObjectForKey: rtfKey];
          [properties removeObjectForKey: MAPIPropertyKey (PR_RTF_IN_SYNC)];
        }
    }
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

- (enum mapistore_error) saveMessage
{
  enum mapistore_error rc;
  NSArray *containerTables;
  NSUInteger count, max;
  struct mapistore_object_notification_parameters *notif_parameters;
  uint64_t folderId;
  struct mapistore_context *mstoreCtx;
  MAPIStoreContext *context;
  SOGoUser *ownerUser;

  context = [self context];
  ownerUser = [[self userContext] sogoUser];
  if ([[context activeUser] isEqual: ownerUser]
      || ((isNew
           && [(MAPIStoreFolder *) container subscriberCanCreateMessages])
          || (!isNew && [self subscriberCanModifyMessage])))
    {
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
      [properties removeAllObjects];
      [container cleanupCaches];
      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = MAPISTORE_ERR_DENIED;

  return rc;
}

/* helper getters */
- (int) getSMTPAddrType: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"SMTP" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

/* getters */
- (int) getPidTagInstID: (void **) data // TODO: DOUBT
               inMemCtx: (TALLOC_CTX *) memCtx
{
  /* we return a unique id based on the key */
  *data = MAPILongLongValue (memCtx, [[sogoObject nameInContainer] hash]);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagInstanceNum: (void **) data // TODO: DOUBT
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPidTagRowType: (void **) data // TODO: DOUBT
                inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, TBL_LEAF_ROW);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagDepth: (void **) data // TODO: DOUBT
              inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongLongValue (memCtx, 0);

  return MAPISTORE_SUCCESS;
}

/*
  Possible values are:
  
  0x00000001 Modify
  0x00000002 Read
  0x00000004 Delete
  0x00000008 Create Hierarchy Table
  0x00000010 Create Contents Table
  0x00000020 Create Associated Contents Table
*/
- (int) getPidTagAccess: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  uint32_t access = 0;
  BOOL userIsOwner;
  MAPIStoreContext *context;
  SOGoUser *ownerUser;

  context = [self context];
  ownerUser = [[self userContext] sogoUser];
  userIsOwner = [[context activeUser] isEqual: ownerUser];
  if (userIsOwner || [self subscriberCanModifyMessage])
    access |= 0x01;
  if (userIsOwner || [self subscriberCanReadMessage])
    access |= 0x02;
  if (userIsOwner || [(MAPIStoreFolder *) container subscriberCanDeleteMessages])
    access |= 0x04;
  
  *data = MAPILongValue (memCtx, access);

  return MAPISTORE_SUCCESS;
}

/*
  Possible values are:

  0x00000000 Read-Only
  0x00000001 Modify
*/
- (int) getPidTagAccessLevel: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  uint32_t access = 0;
  BOOL userIsOwner;
  MAPIStoreContext *context;
  SOGoUser *ownerUser;

  context = [self context];
  ownerUser = [[self userContext] sogoUser];
  userIsOwner = [[context activeUser] isEqual: ownerUser];
  if (userIsOwner || [self subscriberCanModifyMessage])
    access = 0x01;
  else
    access = 0;
  *data = MAPILongValue (memCtx, access);

  return MAPISTORE_SUCCESS;
}

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

- (int) getPidTagFolderId: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongLongValue (memCtx, [container objectId]);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagMid: (void **) data
            inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongLongValue (memCtx, [self objectId]);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagMessageLocaleId: (void **) data
                        inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0x0409);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagMessageFlags: (void **) data // TODO
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, MSGFLAG_FROMME | MSGFLAG_READ | MSGFLAG_UNMODIFIED);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagMessageSize: (void **) data // TODO
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  /* TODO: choose another name in SOGo for that method */
  *data = MAPILongValue (memCtx, [[sogoObject davContentLength] intValue]);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagImportance: (void **) data // TODO -> subclass?
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 1);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagPriority: (void **) data // TODO -> subclass?
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPidTagSensitivity: (void **) data // TODO -> subclass in calendar
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPidTagSubject: (void **) data
                inMemCtx: (TALLOC_CTX *) memCtx
{
  [self subclassResponsibility: _cmd];

  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidTagNormalizedSubject: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagSubject: data inMemCtx: memCtx];
}

- (int) getPidTagOriginalSubject: (void **) data
                        inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagNormalizedSubject: data inMemCtx: memCtx];
}

- (int) getPidTagConversationTopic: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagNormalizedSubject: data inMemCtx: memCtx];
}

- (int) getPidTagSubjectPrefix: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getEmptyString: data inMemCtx: memCtx];
}

- (int) getPidTagDisplayTo: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getEmptyString: data inMemCtx: memCtx];
}

- (int) getPidTagDisplayCc: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getEmptyString: data inMemCtx: memCtx];
}

- (int) getPidTagDisplayBcc: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getEmptyString: data inMemCtx: memCtx];
}

// - (int) getPidTagOriginalDisplayTo: (void **) data
// {
//   return [self getPidTagDisplayTo: data];
// }

// - (int) getPidTagOriginalDisplayCc: (void **) data
// {
//   return [self getPidTagDisplayCc: data];
// }

// - (int) getPidTagOriginalDisplayBcc: (void **) data
// {
//   return [self getPidTagDisplayBcc: data];
// }

- (int) getPidTagLastModifierName: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  NSURL *contextUrl;

  contextUrl = (NSURL *) [[self context] url];
  *data = [[contextUrl user] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagMessageClass: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  [self subclassResponsibility: _cmd];

  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidTagOriginalMessageClass: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagMessageClass: data inMemCtx: memCtx];
}

- (int) getPidTagHasAttachments: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPIBoolValue (memCtx,
                         [[self attachmentKeys] count] > 0);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagAssociated: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];;
}

- (int) setReadFlag: (uint8_t) flag
{
  // [self subclassResponsibility: _cmd];

  return MAPISTORE_ERROR;
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

- (NSArray *) activeUserRoles
{
  MAPIStoreContext *context;
  MAPIStoreUserContext *userContext;

  if (!activeUserRoles)
    {
      context = [self context];
      userContext = [self userContext];
      activeUserRoles = [[context activeUser]
                          rolesForObject: sogoObject
                               inContext: [userContext woContext]];
      [activeUserRoles retain];
    }

  return activeUserRoles;
}

- (BOOL) subscriberCanReadMessage
{
  return NO;
}

- (BOOL) subscriberCanModifyMessage
{
  return NO;
}

@end
