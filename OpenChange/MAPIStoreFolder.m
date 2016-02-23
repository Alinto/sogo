/* MAPIStoreFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2014 Inverse inc
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
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <SOGo/SOGoContentObject.h>
#import <SOGo/SOGoUser.h>
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
#import "NSData+MAPIStore.h"
#import "NSDate+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "NSObject+MAPIStore.h"
#import <SOGo/SOGoCacheGCSFolder.h>
#import "SOGoMAPIDBMessage.h"
#import "SOGoCacheGCSObject+MAPIStore.h"
#import <Mailer/SOGoMailObject.h>

#include <gen_ndr/exchange.h>

#undef DEBUG
#include <util/attr.h>
#include <libmapiproxy.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

Class NSExceptionK, MAPIStoreFAIMessageK, MAPIStoreMessageTableK, MAPIStoreFAIMessageTableK, MAPIStoreFolderTableK;

/* MAPI permissions */
NSString *MAPIStoreRightReadItems = @"RightsReadItems";
NSString *MAPIStoreRightCreateItems = @"RightsCreateItems";
NSString *MAPIStoreRightEditOwn = @"RightsEditOwn";
NSString *MAPIStoreRightEditAll = @"RightsEditAll";
NSString *MAPIStoreRightDeleteOwn = @"RightsDeleteOwn";
NSString *MAPIStoreRightDeleteAll = @"RightsDeleteAll";
NSString *MAPIStoreRightCreateSubfolders = @"RightsCreateSubfolders";
NSString *MAPIStoreRightFolderOwner = @"RightsFolderOwner";
NSString *MAPIStoreRightFolderContact = @"RightsFolderContact";

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
      dbFolder = nil;
      context = nil;

      // propsFolder = nil;
      // propsMessage = nil;
    }

  return self;
}

- (void) setupAuxiliaryObjects
{
  NSURL *folderURL;
  NSMutableString *pathPrefix;
  NSString *path, *folderName;
  NSArray *parts;
  NSUInteger lastPartIdx;
  MAPIStoreUserContext *userContext;

  parts = 0;
  lastPartIdx = 0;
  folderURL = [NSURL URLWithString: [self url]];
  /* note: -[NSURL path] returns an unescaped representation */
  path = [folderURL path];
  path = [path substringFromIndex: 1];
  if ([path length] > 0)
    {
      parts = [path componentsSeparatedByString: @"/"];
      lastPartIdx = [parts count] - 1;
      if ([path hasSuffix: @"/"])
        lastPartIdx--;
      folderName = [parts objectAtIndex: lastPartIdx];
    }
  else
    folderName = [folderURL host];

  userContext = [self userContext];
  [userContext activate];
  [userContext ensureFolderTableExists];

  ASSIGN (dbFolder,
          [SOGoCacheGCSFolder objectWithName: folderName
                               inContainer: [container dbFolder]]);
  [dbFolder setTableUrl: [userContext folderTableURL]];
  if (!container && [path length] > 0)
    {
      pathPrefix = [NSMutableString stringWithCapacity: 64];
      [pathPrefix appendFormat: @"/%@", [folderURL host]];
      parts = [parts subarrayWithRange: NSMakeRange (0, lastPartIdx)];
      if ([parts count] > 0)
        [pathPrefix appendFormat: @"/%@", [parts componentsJoinedByString: @"/"]];
      [dbFolder setPathPrefix: pathPrefix];
    }
  [dbFolder reloadIfNeeded];

  /* propsMessage and self share the same properties dictionary */
  // ASSIGN (propsMessage,
  //         [SOGoMAPIDBMessage objectWithName: @"properties.plist"
  //                               inContainer: dbFolder]);
  // [propsMessage setObjectType: MAPIInternalCacheObject];
  // [propsMessage reloadIfNeeded];
  [properties release];
  properties = [dbFolder properties];
  [properties retain];

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
      [self setupAuxiliaryObjects];
    }

  return self;
}

- (void) setContext: (MAPIStoreContext *) newContext
{
  ASSIGN (context, newContext);
  if (newContext)
    [self setupAuxiliaryObjects];
}

