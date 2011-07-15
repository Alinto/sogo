/* MAPIStoreFolder.m - this file is part of SOGo
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

/* TODO: main key arrays must be initialized */

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <NGExtensions/NSObject+Logs.h>
#import <SOGo/SOGoFolder.h>

#import "MAPIStoreActiveTables.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreFAIMessage.h"
#import "MAPIStoreFAIMessageTable.h"
#import "MAPIStoreFolder.h"
#import "MAPIStoreFolderTable.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreMessage.h"
#import "MAPIStoreTypes.h"
#import "NSDate+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "NSObject+MAPIStore.h"
#import "SOGoMAPIFSFolder.h"
#import "SOGoMAPIFSMessage.h"

#include <gen_ndr/exchange.h>

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_nameid.h>
#include <mapistore/mapistore_errors.h>

Class NSExceptionK, MAPIStoreFAIMessageK, MAPIStoreMessageTableK, MAPIStoreFAIMessageTableK, MAPIStoreFolderTableK;

@implementation MAPIStoreFolder

+ (void) initialize
{
  NSExceptionK = [NSException class];
  MAPIStoreFAIMessageK = [MAPIStoreFAIMessage class];
  MAPIStoreMessageTableK = [MAPIStoreMessageTable class];
  MAPIStoreFAIMessageTableK = [MAPIStoreFAIMessageTable class];
  MAPIStoreFolderTableK = [MAPIStoreFolderTable class];
}

+ (id) baseFolderWithURL: (NSURL *) newURL
               inContext: (MAPIStoreContext *) newContext
{
  id newFolder;

  newFolder = [[self alloc] initWithURL: newURL inContext: newContext];
  [newFolder autorelease];

  return newFolder;
}

- (id) init
{
  if ((self = [super init]))
    {
      messageKeys = nil;
      faiMessageKeys = nil;
      folderKeys = nil;
      faiFolder = nil;
      folderURL = nil;
      context = nil;

      propsFolder = nil;
      propsMessage = nil;
    }

  return self;
}

/* from context */
- (id) initWithURL: (NSURL *) newURL
         inContext: (MAPIStoreContext *) newContext
{
  if ((self = [self init]))
    {
      context = newContext;
      ASSIGN (folderURL, newURL);
      ASSIGN (faiFolder,
              [SOGoMAPIFSFolder folderWithURL: newURL
                                 andTableType: MAPISTORE_FAI_TABLE]);
      ASSIGN (propsFolder,
              [SOGoMAPIFSFolder folderWithURL: newURL
                                andTableType: MAPISTORE_FOLDER_TABLE]);
      ASSIGN (propsMessage,
              [SOGoMAPIFSMessage objectWithName: @"properties.plist"
                                 inContainer: propsFolder]);
    }

  return self;
}

