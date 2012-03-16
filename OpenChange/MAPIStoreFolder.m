/* MAPIStoreFolder.m - this file is part of SOGo
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

/* TODO: main key arrays must be initialized */

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <NGExtensions/NSObject+Logs.h>
#import <SOGo/SOGoContentObject.h>
#import <SOGo/SOGoFolder.h>

#import "MAPIStoreActiveTables.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreFAIMessage.h"
#import "MAPIStoreFAIMessageTable.h"
#import "MAPIStoreFolder.h"
#import "MAPIStoreFolderTable.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreMessage.h"
#import "MAPIStorePermissionsTable.h"
#import "MAPIStoreSamDBUtils.h"
#import "MAPIStoreTypes.h"
#import "MAPIStoreUserContext.h"
#import "NSDate+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "NSObject+MAPIStore.h"
#import "SOGoMAPIFSFolder.h"
#import "SOGoMAPIFSMessage.h"

#include <gen_ndr/exchange.h>

#undef DEBUG
#include <util/attr.h>
#include <libmapiproxy.h>
#include <mapistore/mapistore.h>
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

- (id) init
{
  if ((self = [super init]))
    {
      // messageKeys = nil;
      // faiMessageKeys = nil;
      // folderKeys = nil;
      faiFolder = nil;
      context = nil;

      propsFolder = nil;
      propsMessage = nil;
    }

  return self;
}

