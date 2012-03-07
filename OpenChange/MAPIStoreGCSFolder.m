/* MAPIStoreGCSFolder.m - this file is part of SOGo
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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <NGExtensions/NSObject+Logs.h>
#import <EOControl/EOQualifier.h>
#import <EOControl/EOFetchSpecification.h>
#import <EOControl/EOSortOrdering.h>
#import <GDLContentStore/GCSFolder.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoGCSFolder.h>
#import <SOGo/SOGoParentFolder.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>

#import "MAPIStoreGCSBaseContext.h"
#import "MAPIStoreTypes.h"
#import "MAPIStoreUserContext.h"
#import "NSData+MAPIStore.h"
#import "NSDate+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "SOGoMAPIFSMessage.h"

#import "MAPIStoreGCSFolder.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreGCSFolder

- (id) initWithSOGoObject: (id) newSOGoObject
              inContainer: (MAPIStoreObject *) newContainer
{
  if ((self = [super initWithSOGoObject: newSOGoObject inContainer: newContainer]))
    {
      activeUserRoles = nil;
    }

  return self;
}

- (void) setupVersionsMessage
{
  ASSIGN (versionsMessage,
          [SOGoMAPIFSMessage objectWithName: @"versions.plist"
                                inContainer: propsFolder]);
}

- (void) dealloc
{
  [versionsMessage release];
  [activeUserRoles release];
  [super dealloc];
}

- (int) deleteFolder
{
  int rc;
  NSException *error;
  NSString *name;

  name = [self nameInContainer];
  if ([name isEqualToString: @"personal"])
    rc = MAPISTORE_ERR_DENIED;
  else
    {
      [[sogoObject container] removeSubFolder: name];
      error = [(SOGoGCSFolder *) sogoObject delete];
      if (error)
        rc = MAPISTORE_ERROR;
      else
        {
          if (![versionsMessage delete])
            rc = MAPISTORE_SUCCESS;
          else
            rc = MAPISTORE_ERROR;
        }
    }

  return (rc == MAPISTORE_SUCCESS) ? [super deleteFolder] : rc;
}

- (void) setDisplayName: (NSString *) newDisplayName
{
  NSString *suffix, *fullSuffix;
  Class cClass;

  cClass = [(MAPIStoreGCSBaseContext *) [self context] class];

  /* if a suffix exists, we strip it from the final name */
  suffix = [cClass folderNameSuffix];
  if ([suffix length] > 0)
    {
      fullSuffix = [NSString stringWithFormat: @"(%@)", suffix];
      if ([newDisplayName hasSuffix: fullSuffix])
        {
          newDisplayName = [newDisplayName substringToIndex:
                                             [newDisplayName length]
                                           - [fullSuffix length]];
          newDisplayName = [newDisplayName stringByTrimmingSpaces];
        }
    }

  if (![[sogoObject displayName] isEqualToString: newDisplayName])
    [sogoObject renameTo: newDisplayName];
}

