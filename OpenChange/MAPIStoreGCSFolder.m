/* MAPIStoreGCSFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
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
#import <NGExtensions/NSObject+Values.h>
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
#import "SOGoMAPIDBMessage.h"

#import "MAPIStoreGCSFolder.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

static Class NSNumberK;

@implementation MAPIStoreGCSFolder

+ (void) initialize
{
  NSNumberK = [NSNumber class];
}

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
          [SOGoMAPIDBMessage objectWithName: @"versions.plist"
                                inContainer: dbFolder]);
  [versionsMessage setObjectType: MAPIDBObjectTypeInternal];
}

- (void) dealloc
{
  [versionsMessage release];
  [activeUserRoles release];
  [componentQualifier release];
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
  NSDate *value;
  NSNumber *ti;

  [self synchroniseCache];

  ti = [[versionsMessage properties]
         objectForKey: @"SyncLastModificationDate"];
  if (ti)
    value = [NSDate dateWithTimeIntervalSince1970: [ti doubleValue]];
  else
    value = nil;

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
    Version = last-modified;
    ...
  }
}
 */

- (void) _setChangeKey: (NSData *) changeKey
       forMessageEntry: (NSMutableDictionary *) messageEntry
      inChangeListOnly: (BOOL) inChangeListOnly
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

  if (!inChangeListOnly)
    {
      /* 1. set change key association */
      changeKeyDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                      guid, @"GUID",
                                    globCnt, @"LocalId",
                                    nil];
      [messageEntry setObject: changeKeyDict forKey: @"ChangeKey"];
    }

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

- (EOQualifier *) componentQualifier
{
  if (!componentQualifier)
    componentQualifier
      = [[EOKeyValueQualifier alloc] initWithKey: @"c_component"
				operatorSelector: EOQualifierOperatorEqual
					   value: [self component]];

  return componentQualifier;
}

- (EOQualifier *) contentComponentQualifier
{
  EOQualifier *contentComponentQualifier;
  NSString *likeString;
  
  likeString = [NSString stringWithFormat: @"%%BEGIN:%@%%",
                         [[self component] uppercaseString]];
  contentComponentQualifier = [[EOKeyValueQualifier alloc]
                                initWithKey: @"c_content"
                           operatorSelector: EOQualifierOperatorLike
                                      value: likeString];
  [contentComponentQualifier autorelease];

  return contentComponentQualifier;
}