- (MAPIStoreContext *) context
{
  if (!context)
    [self setContext: (MAPIStoreContext *) [container context]];

  return context;
}

- (void) dealloc
{
  //[self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

  // [messageKeys release];
  // [faiMessageKeys release];
  // [folderKeys release];
  // [propsMessage release];
  [dbFolder release];
  [context release];

  [super dealloc];
}

- (SOGoCacheGCSFolder *) dbFolder
{
  return dbFolder;
}

/* backend interface */

// - (SOGoMAPIDBMessage *) propertiesMessage
// {
//   return propsMessage;
// }

- (uint64_t) objectVersion
{
  NSNumber *value;
  uint64_t cn;

  value = [properties objectForKey: MAPIPropertyKey (PidTagChangeNumber)];
  if (value)
    cn = [value unsignedLongLongValue];
  else
    {
      [self logWithFormat: @"no value for PidTagChangeNumber, adding one now"];
      cn = [[self context] getNewChangeNumber];
      value = [NSNumber numberWithUnsignedLongLong: cn];

      [properties setObject: value
                     forKey: MAPIPropertyKey (PidTagChangeNumber)];
      [dbFolder save];
    }

  return cn >> 16;
}

- (id) lookupFolder: (NSString *) folderKey
{
  MAPIStoreFolder *childFolder = nil;
  SOGoFolder *sogoFolder;

  if ([[self folderKeys] containsObject: folderKey])
    {
      [[self userContext] activate];
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
  MAPIStoreObject *foundObject;
  NSString *key, *slashLessURL;

  if ([childURL hasSuffix: @"/"])
    slashLessURL = [childURL substringToIndex: [childURL length] - 1];
  else
    slashLessURL = childURL;
  key = [self childKeyFromURL: slashLessURL];
  if (key)
    foundObject = [self lookupFolder: key];
  else
    foundObject = nil;

  return foundObject;
}

- (id) lookupMessage: (NSString *) messageKey
{
  MAPIStoreObject *childMessage = nil;
  Class messageClass;
  SOGoObject *msgObject;

  if (messageKey)
    {
      [[self userContext] activate];
      msgObject = [sogoObject lookupName: messageKey
                               inContext: nil
                                 acquire: NO];
      /* If the lookup in the indexing table works, but the IMAP does
         not have the message, then the message does not exist in this
         folder */
      if (msgObject && [msgObject isKindOfClass: [SOGoMailObject class]]
          && ! [(SOGoMailObject *)msgObject doesMailExist])
        return nil;
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
      [[self userContext] activate];
      if ([[self faiMessageKeys] containsObject: messageKey])
        {
          msgObject = [dbFolder lookupName: messageKey
                                 inContext: nil
                                   acquire: NO];
          childMessage
            = [MAPIStoreFAIMessageK mapiStoreObjectWithSOGoObject: msgObject
                                                      inContainer: self];
        }
    }

  return childMessage;
}

- (NSString *) childKeyFromURL: (NSString *) childURL
{
  NSString *baseURL, *subURL, *key = nil;
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
              key = [[parts objectAtIndex: 0]
                      stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
            }
        }
    }

  return key;
}

- (id) lookupMessageByURL: (NSString *) childURL
{
  MAPIStoreObject *foundObject;
  NSString *key;

  key = [self childKeyFromURL: childURL];
  if (key)
    {
      foundObject = [self lookupFAIMessage: key];
      if (!foundObject)
        foundObject = [self lookupMessage: key];
    }
  else
    foundObject = nil;

  return foundObject;
}