/* from parent folder */
- (id) initWithSOGoObject: (id) newSOGoObject
              inContainer: (MAPIStoreObject *) newContainer
{
  NSURL *propsURL;
  NSString *urlString;

  if ((self = [super initWithSOGoObject: newSOGoObject inContainer: newContainer]))
    {
      urlString = [[self url] stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
      propsURL = [NSURL URLWithString: urlString];
      ASSIGN (propsFolder,
              [SOGoMAPIFSFolder folderWithURL: propsURL
                                andTableType: MAPISTORE_FOLDER_TABLE]);
      ASSIGN (propsMessage,
              [SOGoMAPIFSMessage objectWithName: @"properties.plist"
                                 inContainer: propsFolder]);
    }

  return self;
}

/* backend interface */
- (id) lookupFolder: (NSString *) folderKey
{
  MAPIStoreFolder *childFolder = nil;
  SOGoFolder *sogoFolder;

  if ([[self folderKeys] containsObject: folderKey])
    {
      sogoFolder = [sogoObject lookupName: folderKey
                               inContext: nil
                               acquire: NO];
      if (sogoFolder && ![sogoFolder isKindOfClass: NSExceptionK])
        childFolder = [isa mapiStoreObjectWithSOGoObject: sogoFolder
                                             inContainer: self];
    }

  return childFolder;
}

- (id) lookupFolderByURL: (NSString *) childURL
{
  MAPIStoreObject *foundObject = nil;
  NSString *baseURL, *subURL;
  NSArray *parts;
  NSUInteger partsCount;

  baseURL = [self url];
  if (![baseURL hasSuffix: @"/"])
    baseURL = [NSString stringWithFormat: @"%@/", baseURL];
  if ([childURL hasPrefix: baseURL])
    {
      subURL = [childURL substringFromIndex: [baseURL length]];
      if ([subURL length] > 0)
        {
          parts = [subURL componentsSeparatedByString: @"/"];
          partsCount = [parts count];
          if ((partsCount == 1)
              || (partsCount == 2 && [[parts objectAtIndex: 1] length] == 0))
            foundObject = [self lookupFolder: [parts objectAtIndex: 0]];
        }
    }

  return foundObject;
}

- (id) lookupMessage: (NSString *) messageKey
{
  MAPIStoreObject *childMessage = nil;
  SOGoObject *msgObject;

  if (messageKey)
    {
      [self faiMessageKeys];
      if ([faiMessageKeys containsObject: messageKey])
        {
          msgObject = [faiFolder lookupName: messageKey
                                  inContext: nil
                                    acquire: NO];
          childMessage
            = [MAPIStoreFAIMessageK mapiStoreObjectWithSOGoObject: msgObject
                                                      inContainer: self];
        }
      else
        {
          msgObject = [sogoObject lookupName: messageKey
                                   inContext: nil
                                     acquire: NO];
          if (msgObject && ![msgObject isKindOfClass: NSExceptionK])
            childMessage
              = [[self messageClass] mapiStoreObjectWithSOGoObject: msgObject
                                                       inContainer: self];
        }
    }

  return childMessage;
}

- (id) lookupMessageByURL: (NSString *) childURL
{
  MAPIStoreObject *foundObject = nil;
  NSString *baseURL, *subURL;
  NSArray *parts;
  NSUInteger partsCount;

  baseURL = [self url];
  if (![baseURL hasSuffix: @"/"])
    baseURL = [NSString stringWithFormat: @"%@/", baseURL];
  if ([childURL hasPrefix: baseURL])
    {
      subURL = [childURL substringFromIndex: [baseURL length]];
      if ([subURL length] > 0)
        {
          parts = [subURL componentsSeparatedByString: @"/"];
          partsCount = [parts count];
          if (partsCount == 1)
            foundObject = [self lookupMessage: [parts objectAtIndex: 0]];
        }
    }

  return foundObject;
}

- (int) openFolder: (MAPIStoreFolder **) childFolderPtr
           withFID: (uint64_t) fid
{
  int rc = MAPISTORE_ERR_NOT_FOUND;
  MAPIStoreFolder *childFolder;
  MAPIStoreMapping *mapping;
  NSString *childURL;

  [self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

  mapping = [[self context] mapping];
  childURL = [mapping urlFromID: fid];
  if (childURL)
    {
      childFolder = [self lookupFolderByURL: childURL];
      if (childFolder)
        {
          *childFolderPtr = childFolder;
          rc = MAPISTORE_SUCCESS;
        }
    }

  return rc;
}

- (int) createFolder: (MAPIStoreFolder **) childFolderPtr
             withRow: (struct SRow *) aRow
              andFID: (uint64_t) fid
{
  int rc;
  MAPIStoreMapping *mapping;
  NSString *baseURL, *childURL, *folderKey;
  MAPIStoreFolder *childFolder;

  [self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

  mapping = [[self context] mapping];
  childURL = [mapping urlFromID: fid];
  if (childURL)
    rc = MAPISTORE_ERR_EXIST;
  else
    {
      folderKey = [self createFolder: aRow withFID: fid];
      if (folderKey)
        {
          [self cleanupCaches];
          baseURL = [self url];
          if (![baseURL hasSuffix: @"/"])
            baseURL = [NSString stringWithFormat: @"%@/", baseURL];
          childURL = [NSString stringWithFormat: @"%@%@",
                               baseURL, folderKey];
          [mapping registerURL: childURL withID: fid];
          childFolder = [self lookupFolder: folderKey];
          if (childFolder)
            {
              [childFolder setProperties: aRow];
              *childFolderPtr = childFolder;
              rc = MAPISTORE_SUCCESS;
            }
          else
            [NSException raise: @"MAPIStoreIOException"
                        format: @"unable to fetch created folder"];
        }
      else
        rc = MAPISTORE_ERROR;
    }

  return rc;
}

- (int) deleteFolderWithFID: (uint64_t) fid
{
  [self logWithFormat: @"UNIMPLEMENTED METHOD '%s' (%d)", __FUNCTION__, __LINE__];

  return MAPISTORE_ERROR;
}

- (int) getChildCount: (uint32_t *) rowCount
          ofTableType: (uint8_t) tableType
{
  NSArray *keys;
  int rc;

  [self logWithFormat: @"METHOD '%s' (%d) -- tableType: %d",
	__FUNCTION__, __LINE__, tableType];

  if (tableType == MAPISTORE_MESSAGE_TABLE)
    keys = [self messageKeys];
  else if (tableType == MAPISTORE_FOLDER_TABLE)
    keys = [self folderKeys];
  else if (tableType == MAPISTORE_FAI_TABLE)
    keys = [self faiMessageKeys];
  *rowCount = [keys count];
  rc = MAPI_E_SUCCESS;

  return rc;
}

- (int) openMessage: (MAPIStoreMessage **) messagePtr
     andMessageData: (struct mapistore_message **) dataPtr
            withMID: (uint64_t) mid
           inMemCtx: (TALLOC_CTX *) memCtx;
{
  NSString *messageURL;
  MAPIStoreMapping *mapping;
  MAPIStoreMessage *message;
  int rc = MAPISTORE_ERR_NOT_FOUND;

  mapping = [[self context] mapping];
  messageURL = [mapping urlFromID: mid];
  if (messageURL)
    {
      message = [self lookupMessageByURL: messageURL];
      if (message)
        {
          [message getMessageData: dataPtr inMemCtx: memCtx];
          *messagePtr = message;
          rc = MAPISTORE_SUCCESS;
        }
    }

  return rc;
}

- (int) createMessage: (MAPIStoreMessage **) messagePtr
              withMID: (uint64_t) mid
         isAssociated: (BOOL) isAssociated
{
  int rc;
  MAPIStoreMessage *message;
  NSString *baseURL, *childURL;
  MAPIStoreMapping *mapping;

  [self logWithFormat: @"METHOD '%s' -- mid: 0x%.16x, associated: %d",
	__FUNCTION__, mid, isAssociated];

  mapping = [[self context] mapping];
  if ([mapping urlFromID: mid])
    rc = MAPISTORE_ERR_EXIST;
  else
    {
      message = [self createMessage: isAssociated];
      if (message)
        {
          baseURL = [self url];
          if (![baseURL hasSuffix: @"/"])
            baseURL = [NSString stringWithFormat: @"%@/", baseURL];
          childURL = [NSString stringWithFormat: @"%@%@",
                               baseURL, [message nameInContainer]];
          [mapping registerURL: childURL withID: mid];
          *messagePtr = message;
          rc = MAPISTORE_SUCCESS;
        }
      else
        rc = MAPISTORE_ERROR;
    }

  return rc;
}

- (int) deleteMessageWithMID: (uint64_t) mid
                    andFlags: (uint8_t) flags
{
  NSString *childURL;
  MAPIStoreMapping *mapping;
  MAPIStoreMessage *message;
  NSArray *activeTables;
  NSUInteger count, max;
  struct mapistore_connection_info *connInfo;
  struct mapistore_object_notification_parameters *notif_parameters;
  int rc;

  [self logWithFormat: @"-deleteMessageWithMID: mid: 0x%.16x  flags: %d", mid, flags];
  
  mapping = [[self context] mapping];
  childURL = [mapping urlFromID: mid];
  if (childURL)
    {
      message = [self lookupMessageByURL: childURL];
      if (message)
        {
          /* we ensure the table caches are loaded so that old and new state
             can be compared */
          /* we ensure the table caches are loaded so that old and new state
             can be compared */
          activeTables = ([message isKindOfClass: MAPIStoreFAIMessageK]
                          ? [self activeFAIMessageTables]
                          : [self activeMessageTables]);
          max = [activeTables count];
          for (count = 0; count < max; count++)
            [[activeTables objectAtIndex: count] restrictedChildKeys];

          if ([[message sogoObject] delete])
            {
              rc = MAPISTORE_ERROR;
              [self logWithFormat: @"ERROR deleting object at URL: %@", childURL];
            }
          else
            {
              if (![message isNew])
                {
                  /* folder notification */
                  notif_parameters
                    = talloc_zero(NULL,
                                  struct mapistore_object_notification_parameters);
                  notif_parameters->object_id = [self objectId];
                  notif_parameters->tag_count = 5;
                  notif_parameters->tags = talloc_array (notif_parameters,
                                                         enum MAPITAGS, 5);
                  notif_parameters->tags[0] = PR_CONTENT_COUNT;
                  notif_parameters->tags[1] = PR_DELETED_COUNT_TOTAL;
                  notif_parameters->tags[2] = PR_MESSAGE_SIZE;
                  notif_parameters->tags[3] = PR_NORMAL_MESSAGE_SIZE;
                  notif_parameters->tags[4] = PR_DELETED_MSG_COUNT;
                  notif_parameters->new_message_count = true;
                  notif_parameters->message_count = [[self messageKeys]
                                                      count] - 1;
                  connInfo = [[self context] connectionInfo];
                  mapistore_push_notification (connInfo->mstore_ctx,
                                               MAPISTORE_FOLDER,
                                               MAPISTORE_OBJECT_MODIFIED,
                                               notif_parameters);
                  talloc_free(notif_parameters);

                  /* message notification */
                  notif_parameters
                    = talloc_zero(NULL,
                                  struct mapistore_object_notification_parameters);
                  notif_parameters->object_id = mid;
                  notif_parameters->folder_id = [self objectId];
                  /* Exchange sends a fnevObjectCreated!! */
                  mapistore_push_notification (connInfo->mstore_ctx,
                                               MAPISTORE_MESSAGE,
                                               MAPISTORE_OBJECT_CREATED,
                                               notif_parameters);
                  talloc_free(notif_parameters);

                  /* table notification */
                  for (count = 0; count < max; count++)
                    [[activeTables objectAtIndex: count]
                      notifyChangesForChild: message];
                }
              [self logWithFormat: @"successfully deleted object at URL: %@", childURL];
              [mapping unregisterURLWithID: mid];
              [self cleanupCaches];
              rc = MAPISTORE_SUCCESS;
            }
        }
      else
        rc = MAPI_E_INVALID_OBJECT;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getTable: (MAPIStoreTable **) tablePtr
     andRowCount: (uint32_t *) countPtr
       tableType: (uint8_t) tableType
     andHandleId: (uint32_t) handleId
{
  MAPIStoreTable *table;

  if (tableType == MAPISTORE_MESSAGE_TABLE)
    table = [self messageTable];
  else if (tableType == MAPISTORE_FAI_TABLE)
    table = [self faiMessageTable];
  else if (tableType == MAPISTORE_FOLDER_TABLE)
    table = [self folderTable];
  else
    {
      table = nil;
      [NSException raise: @"MAPIStoreIOException"
                  format: @"unsupported table type: %d", tableType];
    }
  [table setHandleId: handleId];
  *tablePtr = table;
  *countPtr = [[table childKeys] count];

  return MAPISTORE_SUCCESS;
}

- (int) setProperties: (struct SRow *) aRow
{
  static enum MAPITAGS bannedProps[] = { PR_MID, PR_FID, PR_PARENT_FID,
                                         PR_SOURCE_KEY, PR_PARENT_SOURCE_KEY,
                                         PR_CHANGE_NUM, PR_CHANGE_KEY,
                                         0x00000000 };
  enum MAPITAGS *currentProp;
  int rc;

  rc = [super setProperties: aRow];

  /* TODO: this should no longer be required once mapistore v2 API is in
     place, when we can then do this from -dealloc below */
  if ([newProperties count] > 0)
    {
      currentProp = bannedProps;
      while (*currentProp)
        {
          [newProperties removeObjectForKey: MAPIPropertyKey (*currentProp)];
          currentProp++;
        }

      [propsMessage appendProperties: newProperties];
      [propsMessage save];
      [self resetNewProperties];
    }

  return rc;
}

- (void) dealloc
{
  [propsMessage release];
  [propsFolder release];
  [folderURL release];
  [messageKeys release];
  [faiMessageKeys release];
  [folderKeys release];
  [faiFolder release];

  [super dealloc];
}

- (MAPIStoreContext *) context
{
  if (!context)
    context = [container context];

  return context;
}

- (NSArray *) messageKeys
{
  if (!messageKeys)
    {
      messageKeys = [self childKeysMatchingQualifier: nil
                                    andSortOrderings: nil];
      [messageKeys retain];
    }

  return messageKeys;
}

- (MAPIStoreFAIMessageTable *) faiMessageTable
{
  return [MAPIStoreFAIMessageTable tableForContainer: self];
}

- (NSArray *) faiMessageKeys
{
  if (!faiMessageKeys)
    {
      faiMessageKeys = [faiFolder toOneRelationshipKeys];
      [faiMessageKeys retain];
    }

  return faiMessageKeys;
}

- (MAPIStoreFolderTable *) folderTable
{
  return nil;
}

- (NSArray *) folderKeys
{
  return nil;
}

- (NSArray *) activeMessageTables
{
  return [[MAPIStoreActiveTables activeTables]
             activeTablesForFMID: [self objectId]
                         andType: MAPISTORE_MESSAGE_TABLE];
}

- (NSArray *) activeFAIMessageTables
{
  return [[MAPIStoreActiveTables activeTables]
             activeTablesForFMID: [self objectId]
                         andType: MAPISTORE_FAI_TABLE];
}

- (void) _cleanupTableCaches: (uint8_t) tableType
{
  NSArray *tables;
  NSUInteger count, max;

  tables = [[MAPIStoreActiveTables activeTables]
               activeTablesForFMID: [self objectId]
                           andType: tableType];
  max = [tables count];
  for (count = 0; count < max; count++)
    [[tables objectAtIndex: count] cleanupCaches];
}

- (void) cleanupCaches
{
  [self _cleanupTableCaches: MAPISTORE_MESSAGE_TABLE];
  [self _cleanupTableCaches: MAPISTORE_FAI_TABLE];
  [self _cleanupTableCaches: MAPISTORE_FOLDER_TABLE];
  [faiMessageKeys release];
  faiMessageKeys = nil;
  [messageKeys release];
  messageKeys = nil;
  [folderKeys release];
  folderKeys = nil;
}

- (id) lookupChild: (NSString *) childKey
{
  return [self lookupMessage: childKey];
}

- (int) getPrParentFid: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongLongValue (memCtx, [container objectId]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrFid: (void **) data
        inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongLongValue (memCtx, [self objectId]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrAccess: (void **) data
           inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0x63);

  return MAPISTORE_SUCCESS;
}

- (int) getPrAccessLevel: (void **) data
                inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0x01);

  return MAPISTORE_SUCCESS;
}

- (int) getPrAttrHidden: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (int) getPrAttrSystem: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (int) getPrAttrReadOnly: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (int) getPrSubfolders: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPIBoolValue (memCtx, [folderKeys count] > 0);
  
  return MAPISTORE_SUCCESS;
}

- (int) getPrFolderChildCount: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, [[self folderKeys] count]);
  
  return MAPISTORE_SUCCESS;
}