- (BOOL) synchroniseCache
{
  BOOL rc = YES;
  uint64_t newChangeNum;
  NSData *changeKey;
  NSString *cName, *changeNumber;
  NSNumber *ti, *lastModificationDate, *cVersion, *cLastModified, *cDeleted;
  EOFetchSpecification *fs;
  EOQualifier *searchQualifier, *fetchQualifier;
  NSUInteger count, max;
  NSArray *fetchResults, *changeNumbers;
  NSMutableArray *keys, *modifiedEntries;
  NSDictionary *result;
  NSMutableDictionary *currentProperties, *messages, *mapping, *messageEntry;
  NSCalendarDate *now;
  GCSFolder *ocsFolder;
  static NSArray *fields = nil;
  static EOSortOrdering *sortOrdering = nil;

  /* NOTE: we are using NSString instance for "changeNumber" because
     NSNumber proved to give very bad performances when used as NSDictionary
     keys with GNUstep 1.22.1. The bug seems to be solved with 1.24 but many
     distros still ship an older version. */

  if (!fields)
    fields = [[NSArray alloc]
	       initWithObjects: @"c_name", @"c_version", @"c_lastmodified",
               @"c_deleted", nil];

  if (!sortOrdering)
    {
      sortOrdering = [EOSortOrdering sortOrderingWithKey: @"c_lastmodified"
                                                selector: EOCompareAscending];
      [sortOrdering retain];
    }

  [versionsMessage reloadIfNeeded];
  currentProperties = [versionsMessage properties];

  lastModificationDate = [currentProperties objectForKey: @"SyncLastModificationDate"];
  if (lastModificationDate)
    {
      searchQualifier = [[EOKeyValueQualifier alloc]
                                initWithKey: @"c_lastmodified"
                           operatorSelector: EOQualifierOperatorGreaterThanOrEqualTo
                                      value: lastModificationDate];
      fetchQualifier = [[EOAndQualifier alloc]
                         initWithQualifiers: searchQualifier,
                         [self contentComponentQualifier],
                         nil];
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
  fetchResults = [ocsFolder fetchFields: fields
                     fetchSpecification: fs
                          ignoreDeleted: NO];
  max = [fetchResults count];
  if (max > 0)
    {
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

      keys = [NSMutableArray arrayWithCapacity: max];
      modifiedEntries = [NSMutableArray arrayWithCapacity: max];
      for (count = 0; count < max; count++)
        {
          result = [fetchResults objectAtIndex: count];
          cName = [result objectForKey: @"c_name"];
          [keys addObject: cName];
          cDeleted = [result objectForKey: @"c_deleted"];
          if ([cDeleted isKindOfClass: NSNumberK] && [cDeleted intValue])
            cVersion = [NSNumber numberWithInt: -1];
          else
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
              [sogoObject removeChildRecordWithName: cName];

              [modifiedEntries addObject: messageEntry];

              [messageEntry setObject: cLastModified forKey: @"c_lastmodified"];
              [messageEntry setObject: cVersion forKey: @"c_version"];

              if (!lastModificationDate
                  || ([lastModificationDate compare: cLastModified]
                      == NSOrderedAscending))
                lastModificationDate = cLastModified;
            }
        }

      /* make sure all returned objects have a corresponding mid */
      [self ensureIDsForChildKeys: keys];

      max = [modifiedEntries count];
      if (max > 0)
        {
          changeNumbers = [[self context] getNewChangeNumbers: max];
          for (count = 0; count < max; count++)
            {
              messageEntry = [modifiedEntries objectAtIndex: count];

              changeNumber = [changeNumbers objectAtIndex: count];
              cLastModified = [messageEntry objectForKey: @"c_lastmodified"];
              [mapping setObject: cLastModified forKey: changeNumber];
              [messageEntry setObject: changeNumber forKey: @"version"];

              newChangeNum = [changeNumber unsignedLongValue];
              changeKey = [self getReplicaKeyFromGlobCnt: newChangeNum >> 16];
              [self _setChangeKey: changeKey forMessageEntry: messageEntry
                 inChangeListOnly: NO];
            }

          now = [NSCalendarDate date];
          ti = [NSNumber numberWithDouble: [now timeIntervalSince1970]];
          [currentProperties setObject: ti
                                forKey: @"SyncLastSynchronisationDate"];
          [currentProperties setObject: lastModificationDate
                                forKey: @"SyncLastModificationDate"];
          [versionsMessage save];
        }
    }

  return rc;
}

- (void) updateVersionsForMessageWithKey: (NSString *) messageKey
                           withChangeKey: (NSData *) newChangeKey
{
  NSMutableDictionary *messages, *messageEntry;

  [self synchroniseCache];
  if (newChangeKey)
    {
      messages = [[versionsMessage properties] objectForKey: @"Messages"];
      messageEntry = [messages objectForKey: messageKey];
      if (!messageEntry)
        [NSException raise: @"MAPIStoreIOException"
                    format: @"no version record found for message '%@'",
                     messageKey];
      [self _setChangeKey: newChangeKey forMessageEntry: messageEntry
         inChangeListOnly: YES];
      [versionsMessage save];
    }
}
 
- (NSNumber *) lastModifiedFromMessageChangeNumber: (NSString *) changeNumber
{
  NSDictionary *mapping;
  NSNumber *modseq;

  mapping = [[versionsMessage properties] objectForKey: @"VersionMapping"];
  modseq = [mapping objectForKey: changeNumber];

  return modseq;
}