- (int) getPidTagDisplayName: (void **) data
                inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *displayName;
  Class cClass;

  cClass = [(MAPIStoreGCSBaseContext *) [self context] class];
  displayName = [cClass getFolderDisplayName: [sogoObject displayName]];
  *data = [displayName asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (void) addProperties: (NSDictionary *) newProperties
{
  NSString *newDisplayName;
  NSMutableDictionary *propsCopy;
  NSNumber *key;

  key = MAPIPropertyKey (PR_DISPLAY_NAME_UNICODE);
  newDisplayName = [newProperties objectForKey: key];
  if (newDisplayName)
    {
      [self setDisplayName: newDisplayName];
      propsCopy = [newProperties mutableCopy];
      [propsCopy removeObjectForKey: key];
      [propsCopy autorelease];
      newProperties = propsCopy;
    }

  [super addProperties: newProperties];
}

- (NSArray *) messageKeysMatchingQualifier: (EOQualifier *) qualifier
                          andSortOrderings: (NSArray *) sortOrderings
{
  static NSArray *fields = nil;
  SOGoUser *ownerUser;
  NSArray *records;
  NSMutableArray *qualifierArray;
  EOQualifier *fetchQualifier, *aclQualifier;
  GCSFolder *ocsFolder;
  EOFetchSpecification *fs;
  NSArray *keys;

  if (!fields)
    fields = [[NSArray alloc]
	       initWithObjects: @"c_name", @"c_version", nil];

  qualifierArray = [NSMutableArray new];
  ownerUser = [[self userContext] sogoUser];
  if (![[context activeUser] isEqual: ownerUser])
    {
      aclQualifier = [self aclQualifier];
      if (aclQualifier)
        [qualifierArray addObject: aclQualifier];
    }
  [qualifierArray addObject: [self componentQualifier]];
  if (qualifier)
    [qualifierArray addObject: qualifier];

  fetchQualifier = [[EOAndQualifier alloc]
                     initWithQualifierArray: qualifierArray];

  ocsFolder = [sogoObject ocsFolder];
  fs = [EOFetchSpecification
         fetchSpecificationWithEntityName: [ocsFolder folderName]
                                qualifier: fetchQualifier
                            sortOrderings: sortOrderings];
  [fetchQualifier release];
  [qualifierArray release];
  records = [ocsFolder fetchFields: fields fetchSpecification: fs];
  keys = [records objectsForKey: @"c_name"
                 notFoundMarker: nil];

  return keys;
}

- (NSDate *) lastMessageModificationTime
{
  NSNumber *ti;
  NSDate *value = nil;

  ti = [[versionsMessage properties]
         objectForKey: @"SyncLastSynchronisationDate"];
  if (ti)
    value = [NSDate dateWithTimeIntervalSince1970: [ti doubleValue]];
  else
    value = [NSDate date];

  [self logWithFormat: @"lastMessageModificationTime: %@", value];

  return value;
}

- (SOGoFolder *) aclFolder
{
  return (SOGoFolder *) sogoObject;
}

/* synchronisation */

/* Tree
{
  SyncLastModseq = x;
  SyncLastSynchronisationDate = x; ** not updated until something changed
  Messages = {
    MessageKey = {
      Version = x;
      Modseq = x;
      Deleted = b;
      ChangeKey = d;
      PredecessorChangeList = { guid1 = globcnt1, guid2 ... };
    };
    ...
  };
  VersionMapping = {
    Version = MessageKey;
    ...
  }
}
 */

- (void) _setChangeKey: (NSData *) changeKey
       forMessageEntry: (NSMutableDictionary *) messageEntry
{
  struct XID *xid;
  NSString *guid;
  NSData *globCnt;
  NSDictionary *changeKeyDict;
  NSMutableDictionary *changeList;

  xid = [changeKey asXIDInMemCtx: NULL];
  guid = [NSString stringWithGUID: &xid->GUID];
  globCnt = [NSData dataWithBytes: xid->Data length: xid->Size];
  talloc_free (xid);

  /* 1. set change key association */
  changeKeyDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                  guid, @"GUID",
                                globCnt, @"LocalId",
                                nil];
  [messageEntry setObject: changeKeyDict forKey: @"ChangeKey"];

  /* 2. append/update predecessor change list */
  changeList = [messageEntry objectForKey: @"PredecessorChangeList"];
  if (!changeList)
    {
      changeList = [NSMutableDictionary new];
      [messageEntry setObject: changeList
                    forKey: @"PredecessorChangeList"];
      [changeList release];
    }
  [changeList setObject: globCnt forKey: guid];
}

