/* MAPIStoreMailFolder.m - this file is part of SOGo
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

#include <talloc.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <EOControl/EOQualifier.h>
#import <EOControl/EOSortOrdering.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSObject+Values.h>
#import <NGExtensions/NSString+misc.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4Client.h>
#import <Mailer/SOGoDraftsFolder.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailAccounts.h>
#import <Mailer/SOGoMailFolder.h>
#import <Mailer/SOGoMailObject.h>
#import <Mailer/SOGoSentFolder.h>
#import <Mailer/SOGoTrashFolder.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoPermissions.h>

#import "MAPIApplication.h"
#import "MAPIStoreAppointmentWrapper.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreFAIMessage.h"
#import "MAPIStoreMailContext.h"
#import "MAPIStoreMailMessage.h"
#import "MAPIStoreMailMessageTable.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreTypes.h"
#import "MAPIStoreUserContext.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "SOGoMAPIDBMessage.h"
#import "SOGoMAPIDBFolder.h"

#import "MAPIStoreMailVolatileMessage.h"

#import "MAPIStoreMailFolder.h"

static Class SOGoMailFolderK, MAPIStoreMailFolderK, MAPIStoreOutboxFolderK;

#undef DEBUG
#include <util/attr.h>
#include <libmapi/libmapi.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreMailFolder

+ (void) initialize
{
  SOGoMailFolderK = [SOGoMailFolder class];
  MAPIStoreMailFolderK = [MAPIStoreMailFolder class];
  MAPIStoreOutboxFolderK = [MAPIStoreOutboxFolder class];
  [MAPIStoreAppointmentWrapper class];
}

- (id) init
{
  if ((self = [super init]))
    {
      versionsMessage = nil;
      bodyData = [NSMutableDictionary new];
    }

  return self;
}

- (void) dealloc
{
  [versionsMessage release];
  [bodyData release];
  [super dealloc];
}

- (void) setupVersionsMessage
{
  ASSIGN (versionsMessage,
          [SOGoMAPIDBMessage objectWithName: @"versions.plist"
                                inContainer: dbFolder]);
  [versionsMessage setObjectType: MAPIDBObjectTypeInternal];
}

- (BOOL) ensureFolderExists
{
  return [(SOGoMailFolder *) sogoObject exists] || [sogoObject create];
}

- (void) addProperties: (NSDictionary *) newProperties
{
  NSString *newDisplayName, *newNameInContainer;
  NSMutableDictionary *propsCopy;
  NSNumber *key;
  uint64_t fid;

  key = MAPIPropertyKey (PR_DISPLAY_NAME_UNICODE);
  newDisplayName = [newProperties objectForKey: key];
  if (newDisplayName
      && ![self isKindOfClass: MAPIStoreOutboxFolderK]
      && ![[(SOGoMailFolder *) sogoObject displayName]
            isEqualToString: newDisplayName])
    {
      fid = [self objectId];
      [(SOGoMailFolder *) sogoObject renameTo: newDisplayName];
      newNameInContainer = [sogoObject nameInContainer];
      if (!container)
        [(MAPIStoreMailContext *) context
           updateURLWithFolderName: newNameInContainer];
      [[self mapping] updateID: fid withURL: [self url]];
      [dbFolder setNameInContainer: newNameInContainer];
      [self cleanupCaches];
      
      propsCopy = [newProperties mutableCopy];
      [propsCopy removeObjectForKey: key];
      [propsCopy autorelease];
      newProperties = propsCopy;
    }

  [super addProperties: newProperties];
}

- (MAPIStoreMessageTable *) messageTable
{
  [self synchroniseCache];
  return [MAPIStoreMailMessageTable tableForContainer: self];
}

- (enum mapistore_error) createFolder: (struct SRow *) aRow
                              withFID: (uint64_t) newFID
                               andKey: (NSString **) newKeyP
{
  enum mapistore_error rc;
  NSString *folderName, *nameInContainer;
  SOGoMailFolder *newFolder;
  int i;

  nameInContainer = nil;

  folderName = nil;
  for (i = 0; !folderName && i < aRow->cValues; i++)
    {
      if (aRow->lpProps[i].ulPropTag == PR_DISPLAY_NAME_UNICODE)
        folderName = [NSString stringWithUTF8String: aRow->lpProps[i].value.lpszW];
      else if (aRow->lpProps[i].ulPropTag == PR_DISPLAY_NAME)
        folderName = [NSString stringWithUTF8String: aRow->lpProps[i].value.lpszA];
    }

  if (folderName)
    {
      nameInContainer = [NSString stringWithFormat: @"folder%@",
                                  [folderName asCSSIdentifier]];
      newFolder = [SOGoMailFolderK objectWithName: nameInContainer
                                      inContainer: sogoObject];
      if ([newFolder create])
        {
          *newKeyP = nameInContainer;
          rc = MAPISTORE_SUCCESS;
        }
      else if ([newFolder exists])
        rc = MAPISTORE_ERR_EXIST;
      else
        rc = MAPISTORE_ERR_DENIED;
    }

  return rc;
}

- (int) deleteFolder
{
  int rc;
  NSException *error;
  NSString *name;

  name = [self nameInContainer];
  if ([name isEqualToString: @"folderINBOX"])
    rc = MAPISTORE_ERR_DENIED;
  else
    {
      error = [(SOGoMailFolder *) sogoObject delete];
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

- (int) getPidTagContentUnreadCount: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  EOQualifier *searchQualifier;
  uint32_t longValue;

  searchQualifier
    = [EOQualifier qualifierWithQualifierFormat: @"flags = %@", @"unseen"];
  longValue = [[sogoObject fetchUIDsMatchingQualifier: searchQualifier
                                         sortOrdering: nil]
                count];
  *data = MAPILongValue (memCtx, longValue);
  
  return MAPISTORE_SUCCESS;
}

- (int) getPidTagContainerClass: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"IPF.Note" asUnicodeInMemCtx: memCtx];
  
  return MAPISTORE_SUCCESS;
}

- (EOQualifier *) nonDeletedQualifier
{
  static EOQualifier *nonDeletedQualifier = nil;
  EOQualifier *deletedQualifier;

  if (!nonDeletedQualifier)
    {
      deletedQualifier
        = [[EOKeyValueQualifier alloc] 
                 initWithKey: @"FLAGS"
            operatorSelector: EOQualifierOperatorContains
                       value: [NSArray arrayWithObject: @"Deleted"]];
      nonDeletedQualifier = [[EONotQualifier alloc]
                              initWithQualifier: deletedQualifier];
      [deletedQualifier release];
    }

  return nonDeletedQualifier;
}

- (NSArray *) messageKeysMatchingQualifier: (EOQualifier *) qualifier
                          andSortOrderings: (NSArray *) sortOrderings
{
  NSArray *uidKeys;
  EOQualifier *fetchQualifier;

  if ([self ensureFolderExists])
    {
      if (!sortOrderings)
        sortOrderings = [NSArray arrayWithObject: @"ARRIVAL"];

      if (qualifier)
        {
          fetchQualifier
            = [[EOAndQualifier alloc] initWithQualifiers:
                                        [self nonDeletedQualifier], qualifier,
                                      nil];
          [fetchQualifier autorelease];
        }
      else
        fetchQualifier = [self nonDeletedQualifier];

      uidKeys = [[sogoObject fetchUIDsMatchingQualifier: fetchQualifier
                                          sortOrdering: sortOrderings]
                   stringsWithFormat: @"%@.eml"];
    }
  else
    uidKeys = nil;

  return uidKeys;
}

- (NSMutableString *) _imapFolderNameRepresentation: (NSString *) subfolderName
{
  NSMutableString *representation;
  NSString *nameInContainer, *strippedName;

  nameInContainer = [self nameInContainer];
  if (container)
    representation = [(MAPIStoreMailFolder *) container
                       _imapFolderNameRepresentation: nameInContainer];
  else
    {
      if (![nameInContainer hasPrefix: @"folder"])
        abort ();
      strippedName = [nameInContainer substringFromIndex: 6];
      representation = [NSMutableString stringWithString: strippedName];
    }

  if (![subfolderName hasPrefix: @"folder"])
    abort ();
  strippedName = [subfolderName substringFromIndex: 6];
  [representation appendFormat: @"/%@", strippedName];

  return representation;
}

- (void) _cleanupSubfolderKeys: (NSMutableArray *) subfolderKeys
{
  SOGoMailAccount *account;
  NSString *draftsFolderName, *sentFolderName, *trashFolderName;
  NSString *subfolderKey, *cmpString;
  NSUInteger count, max;
  NSMutableArray *keysToRemove;

  account = [(SOGoMailFolder *) sogoObject mailAccountFolder];
  draftsFolderName = [account draftsFolderNameInContext: nil];
  sentFolderName = [account sentFolderNameInContext: nil];
  trashFolderName = [account trashFolderNameInContext: nil];

  max = [subfolderKeys count];
  keysToRemove = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      subfolderKey = [subfolderKeys  objectAtIndex: count];
      cmpString = [self _imapFolderNameRepresentation: subfolderKey];
      if ([cmpString isEqualToString: draftsFolderName]
          || [cmpString isEqualToString: sentFolderName]
          || [cmpString isEqualToString: trashFolderName])
        [keysToRemove addObject: subfolderKey];
    }

  [subfolderKeys removeObjectsInArray: keysToRemove];
}

- (NSArray *) folderKeysMatchingQualifier: (EOQualifier *) qualifier
                         andSortOrderings: (NSArray *) sortOrderings
{
  NSMutableArray *subfolderKeys;

  if ([self ensureFolderExists])
    {
      if (qualifier)
        [self errorWithFormat: @"qualifier is not used for folders"];
      if (sortOrderings)
        [self errorWithFormat: @"sort orderings are not used for folders"];
      
      subfolderKeys = [[sogoObject toManyRelationshipKeys] mutableCopy];
      [subfolderKeys autorelease];

      [self _cleanupSubfolderKeys: subfolderKeys];
    }
  else
    subfolderKeys = nil;

  return subfolderKeys;
}

- (NSDate *) creationTime
{
  return [NSCalendarDate dateWithTimeIntervalSince1970: 0x4dbb2dbe]; /* oc_version_time */
}