- (int) getPrContentCount: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, [[self messageKeys] count]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrContentUnread: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0);

  return MAPISTORE_SUCCESS;
}

- (int) getPrAssocContentCount: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, [[self faiMessageKeys] count]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrDeletedCountTotal: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  /* TODO */
  *data = MAPILongValue (memCtx, 0);

  return MAPISTORE_SUCCESS;
}

- (int) getPrLocalCommitTimeMax: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[self lastMessageModificationTime] asFileTimeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getProperty: (void **) data
            withTag: (enum MAPITAGS) propTag
           inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc;
  id value;

  value = [[propsMessage properties]
            objectForKey: MAPIPropertyKey (propTag)];
  if (value)
    rc = [value getMAPIValue: data forTag: propTag inMemCtx: memCtx];
  else
    rc = [super getProperty: data withTag: propTag inMemCtx: memCtx];

  return rc;
}

- (MAPIStoreMessage *) _createAssociatedMessage
{
  MAPIStoreMessage *newMessage;
  SOGoMAPIFSMessage *fsObject;
  NSString *newKey;

  newKey = [NSString stringWithFormat: @"%@.plist",
                     [SOGoObject globallyUniqueObjectId]];
  fsObject = [SOGoMAPIFSMessage objectWithName: newKey inContainer: faiFolder];
  newMessage = [MAPIStoreFAIMessageK mapiStoreObjectWithSOGoObject: fsObject
                                                       inContainer: self];

  
  return newMessage;
}