- (BOOL) synchroniseCache
{
  BOOL rc = YES, foundChange = NO;
  uint64_t newChangeNum;
  NSData *changeKey;
  NSNumber *ti, *changeNumber, *lastModificationDate, *cName, *cVersion, *cLastModified;
  EOFetchSpecification *fs;
  EOQualifier *searchQualifier, *fetchQualifier;
  NSUInteger count, max;
  NSArray *fetchResults;
  NSDictionary *result;
  NSMutableDictionary *currentProperties, *messages, *mapping, *messageEntry;
  NSCalendarDate *now;
  GCSFolder *ocsFolder;
  static NSArray *fields = nil;
  static EOSortOrdering *sortOrdering = nil;

  if (!fields)
    fields = [[NSArray alloc]
	       initWithObjects: @"c_name", @"c_version", @"c_lastmodified",
               nil];

  if (!sortOrdering)
    {
      sortOrdering = [EOSortOrdering sortOrderingWithKey: @"c_lastmodified"
                                                selector: EOCompareAscending];
      [sortOrdering retain];
    }

  now = [NSCalendarDate date];

  currentProperties = [[versionsMessage properties] mutableCopy];
  if (!currentProperties)
    currentProperties = [NSMutableDictionary new];
  [currentProperties autorelease];
  messages = [currentProperties objectForKey: @"Messages"];
  if (!messages)
    {
      messages = [NSMutableDictionary new];
      [currentProperties setObject: messages forKey: @"Messages"];
      [messages release];
    }
  mapping = [currentProperties objectForKey: @"VersionMapping"];
  if (!mapping)
    {
      mapping = [NSMutableDictionary new];
      [currentProperties setObject: mapping forKey: @"VersionMapping"];
      [mapping release];
    }

  lastModificationDate = [currentProperties objectForKey: @"SyncLastModificationDate"];
  if (lastModificationDate)
    {
      searchQualifier = [[EOKeyValueQualifier alloc]
                                initWithKey: @"c_lastmodified"
                           operatorSelector: EOQualifierOperatorGreaterThanOrEqualTo
                                      value: lastModificationDate];
      fetchQualifier = [[EOAndQualifier alloc]
                         initWithQualifiers:
                           searchQualifier, [self componentQualifier], nil];
      [fetchQualifier autorelease];
      [searchQualifier release];
    }
  else
    fetchQualifier = [self componentQualifier];

  ocsFolder = [sogoObject ocsFolder];
  fs = [EOFetchSpecification
             fetchSpecificationWithEntityName: [ocsFolder folderName]
                                    qualifier: fetchQualifier
                                sortOrderings: [NSArray arrayWithObject: sortOrdering]];
  fetchResults = [ocsFolder fetchFields: fields fetchSpecification: fs];
  max = [fetchResults count];
  if (max > 0)
    {
      ldb_transaction_start([[self context] connectionInfo]->oc_ctx);

      for (count = 0; count < max; count++)
        {
          result = [fetchResults objectAtIndex: count];
          cName = [result objectForKey: @"c_name"];
          cVersion = [result objectForKey: @"c_version"];
          cLastModified = [result objectForKey: @"c_lastmodified"];

          messageEntry = [messages objectForKey: cName];
          if (!messageEntry)
            {
              messageEntry = [NSMutableDictionary new];
              [messages setObject: messageEntry forKey: cName];
              [messageEntry release];
            }
          if (![[messageEntry objectForKey: @"c_version"]
                 isEqual: cVersion])
            {
              foundChange = YES;

              newChangeNum = [[self context] getNewChangeNumber];
              changeNumber = [NSNumber numberWithUnsignedLongLong: newChangeNum];

              [messageEntry setObject: cLastModified forKey: @"c_lastmodified"];
              [messageEntry setObject: cVersion forKey: @"c_version"];
              [messageEntry setObject: changeNumber forKey: @"version"];

              changeKey = [self getReplicaKeyFromGlobCnt: newChangeNum >> 16];
              [self _setChangeKey: changeKey forMessageEntry: messageEntry];

              [mapping setObject: cLastModified forKey: changeNumber];

              if (!lastModificationDate
                  || ([lastModificationDate compare: cLastModified]
                      == NSOrderedAscending))
                lastModificationDate = cLastModified;
            }
        }
      
      ldb_transaction_commit([[self context] connectionInfo]->oc_ctx);
      
      if (foundChange)
        {
          ti = [NSNumber numberWithDouble: [now timeIntervalSince1970]];
          [currentProperties setObject: ti
                                forKey: @"SyncLastSynchronisationDate"];
          [currentProperties setObject: lastModificationDate
                                forKey: @"SyncLastModificationDate"];
          [versionsMessage appendProperties: currentProperties];
          [versionsMessage save];
        }
    }

  return rc;
}
 