- (void) _setupAuxiliaryObjects
{
  NSURL *propsURL;
  NSString *urlString;

  urlString = [[self url] stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
  propsURL = [NSURL URLWithString: urlString];
  [self logWithFormat: @"_setupAuxiliaryObjects: %@", propsURL];
  ASSIGN (faiFolder,
          [SOGoMAPIFSFolder folderWithURL: propsURL
                             andTableType: MAPISTORE_FAI_TABLE]);
  ASSIGN (propsFolder,
          [SOGoMAPIFSFolder folderWithURL: propsURL
                             andTableType: MAPISTORE_FOLDER_TABLE]);
  ASSIGN (propsMessage,
          [SOGoMAPIFSMessage objectWithName: @"properties.plist"
                                inContainer: propsFolder]);
  [self setupVersionsMessage];
}

- (id) initWithSOGoObject: (id) newSOGoObject
              inContainer: (MAPIStoreObject *) newContainer
{
  /* The instantiation of auxiliary folders is postponed when newContainer is
     nil since there is no way to deduce the parent url. When setContext: is
     invoked, it becomes possible again. */
  if ((self = [super initWithSOGoObject: newSOGoObject
                            inContainer: newContainer])
      && newContainer)
    {
      [self _setupAuxiliaryObjects];
    }

  return self;
}

- (void) setContext: (MAPIStoreContext *) newContext
{
  ASSIGN (context, newContext);
  if (newContext)
    [self _setupAuxiliaryObjects];
}

- (MAPIStoreContext *) context
{
  if (!context)
    [self setContext: [container context]];

  return context;
}

- (void) dealloc
{
  // [messageKeys release];
  // [faiMessageKeys release];
  // [folderKeys release];
  [propsMessage release];
  [propsFolder release];
  [faiFolder release];
  [context release];

  [super dealloc];
}

/* backend interface */

- (SOGoMAPIFSMessage *) propertiesMessage
{
  return propsMessage;
}

- (uint64_t) objectVersion
{
  NSNumber *value;
  NSDictionary *props;
  uint64_t cn;

  props = [propsMessage properties];
  value = [props objectForKey: MAPIPropertyKey (PidTagChangeNumber)];
  if (value)
    cn = [value unsignedLongLongValue];
  else
    {
      [self logWithFormat: @"no value for PidTagChangeNumber, adding one now"];
      cn = [[self context] getNewChangeNumber];
      value = [NSNumber numberWithUnsignedLongLong: cn];
      props = [NSDictionary dictionaryWithObject: value
                                          forKey: MAPIPropertyKey (PidTagChangeNumber)];
      [propsMessage appendProperties: props];
      [propsMessage save];
    }

  return cn >> 16;
}

- (id) lookupFolder: (NSString *) folderKey
{
  MAPIStoreFolder *childFolder = nil;
  SOGoFolder *sogoFolder;
  WOContext *woContext;

  if ([[self folderKeys] containsObject: folderKey])
    {
      woContext = [[self userContext] woContext];
      sogoFolder = [sogoObject lookupName: folderKey
                                inContext: woContext
                                  acquire: NO];
      [sogoFolder setContext: woContext];
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
  Class messageClass;
  SOGoObject *msgObject;

  if (messageKey)
    {
      msgObject = [sogoObject lookupName: messageKey
                               inContext: nil
                                 acquire: NO];
      if (msgObject && ![msgObject isKindOfClass: NSExceptionK])
        {
          [msgObject setContext: [[self userContext] woContext]];
          messageClass = [msgObject mapistoreMessageClass];
          childMessage
            = [messageClass mapiStoreObjectWithSOGoObject: msgObject
                                              inContainer: self];
        }
    }

  return childMessage;
}

- (id) lookupFAIMessage: (NSString *) messageKey
{
  MAPIStoreObject *childMessage = nil;
  SOGoObject *msgObject;

  if (messageKey)
    {
      if ([[self faiMessageKeys] containsObject: messageKey])
        {
          msgObject = [faiFolder lookupName: messageKey
                                  inContext: nil
                                    acquire: NO];
          childMessage
            = [MAPIStoreFAIMessageK mapiStoreObjectWithSOGoObject: msgObject
                                                      inContainer: self];
        }
    }

  return childMessage;
}

- (id) lookupMessageByURL: (NSString *) childURL
{
  MAPIStoreObject *foundObject = nil;
  NSString *baseURL, *subURL, *key;
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
            {
              key = [parts objectAtIndex: 0];
              foundObject = [self lookupFAIMessage: key];
              if (!foundObject)
                foundObject = [self lookupMessage: key];
            }
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

  mapping = [self mapping];
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
  int rc = MAPISTORE_SUCCESS;
  MAPIStoreMapping *mapping;
  NSString *baseURL, *childURL, *folderKey;
  MAPIStoreFolder *childFolder;
  SOGoUser *ownerUser;

  [self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

  ownerUser = [[self userContext] sogoUser];
  if ([[context activeUser] isEqual: ownerUser]
      || [self subscriberCanCreateSubFolders])
    {
      mapping = [self mapping];
      childURL = [mapping urlFromID: fid];
      if (childURL)
        rc = MAPISTORE_ERR_EXIST;
      else
        {
          rc = [self createFolder: aRow withFID: fid andKey: &folderKey];
          if (rc == MAPISTORE_SUCCESS)
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
                  [childFolder addPropertiesFromRow: aRow];
                  *childFolderPtr = childFolder;
                }
              else
                [NSException raise: @"MAPIStoreIOException"
                            format: @"unable to fetch created folder"];
            }
        }
    }
  else
    rc = MAPISTORE_ERR_DENIED;

  return rc;
}

- (int) deleteFolder
{
  [propsMessage delete];
  [propsFolder delete];
  [faiFolder delete];

  [self cleanupCaches];

  return MAPISTORE_SUCCESS;
}

- (int) getChildCount: (uint32_t *) rowCount
          ofTableType: (enum mapistore_table_type) tableType
{
  NSArray *keys;
  int rc = MAPISTORE_SUCCESS;

  [self logWithFormat: @"METHOD '%s' (%d) -- tableType: %d",
	__FUNCTION__, __LINE__, tableType];

  if (tableType == MAPISTORE_MESSAGE_TABLE)
    keys = [self messageKeys];
  else if (tableType == MAPISTORE_FOLDER_TABLE)
    keys = [self folderKeys];
  else if (tableType == MAPISTORE_FAI_TABLE)
    keys = [self faiMessageKeys];
  else
    {
      keys = nil;
      rc = MAPISTORE_ERR_NOT_FOUND;
    }
  *rowCount = [keys count];

  return rc;
}

- (int) openMessage: (MAPIStoreMessage **) messagePtr
            withMID: (uint64_t) mid
         forWriting: (BOOL) readWrite
           inMemCtx: (TALLOC_CTX *) memCtx;
{
  NSString *messageURL;
  MAPIStoreMapping *mapping;
  MAPIStoreMessage *message;
  SOGoUser *ownerUser;
  int rc = MAPISTORE_ERR_NOT_FOUND;

  mapping = [self mapping];
  messageURL = [mapping urlFromID: mid];
  if (messageURL)
    {
      message = [self lookupMessageByURL: messageURL];
      if (message)
        {
          ownerUser = [[self userContext] sogoUser];
          if ([[context activeUser] isEqual: ownerUser]
              || (readWrite && [message subscriberCanModifyMessage])
              || (!readWrite && [message subscriberCanReadMessage]))
            {
              *messagePtr = message;
              rc = MAPISTORE_SUCCESS;
            }
          else
            rc = MAPISTORE_ERR_DENIED;
        }
    }

  return rc;
}

- (int) createMessage: (MAPIStoreMessage **) messagePtr
              withMID: (uint64_t) mid
         isAssociated: (BOOL) isAssociated
{
  enum mapistore_error rc;
  MAPIStoreMessage *message;
  NSString *baseURL, *childURL;
  MAPIStoreMapping *mapping;
  SOGoUser *ownerUser;

  [self logWithFormat: @"METHOD '%s' -- mid: 0x%.16llx  associated: %d",
	__FUNCTION__, mid, isAssociated];

  context = [self context];
  ownerUser = [[self userContext] sogoUser];

  if ([[context activeUser] isEqual: ownerUser]
      || (!isAssociated && [self subscriberCanCreateMessages]))
    {
      mapping = [self mapping];
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
    }
  else
    rc = MAPISTORE_ERR_DENIED;

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
  id msgObject;
  SOGoUser *ownerUser;
  struct mapistore_connection_info *connInfo;
  struct mapistore_object_notification_parameters *notif_parameters;
  int rc;

  [self logWithFormat: @"-deleteMessageWithMID: mid: 0x%.16llx  flags: %d", mid, flags];
  
  mapping = [self mapping];
  childURL = [mapping urlFromID: mid];
  if (childURL)
    {
      message = [self lookupMessageByURL: childURL];
      if (message)
        {
          ownerUser = [[self userContext] sogoUser];

          if ([[context activeUser] isEqual: ownerUser]
              || (![message isKindOfClass: MAPIStoreFAIMessageK]
                  && [self subscriberCanDeleteMessages]))
            {
              /* we ensure the table caches are loaded so that old and new state
                 can be compared */
              activeTables = ([message isKindOfClass: MAPIStoreFAIMessageK]
                              ? [self activeFAIMessageTables]
                              : [self activeMessageTables]);
              max = [activeTables count];
              for (count = 0; count < max; count++)
                [[activeTables objectAtIndex: count] restrictedChildKeys];

              msgObject = [message sogoObject];
              if (([msgObject respondsToSelector: @selector (prepareDelete)]
                   && [msgObject prepareDelete])
                  || [msgObject delete])
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
            rc = MAPISTORE_ERR_DENIED;
        }
      else
        rc = MAPISTORE_ERR_NOT_FOUND;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) moveCopyMessageWithMID: (uint64_t) srcMid
                    fromFolder: (MAPIStoreFolder *) sourceFolder
                       withMID: (uint64_t) targetMid
                  andChangeKey: (struct Binary_r *) targetChangeKey
                      wantCopy: (uint8_t) wantCopy
{
  int rc;
  MAPIStoreMessage *sourceMsg, *destMsg;
  TALLOC_CTX *memCtx;
  struct SPropTagArray *availableProps;
  bool *exclusions;
  NSUInteger count;
  enum MAPITAGS propTag;
  struct SRow *aRow;
  int error;
  void *data;

  memCtx = talloc_zero (NULL, TALLOC_CTX);
  rc = [sourceFolder openMessage: &sourceMsg
                         withMID: srcMid
                      forWriting: NO
                        inMemCtx: memCtx];
  if (rc != MAPISTORE_SUCCESS)
    goto end;

  rc = [sourceMsg getAvailableProperties: &availableProps
                                inMemCtx: memCtx];
  if (rc != MAPISTORE_SUCCESS)
    goto end;

  exclusions = talloc_array(NULL, bool, 65536);
  exclusions[PR_ROW_TYPE >> 16] = true;
  exclusions[PR_INSTANCE_KEY >> 16] = true;
  exclusions[PR_INSTANCE_NUM >> 16] = true;
  exclusions[PR_INST_ID >> 16] = true;
  exclusions[PR_FID >> 16] = true;
  exclusions[PR_MID >> 16] = true;
  exclusions[PR_SOURCE_KEY >> 16] = true;
  exclusions[PR_PARENT_SOURCE_KEY >> 16] = true;
  exclusions[PR_PARENT_FID >> 16] = true;
  exclusions[PR_CHANGE_KEY >> 16] = true;
  exclusions[PR_PREDECESSOR_CHANGE_LIST >> 16] = true;

  aRow = talloc_zero (memCtx, struct SRow);
  aRow->lpProps = talloc_array (aRow, struct SPropValue, 65535);

  for (count = 0; count < availableProps->cValues; count++)
    {
      propTag = availableProps->aulPropTag[count];
      if (!exclusions[propTag >> 16])
        {
          error = [sourceMsg getProperty: &data
                                 withTag: propTag
                                inMemCtx: aRow];
          if (error == MAPISTORE_SUCCESS && data)
            {
              set_SPropValue_proptag(&aRow->lpProps[aRow->cValues], propTag, data);
              aRow->cValues++;
            }
        }
    }

  if (targetChangeKey)
    {
      set_SPropValue_proptag(&aRow->lpProps[aRow->cValues], PR_CHANGE_KEY, targetChangeKey);
      aRow->cValues++;
    }

  rc = [self createMessage: &destMsg withMID: targetMid
              isAssociated: [sourceMsg isKindOfClass: MAPIStoreFAIMessageK]];
  if (rc != MAPISTORE_SUCCESS)
    goto end;
  rc = [destMsg addPropertiesFromRow: aRow];
  if (rc != MAPISTORE_SUCCESS)
    goto end;
  [destMsg save];
  if (!wantCopy)
    rc = [sourceFolder deleteMessageWithMID: srcMid andFlags: 0];

 end:
  talloc_free (memCtx);

  return rc;
}

- (int) moveCopyMessagesWithMIDs: (uint64_t *) srcMids
                        andCount: (uint32_t) midCount
                      fromFolder: (MAPIStoreFolder *) sourceFolder
                        withMIDs: (uint64_t *) targetMids
                   andChangeKeys: (struct Binary_r **) targetChangeKeys
                        wantCopy: (uint8_t) wantCopy
{
  int rc = MAPISTORE_SUCCESS;
  NSUInteger count;
  NSMutableArray *oldMessageURLs;
  NSString *oldMessageURL;
  MAPIStoreMapping *mapping;
  SOGoUser *ownerUser;
  struct Binary_r *targetChangeKey;

  ownerUser = [[self userContext] sogoUser];

  if (wantCopy || [[context activeUser] isEqual: ownerUser])
    {
      if ([sourceFolder isKindOfClass: isa]
          || [self isKindOfClass: [sourceFolder class]])
        [self logWithFormat: @"%s: this class could probably implement"
              @" a specialized/optimized version", __FUNCTION__];
      oldMessageURLs = [NSMutableArray arrayWithCapacity: midCount];
      mapping = [self mapping];
      for (count = 0; rc == MAPISTORE_SUCCESS && count < midCount; count++)
        {
          oldMessageURL = [mapping urlFromID: srcMids[count]];
          if (oldMessageURL)
            {
              [oldMessageURLs addObject: oldMessageURL];
              if (targetChangeKeys)
                targetChangeKey = targetChangeKeys[count];
              else
                targetChangeKey = NULL;
              rc = [self moveCopyMessageWithMID: srcMids[count]
                                     fromFolder: sourceFolder
                                        withMID: targetMids[count]
                                   andChangeKey: targetChangeKey
                                       wantCopy: wantCopy];
            }
          else
            rc = MAPISTORE_ERR_NOT_FOUND;
        }

      /* Notifications */
      if (rc == MAPISTORE_SUCCESS)
        {
          [self postNotificationsForMoveCopyMessagesWithMIDs: srcMids
                                              andMessageURLs: oldMessageURLs
                                                    andCount: midCount
                                                  fromFolder: sourceFolder
                                                    withMIDs: targetMids
                                                    wantCopy: wantCopy];

          // We cleanup cache of our source and destination folders
          [self cleanupCaches];
          [sourceFolder cleanupCaches];
        }
    }
  else
    rc = MAPISTORE_ERR_DENIED;

  return rc;
}

- (SOGoFolder *) aclFolder
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (void) _modifyPermissionEntryForUser: (NSString *) user
                             withRoles: (NSArray *) roles
                            isAddition: (BOOL) isAddition
                         withACLFolder: (SOGoFolder *) aclFolder
{
  if (user)
    {
      if (isAddition)
        [aclFolder addUserInAcls: user];
      [aclFolder setRoles: roles forUser: user];
    }
  else
    [self logWithFormat: @"user is nil, keeping intended entry intact"];
}

- (void) setupVersionsMessage
{
}

- (void) postNotificationsForMoveCopyMessagesWithMIDs: (uint64_t *) srcMids
                                       andMessageURLs: (NSArray *) oldMessageURLs
                                             andCount: (uint32_t) midCount
                                           fromFolder: (MAPIStoreFolder *) sourceFolder
                                             withMIDs: (uint64_t *) targetMids
                                             wantCopy: (uint8_t) wantCopy
{
  NSArray *activeTables;
  NSUInteger count, tableCount, max;
  MAPIStoreMessage *message;
  NSString *messageURL;
  MAPIStoreMapping *mapping;
  struct mapistore_object_notification_parameters *notif_parameters;
  struct mapistore_connection_info *connInfo;

  connInfo = [[self context] connectionInfo];
  
  // For the "source folder, we ensure the table caches are loaded so
  // that old and new state can be compared
  activeTables = [sourceFolder activeMessageTables];
  max = [activeTables count];
  for (count = 0; count < max; count++)
    [[activeTables objectAtIndex: count] restrictedChildKeys];
 
  if (!wantCopy)
    {
      // We notify the client. We start with the source folder.
      notif_parameters = talloc_zero(NULL, struct mapistore_object_notification_parameters);
      notif_parameters->object_id = [sourceFolder objectId];
      notif_parameters->tag_count = 5;
      notif_parameters->tags = talloc_array (notif_parameters, enum MAPITAGS, 5);
      notif_parameters->tags[0] = PR_CONTENT_COUNT;
      notif_parameters->tags[1] = PR_DELETED_COUNT_TOTAL;
      notif_parameters->tags[2] = PR_MESSAGE_SIZE;
      notif_parameters->tags[3] = PR_NORMAL_MESSAGE_SIZE;
      notif_parameters->tags[4] = PR_RECIPIENT_ON_NORMAL_MSG_COUNT;
      notif_parameters->new_message_count = true;
      notif_parameters->message_count = [[sourceFolder messageKeys] count] - midCount;
      mapistore_push_notification (connInfo->mstore_ctx,
                                   MAPISTORE_FOLDER,
                                   MAPISTORE_OBJECT_MODIFIED,
                                   notif_parameters);
      talloc_free(notif_parameters);
    }

  // move/copy notification of the copied/moved message
  for (count = 0; count < midCount; count++)
    {
      notif_parameters = talloc_zero (NULL, struct mapistore_object_notification_parameters);
      notif_parameters->tag_count = 0;
      notif_parameters->new_message_count = true;
      notif_parameters->message_count = 0;
      notif_parameters->object_id = targetMids[count];
      notif_parameters->folder_id = [self objectId];
      notif_parameters->old_object_id = srcMids[count];
      notif_parameters->old_folder_id = [sourceFolder objectId];

      mapistore_push_notification (connInfo->mstore_ctx,
                                   MAPISTORE_MESSAGE,
                                   (wantCopy ? MAPISTORE_OBJECT_COPIED : MAPISTORE_OBJECT_MOVED),
                                   notif_parameters);
      talloc_free (notif_parameters);

      message = [sourceFolder lookupMessageByURL: [oldMessageURLs objectAtIndex: count]];
      // table notification 
      for (tableCount = 0; tableCount < max; tableCount++)
        [[activeTables objectAtIndex: tableCount]
          notifyChangesForChild: message];
    }

  // For the "destination folder, we ensure the table caches are loaded so
  // that old and new state can be compared
  activeTables = [self activeMessageTables];
  max = [activeTables count];
  for (count = 0; count < max; count++)
    [[activeTables objectAtIndex: count] restrictedChildKeys];

  notif_parameters = talloc_zero(NULL, struct mapistore_object_notification_parameters);
  notif_parameters->object_id = [self objectId];
  notif_parameters->tag_count = 5;
  notif_parameters->tags = talloc_array (notif_parameters, enum MAPITAGS, 5);
  notif_parameters->tags[0] = PR_CONTENT_COUNT;
  notif_parameters->tags[1] = PR_DELETED_COUNT_TOTAL;
  notif_parameters->tags[2] = PR_MESSAGE_SIZE;
  notif_parameters->tags[3] = PR_NORMAL_MESSAGE_SIZE;
  notif_parameters->tags[4] = PR_RECIPIENT_ON_NORMAL_MSG_COUNT;
  notif_parameters->new_message_count = true;
  notif_parameters->message_count = [[self messageKeys] count] + midCount;
  connInfo = [[self context] connectionInfo];
  mapistore_push_notification (connInfo->mstore_ctx,
                               MAPISTORE_FOLDER,
                               MAPISTORE_OBJECT_MODIFIED,
                               notif_parameters);
  talloc_free(notif_parameters);

  // table notification 
  mapping = [self mapping];
  for (count = 0; count < midCount; count++)
    {
      messageURL = [mapping urlFromID: targetMids[count]];
      message = [self lookupMessageByURL: messageURL];
      for (tableCount = 0; tableCount < max; tableCount++)
        [[activeTables objectAtIndex: tableCount]
          notifyChangesForChild: message];
    }
}

- (int) getDeletedFMIDs: (struct I8Array_r **) fmidsPtr
                  andCN: (uint64_t *) cnPtr
       fromChangeNumber: (uint64_t) changeNum
            inTableType: (enum mapistore_table_type) tableType
               inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc;
  NSString *baseURL, *format, *url;
  NSArray *keys;
  NSNumber *cnNbr;
  NSUInteger count, max;
  MAPIStoreMapping *mapping;
  struct I8Array_r *fmids;
  uint64_t fmid;

  keys = [self getDeletedKeysFromChangeNumber: changeNum andCN: &cnNbr
                                  inTableType: tableType];
  if (keys)
    {
      mapping = [self mapping];

      max = [keys count];

      fmids = talloc_zero (memCtx, struct I8Array_r);
      fmids->cValues = 0;
      fmids->lpi8 = talloc_array (fmids, int64_t, max);
      *fmidsPtr = fmids;
      if (max > 0)
        *cnPtr = [cnNbr unsignedLongLongValue];

      baseURL = [self url];
      if ([baseURL hasSuffix: @"/"])
        format = @"%@%@";
      else
        format = @"%@/%@";

      for (count = 0; count < max; count++)
        {
          url = [NSString stringWithFormat: format,
                          baseURL, [keys objectAtIndex: count]];
          fmid = [mapping idFromURL: url];
          if (fmid != NSNotFound) /* if no fmid is returned, then the object
                                     "never existed" in the OpenChange
                                     databases */
            {
              fmids->lpi8[fmids->cValues] = fmid;
              fmids->cValues++;
            }
        }

      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getTable: (MAPIStoreTable **) tablePtr
     andRowCount: (uint32_t *) countPtr
       tableType: (enum mapistore_table_type) tableType
     andHandleId: (uint32_t) handleId
{
  int rc = MAPISTORE_SUCCESS;
  MAPIStoreTable *table;
  SOGoUser *ownerUser;

  if (tableType == MAPISTORE_MESSAGE_TABLE)
    table = [self messageTable];
  else if (tableType == MAPISTORE_FAI_TABLE)
    table = [self faiMessageTable];
  else if (tableType == MAPISTORE_FOLDER_TABLE)
    table = [self folderTable];
  else if (tableType == MAPISTORE_PERMISSIONS_TABLE)
    {
      ownerUser = [[self userContext] sogoUser];
      if ([[context activeUser] isEqual: ownerUser])
        table = [self permissionsTable];
      else
        rc = MAPISTORE_ERR_DENIED;
    }
  else
    {
      table = nil;
      [NSException raise: @"MAPIStoreIOException"
                  format: @"unsupported table type: %d", tableType];
    }

  if (rc == MAPISTORE_SUCCESS)
    {
      if (table)
        {
          [table setHandleId: handleId];
          *tablePtr = table;
          *countPtr = [[table childKeys] count];
        }
      else
        rc = MAPISTORE_ERR_NOT_FOUND;
    }

  return rc;
}

- (void) addProperties: (NSDictionary *) newProperties
{
  static enum MAPITAGS bannedProps[] = { PR_MID, PR_FID, PR_PARENT_FID,
                                         PR_SOURCE_KEY, PR_PARENT_SOURCE_KEY,
                                         PR_CHANGE_KEY, 0x00000000 };
  enum MAPITAGS *currentProp;
  NSMutableDictionary *propsCopy;

  /* TODO: this should no longer be required once mapistore v2 API is in
     place, when we can then do this from -dealloc below */

  propsCopy = [newProperties mutableCopy];
  currentProp = bannedProps;
  while (*currentProp)
    {
      [propsCopy removeObjectForKey: MAPIPropertyKey (*currentProp)];
      currentProp++;
    }

  [propsMessage appendProperties: propsCopy];
  [propsMessage save];
  [propsCopy release];
}

- (NSArray *) messageKeys
{
  return [self messageKeysMatchingQualifier: nil
                           andSortOrderings: nil];
  // if (!messageKeys)
  //   {
  //     messageKeys = [self messageKeysMatchingQualifier: nil
  //                                     andSortOrderings: nil];
  //     [messageKeys retain];
  //   }

  // return messageKeys;
}

- (MAPIStoreFAIMessageTable *) faiMessageTable
{
  return [MAPIStoreFAIMessageTable tableForContainer: self];
}

- (NSArray *) faiMessageKeysMatchingQualifier: (EOQualifier *) qualifier
                             andSortOrderings: (NSArray *) sortOrderings
{
  return [faiFolder
           toOneRelationshipKeysMatchingQualifier: qualifier
                                 andSortOrderings: sortOrderings];
}

- (NSArray *) faiMessageKeys
{
  return [self faiMessageKeysMatchingQualifier: nil
                              andSortOrderings: nil];
  // if (!faiMessageKeys)
  //   {
  //     faiMessageKeys = [self faiMessageKeysMatchingQualifier: nil
  //                                           andSortOrderings: nil];
  //     [faiMessageKeys retain];
  //   }

  // return faiMessageKeys;
}

- (MAPIStoreFolderTable *) folderTable
{
  return [MAPIStoreFolderTable tableForContainer: self];
}

- (NSArray *) folderKeys
{
  return [self folderKeysMatchingQualifier: nil
                          andSortOrderings: nil];
  // if (!folderKeys)
  //   {
  //     folderKeys = [self folderKeysMatchingQualifier: nil
  //                                   andSortOrderings: nil];
  //     [folderKeys retain];
  //   }

  // return folderKeys;
}

- (NSArray *) folderKeysMatchingQualifier: (EOQualifier *) qualifier
                         andSortOrderings: (NSArray *) sortOrderings
{
  if (qualifier)
    [self errorWithFormat: @"qualifier is not used for folders"];
  if (sortOrderings)
    [self errorWithFormat: @"sort orderings are not used for folders"];

  return [sogoObject toManyRelationshipKeys];
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

- (void) _cleanupTableCaches: (enum mapistore_table_type) tableType
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
  // [faiMessageKeys release];
  // faiMessageKeys = nil;
  // [messageKeys release];
  // messageKeys = nil;
  // [folderKeys release];
  // folderKeys = nil;
}

- (int) getPidTagParentFolderId: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongLongValue (memCtx, [container objectId]);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagFolderId: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongLongValue (memCtx, [self objectId]);

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
  SOGoUser *ownerUser;
  BOOL userIsOwner;

  ownerUser = [[self userContext] sogoUser];

  userIsOwner = [[context activeUser] isEqual: ownerUser];
  if (userIsOwner || [self subscriberCanModifyMessages])
    access |= 0x01;
  if (userIsOwner || [self subscriberCanReadMessages])
    access |= 0x02;
  if (userIsOwner || [self subscriberCanDeleteMessages])
    access |= 0x04;
  if ((userIsOwner || [self subscriberCanCreateSubFolders])
      && [self supportsSubFolders])
    access |= 0x08;
  if (userIsOwner || [self subscriberCanCreateMessages])
    access |= 0x10;
  if (userIsOwner)
    access |= 0x20;
  
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
  *data = MAPILongValue (memCtx, 0x01);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagAttributeHidden: (void **) data
                        inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (int) getPidTagAttributeSystem: (void **) data
                        inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (int) getPidTagAttributeReadOnly: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (int) getPidTagSubfolders: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPIBoolValue (memCtx, [[self folderKeys] count] > 0);
  
  return MAPISTORE_SUCCESS;
}

- (int) getPidTagFolderChildCount: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, [[self folderKeys] count]);
  
  return MAPISTORE_SUCCESS;
}

- (int) getPidTagContentCount: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, [[self messageKeys] count]);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagContentUnreadCount: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagAssociatedContentCount: (void **) data
                               inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, [[self faiMessageKeys] count]);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagDeletedCountTotal: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  /* TODO */
  *data = MAPILongValue (memCtx, 0);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagLocalCommitTimeMax: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;
  NSDate *date;

  date = [self lastMessageModificationTime];
  if (date)
    *data = [date asFileTimeInMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidTagDefaultPostMessageClass: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"IPM.Note" asUnicodeInMemCtx: memCtx];

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
    rc = [value getValue: data forTag: propTag inMemCtx: memCtx];
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
  WOContext *woContext;

  if (isAssociated)
    newMessage = [self _createAssociatedMessage];
  else
    newMessage = [self createMessage];
  [newMessage setIsNew: YES];
  woContext = [[self userContext] woContext];
  [[newMessage sogoObject] setContext: woContext];

  return newMessage;
}

