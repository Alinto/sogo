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

Class NSExceptionK, MAPIStoreMessageTableK, MAPIStoreFAIMessageTableK, MAPIStoreFolderTableK;

@implementation MAPIStoreFolder

+ (void) initialize
{
  NSExceptionK = [NSException class];
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
  MAPIStoreObject *newChild;
  SOGoObject *msgObject;

  if (childKey)
    {
      [self faiMessageKeys];
      if ([faiMessageKeys containsObject: childKey])
        {
          msgObject = [faiFolder lookupName: childKey
                                  inContext: nil
                                    acquire: NO];
          newChild
            = [MAPIStoreFAIMessage mapiStoreObjectWithSOGoObject: msgObject
                                                     inContainer: self];
        }
      else
        {
          msgObject = [sogoObject lookupName: childKey
                                   inContext: nil
                                     acquire: NO];
          if ([msgObject isKindOfClass: NSExceptionK])
            msgObject = nil;
          
          if (msgObject)
            newChild
              = [[self messageClass] mapiStoreObjectWithSOGoObject: msgObject
                                                       inContainer: self];
          else
            newChild = nil;
        }
    }
  else
    newChild = nil;

  return newChild;
}

- (int) getPrParentFid: (void **) data
{
  *data = MAPILongLongValue (memCtx, [container objectId]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrFid: (void **) data
{
  *data = MAPILongLongValue (memCtx, [self objectId]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrAccess: (void **) data
{
  *data = MAPILongValue (memCtx, 0x63);

  return MAPISTORE_SUCCESS;
}

- (int) getPrAccessLevel: (void **) data
{
  *data = MAPILongValue (memCtx, 0x01);

  return MAPISTORE_SUCCESS;
}

- (int) getPrAttrHidden: (void **) data
{
  return [self getNo: data];
}

- (int) getPrAttrSystem: (void **) data
{
  return [self getNo: data];
}

- (int) getPrAttrReadOnly: (void **) data
{
  return [self getNo: data];
}

- (int) getPrSubfolders: (void **) data
{
  *data = MAPIBoolValue (memCtx, [folderKeys count] > 0);
  
  return MAPISTORE_SUCCESS;
}

- (int) getPrFolderChildCount: (void **) data;
{
  *data = MAPILongValue (memCtx, [[self folderKeys] count]);
  
  return MAPISTORE_SUCCESS;
}

- (int) getPrContentCount: (void **) data
{
  *data = MAPILongValue (memCtx, [[self messageKeys] count]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrContentUnread: (void **) data
{
  *data = MAPILongValue (memCtx, 0);

  return MAPISTORE_SUCCESS;
}

- (int) getPrAssocContentCount: (void **) data
{
  *data = MAPILongValue (memCtx, [[self faiMessageKeys] count]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrDeletedCountTotal: (void **) data
{
  /* TODO */
  *data = MAPILongValue (memCtx, 0);

  return MAPISTORE_SUCCESS;
}

- (int) getPrLocalCommitTimeMax: (void **) data
{
  *data = [[self lastMessageModificationTime] asFileTimeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getProperty: (void **) data
            withTag: (enum MAPITAGS) propTag
{
  int rc;
  id value;

  value = [[propsMessage properties]
            objectForKey: MAPIPropertyKey (propTag)];
  if (value)
    rc = [value getMAPIValue: data forTag: propTag inMemCtx: memCtx];
  else
    rc = [super getProperty: data withTag: propTag];

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
  newMessage = [MAPIStoreFAIMessage mapiStoreObjectWithSOGoObject: fsObject
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