- (NSNumber *) lastModifiedFromMessageChangeNumber: (NSNumber *) changeNum
{
  NSDictionary *mapping;
  NSNumber *modseq;

  mapping = [[versionsMessage properties] objectForKey: @"VersionMapping"];
  modseq = [mapping objectForKey: changeNum];

  return modseq;
}

- (NSNumber *) changeNumberForMessageWithKey: (NSString *) messageKey
{
  NSDictionary *messages;
  NSNumber *changeNumber;

  messages = [[versionsMessage properties] objectForKey: @"Messages"];
  changeNumber = [[messages objectForKey: messageKey]
                   objectForKey: @"version"];

  return changeNumber;
}

- (void) setChangeKey: (NSData *) changeKey
    forMessageWithKey: (NSString *) messageKey
{
  NSMutableDictionary *messages;
  NSMutableDictionary *messageEntry;

  messages = [[versionsMessage properties] objectForKey: @"Messages"];
  messageEntry = [messages objectForKey: messageKey];
  if (!messageEntry)
    abort ();
  [self _setChangeKey: changeKey forMessageEntry: messageEntry];
  
  [versionsMessage save];
}

- (NSData *) _dataFromChangeKeyGUID: (NSString *) guidString
                             andCnt: (NSData *) globCnt
{
  NSMutableData *changeKey;
  struct GUID guid;

  changeKey = [NSMutableData dataWithCapacity: 16 + [globCnt length]];

  [guidString extractGUID: &guid];
  [changeKey appendData: [NSData dataWithGUID: &guid]];
  [changeKey appendData: globCnt];

  return changeKey;
}

- (NSData *) changeKeyForMessageWithKey: (NSString *) messageKey
{
  NSDictionary *messages, *changeKeyDict;
  NSString *guid;
  NSData *globCnt, *changeKey = nil;

  messages = [[versionsMessage properties] objectForKey: @"Messages"];
  changeKeyDict = [[messages objectForKey: messageKey]
                    objectForKey: @"ChangeKey"];
  if (changeKeyDict)
    {
      guid = [changeKeyDict objectForKey: @"GUID"];
      globCnt = [changeKeyDict objectForKey: @"LocalId"];
      changeKey = [self _dataFromChangeKeyGUID: guid andCnt: globCnt];
    }

  return changeKey;
}

- (NSData *) predecessorChangeListForMessageWithKey: (NSString *) messageKey
{
  NSMutableData *changeKeys = nil;
  NSDictionary *messages, *changeListDict;
  NSArray *keys;
  NSUInteger count, max;
  NSData *changeKey;
  NSString *guid;
  NSData *globCnt;

  messages = [[versionsMessage properties] objectForKey: @"Messages"];
  changeListDict = [[messages objectForKey: messageKey]
                     objectForKey: @"PredecessorChangeList"];
  if (changeListDict)
    {
      changeKeys = [NSMutableData data];
      keys = [changeListDict allKeys];
      max = [keys count];

      for (count = 0; count < max; count++)
        {
          guid = [keys objectAtIndex: count];
          globCnt = [changeListDict objectForKey: guid];
          changeKey = [self _dataFromChangeKeyGUID: guid andCnt: globCnt];
          [changeKeys appendUInt8: [changeKey length]];
          [changeKeys appendData: changeKey];
        }
    }

  return changeKeys;
}