- (enum mapistore_error) createFolder: (struct SRow *) aRow
                              withFID: (uint64_t) newFID
                               andKey: (NSString **) newKeyP
{
  [self errorWithFormat: @"new folders cannot be created in this context"];

  return MAPISTORE_ERR_DENIED;
}

/* helpers */

- (NSString *) url
{
  NSString *url;

  if (container)
    url = [NSString stringWithFormat: @"%@/", [super url]];
  else
    {
      url = [[context url] absoluteString];
      if (![url hasSuffix: @"/"])
        url = [NSString stringWithFormat: @"%@/", url];
    }

  return url;
}

- (MAPIStorePermissionsTable *) permissionsTable
{
  return [MAPIStorePermissionsTable tableForContainer: self];
}

- (NSArray *) permissionEntries
{
  NSMutableArray *permissionEntries;
  MAPIStorePermissionEntry *entry;
  NSArray *aclUsers;
  uint64_t memberId, regularMemberId = 1;
  NSUInteger count, max;
  NSString *username, *defaultUserId;
  SOGoFolder *aclFolder;

  aclFolder = [self aclFolder];

  defaultUserId = [aclFolder defaultUserID];
  aclUsers = [aclFolder aclUsers];
  max = [aclUsers count];
  permissionEntries = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      username = [aclUsers objectAtIndex: count];
      if (![username hasPrefix: @"@"])
        {
          if ([username isEqualToString: defaultUserId])
            memberId = 0;
          else if ([username isEqualToString: @"anonymous"])
            memberId = ULLONG_MAX;
          else
            {
              memberId = regularMemberId;
              regularMemberId++;
            }
          entry = [MAPIStorePermissionEntry entryWithUserId: username
                                                andMemberId: memberId
                                                  forFolder: self];
          [permissionEntries addObject: entry];
        }
    }

  return permissionEntries;
}