- (MAPIStoreMessage *) createMessage: (BOOL) isAssociated
{
  MAPIStoreMessage *newMessage;

  if (isAssociated)
    newMessage = [self _createAssociatedMessage];
  else
    newMessage = [self createMessage];
  [newMessage setIsNew: YES];

  return newMessage;
}

- (NSString *) createFolder: (struct SRow *) aRow
                    withFID: (uint64_t) newFID
{
  [self errorWithFormat: @"new folders cannot be created in this context"];

  return nil;
}

/* helpers */

- (NSString *) url
{
  NSString *url;

  if (folderURL)
    url = [folderURL absoluteString];
  else
    url = [NSString stringWithFormat: @"%@/", [super url]];

  return url;
}

- (uint64_t) objectId
{
  uint64_t objectId;

  if (folderURL)
    objectId = [self idForObjectWithKey: nil];
  else
    objectId = [super objectId];

  return objectId;
}

- (uint64_t) idForObjectWithKey: (NSString *) childKey
{
  return [[self context] idForObjectWithKey: childKey
                                inFolderURL: [self url]];
}

- (NSCalendarDate *) creationTime
{
  return [propsMessage creationTime];
}

- (NSCalendarDate *) lastModificationTime
{
  return [propsMessage lastModificationTime];
}

/* subclasses */

- (MAPIStoreMessageTable *) messageTable
{
  return nil;
}

- (Class) messageClass
{
  [self subclassResponsibility: _cmd];

  return Nil;
}

- (MAPIStoreMessage *) createMessage
{
  [self logWithFormat: @"ignored method: %s", __PRETTY_FUNCTION__];
  return nil;
}

- (NSCalendarDate *) lastMessageModificationTime
{
  [self subclassResponsibility: _cmd];

  return nil;
}

@end