- (enum mapistore_error) openFolder: (MAPIStoreFolder **) childFolderPtr
                            withFID: (uint64_t) fid
{
  enum mapistore_error rc = MAPISTORE_ERR_NOT_FOUND;
  MAPIStoreFolder *childFolder;
  MAPIStoreMapping *mapping;
  NSString *childURL;

  //[self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

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

- (enum mapistore_error) createFolder: (MAPIStoreFolder **) childFolderPtr
                              withRow: (struct SRow *) aRow
                               andFID: (uint64_t) fid
{
  BOOL mapped;
  enum mapistore_error rc = MAPISTORE_SUCCESS;
  MAPIStoreMapping *mapping;
  NSString *baseURL, *childURL, *folderKey;
  MAPIStoreFolder *childFolder;
  SOGoUser *ownerUser;

  //[self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

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
              childURL = [NSString stringWithFormat: @"%@%@/",
                                   baseURL,
                                   [folderKey stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]];

              mapped = [mapping registerURL: childURL withID: fid];
              if (!mapped)
                /* Enforce the creation if the backend does know the fid */
                [mapping updateURL: childURL withID: fid];

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

- (enum mapistore_error) deleteFolder
{
  // TODO: raise exception in case underlying delete fails?
  // [propsMessage delete];
  [dbFolder delete];

  [self cleanupCaches];

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getChildCount: (uint32_t *) rowCount
                           ofTableType: (enum mapistore_table_type) tableType
{
  NSArray *keys;
  enum mapistore_error rc = MAPISTORE_SUCCESS;

  //[self logWithFormat: @"METHOD '%s' (%d) -- tableType: %d",
	//__FUNCTION__, __LINE__, tableType];

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

- (enum mapistore_error) openMessage: (MAPIStoreMessage **) messagePtr
                             withMID: (uint64_t) mid
                          forWriting: (BOOL) readWrite
                            inMemCtx: (TALLOC_CTX *) memCtx;
{
  NSString *messageURL;
  MAPIStoreMapping *mapping;
  MAPIStoreMessage *message;
  SOGoUser *ownerUser;
  enum mapistore_error rc = MAPISTORE_ERR_NOT_FOUND;

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
      else
        {
          /* Unregistering from indexing table as the backend says the
             object was not found */
          [mapping unregisterURLWithID: mid];
        }
    }

  return rc;
}

- (enum mapistore_error) createMessage: (MAPIStoreMessage **) messagePtr
                               withMID: (uint64_t) mid
                          isAssociated: (BOOL) isAssociated
{
  enum mapistore_error rc;
  MAPIStoreMessage *message;
  NSString *baseURL, *childURL;
  MAPIStoreMapping *mapping;
  SOGoUser *ownerUser;

  //[self logWithFormat: @"METHOD '%s' -- mid: 0x%.16llx  associated: %d",
  //	__FUNCTION__, mid, isAssociated];

  context = [self context];
  ownerUser = [[self userContext] sogoUser];
  [[self userContext] activate];

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

- (enum mapistore_error) deleteMessageWithMID: (uint64_t) mid
                                     andFlags: (uint8_t) flags
{
  NSString *childURL;
  MAPIStoreMapping *mapping;
  MAPIStoreMessage *message;
  NSArray *activeTables;
  NSUInteger count, max;
  id msgObject;
  SOGoUser *ownerUser;
  enum mapistore_error rc;

  /* flags that control the behaviour of the operation
     (MAPISTORE_SOFT_DELETE or MAPISTORE_PERMANENT_DELETE) */
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
                  && ([self subscriberCanDeleteMessages] || [message subscriberCanDeleteMessage])))
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
                  [self logWithFormat: @"successfully deleted object at URL: %@", childURL];
                  /* Ensure we are respecting flags parameter */
                  [mapping unregisterURLWithID: mid andFlags: flags];
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

// private method
- (enum mapistore_error) _moveCopyMessageWithMID: (uint64_t) srcMid
                                      fromFolder: (MAPIStoreFolder *) sourceFolder
                                         withMID: (uint64_t) targetMid
                                    andChangeKey: (struct Binary_r *) targetChangeKey
                        andPredecessorChangeList: (struct Binary_r *) targetPredecessorChangeList
                                        wantCopy: (uint8_t) wantCopy
                                        inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc;
  MAPIStoreMessage *sourceMsg, *destMsg;
  //TALLOC_CTX *memCtx;
  struct SRow aRow;
  struct SPropValue property;
  uint8_t deleteFlags;

  [self logWithFormat: @"-moveCopyMessageWithMID: 0x%.16llx .. withMID: 0x%.16llx .. wantCopy: %d", srcMid, targetMid, wantCopy];

  //memCtx = talloc_zero (NULL, TALLOC_CTX);
  rc = [sourceFolder openMessage: &sourceMsg
                         withMID: srcMid
                      forWriting: NO
                        inMemCtx: memCtx];
  if (rc != MAPISTORE_SUCCESS)
    goto end;

  rc = [self createMessage: &destMsg withMID: targetMid
              isAssociated: [sourceMsg isKindOfClass: MAPIStoreFAIMessageK]];
  if (rc != MAPISTORE_SUCCESS)
    goto end;

  [sourceMsg copyToMessage: destMsg  inMemCtx: memCtx];

  if (targetPredecessorChangeList)
    {
      property.ulPropTag = PidTagPredecessorChangeList;
      property.value.bin = *targetPredecessorChangeList;
      aRow.cValues = 1;
      aRow.lpProps = &property;
      rc = [destMsg addPropertiesFromRow: &aRow];
      if (rc != MAPISTORE_SUCCESS)
        {
          [self errorWithFormat: @"Cannot add PredecessorChangeList on move"];
          goto end;
        }
    }
  [destMsg save: memCtx];
  if (!wantCopy)
    /* We want to keep mid for restoring/shared data to work if mids are different. */
    deleteFlags = (srcMid == targetMid) ? MAPISTORE_PERMANENT_DELETE : MAPISTORE_SOFT_DELETE;
    rc = [sourceFolder deleteMessageWithMID: srcMid andFlags: deleteFlags];

 end:
  //talloc_free (memCtx);

  return rc;
}

- (enum mapistore_error) moveCopyMessagesWithMIDs: (uint64_t *) srcMids
                                         andCount: (uint32_t) midCount
                                       fromFolder: (MAPIStoreFolder *) sourceFolder
                                         withMIDs: (uint64_t *) targetMids
                                    andChangeKeys: (struct Binary_r **) targetChangeKeys
                        andPredecessorChangeLists: (struct Binary_r **) targetPredecessorChangeLists
                                         wantCopy: (uint8_t) wantCopy
                                         inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc = MAPISTORE_SUCCESS;
  NSUInteger count;
  NSMutableArray *oldMessageURLs;
  NSString *oldMessageURL;
  MAPIStoreMapping *mapping;
  SOGoUser *ownerUser;
  struct Binary_r *targetChangeKey, *targetPredecessorChangeList;
  //TALLOC_CTX *memCtx;

  //memCtx = talloc_zero (NULL, TALLOC_CTX);

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
              if (targetChangeKeys && targetPredecessorChangeList)
                {
                  targetChangeKey = targetChangeKeys[count];
                  targetPredecessorChangeList = targetPredecessorChangeLists[count];
                }
              else
                {
                  targetChangeKey = NULL;
                  targetPredecessorChangeList = NULL;
                }
              rc = [self _moveCopyMessageWithMID: srcMids[count]
                                      fromFolder: sourceFolder
                                         withMID: targetMids[count]
                                    andChangeKey: targetChangeKey
                        andPredecessorChangeList: targetPredecessorChangeList
                                        wantCopy: wantCopy
                                        inMemCtx: memCtx];
            }
          else
            rc = MAPISTORE_ERR_NOT_FOUND;
        }

      /* Notifications */
      if (rc == MAPISTORE_SUCCESS)
        {
          // We cleanup cache of our source and destination folders
          [self cleanupCaches];
          [sourceFolder cleanupCaches];
        }
    }
  else
    rc = MAPISTORE_ERR_DENIED;

  //talloc_free (memCtx);

  return rc;
}