- (NSArray *) rolesForExchangeRights: (uint32_t) rights
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (uint32_t) exchangeRightsForRoles: (NSArray *) roles
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (NSString *) _usernameFromEntryId: (struct SBinary_short *) bin
{
  struct Binary_r bin32;
  struct AddressBookEntryId *entryId;
  NSString *username;
  struct ldb_context *samCtx;

  if (bin && bin->cb)
    {
      bin32.cb = bin->cb;
      bin32.lpb = bin->lpb;

      entryId = get_AddressBookEntryId (NULL, &bin32);
      if (entryId)
        {
          samCtx = [[self context] connectionInfo]->sam_ctx;
          username = MAPIStoreSamDBUserAttribute (samCtx, @"legacyExchangeDN",
                                                  [NSString stringWithUTF8String: entryId->X500DN],
                                                  @"sAMAccountName");
        }
      else
        username = nil;
      talloc_free (entryId);
    }
  else
    username = nil;

  return username;
}

- (NSString *) _usernameFromMemberId: (uint64_t) memberId
                           inEntries: (NSArray *) entries
{
  NSString *username = nil;
  NSUInteger count, max;
  MAPIStorePermissionEntry *entry;

  if (memberId == 0)
    username = [[self aclFolder] defaultUserID];
  else if (memberId == ULLONG_MAX)
    username = @"anonymous";
  else
    {
      max = [entries count];
      for (count = 0; !username && count < max; count++)
        {
          entry = [entries objectAtIndex: count];
          if ([entry memberId] == memberId)
            username = [entry userId];
        }
    }

  return username;
}