- (NSArray *) getDeletedKeysFromChangeNumber: (uint64_t) changeNum
                                       andCN: (NSNumber **) cnNbr
                                 inTableType: (uint8_t) tableType
{
  NSArray *deletedKeys, *deletedCNames, *records;
  NSNumber *changeNumNbr, *lastModified;
  NSString *cName;
  NSDictionary *versionProperties;
  NSMutableDictionary *messages, *mapping;
  uint64_t newChangeNum = 0;
  EOAndQualifier *fetchQualifier;
  EOKeyValueQualifier *cDeletedQualifier, *cLastModifiedQualifier;
  EOFetchSpecification *fs;
  GCSFolder *ocsFolder;
  NSUInteger count, max;

  if (tableType == MAPISTORE_MESSAGE_TABLE)
    {
      deletedKeys = [NSMutableArray array];

      changeNumNbr = [NSNumber numberWithUnsignedLongLong: changeNum];
      lastModified = [self lastModifiedFromMessageChangeNumber: changeNumNbr];
      if (lastModified)
        {
          versionProperties = [versionsMessage properties];
          messages = [versionProperties objectForKey: @"Messages"];

          ocsFolder = [sogoObject ocsFolder];
          cLastModifiedQualifier = [[EOKeyValueQualifier alloc]
                                           initWithKey: @"c_lastmodified"
                                      operatorSelector: EOQualifierOperatorGreaterThanOrEqualTo
                                                 value: lastModified];
          cDeletedQualifier = [[EOKeyValueQualifier alloc]
                                           initWithKey: @"c_deleted"
                                      operatorSelector: EOQualifierOperatorEqual
                                                 value: [NSNumber numberWithInt: 1]];
          fetchQualifier = [[EOAndQualifier alloc] initWithQualifiers:
                                                     cLastModifiedQualifier,
                                                   cDeletedQualifier,
                                                   nil];
          [fetchQualifier autorelease];
          [cLastModifiedQualifier release];
          [cDeletedQualifier release];

          fs = [EOFetchSpecification
                 fetchSpecificationWithEntityName: [ocsFolder folderName]
                                        qualifier: fetchQualifier
                                    sortOrderings: nil];
          records = [ocsFolder
                               fetchFields: [NSArray arrayWithObject: @"c_name"]
                        fetchSpecification: fs
                             ignoreDeleted: NO];
          deletedCNames = [records objectsForKey: @"c_name" notFoundMarker: nil];
          max = [deletedCNames count];
          if (max > 0)
            {
              mapping = [versionProperties objectForKey: @"VersionsMapping"];
              for (count = 0; count < max; count++)
                {
                  cName = [deletedCNames objectAtIndex: count];
                  if ([messages objectForKey: cName])
                    {
                      [messages removeObjectForKey: cName];
                      [(NSMutableArray *) deletedKeys addObject: cName];
                      newChangeNum = [[self context] getNewChangeNumber];
                    }
                }
              if (newChangeNum)
                {
                  changeNumNbr
                    = [NSNumber numberWithUnsignedLongLong: newChangeNum];
                  [mapping setObject: lastModified forKey: changeNumNbr];
                  *cnNbr = changeNumNbr;
                  [versionsMessage save];
                }
            }
        }
    }
  else
    deletedKeys = [super getDeletedKeysFromChangeNumber: changeNum
                                                  andCN: cnNbr
                                            inTableType: tableType];

  return deletedKeys;
}

- (NSArray *) activeUserRoles
{
  SOGoUser *activeUser;
  WOContext *woContext;

  if (!activeUserRoles)
    {
      activeUser = [[self context] activeUser];
      woContext = [[self userContext] woContext];
      activeUserRoles = [activeUser rolesForObject: sogoObject
                                         inContext: woContext];
      [activeUserRoles retain];
    }

  return activeUserRoles;
}

- (BOOL) subscriberCanCreateMessages
{
  return [[self activeUserRoles] containsObject: SOGoRole_ObjectCreator];
}

- (BOOL) subscriberCanDeleteMessages
{
  return [[self activeUserRoles] containsObject: SOGoRole_ObjectEraser];
}

/* subclasses */

- (EOQualifier *) aclQualifier
{
  return nil;
}

- (EOQualifier *) componentQualifier
{
  [self subclassResponsibility: _cmd];

  return nil;
}

@end