- (enum mapistore_error) moveCopyToFolder: (MAPIStoreFolder *) targetFolder
                              withNewName: (NSString *) newFolderName
                                   isMove: (BOOL) isMove
                              isRecursive: (BOOL) isRecursive
                                 inMemCtx: (TALLOC_CTX *) memCtx

{
  enum mapistore_error rc;
  NSAutoreleasePool *pool;
  struct SRow folderRow;
  struct SPropValue nameProperty;
  MAPIStoreFolder *subFolder, *newFolder;
  NSArray *children;
  MAPIStoreMapping *mapping;
  MAPIStoreMessage *message, *targetMessage;
  NSUInteger count, max;
  NSString *childKey;
  uint64_t fmid;
  //TALLOC_CTX *memCtx;

  //memCtx = talloc_zero (NULL, TALLOC_CTX);

  /* TODO: one possible issue with this algorithm is that moved messages will
     lack a version number and will all be assigned a new one, even though
     they have not changed. This also means that they will be transferred
     again to the client during a sync operation. */

  if ([targetFolder supportsSubFolders])
    {
      mapping = [self mapping];

      if (!newFolderName)
        newFolderName = [sogoObject displayName];
      nameProperty.ulPropTag = PidTagDisplayName;
      nameProperty.value.lpszW = [newFolderName UTF8String];
      folderRow.lpProps = &nameProperty;
      folderRow.cValues = 1;
      rc = [targetFolder createFolder: &folderRow
                              withFID: [self objectId]
                               andKey: &childKey];
      if (rc == MAPISTORE_SUCCESS)
        {
          newFolder = [targetFolder lookupFolder: childKey];
          [self copyPropertiesToObject: newFolder  inMemCtx: memCtx];

          pool = [NSAutoreleasePool new];
          children = [self messageKeys];
          max = [children count];
          for (count = 0; count < max; count++)
            {
              childKey = [children objectAtIndex: count];
              message = [self lookupMessage: childKey];
              targetMessage = [newFolder createMessage: NO];
              [targetMessage setIsNew: YES];
              [message copyToMessage: targetMessage  inMemCtx: memCtx];
              if (isMove)
                {
                  fmid = [mapping idFromURL: [message url]];
                  [self deleteMessageWithMID: fmid andFlags: MAPISTORE_PERMANENT_DELETE];
                  [mapping registerURL: [targetMessage url]
                                withID: fmid];
                }
              [targetMessage save: memCtx];
            }
          [pool release];

          pool = [NSAutoreleasePool new];
          children = [self faiMessageKeys];
          max = [children count];
          for (count = 0; count < max; count++)
            {
              childKey = [children objectAtIndex: count];
              message = [self lookupFAIMessage: childKey];
              targetMessage = [newFolder createMessage: YES];
              [targetMessage setIsNew: YES];
              [message copyToMessage: targetMessage  inMemCtx: memCtx];
              if (isMove)
                {
                  fmid = [mapping idFromURL: [message url]];
                  [self deleteMessageWithMID: fmid andFlags: MAPISTORE_PERMANENT_DELETE];
                  [mapping registerURL: [targetMessage url]
                                withID: fmid];
                }
              [targetMessage save: memCtx];
            }
          [pool release];

          if (isRecursive)
            {
              pool = [NSAutoreleasePool new];
              children = [self folderKeys];
              max = [children count];
              for (count = 0; count < max; count++)
                {
                  childKey = [children objectAtIndex: count];
                  subFolder = [self lookupFolder: childKey];
                  [subFolder moveCopyToFolder: newFolder withNewName: nil
                                       isMove: isMove
                                  isRecursive: isRecursive
                                     inMemCtx: memCtx];

                }
              [pool release];
            }

          if (isMove)
              [self deleteFolder];

          [targetFolder cleanupCaches];
        }
      [self cleanupCaches];

      /* We perform the mapping operations at the
         end as objectId is required to be available
         until the caches are cleaned up */
      if (isMove && rc == MAPISTORE_SUCCESS)
        {
          fmid = [mapping idFromURL: [self url]];
          [mapping unregisterURLWithID: fmid];
          [mapping registerURL: [newFolder url]
                        withID: fmid];
        }

    }
  else
    rc = MAPISTORE_ERR_DENIED;

  //talloc_free (memCtx);

  return rc;
}