- (NSDate *) lastMessageModificationTime
{
  NSNumber *ti;
  NSDate *value = nil;

  [self synchroniseCache];
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

- (NSArray *) permissionEntries
{
  NSArray *permissionEntries;

  if ([self ensureFolderExists])
    permissionEntries = [super permissionEntries];
  else
    permissionEntries = nil;

  return permissionEntries;
}

- (BOOL) supportsSubFolders
{
  BOOL supportsSubFolders;
  MAPIStoreUserContext *userContext;

  if ([[self nameInContainer] isEqualToString: @"folderINBOX"])
    {
      userContext = [self userContext];
      supportsSubFolders = ![userContext inboxHasNoInferiors];
    }
  else
    supportsSubFolders = YES;
  
  return supportsSubFolders;
}

/* synchronisation */

/* Tree:
{
  SyncLastModseq = x;
  SyncLastSynchronisationDate = x; ** not updated until something changed
  Messages = {
    MessageKey = {
      Version = x;
      Modseq = x;
      Deleted = b;
    };
    ...
  };
  VersionMapping = {
    Version = MessageKey;
    ...
  }
}
*/

static NSComparisonResult
_compareFetchResultsByMODSEQ (id entry1, id entry2, void *data)
{
  static NSNumber *zeroNumber = nil;
  NSNumber *modseq1, *modseq2;

  if (!zeroNumber)
    {
      zeroNumber = [NSNumber numberWithUnsignedLongLong: 0];
      [zeroNumber retain];
    }

  modseq1 = [entry1 objectForKey: @"modseq"];
  if (!modseq1)
    modseq1 = zeroNumber;
  modseq2 = [entry2 objectForKey: @"modseq"];
  if (!modseq2)
    modseq2 = zeroNumber;

  return [modseq1 compare: modseq2];
}

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
  BOOL rc = YES;
  uint64_t newChangeNum;
  NSNumber *ti, *modseq, *initialLastModseq, *lastModseq,
    *nextModseq;
  NSString *changeNumber, *uid, *messageKey;
  uint64_t lastModseqNbr;
  EOQualifier *kvQualifier, *searchQualifier;
  NSArray *uids, *changeNumbers;
  NSUInteger count, max;
  NSArray *fetchResults;
  NSDictionary *result;
  NSData *changeKey;
  NSMutableArray *messageKeys;
  NSMutableDictionary *currentProperties, *messages, *mapping, *messageEntry;
  NSCalendarDate *now;
  BOOL foundChange = NO;

  /* NOTE: we are using NSString instance for "uid" and "changeNumber" because
     NSNumber proved to give very bad performances when used as NSDictionary
     keys with GNUstep 1.22.1. The bug seems to be solved with 1.24 but many
     distros still ship an older version. */
  now = [NSCalendarDate date];
  [now setTimeZone: utcTZ];

  [versionsMessage reloadIfNeeded];
  currentProperties = [versionsMessage properties];
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

  lastModseq = [currentProperties objectForKey: @"SyncLastModseq"];
  initialLastModseq = lastModseq;
  if (lastModseq)
    {
      lastModseqNbr = [lastModseq unsignedLongLongValue];
      nextModseq = [NSNumber numberWithUnsignedLongLong: lastModseqNbr + 1];
      kvQualifier = [[EOKeyValueQualifier alloc]
                                initWithKey: @"modseq"
                           operatorSelector: EOQualifierOperatorGreaterThanOrEqualTo
                                      value: nextModseq];
      searchQualifier = [[EOAndQualifier alloc]
                          initWithQualifiers:
                            kvQualifier, [self nonDeletedQualifier], nil];
      [kvQualifier release];
      [searchQualifier autorelease];
    }
  else
    {
      lastModseqNbr = 0;
      searchQualifier = [self nonDeletedQualifier];
    }

  /* 1. we fetch modified or added uids */
  uids = [sogoObject fetchUIDsMatchingQualifier: searchQualifier
                                   sortOrdering: nil];
  max = [uids count];
  if (max > 0)
    {
      messageKeys = [NSMutableArray arrayWithCapacity: max];
      for (count = 0; count < max; count++)
        {
          messageKey = [NSString stringWithFormat: @"%@.eml",
                                 [uids objectAtIndex: count]];
          [messageKeys addObject: messageKey];
        }
      [self ensureIDsForChildKeys: messageKeys];

      changeNumbers = [[self context] getNewChangeNumbers: max];

      fetchResults
        = [(NSDictionary *) [sogoObject fetchUIDs: uids
                                            parts: [NSArray arrayWithObject: @"modseq"]]
                          objectForKey: @"fetch"];

      /* NOTE: we sort items manually because Cyrus does not properly sort
         entries with a MODSEQ of 0 */
      fetchResults
        = [fetchResults sortedArrayUsingFunction: _compareFetchResultsByMODSEQ
                                         context: NULL];
      
      for (count = 0; count < max; count++)
        {
          result = [fetchResults objectAtIndex: count];
          uid = [[result objectForKey: @"uid"] stringValue];
          modseq = [result objectForKey: @"modseq"];
          newChangeNum = [[changeNumbers objectAtIndex: count]
                             unsignedLongLongValue];
          changeNumber = [NSString stringWithUnsignedLongLong: newChangeNum];

          messageEntry = [NSMutableDictionary new];
          [messages setObject: messageEntry forKey: uid];
          [messageEntry release];

          [messageEntry setObject: modseq forKey: @"modseq"];
          [messageEntry setObject: changeNumber forKey: @"version"];

          [self logWithFormat: @"added message entry for uid %@, modseq %@,"
                @" version %@", uid, modseq, changeNumber];

          changeKey = [self getReplicaKeyFromGlobCnt: newChangeNum >> 16];
          [self _setChangeKey: changeKey forMessageEntry: messageEntry];

          [mapping setObject: modseq forKey: changeNumber];

          if (!lastModseq
              || ([lastModseq compare: modseq] == NSOrderedAscending))
            lastModseq = modseq;
        }

      [currentProperties setObject: lastModseq forKey: @"SyncLastModseq"];
      foundChange = YES;
    }

  /* 2. we synchronise deleted UIDs */
  if (initialLastModseq)
    {
      fetchResults = [(SOGoMailFolder *) sogoObject
                         fetchUIDsOfVanishedItems: lastModseqNbr];
      max = [fetchResults count];
      changeNumbers = [[self context] getNewChangeNumbers: max];
      changeNumber = nil;
      for (count = 0; count < max; count++)
        {
          uid = [fetchResults objectAtIndex: count];
          if ([messages objectForKey: uid])
            {
              newChangeNum = [[changeNumbers objectAtIndex: count]
                               unsignedLongLongValue];
              changeNumber = [NSString stringWithUnsignedLongLong: newChangeNum];
              [messages removeObjectForKey: uid];
              [self logWithFormat: @"removed message entry for uid %@", uid];
            }
        }
      if (changeNumber)
        {
          [currentProperties setObject: changeNumber
                                forKey: @"SyncLastDeleteChangeNumber"];
          foundChange = YES;
        }
    }

  if (foundChange)
    {
      ti = [NSNumber numberWithDouble: [now timeIntervalSince1970]];
      [currentProperties setObject: ti
                            forKey: @"SyncLastSynchronisationDate"];
      [versionsMessage save];
    }

  return rc;
}
 