- (NSString *) changeNumberForMessageWithKey: (NSString *) messageKey
{
  NSDictionary *messages;
  NSString *changeNumber;

  messages = [[versionsMessage properties] objectForKey: @"Messages"];
  changeNumber = [[messages objectForKey: messageKey]
                   objectForKey: @"version"];

  return changeNumber;
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
      changeKey = [NSData dataWithChangeKeyGUID: guid andCnt: globCnt];
    }

  return changeKey;
}

- (NSData *) predecessorChangeListForMessageWithKey: (NSString *) messageKey
{
  NSMutableData *list = nil;
  NSDictionary *messages, *changeListDict;
  NSArray *keys;
  NSMutableArray *changeKeys;
  NSUInteger count, max;
  NSData *changeKey;
  NSString *guid;
  NSData *globCnt;

  messages = [[versionsMessage properties] objectForKey: @"Messages"];
  changeListDict = [[messages objectForKey: messageKey]
                     objectForKey: @"PredecessorChangeList"];
  if (changeListDict)
    {
      keys = [changeListDict allKeys];
      max = [keys count];

      changeKeys = [NSMutableArray arrayWithCapacity: max];
      for (count = 0; count < max; count++)
        {
          guid = [keys objectAtIndex: count];
          globCnt = [changeListDict objectForKey: guid];
          changeKey = [NSData dataWithChangeKeyGUID: guid andCnt: globCnt];
          [changeKeys addObject: changeKey];
        }
      [changeKeys sortUsingFunction: MAPIChangeKeyGUIDCompare
                            context: nil];

      list = [NSMutableData data];
      for (count = 0; count < max; count++)
        {
          changeKey = [changeKeys objectAtIndex: count];
          [list appendUInt8: [changeKey length]];
          [list appendData: changeKey];
        }
    }

  return list;
}

- (NSArray *) getDeletedKeysFromChangeNumber: (uint64_t) changeNum
                                       andCN: (NSNumber **) cnNbr
                                 inTableType: (uint8_t) tableType
{
  NSArray *deletedKeys, *deletedCNames, *records;
  NSNumber *lastModified;
  NSString *cName, *changeNumber;
  NSDictionary *versionProperties, *messageEntry;
  NSMutableDictionary *messages;
  uint64_t maxChangeNum = changeNum, currentChangeNum;
  EOAndQualifier *fetchQualifier;
  EOKeyValueQualifier *cDeletedQualifier, *cLastModifiedQualifier;
  EOFetchSpecification *fs;
  GCSFolder *ocsFolder;
  NSUInteger count, max;

  if (tableType == MAPISTORE_MESSAGE_TABLE)
    {
      deletedKeys = [NSMutableArray array];

      changeNumber = [NSString stringWithUnsignedLongLong: changeNum];
      lastModified = [self lastModifiedFromMessageChangeNumber: changeNumber];
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
          for (count = 0; count < max; count++)
            {
              cName = [deletedCNames objectAtIndex: count];
              [sogoObject removeChildRecordWithName: cName];
              messageEntry = [messages objectForKey: cName];
              if (messageEntry)
                {
                  currentChangeNum
                    = [[messageEntry objectForKey: @"version"]
                        unsignedLongLongValue];
                  if (MAPICNCompare (changeNum, currentChangeNum, NULL)
                      == NSOrderedAscending)
                    {
                      [(NSMutableArray *) deletedKeys addObject: cName];
                      if (MAPICNCompare (maxChangeNum, currentChangeNum, NULL)
                          == NSOrderedAscending)
                        maxChangeNum = currentChangeNum;
                    }
                }
            }
          if (maxChangeNum != changeNum)
            *cnNbr = [NSNumber numberWithUnsignedLongLong: maxChangeNum];
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

- (NSString *) component
{
  [self subclassResponsibility: _cmd];

  return nil;
}

@end