- (SOGoFolder *) aclFolder
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSArray *) expandRoles: (NSArray *) roles
{
  return roles;
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

- (void) ensureIDsForChildKeys: (NSArray *) keys
{
  NSMutableArray *missingURLs;
  MAPIStoreMapping *mapping;
  NSUInteger count, max;
  NSString *baseURL, *URL, *key;
  NSArray *newIDs;
  uint64_t idNbr;
  bool softDeleted;

  baseURL = [self url];

  mapping = [self mapping];
  max = [keys count];
  missingURLs = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      key = [keys objectAtIndex: count];
      URL = [NSString stringWithFormat: @"%@%@", baseURL, key];
      idNbr = [mapping idFromURL: URL isSoftDeleted: &softDeleted];
      if (idNbr == NSNotFound && !softDeleted)
        [missingURLs addObject: URL];
    }

  max = [missingURLs count];
  newIDs = [[self context] getNewFMIDs: max];
  [mapping registerURLs: missingURLs
                withIDs: newIDs];
}

- (enum mapistore_error) getDeletedFMIDs: (struct UI8Array_r **) fmidsPtr
                                   andCN: (uint64_t *) cnPtr
                        fromChangeNumber: (uint64_t) changeNum
                             inTableType: (enum mapistore_table_type) tableType
                                inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc;
  NSString *baseURL, *format, *url;
  NSArray *keys;
  NSNumber *cnNbr;
  NSUInteger count, max;
  MAPIStoreMapping *mapping;
  struct UI8Array_r *fmids;
  uint64_t fmid;
  bool softDeleted;

  keys = [self getDeletedKeysFromChangeNumber: changeNum andCN: &cnNbr
                                  inTableType: tableType];
  if (keys)
    {
      mapping = [self mapping];

      max = [keys count];

      fmids = talloc_zero (memCtx, struct UI8Array_r);
      fmids->cValues = 0;
      fmids->lpui8 = talloc_array (fmids, uint64_t, max);
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
          fmid = [mapping idFromURL: url isSoftDeleted: &softDeleted];
          if (fmid != NSNotFound) /* if no fmid is returned, then the object
                                     "never existed" in the OpenChange
                                     databases. Soft-deleted messages are returned back */
            {
              fmids->lpui8[fmids->cValues] = fmid;
              fmids->cValues++;
            }
        }

      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (enum mapistore_error) getTable: (MAPIStoreTable **) tablePtr
                      andRowCount: (uint32_t *) countPtr
                        tableType: (enum mapistore_table_type) tableType
                      andHandleId: (uint32_t) handleId
{
  BOOL access;
  enum mapistore_error rc = MAPISTORE_SUCCESS;
  MAPIStoreTable *table;
  SOGoUser *activeUser, *ownerUser;

  if (tableType == MAPISTORE_MESSAGE_TABLE)
    table = [self messageTable];
  else if (tableType == MAPISTORE_FAI_TABLE)
    table = [self faiMessageTable];
  else if (tableType == MAPISTORE_FOLDER_TABLE)
    table = [self folderTable];
  else if (tableType == MAPISTORE_PERMISSIONS_TABLE)
    {
      ownerUser = [[self userContext] sogoUser];
      activeUser = [context activeUser];
      access = [activeUser isEqual: ownerUser];
      if (!access)
        {
          NSArray *roles;

          roles = [[self aclFolder] aclsForUser: [activeUser login]];
          roles = [self expandRoles: roles];  // Not required here
          /* Check FolderVisible right to return the table */
          access = ([self exchangeRightsForRoles: roles] & RoleNone) != 0;
        }

      if (access)
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
                                         PR_CHANGE_KEY, PidTagChangeNumber, 0x00000000 };
  enum MAPITAGS *currentProp;
  NSMutableDictionary *propsCopy;
  uint64_t cn;

  /* TODO: this should no longer be required once mapistore v2 API is in
     place, when we can then do this from -dealloc below */

  [dbFolder reloadIfNeeded];

  propsCopy = [newProperties mutableCopy];
  [propsCopy autorelease];

  currentProp = bannedProps;
  while (*currentProp)
    {
      [propsCopy removeObjectForKey: MAPIPropertyKey (*currentProp)];
      currentProp++;
    }

  [properties addEntriesFromDictionary: propsCopy];

  /* Update change number after setting the properties */
  cn = [[self context] getNewChangeNumber];
  [properties setObject: [NSNumber numberWithUnsignedLongLong: cn]
                 forKey: MAPIPropertyKey (PidTagChangeNumber)];

  [dbFolder save];
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
  [[self userContext] activate];
  return [dbFolder childKeysOfType: MAPIFAICacheObject
                    includeDeleted: NO
                 matchingQualifier: qualifier
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

- (enum mapistore_error) getPidTagParentFolderId: (void **) data
                                        inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongLongValue (memCtx, [container objectId]);

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagFolderId: (void **) data
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
- (enum mapistore_error) getPidTagAccess: (void **) data
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

- (enum mapistore_error) getPidTagRights: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx
{
  uint32_t rights = 0;
  SOGoUser *activeUser, *ownerUser;

  ownerUser = [[self userContext] sogoUser];
  activeUser = [context activeUser];

  if ([activeUser isEqual: ownerUser])
    {
      rights = RightsReadItems | RightsCreateItems | RightsEditOwn | RightsEditAll
        | RightsDeleteOwn | RightsDeleteAll | RightsFolderOwner | RightsFolderContact | RoleNone;
      if ([self supportsSubFolders])
        rights |= RightsCreateSubfolders;
    }
  else
    {
      NSArray *roles;

      roles = [[self aclFolder] aclsForUser: [activeUser login]];
      roles = [self expandRoles: roles];
      rights = [self exchangeRightsForRoles: roles];
      /* FreeBusySimple and FreeBusyDetailed does not apply here
         [MS-OXCFOLD] Section 2.2.2.2.2.8 */
      rights &= ~RightsFreeBusySimple & ~RightsFreeBusyDetailed;
    }

  *data = MAPILongValue (memCtx, rights);

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagAccessControlListData: (void **) data
                                               inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[NSData data] asBinaryInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagAttributeHidden: (void **) data
                                         inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagAttributeSystem: (void **) data
                                         inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagAttributeReadOnly: (void **) data
                                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTagSubfolders: (void **) data
                                    inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPIBoolValue (memCtx, [self supportsSubFolders] && [[self folderKeys] count] > 0);

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagFolderChildCount: (void **) data
                                          inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, [[self folderKeys] count]);

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagContentCount: (void **) data
                                      inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, [[self messageKeys] count]);

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagContentUnreadCount: (void **) data
                                            inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0);

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagAssociatedContentCount: (void **) data
                                                inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, [[self faiMessageKeys] count]);

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagDeletedCountTotal: (void **) data
                                           inMemCtx: (TALLOC_CTX *) memCtx
{
  /* TODO */
  *data = MAPILongValue (memCtx, 0);

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidTagLocalCommitTimeMax: (void **) data
                                            inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc = MAPISTORE_SUCCESS;
  NSDate *date;

  date = [self lastMessageModificationTime];
  if (date)
    *data = [date asFileTimeInMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (enum mapistore_error) getPidTagDefaultPostMessageClass: (void **) data
                                                 inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"IPM.Note" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getProperties: (struct mapistore_property_data *) data
                              withTags: (enum MAPITAGS *) tags
                              andCount: (uint16_t) columnCount
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  [dbFolder reloadIfNeeded];

  return [super getProperties: data
                     withTags: tags
                     andCount: columnCount
                     inMemCtx: memCtx];
}

- (enum mapistore_error) getProperty: (void **) data
                             withTag: (enum MAPITAGS) propTag
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc;
  id value;

  value = [properties objectForKey: MAPIPropertyKey (propTag)];
  if (value)
    rc = [value getValue: data forTag: propTag inMemCtx: memCtx];
  else
    rc = [super getProperty: data withTag: propTag inMemCtx: memCtx];

  return rc;
}