- (void) _emptyACL
{
  NSUInteger count, max;
  NSArray *users;
  SOGoFolder *aclFolder;

  aclFolder = [self aclFolder];

  users = [aclFolder aclUsers];
  max = [users count];
  for (count = 0; count < max; count++)
    [aclFolder removeUserFromAcls: [users objectAtIndex: count]];
}

- (int) modifyPermissions: (struct PermissionData *) permissions
                withCount: (uint16_t) pcount
                 andFlags: (int8_t) flags
{
  NSUInteger count, propCount;
  struct PermissionData *currentPermission;
  struct mapi_SPropValue *mapiValue;
  NSString *permissionUser;
  NSArray *entries;
  NSArray *permissionRoles;
  BOOL reset, isAdd = NO, isDelete = NO, isModify = NO;
  SOGoFolder *aclFolder;

  aclFolder = [self aclFolder];

  reset = ((flags & ModifyPerms_ReplaceRows) != 0);
  if (reset)
    [self _emptyACL];

  entries = [self permissionEntries];

  for (count = 0; count < pcount; count++)
    {
      currentPermission = permissions + count;

      permissionUser = nil;
      permissionRoles = nil;
 
      if (currentPermission->PermissionDataFlags == ROW_ADD)
        isAdd = YES;
      else if (currentPermission->PermissionDataFlags == ROW_MODIFY)
        isModify = YES;
      else
        isDelete = YES;

      for (propCount = 0;
           propCount < currentPermission->lpProps.cValues;
           propCount++)
        {
          mapiValue = currentPermission->lpProps.lpProps + propCount;
          switch (mapiValue->ulPropTag)
            {
            case PR_ENTRYID:
              if (isAdd)
                permissionUser
                  = [self _usernameFromEntryId: &mapiValue->value.bin];
              break;
            case PR_MEMBER_ID:
              if (isModify || isDelete)
                permissionUser = [self _usernameFromMemberId: mapiValue->value.d
                                                   inEntries: entries];
              break;
            case PR_MEMBER_RIGHTS:
              if (isAdd || isModify)
                permissionRoles
                  = [self rolesForExchangeRights: mapiValue->value.l];
              break;
            default:
              if (mapiValue->ulPropTag != PR_MEMBER_NAME)
                [self warnWithFormat: @"unhandled permission property: %.8x",
                      mapiValue->ulPropTag];
            }
        }

      if (reset)
        {
          if (isAdd)
            [self _modifyPermissionEntryForUser: permissionUser
                                      withRoles: permissionRoles
                                     isAddition: YES
                                  withACLFolder: aclFolder];
        }
      else
        {
          if (isAdd || currentPermission->PermissionDataFlags == ROW_MODIFY)
            [self _modifyPermissionEntryForUser: permissionUser
                                      withRoles: permissionRoles
                                     isAddition: isAdd
                                  withACLFolder: aclFolder];
          else if (currentPermission->PermissionDataFlags == ROW_REMOVE)
            [aclFolder removeUserFromAcls: permissionUser];
          else
            [self errorWithFormat: @"unhandled permission action flag: %d",
                  currentPermission->PermissionDataFlags];
        }
    }

  return MAPISTORE_SUCCESS;
}

