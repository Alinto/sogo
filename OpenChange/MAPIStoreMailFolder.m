/* MAPIStoreMailFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2013 Inverse inc
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
#import <NGImap4/NSString+Imap4.h>
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
#import "MAPIStoreMailFolderTable.h"
#import "MAPIStoreMailMessageTable.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreTypes.h"
#import "MAPIStoreUserContext.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "SOGoMAPIDBMessage.h"
#import <SOGo/SOGoCacheGCSFolder.h>

#import "MAPIStoreMailVolatileMessage.h"

#import "MAPIStoreMailFolder.h"

static Class SOGoMailFolderK, MAPIStoreMailFolderK, MAPIStoreOutboxFolderK;

#include <gen_ndr/exchange.h>

#undef DEBUG
#include <util/attr.h>
#include <libmapi/libmapi.h>
#include <libmapiproxy.h>
#include <limits.h>
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
  [versionsMessage setObjectType: MAPIInternalCacheObject];
  [versionsMessage reloadIfNeeded];
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

- (MAPIStoreFolderTable *) folderTable
{
  return [MAPIStoreMailFolderTable tableForContainer: self];
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
  rc = MAPISTORE_ERROR;

  folderName = nil;
  for (i = 0; !folderName && i < aRow->cValues; i++)
    {
      if (aRow->lpProps[i].ulPropTag == PR_DISPLAY_NAME_UNICODE)
        folderName = [NSString stringWithUTF8String: aRow->lpProps[i].value.lpszW];
      else if (aRow->lpProps[i].ulPropTag == PR_DISPLAY_NAME)
        folderName = [NSString stringWithUTF8String: (const char *) aRow->lpProps[i].value.lpszA];
    }

  if (folderName)
    {
      nameInContainer = [NSString stringWithFormat: @"folder%@",
                                  [[folderName stringByEncodingImap4FolderName] asCSSIdentifier]];

      [[self userContext] activate];

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

- (enum mapistore_error) deleteFolder
{
  enum mapistore_error rc;
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

- (enum mapistore_error) getPidTagContentUnreadCount: (void **) data
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

- (enum mapistore_error) getPidTagContainerClass: (void **) data
                                        inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"IPF.Note" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (EOQualifier *) simplifyQualifier: (EOQualifier *) qualifier
{
  /* Hack: Reduce the number of MODSEQ constraints to a single one as
     we assume the difference among MODSEQs will be small enough to
     return a small number of UIDs.

     This is the only case we do simplify:
     MODSEQ >= x | MODSEQ >= y | MODSEQ >= z => MODSEQ >= min(x,y,z)
  */
  if (qualifier && [qualifier isKindOfClass: [EOOrQualifier class]])
    {
      EOQualifier *simplifiedQualifier;
      NSArray  *quals;
      NSNumber *minModseq;
      NSUInteger i, count;

      quals = [(EOOrQualifier *)qualifier qualifiers];
      count = [quals count];
      if (count < 2)
        return qualifier;

      minModseq = [NSNumber numberWithUnsignedLongLong: ULLONG_MAX];

      for (i = 0; i < count; i++)
        {
          EOQualifier *subQualifier;

          subQualifier = [quals objectAtIndex: i];
          if ([subQualifier isKindOfClass: [EOAndQualifier class]]
              && [[(EOAndQualifier *)subQualifier qualifiers] count] == 1)
            subQualifier = [[(EOAndQualifier *)subQualifier qualifiers] objectAtIndex: 0];

          if ([subQualifier isKindOfClass: [EOKeyValueQualifier class]]
              && [[(EOKeyValueQualifier *)subQualifier key] isEqualToString: @"MODSEQ"])
            {
              NSNumber *value;

              value = (NSNumber *)[(EOKeyValueQualifier *)subQualifier value];
              if ([minModseq compare: value] == NSOrderedDescending
                  && [value unsignedLongLongValue] > 0)
                minModseq = (NSNumber *)[(EOKeyValueQualifier *)subQualifier value];

            }
          else
            return qualifier;
        }

      if ([minModseq unsignedLongLongValue] > 0 && [minModseq unsignedLongLongValue] < ULLONG_MAX)
        {
          simplifiedQualifier = [[EOKeyValueQualifier alloc]
                                       initWithKey: @"MODSEQ"
                                  operatorSelector: EOQualifierOperatorGreaterThanOrEqualTo
                                             value: minModseq];
          [simplifiedQualifier autorelease];
          return simplifiedQualifier;
        }
    }

  return qualifier;
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
  EOQualifier *fetchQualifier, *simplifiedQualifier;

  if ([self ensureFolderExists])
    {
      if (!sortOrderings)
        sortOrderings = [NSArray arrayWithObject: @"ARRIVAL"];

      if (qualifier)
        {
          simplifiedQualifier = [self simplifyQualifier: qualifier];
          fetchQualifier
            = [[EOAndQualifier alloc] initWithQualifiers:
                                        [self nonDeletedQualifier], simplifiedQualifier,
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
  strippedName = [[subfolderName substringFromIndex: 6] stringByDecodingImap4FolderName];
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
  NSArray *filteredSubfolderKeys;
  NSMutableArray *subfolderKeys;
  NSMutableArray *subfolderKeysQualifying;
  NSString *subfolderKey;
  NSUInteger count, max;

  if ([self ensureFolderExists])
    {
      /* Only folder name can be used as qualifier key */
      if (qualifier)
        [self warnWithFormat: @"qualifier is only used for folders with name"];
      if (sortOrderings)
        [self errorWithFormat: @"sort orderings are not used for folders"];

      /* FIXME: Flush any cache before retrieving the hierarchy, this
         slows things down but it is safer */
      if (!qualifier)
        [sogoObject flushMailCaches];

      subfolderKeys = [[sogoObject toManyRelationshipKeys] mutableCopy];
      [subfolderKeys autorelease];

      [self _cleanupSubfolderKeys: subfolderKeys];

      if (qualifier)
        {
          subfolderKeysQualifying = [NSMutableArray array];
          max = [subfolderKeys count];
          for (count = 0; count < max; count++) {
            subfolderKey = [subfolderKeys objectAtIndex: count];
            /* Remove "folder" prefix */
            subfolderKey = [subfolderKey substringFromIndex: 6];
            subfolderKey = [[subfolderKey fromCSSIdentifier] stringByDecodingImap4FolderName];
            [subfolderKeysQualifying addObject: [NSDictionary dictionaryWithObject: subfolderKey
                                                                            forKey: @"name"]];
          }
          filteredSubfolderKeys = [subfolderKeysQualifying filteredArrayUsingQualifier: qualifier];

          max = [filteredSubfolderKeys count];
          subfolderKeys = [NSMutableArray arrayWithCapacity: max];
          for (count = 0; count < max; count++)
            {
              subfolderKey = [[filteredSubfolderKeys objectAtIndex: count] valueForKey: @"name"];
              subfolderKey = [NSString stringWithFormat: @"folder%@", [[subfolderKey stringByEncodingImap4FolderName] asCSSIdentifier]];
              [subfolderKeys addObject: subfolderKey];
            }

        }
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

  //[self logWithFormat: @"lastMessageModificationTime: %@", value];

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

- (void) _updatePredecessorChangeListWith: (NSData *) predecessorChangeList
                          forMessageEntry: (NSMutableDictionary *) messageEntry
{
  NSData *globCnt, *oldGlobCnt;
  NSMutableDictionary *changeList;
  NSString *guid;
  struct SizedXid *sizedXIDList;
  struct XID xid;
  uint32_t i, length;

  sizedXIDList = [predecessorChangeList asSizedXidArrayInMemCtx: NULL with: &length];

  changeList = [messageEntry objectForKey: @"PredecessorChangeList"];
  if (!changeList)
    {
      changeList = [NSMutableDictionary new];
      [messageEntry setObject: changeList
                    forKey: @"PredecessorChangeList"];
      [changeList release];
    }

  if (sizedXIDList) {
    for (i = 0; i < length; i++)
      {
        xid = sizedXIDList[i].XID;
        guid = [NSString stringWithGUID: &xid.NameSpaceGuid];
        globCnt = [NSData dataWithBytes: xid.LocalId.data length: xid.LocalId.length];
        oldGlobCnt = [changeList objectForKey: guid];
        if (!oldGlobCnt || ([globCnt compare: oldGlobCnt] == NSOrderedDescending))
          [changeList setObject: globCnt forKey: guid];
      }

    talloc_free (sizedXIDList);
  }

  [versionsMessage save];
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
  guid = [NSString stringWithGUID: &xid->NameSpaceGuid];
  globCnt = [NSData dataWithBytes: xid->LocalId.data length: xid->LocalId.length];
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
  NSNumber *ti, *modseq, *lastModseq, *nextModseq;
  NSString *changeNumber, *uid, *messageKey;
  uint64_t lastModseqNbr;
  EOQualifier *searchQualifier;
  NSArray *uids, *changeNumbers;
  NSUInteger count, max, nFetched;
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
  if (lastModseq)
    {
      lastModseqNbr = [lastModseq unsignedLongLongValue];
      nextModseq = [NSNumber numberWithUnsignedLongLong: lastModseqNbr + 1];
      searchQualifier = [[EOKeyValueQualifier alloc]
                                initWithKey: @"modseq"
                           operatorSelector: EOQualifierOperatorGreaterThanOrEqualTo
                                      value: nextModseq];

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
                                            parts: [NSArray arrayWithObjects: @"modseq", @"flags", nil]]
                          objectForKey: @"fetch"];

      /* NOTE: we sort items manually because Cyrus does not properly sort
         entries with a MODSEQ of 0 */
      fetchResults
        = [fetchResults sortedArrayUsingFunction: _compareFetchResultsByMODSEQ
                                         context: NULL];

      nFetched = [fetchResults count];
      if (nFetched != max) {
        [self errorWithFormat: @"Error fetching UIDs. Asked: %d Received: %d."
              @"Check the IMAP conversation for details", max, nFetched];
        return NO;
      }

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

          //[self logWithFormat: @"added message entry for uid %@, modseq %@,"
          //      @" version %@", uid, modseq, changeNumber];

          changeKey = [self getReplicaKeyFromGlobCnt: newChangeNum >> 16];
          [self _setChangeKey: changeKey forMessageEntry: messageEntry];

          [mapping setObject: modseq forKey: changeNumber];

          if (!lastModseq
              || ([lastModseq compare: modseq] == NSOrderedAscending))
            lastModseq = modseq;

          if ([[result objectForKey: @"flags"] containsObject: @"deleted"])
            [currentProperties setObject: changeNumber
                                  forKey: @"SyncLastDeleteChangeNumber"];
        }

      [currentProperties setObject: lastModseq forKey: @"SyncLastModseq"];
      foundChange = YES;
    }

  /* 2. we synchronise expunged UIDs */
  fetchResults = [(SOGoMailFolder *) sogoObject
                     fetchUIDsOfVanishedItems: lastModseqNbr];

  max = [fetchResults count];

  changeNumber = nil;
  for (count = 0; count < max; count++)
    {
      uid = [[fetchResults objectAtIndex: count] stringValue];
      if ([messages objectForKey: uid])
        {
          if (!changeNumber)
            {
              newChangeNum = [[self context] getNewChangeNumber];
              changeNumber = [NSString stringWithUnsignedLongLong: newChangeNum];
            }
          [messages removeObjectForKey: uid];
          [self logWithFormat: @"Removed message entry for UID %@", uid];
        }
      else
        {
          [self logWithFormat:@"Message entry not found for UID %@", uid];
        }
    }
  if (changeNumber)
    {
      [currentProperties setObject: changeNumber
                            forKey: @"SyncLastDeleteChangeNumber"];
      [mapping setObject: lastModseq forKey: changeNumber];
      foundChange = YES;
    }

  if (foundChange)
    {
      [self synchronizeUpdatedFolder: lastModseq
                         withMapping: mapping];

      ti = [NSNumber numberWithDouble: [now timeIntervalSince1970]];
      [currentProperties setObject: ti
                            forKey: @"SyncLastSynchronisationDate"];
      [versionsMessage save];
    }


  return rc;
}

- (void) synchronizeUpdatedFolder: (NSNumber *) lastModseq
                      withMapping: (NSMutableDictionary *) mapping
{
  /* This method should be called whenever something has changed on the folder.
     Then we will perform two actions:
         1 - Update the PidTagChangeNumber property of the root container.
         2 - Store relationship PidTagChangenumber with lastModseq value on the
             mapping given as parameter for this folder */
  uint64_t *current_cn;
  struct SRow row;
  struct SPropValue prop;
  uint64_t fid;
  const char *username;
  struct openchangedb_context *oc_ctx;
  enum MAPISTATUS retval;
  TALLOC_CTX *local_mem_ctx = NULL;

  row.cValues = 1;
  prop.ulPropTag = PidTagChangeNumber;
  prop.value.d = 0; // It doesn't matter, it will be autogenerated
  row.lpProps = &prop;

  /* We are doing a "touch" operation to update change number of the root container.
     We get the root container as it has the properties in the OpenChange DB */
  username = [[self context] connectionInfo]->username;
  oc_ctx = [[self context] connectionInfo]->oc_ctx;
  fid = [[self rootContainer] objectId];
  retval = openchangedb_set_folder_properties(oc_ctx, username, fid, &row);
  if (retval != MAPI_E_SUCCESS)
    {
      [self errorWithFormat:@"%s: Error setting change number on %"PRIu64,
            __PRETTY_FUNCTION__, fid];
      return;
    }

  local_mem_ctx = talloc_named(NULL, 0, __PRETTY_FUNCTION__);
  if (local_mem_ctx == NULL)
    {
      [self errorWithFormat:@"%s: Error with talloc_named, out of memory?",
            __PRETTY_FUNCTION__];
      return;
    }
  retval = openchangedb_get_folder_property(local_mem_ctx, oc_ctx, username,
                                            PidTagChangeNumber, fid,
                                            (void **) &current_cn);
  if (retval != MAPI_E_SUCCESS)
    {
      [self errorWithFormat:@"%s: Error getting change number on %"PRIu64,
            __PRETTY_FUNCTION__, fid];
      talloc_free(local_mem_ctx);
      return;
    }

  [mapping setObject: lastModseq
              forKey: [NSString stringWithUnsignedLongLong: *current_cn]];
  talloc_free(local_mem_ctx);
}

- (BOOL) synchroniseCacheForUID: (NSString *) messageUID
{
  /* Try to synchronise old UIDs in versions.plist cache using an
     specific UID. It returns a boolean indicating if the
     synchronisation were done.

     It should be used as last resort, keeping synchroniseCache to main
     sync entry point.
  */
  NSMutableDictionary *currentProperties, *messages, *messageEntry, *mapping;
  NSArray *fetchResults;
  uint64_t changeNumber;
  NSDictionary *result;
  NSNumber *modseq;
  NSString *changeNumberStr;
  NSData *changeKey;

  [versionsMessage reloadIfNeeded];
  currentProperties = [versionsMessage properties];
  messages = [currentProperties objectForKey: @"Messages"];
  messageEntry = [messages objectForKey: messageUID];
  if (!messageEntry)
    {
      fetchResults = [(NSDictionary *) [sogoObject fetchUIDs: [NSArray arrayWithObject: messageUID]
                                                       parts: [NSArray arrayWithObjects: @"modseq", @"flags", nil]]
                         objectForKey: @"fetch"];
      if ([fetchResults count] == 1)
        {
          result = [fetchResults objectAtIndex: 0];
          modseq = [result objectForKey: @"modseq"];
          changeNumber = [[self context] getNewChangeNumber];
          changeNumberStr = [NSString stringWithUnsignedLongLong: changeNumber];

          /* Create new message entry in Messages dict */
          messageEntry = [NSMutableDictionary new];
          [messages setObject: messageEntry forKey: messageUID];
          [messageEntry release];

          /* Store the modseq and change number */
          [messageEntry setObject: modseq forKey: @"modseq"];
          [messageEntry setObject: changeNumberStr forKey: @"version"];

          /* Store the change key */
          changeKey = [self getReplicaKeyFromGlobCnt: changeNumber >> 16];
          [self _setChangeKey: changeKey forMessageEntry: messageEntry];

          /* Store the changeNumber -> modseq mapping */
          mapping = [currentProperties objectForKey: @"VersionMapping"];
          [mapping setObject: modseq forKey: changeNumberStr];

          /* Store the last deleted change number if it is soft-deleted */
          if ([[result objectForKey: @"flags"] containsObject: @"deleted"])
            [currentProperties setObject: changeNumberStr
                                  forKey: @"SyncLastDeleteChangeNumber"];

          /* Save the message */
          [versionsMessage save];
          return YES;
        }
      else
        {
          return NO;
        }
    }
  /* If message entry exists, then synchroniseCache did its job */
  return YES;
}


- (NSNumber *) modseqFromMessageChangeNumber: (NSString *) changeNum
{
  NSDictionary *mapping;
  NSNumber *modseq;
  NSEnumerator *enumerator;
  id key;
  uint64_t found, target, current, replica_id, current_cn;
  NSString *closestChangeNum;

  mapping = [[versionsMessage properties] objectForKey: @"VersionMapping"];
  modseq = [mapping objectForKey: changeNum];
  if (modseq) return modseq;

  // Not found from stored change numbers for this folder.
  // Get the closest modseq for the change number given.
  // O(n) cost but will be unusual behaviour.
  target = exchange_globcnt([changeNum unsignedLongLongValue] >> 16);
  replica_id = [changeNum unsignedLongLongValue] & 0xFFFF;
  found = 0;
  enumerator  = [mapping keyEnumerator];
  while ((key = [enumerator nextObject]))
    {
      current_cn = [(NSString *)key unsignedLongLongValue];
      if ((current_cn & 0xFFFF) != replica_id)
        continue;
      current = exchange_globcnt(current_cn >> 16);
      if (current < target && current > found)
        found = current;
    }

  if (found)
    {
      closestChangeNum = [NSString stringWithUnsignedLongLong:
                                   (exchange_globcnt(found) << 16 | replica_id)];
      modseq = [mapping objectForKey: closestChangeNum];
    }

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
    {
      messageUid = nil;
      [self errorWithFormat:@"%s: Unexpected messageKey value [%@]",
            __PRETTY_FUNCTION__, messageKey];
    }

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

- (NSMutableDictionary *) _messageEntryFromMessageKey: (NSString *) messageKey
{
  NSMutableDictionary *messages, *messageEntry;
  NSString *messageUid;
  BOOL synced;

  messageUid = [self messageUIDFromMessageKey: messageKey];
  messages = [[versionsMessage properties] objectForKey: @"Messages"];
  messageEntry = [messages objectForKey: messageUid];
  if (!messageEntry)
    {
      [self warnWithFormat: @"attempting to synchronise to get the message entry for "
                            @"this message %@", messageKey];
      synced = [self synchroniseCacheForUID: messageUid];
      if (synced)
        messageEntry = [[[versionsMessage properties] objectForKey: @"Messages"] objectForKey: messageUid];
      if (!messageEntry)
        {
          [self errorWithFormat: @"still nothing. We crash!"];
          abort ();
        }
    }

  return messageEntry;
}

- (void) setChangeKey: (NSData *) changeKey
    forMessageWithKey: (NSString *) messageKey
{
  [self _setChangeKey: changeKey
      forMessageEntry: [self _messageEntryFromMessageKey: messageKey]];

  [versionsMessage save];
}

- (BOOL) updatePredecessorChangeListWith: (NSData *) changeKey
                       forMessageWithKey: (NSString *) messageKey
{
  /* Update predecessor change list property given the change key. It
     returns if the change key has been added to the list or not */
  BOOL added = NO;
  NSData *globCnt, *oldGlobCnt;
  NSDictionary *messageEntry;
  NSMutableDictionary *changeList;
  NSString *guid;
  struct XID *xid;

  xid = [changeKey asXIDInMemCtx: NULL];
  guid = [NSString stringWithGUID: &xid->NameSpaceGuid];
  globCnt = [NSData dataWithBytes: xid->LocalId.data length: xid->LocalId.length];
  talloc_free (xid);

  messageEntry = [self _messageEntryFromMessageKey: messageKey];
  if (messageEntry)
    {
      changeList = [messageEntry objectForKey: @"PredecessorChangeList"];
      if (changeList)
        {
          oldGlobCnt = [changeList objectForKey: guid];
          if (!oldGlobCnt || ([globCnt compare: oldGlobCnt] == NSOrderedDescending))
            {
              [changeList setObject: globCnt forKey: guid];
              [versionsMessage save];
              added = YES;
            }
        }
      else
        [self errorWithFormat: @"Missing predecessor change list to update"];
    }

  return added;
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

/* Management for extra properties once they already hit the IMAP server */
- (void) setExtraProperties: (NSDictionary *) props
                 forMessage: (NSString *) messageKey
{
  NSMutableDictionary *extraProps, *currentProperties;
  NSString *messageUid;

  messageUid = [self messageUIDFromMessageKey: messageKey];
  currentProperties = [versionsMessage properties];
  extraProps = [currentProperties objectForKey: @"ExtraMessagesProperties"];
  if (!extraProps)
    {
      extraProps = [NSMutableDictionary new];
      [currentProperties setObject: extraProps forKey: @"ExtraMessagesProperties"];
      [extraProps release];
    }

  [extraProps setObject: props
                 forKey: messageUid];
  [versionsMessage save];
}

- (NSDictionary *) extraPropertiesForMessage: (NSString *) messageKey
{
  NSString *messageUid;

  messageUid = [self messageUIDFromMessageKey: messageKey];
  return [[[versionsMessage properties] objectForKey: @"ExtraMessagesProperties"]
                   objectForKey: messageUid];
}

- (NSArray *) getDeletedKeysFromChangeNumber: (uint64_t) changeNum
                                       andCN: (NSNumber **) cnNbr
                                 inTableType: (uint8_t) tableType
{
  NSArray *deletedKeys, *deletedUIDs;
  NSString *changeNumber;
  uint64_t modseq;
  NSDictionary *versionProperties;
  EOQualifier *deletedQualifier, *kvQualifier, *searchQualifier;

  if (tableType == MAPISTORE_MESSAGE_TABLE)
    {
      changeNumber = [NSString stringWithFormat: @"0x%.16llx", changeNum];
      modseq = [[self modseqFromMessageChangeNumber: changeNumber]
                 unsignedLongLongValue];
      if (modseq > 0)
        {
          /* Hard deleted items */
          deletedUIDs = [(SOGoMailFolder *) sogoObject
                           fetchUIDsOfVanishedItems: modseq];

          /* Soft deleted items */
          kvQualifier = [[EOKeyValueQualifier alloc]
                                initWithKey: @"modseq"
                           operatorSelector: EOQualifierOperatorGreaterThanOrEqualTo
                                      value: [NSNumber numberWithUnsignedLongLong: modseq]];
          deletedQualifier
            = [[EOKeyValueQualifier alloc]
                 initWithKey: @"FLAGS"
                operatorSelector: EOQualifierOperatorContains
                       value: [NSArray arrayWithObject: @"Deleted"]];

          searchQualifier = [[EOAndQualifier alloc]
                              initWithQualifiers:
                                kvQualifier, deletedQualifier, nil];

          deletedUIDs = [deletedUIDs arrayByAddingObjectsFromArray:
                                       [sogoObject fetchUIDsMatchingQualifier: searchQualifier
                                                                 sortOrdering: nil]];

          [deletedQualifier release];
          [kvQualifier release];
          [searchQualifier release];

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

  rangeMin = 0;
  currentUid = 0;
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
- (enum mapistore_error) moveCopyMessagesWithMIDs: (uint64_t *) srcMids
                                         andCount: (uint32_t) midCount
                                       fromFolder: (MAPIStoreFolder *) sourceFolder
                                         withMIDs: (uint64_t *) targetMids
                                    andChangeKeys: (struct Binary_r **) targetChangeKeys
                        andPredecessorChangeLists: (struct Binary_r **) targetPredecessorChangeLists
                                         wantCopy: (uint8_t) wantCopy
                                         inMemCtx: (TALLOC_CTX *) memCtx
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
  NSData *changeList;

  if (![sourceFolder isKindOfClass: [MAPIStoreMailFolder class]])
    return [super moveCopyMessagesWithMIDs: srcMids andCount: midCount
                                fromFolder: sourceFolder withMIDs: targetMids
                             andChangeKeys: targetChangeKeys
                 andPredecessorChangeLists: targetPredecessorChangeLists
                                  wantCopy: wantCopy
                                  inMemCtx: memCtx];

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

  /* "Move" treatment: Store \Deleted and unregister urls as soft-deleted */
  if (!wantCopy)
    {
      [client storeFlags: [NSArray arrayWithObject: @"Deleted"] forUIDs: uids
             addOrRemove: YES];
      for (count = 0; count < midCount; count++)
        {
          /* Using soft-deleted to make deleted fmids to return the
             srcMids.
             See [MAPIStoreFolder getDeletedFMIDs:andCN:fromChangeNumber:inTableType:inMemCtx]
             for details */
          [mapping unregisterURLWithID: srcMids[count]
                              andFlags: MAPISTORE_SOFT_DELETE];
        }
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
          changeList = [NSData dataWithBinary: targetPredecessorChangeLists[count]];
          messageKey = [NSString stringWithFormat: @"%@.eml",
                                 [destUIDs objectAtIndex: count]];
          [self _updatePredecessorChangeListWith: changeList
                                 forMessageEntry: [self _messageEntryFromMessageKey: messageKey]];
        }
    }

  // We cleanup cache of our source and destination folders
  [self cleanupCaches];
  [sourceFolder cleanupCaches];

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) moveCopyToFolder: (MAPIStoreFolder *) targetFolder
                              withNewName: (NSString *) newFolderName
                                   isMove: (BOOL) isMove
                              isRecursive: (BOOL) isRecursive
                                 inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc;
  NSURL *folderURL, *newFolderURL;
  struct SRow folderRow;
  struct SPropValue nameProperty;
  MAPIStoreMailFolder *newFolder;
  SOGoMailAccount *accountFolder;
  SOGoMailFolder *targetSOGoFolder;
  NSMutableArray *uids;
  NSArray *childKeys;
  NSUInteger count, max;
  NGImap4Connection *connection;
  NGImap4Client *client;
  NSString *newURL, *parentDBFolderPath, *childKey, *folderIMAPName,
    *urlNamePart, *newFolderIMAPName, *newFolderDBName;
  NSException *error;
  MAPIStoreMapping *mapping;
  NSDictionary *result;

  if ([targetFolder isKindOfClass: MAPIStoreMailFolderK] || (!targetFolder && isMove))
    {
      folderURL = [sogoObject imap4URL];
      if (!newFolderName)
        newFolderName = [sogoObject displayName];
      targetSOGoFolder = [targetFolder sogoObject];
      if (isMove)
        {
          newFolderDBName = [[newFolderName stringByEncodingImap4FolderName] asCSSIdentifier];
          if (targetSOGoFolder)
            {
              /* Mimetise [SOGoMailFolderK imap4URLString] */
              urlNamePart = [[newFolderName stringByEncodingImap4FolderName] stringByEscapingURL];
              newFolderURL = [NSURL URLWithString: urlNamePart
                                    relativeToURL: [targetSOGoFolder imap4URL]];
            }
          else
            {
              /* Mimetise what createRootSecondaryFolderWithFID does */
              accountFolder = [[[self userContext] rootFolders] objectForKey: @"mail"];
              targetSOGoFolder = [SOGoMailFolder objectWithName: [NSString stringWithFormat: @"folder%@",
                                                                           newFolderDBName]
                                                    inContainer: accountFolder];
              newFolderURL = [targetSOGoFolder imap4URL];
            }
          error = [[sogoObject imap4Connection]
                      moveMailboxAtURL: folderURL
                                 toURL: newFolderURL];
          if (error)
            rc = MAPISTORE_ERR_DENIED;
          else
            {
              rc = MAPISTORE_SUCCESS;
              mapping = [self mapping];
              if (targetFolder)
                newURL = [NSString stringWithFormat: @"%@folder%@/",
                                   [targetFolder url], newFolderDBName];
              else
                newURL = [NSString stringWithFormat: @"sogo://%@:%@@mail/folder%@/",
                                   [[self userContext] username], [[self userContext] username],
                                   newFolderDBName];
              [mapping updateID: [self objectId] withURL: newURL];
              if (targetFolder)
                {
                  parentDBFolderPath = [[targetFolder dbFolder] path];
                  if (!parentDBFolderPath)
                    parentDBFolderPath = @"";
                  [dbFolder changePathTo: [NSString stringWithFormat:
                                                      @"%@/folder%@",
                                                    parentDBFolderPath,
                                                    newFolderDBName]
                        intoNewContainer: [targetFolder dbFolder]];
                }
              else
                [dbFolder changePathTo: [NSString stringWithFormat:
                                                    @"/mail/folder%@", newFolderDBName]
                      intoNewContainer: nil];
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
                                   isRecursive: YES
                                      inMemCtx: memCtx];
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
                     isRecursive: isRecursive
                        inMemCtx: memCtx];

  return rc;
}

- (MAPIStoreMessage *) createMessage
{
  SOGoCacheObject *childObject;

  [[[self context] userContext] activate];

  childObject = [SOGoCacheObject objectWithName: [SOGoCacheObject globallyUniqueObjectId]
                                    inContainer: sogoObject];
  return [MAPIStoreMailVolatileMessage
           mapiStoreObjectWithSOGoObject: childObject
                             inContainer: self];
}

- (id) lookupMessage: (NSString *) messageKey
{
  MAPIStoreMailMessage *message;
  NSArray *rawBodyData;

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
    rights |= RightsDeleteAll | RightsDeleteOwn;

  if ([roles containsObject: SOGoRole_ObjectEditor])
    rights |= RightsEditAll | RightsEditOwn;
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
  NSEnumerator *enumerator;
  NSUInteger max;
  NSString *messageKey;
  MAPIStoreMailMessage *message;
  NSArray* bodyContent;

  if (tableType != MAPISTORE_MESSAGE_TABLE)
    return MAPISTORE_SUCCESS;

  [bodyData removeAllObjects];

  max = [keys count];
  if (max == 0)
    return MAPISTORE_SUCCESS;

  enumerator = [keys objectEnumerator];
  while ((messageKey = [enumerator nextObject]))
    {
      message = [self lookupMessage: messageKey];
      if (message)
        {
          bodyContent = [message getBodyContent];
          if (bodyContent)
            {
              [bodyData setObject: bodyContent forKey: messageKey];
            }
        }
    }

  return MAPISTORE_SUCCESS;
}

@end

@implementation MAPIStoreOutboxFolder

- (enum mapistore_error) getPidTagDisplayName: (void **) data
                                     inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"Outbox" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

@end