- (NSNumber *) modseqFromMessageChangeNumber: (NSString *) changeNum
{
  NSDictionary *mapping;
  NSNumber *modseq;

  mapping = [[versionsMessage properties] objectForKey: @"VersionMapping"];
  modseq = [mapping objectForKey: changeNum];

  return modseq;
}

- (NSString *) messageUIDFromMessageKey: (NSString *) messageKey
{
  NSString *messageUid;
  NSRange dotRange;

  dotRange = [messageKey rangeOfString: @".eml"];
  if (dotRange.location != NSNotFound)
    messageUid = [messageKey substringToIndex: dotRange.location];
  else
    messageUid = nil;

  return messageUid;
}

- (NSString *) changeNumberForMessageUID: (NSString *) messageUid
{
  NSDictionary *messages;
  NSString *changeNumber;

  messages = [[versionsMessage properties] objectForKey: @"Messages"];
  changeNumber = [[messages objectForKey: messageUid]
                   objectForKey: @"version"];

  return changeNumber;
}

- (void) setChangeKey: (NSData *) changeKey
    forMessageWithKey: (NSString *) messageKey
{
  NSMutableDictionary *messages, *messageEntry;
  NSString *messageUid;

  messageUid = [self messageUIDFromMessageKey: messageKey];
  messages = [[versionsMessage properties] objectForKey: @"Messages"];
  messageEntry = [messages objectForKey: messageUid];
  if (!messageEntry)
    abort ();
  [self _setChangeKey: changeKey forMessageEntry: messageEntry];
  
  [versionsMessage save];
}