- (uint64_t) objectId
{
  uint64_t objectId;

  if (container)
    objectId = [super objectId];
  else
    objectId = [self idForObjectWithKey: nil];

  return objectId;
}

- (uint64_t) idForObjectWithKey: (NSString *) childKey
{
  return [[self context] idForObjectWithKey: childKey
                                inFolderURL: [self url]];
}

- (NSDate *) creationTime
{
  return [propsMessage creationTime];
}

- (NSDate *) lastModificationTime
{
  return [propsMessage lastModificationTime];
}

/* subclasses */

- (MAPIStoreMessageTable *) messageTable
{
  return nil;
}

- (NSArray *) messageKeysMatchingQualifier: (EOQualifier *) qualifier
                          andSortOrderings: (NSArray *) sortOrderings
{
  [self subclassResponsibility: _cmd];

  return nil;  
}

- (NSArray *) getDeletedKeysFromChangeNumber: (uint64_t) changeNum
                                       andCN: (NSNumber **) cnNbrs
                                 inTableType: (enum mapistore_table_type) tableType
{
  return nil;
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

- (BOOL) subscriberCanCreateMessages
{
  return NO;
}

- (BOOL) subscriberCanModifyMessages
{
  return NO;
}

- (BOOL) subscriberCanReadMessages
{
  return NO;
}

- (BOOL) subscriberCanDeleteMessages
{
  return NO;
}

- (BOOL) subscriberCanCreateSubFolders
{
  return NO;
}

- (BOOL) supportsSubFolders
{
  return NO;
}

@end