- (MAPIStoreMessage *) _createAssociatedMessage
{
  MAPIStoreMessage *newMessage;
  SOGoMAPIDBMessage *dbObject;
  NSString *newKey;

  newKey = [NSString stringWithFormat: @"%@.plist",
                     [SOGoObject globallyUniqueObjectId]];
  dbObject = [SOGoMAPIDBMessage objectWithName: newKey inContainer: dbFolder];
  [dbObject setObjectType: MAPIFAICacheObject];
  [dbObject setIsNew: YES];
  newMessage = [MAPIStoreFAIMessageK mapiStoreObjectWithSOGoObject: dbObject
                                                       inContainer: self];

  return newMessage;
}

- (MAPIStoreMessage *) createMessage: (BOOL) isAssociated
{
  MAPIStoreMessage *newMessage;
  WOContext *woContext;

  [[self userContext] activate];

  if (isAssociated)
    newMessage = [self _createAssociatedMessage];
  else
    newMessage = [self createMessage];
  /* FIXME: this is ugly as the specifics of message creation should all be
     delegated to subclasses */
  if ([newMessage respondsToSelector: @selector (setIsNew:)])
    [newMessage setIsNew: YES];
  woContext = [[self userContext] woContext];
  /* FIXME: this is ugly too as the specifics of message creation should all
     be delegated to subclasses */
  if ([newMessage respondsToSelector: @selector (sogoObject:)])
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

  if (bin && bin->cb)
    {
      bin32.cb = bin->cb;
      bin32.lpb = bin->lpb;

      entryId = get_AddressBookEntryId (NULL, &bin32);
      if (entryId)
        {
          username = MAPIStoreSamDBUserAttribute ([[self context] connectionInfo],
                                                  @"legacyExchangeDN",
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

  users = [[aclFolder aclUsers] copy];
  max = [users count];
  for (count = 0; count < max; count++)
    [aclFolder removeUserFromAcls: [users objectAtIndex: count]];

  [users release];
}

- (enum mapistore_error) modifyPermissions: (struct PermissionData *) permissions
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
  SOGoUser *activeUser, *ownerUser;

  /* Check if we have permissions to modify the permissions.
   See [MS-OXCPERM] Section 3.2.5.2 for details */
  ownerUser = [[self userContext] sogoUser];
  activeUser = [context activeUser];
  if (![activeUser isEqual: ownerUser])
    {
      /* Check if we have FolderOwner right */
      NSArray *roles;

      roles = [[self aclFolder] aclsForUser: [activeUser login]];
      roles = [self expandRoles: roles]; // Not required
      if (([self exchangeRightsForRoles: roles] & RightsFolderOwner) == 0)
        return MAPISTORE_ERR_DENIED;
    }

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

- (enum mapistore_error) preloadMessageBodiesWithMIDs: (const struct UI8Array_r *) mids
                                          ofTableType: (enum mapistore_table_type) tableType
{
  uint32_t count;
  NSMutableArray *messageKeys;
  MAPIStoreMapping *mapping;
  NSString *messageURL, *messageKey;

  messageKeys = [NSMutableArray arrayWithCapacity: mids->cValues];

  mapping = [self mapping];
  for (count = 0; count < mids->cValues; count++)
    {
      messageURL = [mapping urlFromID: mids->lpui8[count]];
      if (messageURL)
        {
          messageKey = [self childKeyFromURL: messageURL];
          if (messageKey)
            [messageKeys addObject: messageKey];
        }
    }

  return [self preloadMessageBodiesWithKeys: messageKeys
                                ofTableType: tableType];
}

- (enum mapistore_error) preloadMessageBodiesWithKeys: (NSArray *) keys
                                          ofTableType: (enum mapistore_table_type) tableType
{
  return MAPISTORE_SUCCESS;
}

- (uint64_t) objectId
{
  uint64_t objectId;
  NSString *folderKey;

  if (container)
    {
      folderKey = [NSString stringWithFormat: @"%@/",
                            [sogoObject nameInContainer]];
      objectId = [container idForObjectWithKey: folderKey];
    }
  else
    objectId = [self idForObjectWithKey: nil];

  return objectId;
}

- (uint64_t) idForObjectWithKey: (NSString *) childKey
{
  return [[self context] idForObjectWithKey: childKey
                                inFolderURL: [self url]];
}

- (MAPIStoreFolder *) rootContainer
{
  /* Return the oldest ancestor, which does not have
     container. If there is not container, it returns itself.
  */
  if (container)
    return [container rootContainer];
  else
    return self;
}

- (NSDate *) creationTime
{
  return [dbFolder creationDate];
}

- (NSDate *) lastModificationTime
{
  return [dbFolder lastModified];
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