- (NSData *) changeKeyForMessageWithKey: (NSString *) messageKey
{
  NSDictionary *messages, *changeKeyDict;
  NSString *guid, *messageUid;
  NSData *globCnt, *changeKey = nil;

  messageUid = [self messageUIDFromMessageKey: messageKey];
  messages = [[versionsMessage properties] objectForKey: @"Messages"];
  changeKeyDict = [[messages objectForKey: messageUid]
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
  NSString *guid, *messageUid;
  NSData *globCnt;

  messageUid = [self messageUIDFromMessageKey: messageKey];
  messages = [[versionsMessage properties] objectForKey: @"Messages"];
  changeListDict = [[messages objectForKey: messageUid]
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
  NSArray *deletedKeys, *deletedUIDs;
  NSString *changeNumber;
  uint64_t modseq;
  NSDictionary *versionProperties;

  if (tableType == MAPISTORE_MESSAGE_TABLE)
    {
      changeNumber = [NSString stringWithUnsignedLongLong: changeNum];
      modseq = [[self modseqFromMessageChangeNumber: changeNumber]
                 unsignedLongLongValue];
      if (modseq > 0)
        {
          deletedUIDs = [(SOGoMailFolder *) sogoObject
                           fetchUIDsOfVanishedItems: modseq];
          deletedKeys = [deletedUIDs stringsWithFormat: @"%@.eml"];
          if ([deletedUIDs count] > 0)
            {
              versionProperties = [versionsMessage properties];
              changeNumber = [versionProperties
                                  objectForKey: @"SyncLastDeleteChangeNumber"];
              *cnNbr = [NSNumber numberWithUnsignedLongLong:
                                   [changeNumber unsignedLongLongValue]];
              [versionsMessage save];
            }
        }
      else
        deletedKeys = [NSArray array];
    }
  else
    deletedKeys = [super getDeletedKeysFromChangeNumber: changeNum
                                                  andCN: cnNbr
                                            inTableType: tableType];

  return deletedKeys;
}

static void
_appendIMAPRange (NSMutableArray *UIDs, uint32_t low, uint32_t high)
{
  uint32_t count;

  for (count = low; count < high + 1; count++)
    [UIDs addObject: [NSNumber numberWithUnsignedLong: count]];
}

static NSUInteger
_parseUID (const unichar *uniString, uint32_t *newUidP)
{
  NSUInteger count = 0;
  uint32_t newUid = 0;

  while (uniString[count] >= '0' && uniString[count] <= '9')
    {
      newUid = newUid * 10 + (uniString[count] - 48);
      count++;
    }
  *newUidP = newUid;

  return count;
}

static NSUInteger
_parseIMAPRange (const unichar *uniString, NSArray **UIDsP)
{
  NSMutableArray *UIDs;
  NSUInteger count = 0;
  uint32_t currentUid, rangeMin;
  BOOL done = NO, inRange = NO;

  UIDs = [NSMutableArray array];
  while (!done)
    {
      count += _parseUID (uniString + count, &currentUid);
      switch (uniString[count])
        {
        case ':':
          inRange = YES;
          rangeMin = currentUid;
          break;
        case ' ':
        case 0:
          done = YES;
        case ',':
          if (inRange)
            {
              _appendIMAPRange (UIDs, rangeMin, currentUid);
              inRange = NO;
            }
          else
            [UIDs addObject: [NSNumber numberWithUnsignedLong: currentUid]];
          break;
        default:
          abort ();
        }
      count++;
    }
  *UIDsP = UIDs;
 
  return count;
}

static void
_parseCOPYUID (NSString *line, NSArray **destUIDsP)
{
  unichar *uniString;
  NSUInteger count = 0, max;
  // char state = 'i'; /* i = init, v = validity, s = source range, d = dest range */

  /* sample: 1 OK [COPYUID 1311899334 1:3 11:13] Completed */

  max = [line length];
  uniString = NSZoneMalloc (NULL, sizeof (unichar) * (max + 1));
  [line getCharacters: uniString];
  uniString[max] = 0;

  while (count < max && uniString[count] != ' ')
    count++;
  count++;
  while (count < max && uniString[count] != ' ')
    count++;
  count++;
  while (count < max && uniString[count] != ' ')
    count++;
  count++;
  if (count < max)
    count += _parseIMAPRange (uniString + count, destUIDsP);

  NSZoneFree (NULL, uniString);
}

//
// Move (or eventually copy) the mails identified by
// "srcMids" from the source folder into this folder.
//
- (int) moveCopyMessagesWithMIDs: (uint64_t *) srcMids
                        andCount: (uint32_t) midCount
                      fromFolder: (MAPIStoreFolder *) sourceFolder
                        withMIDs: (uint64_t *) targetMids
                   andChangeKeys: (struct Binary_r **) targetChangeKeys
                        wantCopy: (uint8_t) wantCopy
{
  NGImap4Connection *connection;
  NGImap4Client *client;
  NSString *sourceFolderName, *targetFolderName, *messageURL, *messageKey,
    *uid, *v;
  NSMutableArray *uids, *oldMessageURLs;
  NSArray *destUIDs;
  MAPIStoreMapping *mapping;
  NSDictionary *result;
  NSUInteger count;
  NSArray *a;
  NSData *changeKey;

  if (![sourceFolder isKindOfClass: [MAPIStoreMailFolder class]])
    return [super moveCopyMessagesWithMIDs: srcMids andCount: midCount
                                fromFolder: sourceFolder withMIDs: targetMids
                             andChangeKeys: targetChangeKeys
                                  wantCopy: wantCopy];

  /* Conversion of mids to IMAP uids */
  mapping = [self mapping];
  uids = [NSMutableArray arrayWithCapacity: midCount];
  oldMessageURLs = [NSMutableArray arrayWithCapacity: midCount];
  for (count = 0; count < midCount; count++)
    {
      messageURL = [mapping urlFromID: srcMids[count]];
      if (messageURL)
        {
          uid = [self messageUIDFromMessageKey: [messageURL lastPathComponent]];
          [uids addObject: uid];

          [oldMessageURLs addObject: messageURL];
        }
      else
        return MAPISTORE_ERROR;
    }

  /* IMAP COPY */
  connection = [sogoObject imap4Connection];
  sourceFolderName = [connection
                       imap4FolderNameForURL: [[sourceFolder sogoObject] imap4URL]];
  targetFolderName = [connection
                       imap4FolderNameForURL: [sogoObject imap4URL]];

  client = [connection client];
  [client select: sourceFolderName];
  result = [client copyUids: uids toFolder: targetFolderName];
  if (![[result objectForKey: @"result"] boolValue])
    return MAPISTORE_ERROR;

  /* "Move" treatment: Store \Deleted and unregister urls */
  if (!wantCopy)
    {
      [client storeFlags: [NSArray arrayWithObject: @"Deleted"] forUIDs: uids
             addOrRemove: YES];
      for (count = 0; count < midCount; count++)
        [mapping unregisterURLWithID: srcMids[count]];
    }

  /* Registration of target messages */
  //
  // We use the UIDPLUS IMAP extension here in order to speedup UID retrieval
  // If supported by the server, we'll get something like: COPYUID 1315425789 1 8
  //
  // Sometimes COPYUID isn't returned at all by Cyrus or in case the server doesn't
  // support the UIDPLUS IMAP extension, we fallback to a simple UID search.
  //
  v = [[[result objectForKey: @"RawResponse"] objectForKey: @"ResponseResult"] objectForKey: @"flag"];
  if (v)
    {
      destUIDs = nil;
      _parseCOPYUID (v, &destUIDs);
    }
  else
    {
      /* FIXME: this may fail if new messages are appended to the folder
         between the COPY and SORT operations */
      [client select: targetFolderName];
      a = [[client sort: @"ARRIVAL"  qualifier: nil encoding: @"UTF-8"]
            objectForKey: @"sort"];
      destUIDs = [[a sortedArrayUsingSelector: @selector (compare:)]
                   subarrayWithRange: NSMakeRange ([a count] - midCount, midCount)];
    }
  for (count = 0; count < midCount; count++)
    {
      messageURL = [NSString stringWithFormat: @"%@%@.eml",
                             [self url],
                             [destUIDs objectAtIndex: count]];
      [mapping registerURL: messageURL withID: targetMids[count]];
    }

  /* Update the change keys */
  if (targetChangeKeys)
    {
      [self synchroniseCache];
      for (count = 0; count < midCount; count++)
        {
          changeKey = [NSData dataWithBinary: targetChangeKeys[count]];
          messageKey = [NSString stringWithFormat: @"%@.eml",
                                 [destUIDs objectAtIndex: count]];
          [self   setChangeKey: changeKey
             forMessageWithKey: messageKey];
        }
    }

  [self postNotificationsForMoveCopyMessagesWithMIDs: srcMids
                                      andMessageURLs: oldMessageURLs
                                            andCount: midCount
                                          fromFolder: sourceFolder
                                            withMIDs: targetMids
                                            wantCopy: wantCopy];

  // We cleanup cache of our source and destination folders
  [self cleanupCaches];
  [sourceFolder cleanupCaches];

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) moveCopyToFolder: (MAPIStoreFolder *) targetFolder
                              withNewName: (NSString *) newFolderName
                                   isMove: (BOOL) isMove
                              isRecursive: (BOOL) isRecursive
{
  enum mapistore_error rc;
  NSURL *folderURL, *newFolderURL;
  struct SRow folderRow;
  struct SPropValue nameProperty;
  MAPIStoreMailFolder *newFolder;
  SOGoMailFolder *targetSOGoFolder;
  NSMutableArray *uids;
  NSArray *childKeys;
  NSUInteger count, max;
  NGImap4Connection *connection;
  NGImap4Client *client;
  NSString *newURL, *parentDBFolderPath, *childKey, *folderIMAPName,
    *urlNamePart, *newFolderIMAPName;
  NSException *error;
  MAPIStoreMapping *mapping;
  NSDictionary *result;

  if ([targetFolder isKindOfClass: MAPIStoreMailFolderK])
    {
      folderURL = [sogoObject imap4URL];
      if (!newFolderName)
        newFolderName = [sogoObject displayName];
      targetSOGoFolder = [targetFolder sogoObject];
      if (isMove)
        {
          urlNamePart = [newFolderName stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
          newFolderURL = [NSURL URLWithString: urlNamePart
                                relativeToURL: [targetSOGoFolder imap4URL]];
          error = [[sogoObject imap4Connection]
                      moveMailboxAtURL: folderURL
                                 toURL: newFolderURL];
          if (error)
            rc = MAPISTORE_ERR_DENIED;
          else
            {
              rc = MAPISTORE_SUCCESS;
              mapping = [self mapping];
              newURL = [NSString stringWithFormat: @"%@folder%@/",
                                 [targetFolder url], urlNamePart];
              [mapping updateID: [self objectId] withURL: newURL];
              parentDBFolderPath = [[targetFolder dbFolder] path];
              if (!parentDBFolderPath)
                parentDBFolderPath = @"";
              [dbFolder changePathTo: [NSString stringWithFormat:
                                                  @"%@/folder%@",
                                                parentDBFolderPath,
                                                newFolderName]];
            }
        }
      else
        {
          nameProperty.ulPropTag = PidTagDisplayName;
          nameProperty.value.lpszW = [newFolderName UTF8String];
          folderRow.lpProps = &nameProperty;
          folderRow.cValues = 1;
          rc = [targetFolder createFolder: &folderRow
                                  withFID: -1
                                   andKey: &childKey];
          if (rc == MAPISTORE_SUCCESS)
            {
              newFolder = [targetFolder lookupFolder: childKey];

              connection = [sogoObject imap4Connection];
              folderIMAPName = [connection
                                 imap4FolderNameForURL: [sogoObject imap4URL]];
              newFolderIMAPName = [connection
                                    imap4FolderNameForURL: [[newFolder sogoObject] imap4URL]];
              client = [connection client];
              [client select: folderIMAPName];

              childKeys = [self messageKeys];
              max = [childKeys count];
              uids = [NSMutableArray arrayWithCapacity: max];
              for (count = 0; count < max; count++)
                {
                  childKey = [childKeys objectAtIndex: count];
                  [uids addObject: [self messageUIDFromMessageKey: childKey]];
                }

              result = [client copyUids: uids 
                               toFolder: newFolderIMAPName];
              if ([[result objectForKey: @"result"] boolValue])
                {
                  if (isRecursive)
                    {
                      childKeys = [self folderKeys];
                      max = [childKeys count];
                      for (count = 0; count < max; count++)
                        {
                          childKey = [childKeys objectAtIndex: count];
                          [[self lookupFolder: childKey]
                              moveCopyToFolder: newFolder
                                   withNewName: nil
                                        isMove: NO
                                   isRecursive: YES];
                        }
                    }
                }
              else
                rc = MAPISTORE_ERROR;
            }
        }
      [targetFolder cleanupCaches];
    }
  else
    rc = [super moveCopyToFolder: targetFolder withNewName: newFolderName
                          isMove: isMove
                     isRecursive: isRecursive];

  return rc;
}

- (MAPIStoreMessage *) createMessage
{
  SOGoMAPIObject *childObject;

  childObject = [SOGoMAPIObject objectWithName: [SOGoMAPIObject
                                                  globallyUniqueObjectId]
                                   inContainer: sogoObject];
  return [MAPIStoreMailVolatileMessage
           mapiStoreObjectWithSOGoObject: childObject
                             inContainer: self];
}

- (id) lookupMessage: (NSString *) messageKey
{
  MAPIStoreMailMessage *message;
  NSData *rawBodyData;

  message = [super lookupMessage: messageKey];
  if (message)
    {
      rawBodyData = [bodyData objectForKey: messageKey];
      if (rawBodyData)
        [message setBodyContentFromRawData: rawBodyData];
    }

  return message;
}

- (NSArray *) rolesForExchangeRights: (uint32_t) rights
{
  NSMutableArray *roles;

  roles = [NSMutableArray arrayWithCapacity: 6];
  if (rights & RoleOwner)
    [roles addObject: SOGoMailRole_Administrator];
  if (rights & RightsCreateItems)
    {
      [roles addObject: SOGoRole_ObjectCreator];
      [roles addObject: SOGoMailRole_Writer];
      [roles addObject: SOGoMailRole_Poster];
    }
  if (rights & RightsDeleteAll)
    {
      [roles addObject: SOGoRole_ObjectEraser];
      [roles addObject: SOGoRole_FolderEraser];
      [roles addObject: SOGoMailRole_Expunger];
    }
  if (rights & RightsEditAll)
    [roles addObject: SOGoRole_ObjectEditor];
  if (rights & RightsReadItems)
    [roles addObject: SOGoRole_ObjectViewer];
  if (rights & RightsCreateSubfolders)
    [roles addObject: SOGoRole_FolderCreator];

  // [self logWithFormat: @"roles for rights %.8x = (%@)", rights, roles];

  return roles;
}

- (uint32_t) exchangeRightsForRoles: (NSArray *) roles
{
  uint32_t rights = 0;

  if ([roles containsObject: SOGoMailRole_Administrator])
    rights |= (RoleOwner ^ RightsAll);
  if ([roles containsObject: SOGoRole_ObjectCreator])
    rights |= RightsCreateItems;
  if ([roles containsObject: SOGoRole_ObjectEraser]
      && [roles containsObject: SOGoRole_FolderEraser])
    rights |= RightsDeleteAll;

  if ([roles containsObject: SOGoRole_ObjectEditor])
    rights |= RightsEditAll;
  if ([roles containsObject: SOGoRole_ObjectViewer])
    rights |= RightsReadItems;
  if ([roles containsObject: SOGoRole_FolderCreator])
    rights |= RightsCreateSubfolders;

  if (rights != 0)
    rights |= RoleNone; /* actually "folder visible" */

  // [self logWithFormat: @"rights for roles (%@) = %.8x", roles, rights];
 
  return rights;
}

- (enum mapistore_error) preloadMessageBodiesWithKeys: (NSArray *) keys
                                          ofTableType: (enum mapistore_table_type) tableType
{
  MAPIStoreMailMessage *message;
  NSMutableSet *bodyPartKeys;
  NSMutableDictionary *keyAssoc;
  NSDictionary *response;
  NSUInteger count, max;
  NSString *messageKey, *messageUid, *bodyPartKey;
  NGImap4Client *client;
  NSArray *fetch;
  NSData *bodyContent;

  if (tableType == MAPISTORE_MESSAGE_TABLE)
    {
      [bodyData removeAllObjects];
      max = [keys count];

      if (max > 0)
        {
          bodyPartKeys = [NSMutableSet setWithCapacity: max];

          keyAssoc = [NSMutableDictionary dictionaryWithCapacity: max];
          for (count = 0; count < max; count++)
            {
              messageKey = [keys objectAtIndex: count];
              message = [self lookupMessage: messageKey];
              if (message)
                {
                  bodyPartKey = [message bodyContentPartKey];
                  if (bodyPartKey)
                    {
                      [bodyPartKeys addObject: bodyPartKey];
                      messageUid = [self messageUIDFromMessageKey: messageKey];
                      [keyAssoc setObject: bodyPartKey forKey: messageUid];
                    }
                }
            }
      
          client = [[(SOGoMailFolder *) sogoObject imap4Connection] client];
          [client select: [sogoObject absoluteImap4Name]];
          response = [client fetchUids: [keyAssoc allKeys]
                             parts: [bodyPartKeys allObjects]];
          fetch = [response objectForKey: @"fetch"];
          max = [fetch count];
          for (count = 0; count < max; count++)
            {
              response = [fetch objectAtIndex: count];
              messageUid = [[response objectForKey: @"uid"] stringValue];
              bodyPartKey = [keyAssoc objectForKey: messageUid];
              if (bodyPartKey)
                {
                  bodyContent = [[response objectForKey: bodyPartKey]
                                  objectForKey: @"data"];
                  if (bodyContent)
                    {
                      messageKey = [NSString stringWithFormat: @"%@.eml",
                                             messageUid];
                      [bodyData setObject: bodyContent forKey: messageKey];
                    }
                }
            }
        }
    }

  return MAPISTORE_SUCCESS;
}

@end

@implementation MAPIStoreOutboxFolder

- (int) getPidTagDisplayName: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"Outbox" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

@end
