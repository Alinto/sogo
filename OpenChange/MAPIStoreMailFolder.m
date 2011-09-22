/* MAPIStoreMailFolder.m - this file is part of SOGo
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

#include <talloc.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <EOControl/EOQualifier.h>
#import <EOControl/EOSortOrdering.h>
#import <NGExtensions/NSObject+Logs.h>
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

#import "MAPIApplication.h"
#import "MAPIStoreAppointmentWrapper.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreDraftsMessage.h"
#import "MAPIStoreFAIMessage.h"
#import "MAPIStoreMailMessage.h"
#import "MAPIStoreMailMessageTable.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "SOGoMAPIFSMessage.h"

#import "MAPIStoreMailFolder.h"

static Class MAPIStoreDraftsMessageK;
static Class MAPIStoreMailMessageK;
static Class SOGoMailFolderK;

#undef DEBUG
#include <libmapi/libmapi.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreMailFolder

+ (void) initialize
{
  MAPIStoreMailMessageK = [MAPIStoreMailMessage class];
  SOGoMailFolderK = [SOGoMailFolder class];
  [MAPIStoreAppointmentWrapper class];
}

- (id) initWithURL: (NSURL *) newURL
         inContext: (MAPIStoreContext *) newContext
{
  SOGoUserFolder *userFolder;
  SOGoMailAccounts *accountsFolder;
  SOGoMailAccount *accountFolder;
  SOGoFolder *currentContainer;
  WOContext *woContext;

  if ((self = [super initWithURL: newURL
                       inContext: newContext]))
    {
      woContext = [newContext woContext];
      userFolder = [SOGoUserFolder objectWithName: [newURL user]
                                      inContainer: MAPIApp];
      [parentContainersBag addObject: userFolder];
      [woContext setClientObject: userFolder];

      accountsFolder = [userFolder lookupName: @"Mail"
                                    inContext: woContext
                                      acquire: NO];
      [parentContainersBag addObject: accountsFolder];
      [woContext setClientObject: accountsFolder];
      
      accountFolder = [accountsFolder lookupName: @"0"
                                       inContext: woContext
                                         acquire: NO];
      [[accountFolder imap4Connection]
        enableExtension: @"QRESYNC"];

      [parentContainersBag addObject: accountFolder];
      [woContext setClientObject: accountFolder];

      sogoObject = [self specialFolderFromAccount: accountFolder
                                        inContext: woContext];
      [sogoObject retain];
      currentContainer = [sogoObject container];
      while (currentContainer != (SOGoFolder *) accountFolder)
        {
          [parentContainersBag addObject: currentContainer];
          currentContainer = [currentContainer container];
        }

      ASSIGN (versionsMessage,
              [SOGoMAPIFSMessage objectWithName: @"versions.plist"
                                    inContainer: propsFolder]);
    }

  return self;
}

- (id) initWithSOGoObject: (id) newSOGoObject
              inContainer: (MAPIStoreObject *) newContainer
{
  NSURL *propsURL;
  NSString *urlString;

  if ((self = [super initWithSOGoObject: newSOGoObject inContainer: newContainer]))
    {
      urlString = [[self url] stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
      propsURL = [NSURL URLWithString: urlString];
      ASSIGN (versionsMessage,
              [SOGoMAPIFSMessage objectWithName: @"versions.plist"
                                 inContainer: propsFolder]);
    }

  return self;
}

- (void) dealloc
{
  [versionsMessage release];
  [super dealloc];
}

- (SOGoMailFolder *) specialFolderFromAccount: (SOGoMailAccount *) accountFolder
                                    inContext: (WOContext *) woContext
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (MAPIStoreMessageTable *) messageTable
{
  [self synchroniseCache];
  return [MAPIStoreMailMessageTable tableForContainer: self];
}

- (Class) messageClass
{
  return MAPIStoreMailMessageK;
}

- (NSString *) createFolder: (struct SRow *) aRow
                    withFID: (uint64_t) newFID
                inContainer: (id) subfolderParent
{
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
                                      inContainer: subfolderParent];
      if (![newFolder create])
        nameInContainer = nil;
    }

  return nameInContainer;
}

- (NSString *) createFolder: (struct SRow *) aRow
                    withFID: (uint64_t) newFID
{
  return [self createFolder: aRow withFID: newFID
                inContainer: sogoObject];
}

- (int) getPrContentUnread: (void **) data
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

- (int) getPrContainerClass: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"IPF.Note" asUnicodeInMemCtx: memCtx];
  
  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageClass: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"IPM.Note" asUnicodeInMemCtx: memCtx];
  
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

  uidKeys = [sogoObject fetchUIDsMatchingQualifier: fetchQualifier
                                      sortOrdering: sortOrderings];
  return [uidKeys stringsWithFormat: @"%@.eml"];
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

  if (qualifier)
    [self errorWithFormat: @"qualifier is not used for folders"];
  if (sortOrderings)
    [self errorWithFormat: @"sort orderings are not used for folders"];

  subfolderKeys = [[sogoObject toManyRelationshipKeys] mutableCopy];
  [subfolderKeys autorelease];

  [self _cleanupSubfolderKeys: subfolderKeys];

  return subfolderKeys;
}

- (id) lookupFolder: (NSString *) childKey
{
  id childObject = nil;
  SOGoMailFolder *childFolder;

  [self folderKeys];
  if ([folderKeys containsObject: childKey])
    {
      childFolder = [sogoObject lookupName: childKey inContext: nil
                                   acquire: NO];
      childObject = [MAPIStoreMailFolder mapiStoreObjectWithSOGoObject: childFolder
                                                           inContainer: self];
    }

  return childObject;
}

- (NSCalendarDate *) creationTime
{
  return [NSCalendarDate dateWithTimeIntervalSince1970: 0x4dbb2dbe]; /* oc_version_time */
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
    zeroNumber = [NSNumber numberWithUnsignedLongLong: 0];

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
  NSNumber *ti, *changeNumber, *modseq, *lastModseq, *nextModseq, *uid;
  EOQualifier *searchQualifier;
  NSArray *uids;
  NSUInteger count, max;
  NSArray *fetchResults;
  NSDictionary *result;
  NSData *changeKey;
  NSMutableDictionary *currentProperties, *messages, *mapping, *messageEntry;
  NSCalendarDate *now;

  now = [NSCalendarDate date];
  [now setTimeZone: utcTZ];

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

  lastModseq = [currentProperties objectForKey: @"SyncLastModseq"];
  if (lastModseq)
    {
      nextModseq = [NSNumber numberWithUnsignedLongLong:
                               [lastModseq unsignedLongLongValue] + 1];
      searchQualifier = [[EOKeyValueQualifier alloc]
                                initWithKey: @"modseq"
                           operatorSelector: EOQualifierOperatorGreaterThanOrEqualTo
                                      value: nextModseq];
      [searchQualifier autorelease];
    }
  else
    searchQualifier = [self nonDeletedQualifier];

  uids = [sogoObject fetchUIDsMatchingQualifier: searchQualifier
                                   sortOrdering: nil];
  max = [uids count];
  if (max > 0)
    {
      fetchResults
        = [(NSDictionary *) [sogoObject fetchUIDs: uids
                                            parts: [NSArray arrayWithObject: @"modseq"]]
                          objectForKey: @"fetch"];

      /* NOTE: we sort items manually because Cyrus does not properly sort
         entries with a MODSEQ of 0 */
      fetchResults
        = [fetchResults sortedArrayUsingFunction: _compareFetchResultsByMODSEQ
                                         context: NULL];
      
      ldb_transaction_start([[self context] connectionInfo]->oc_ctx);

      for (count = 0; count < max; count++)
        {
          result = [fetchResults objectAtIndex: count];
          uid = [result objectForKey: @"uid"];
          modseq = [result objectForKey: @"modseq"];
          [self logWithFormat: @"uid '%@' has modseq '%@'", uid, modseq];
          newChangeNum = [[self context] getNewChangeNumber];
          changeNumber = [NSNumber numberWithUnsignedLongLong: newChangeNum];

          messageEntry = [NSMutableDictionary new];
          [messages setObject: messageEntry forKey: uid];
          [messageEntry release];

          [messageEntry setObject: modseq forKey: @"modseq"];
          [messageEntry setObject: changeNumber forKey: @"version"];

          changeKey = [self getReplicaKeyFromGlobCnt: newChangeNum >> 16];
          [self _setChangeKey: changeKey forMessageEntry: messageEntry];

          [mapping setObject: modseq forKey: changeNumber];

          if (!lastModseq
              || ([lastModseq compare: modseq] == NSOrderedAscending))
            lastModseq = modseq;
        }

      ldb_transaction_commit([[self context] connectionInfo]->oc_ctx);
      
      ti = [NSNumber numberWithDouble: [now timeIntervalSince1970]];
      [currentProperties setObject: ti
                            forKey: @"SyncLastSynchronisationDate"];
      [currentProperties setObject: lastModseq forKey: @"SyncLastModseq"];
      [versionsMessage appendProperties: currentProperties];
      [versionsMessage save];
    }

  return rc;
}
 
- (NSNumber *) modseqFromMessageChangeNumber: (NSNumber *) changeNum
{
  NSDictionary *mapping;
  NSNumber *modseq;

  mapping = [[versionsMessage properties] objectForKey: @"VersionMapping"];
  modseq = [mapping objectForKey: changeNum];

  return modseq;
}

- (NSNumber *) messageUIDFromMessageKey: (NSString *) messageKey
{
  NSNumber *messageUid;
  NSString *uidString;
  NSRange dotRange;

  dotRange = [messageKey rangeOfString: @".eml"];
  if (dotRange.location != NSNotFound)
    {
      uidString = [messageKey substringToIndex: dotRange.location];
      messageUid = [NSNumber numberWithInt: [uidString intValue]];
    }
  else
    messageUid = nil;

  return messageUid;
}

- (NSNumber *) changeNumberForMessageUID: (NSNumber *) messageUid
{
  NSDictionary *messages;
  NSNumber *changeNumber;

  messages = [[versionsMessage properties] objectForKey: @"Messages"];
  changeNumber = [[messages objectForKey: messageUid]
                   objectForKey: @"version"];

  return changeNumber;
}

- (void) setChangeKey: (NSData *) changeKey
    forMessageWithKey: (NSString *) messageKey
{
  NSMutableDictionary *messages;
  NSMutableDictionary *messageEntry;
  NSNumber *messageUid;

  messageUid = [self messageUIDFromMessageKey: messageKey];
  messages = [[versionsMessage properties] objectForKey: @"Messages"];
  messageEntry = [messages objectForKey: messageUid];
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
  NSNumber *messageUid;
  NSData *globCnt, *changeKey = nil;

  messageUid = [self messageUIDFromMessageKey: messageKey];
  messages = [[versionsMessage properties] objectForKey: @"Messages"];
  changeKeyDict = [[messages objectForKey: messageUid]
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
  NSNumber *messageUid;
  NSData *globCnt;

  messageUid = [self messageUIDFromMessageKey: messageKey];
  messages = [[versionsMessage properties] objectForKey: @"Messages"];
  changeListDict = [[messages objectForKey: messageUid]
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
  NSArray *deletedKeys, *deletedUIDs;
  NSNumber *changeNumNbr;
  uint64_t modseq;
  NSDictionary *versionProperties, *status;
  NSMutableDictionary *messages, *mapping;
  NSNumber *newChangeNumNbr, *highestModseq;
  uint64_t newChangeNum;
  NSUInteger count, max;

  if (tableType == MAPISTORE_MESSAGE_TABLE)
    {
      changeNumNbr = [NSNumber numberWithUnsignedLongLong: changeNum];
      modseq = [[self modseqFromMessageChangeNumber: changeNumNbr]
                 unsignedLongLongValue];
      if (modseq > 0)
        {
          status
            = [sogoObject
                statusForFlags: [NSArray arrayWithObject: @"HIGHESTMODSEQ"]];
          highestModseq = [status objectForKey: @"highestmodseq"];

          versionProperties = [versionsMessage properties];
          messages = [versionProperties objectForKey: @"Messages"];
          deletedUIDs = [(SOGoMailFolder *) sogoObject
                        fetchUIDsOfVanishedItems: modseq];
          deletedKeys = [deletedUIDs stringsWithFormat: @"%@.eml"];
          max = [deletedUIDs count];
          if (max > 0)
            {
              [messages removeObjectsForKeys: deletedUIDs];

              mapping = [versionProperties objectForKey: @"VersionsMapping"];
              for (count = 0; count < max; count++)
                newChangeNum = [[self context] getNewChangeNumber];
              newChangeNumNbr = [NSNumber numberWithUnsignedLongLong: newChangeNum];
              *cnNbr = newChangeNumNbr;
              [mapping setObject: newChangeNumNbr forKey: @"SyncLastModseq"];
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
  uniString = NSZoneMalloc (NULL, max * sizeof (unichar) + 1);
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
                        wantCopy: (uint8_t) wantCopy
{
  NGImap4Connection *connection;
  NGImap4Client *client;
  NSString *sourceFolderName, *targetFolderName, *messageURL, *v;
  NSMutableArray *uids, *oldMessageURLs;
  NSNumber *uid;
  NSArray *destUIDs;
  MAPIStoreMapping *mapping;
  NSDictionary *result;
  NSUInteger count, tableCount, max;
  // uint64_t target_mid;
  MAPIStoreMessage *message;
  NSArray *a, *activeTables;
  struct mapistore_object_notification_parameters *notif_parameters;
  struct mapistore_connection_info *connInfo;

  // FIXME
  // We only support IMAP-to-IMAP copy operations for now.
  // Otherwise we silently fail (for now, at least!)
  if (![sourceFolder isKindOfClass: [MAPIStoreMailFolder class]])
    return [super moveCopyMessagesWithMIDs: srcMids andCount: midCount
                                fromFolder: sourceFolder withMIDs: targetMids
                                  wantCopy: wantCopy];

  /* Conversion of mids to IMAP uids */
  mapping = [[self context] mapping];
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
  // We use the UIDPLUS IMAP extension here in order to speedup UID retreival
  // If supported by the server, we'll get something like: COPYUID 1315425789 1 8
  //
  // Sometimes COPYUID isn't returned at all by Cyrus or in case the server doesn't
  // support the UIDPLUS IMAP extension, we fallback to a simple UID search.
  //
  v = [[[result objectForKey: @"RawResponse"] objectForKey: @"ResponseResult"] objectForKey: @"flag"];
  if (v)
    _parseCOPYUID (v, &destUIDs);
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
      connInfo = [[self context] connectionInfo];
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
  for (count = 0; count < midCount; count++)
    {
      messageURL = [mapping urlFromID: targetMids[count]];
      message = [self lookupMessageByURL: messageURL];
      for (tableCount = 0; tableCount < max; tableCount++)
        [[activeTables objectAtIndex: tableCount]
          notifyChangesForChild: message];
    }

  // We cleanup cache of our source and destination folders
  [self cleanupCaches];
  [sourceFolder cleanupCaches];

  return MAPISTORE_SUCCESS;
}


@end

@implementation MAPIStoreInboxFolder : MAPIStoreMailFolder

- (id) initWithURL: (NSURL *) newURL
         inContext: (MAPIStoreContext *) newContext
{
  NSDictionary *list, *response;
  NGImap4Client *client;

  if ((self = [super initWithURL: newURL
                       inContext: newContext]))
    {
      client = [[(SOGoMailFolder *) sogoObject imap4Connection] client];
      list = [client list: @"" pattern: @"INBOX"];
      response = [[list objectForKey: @"RawResponse"] objectForKey: @"list"];
      usesAltNameSpace = [[response objectForKey: @"flags"] containsObject: @"noinferiors"];
    }

  return self;
}

- (SOGoMailFolder *) specialFolderFromAccount: (SOGoMailAccount *) accountFolder
                                    inContext: (WOContext *) woContext
{
  return [accountFolder inboxFolderInContext: woContext];
}

- (NSString *) createFolder: (struct SRow *) aRow
                    withFID: (uint64_t) newFID
{
  id subfolderParent;

  if (usesAltNameSpace)
    subfolderParent = [(SOGoMailFolder *) sogoObject mailAccountFolder];
  else
    subfolderParent = sogoObject;

  return [self createFolder: aRow withFID: newFID
                inContainer: subfolderParent];
}

- (NSMutableString *) _imapFolderNameRepresentation: (NSString *) subfolderName
{
  NSMutableString *representation;

  if (usesAltNameSpace)
    {
      /* with "altnamespace", the subfolders are NEVER subfolders of INBOX... */;
      if (![subfolderName hasPrefix: @"folder"])
        abort ();
      representation
        = [NSMutableString stringWithString:
          [subfolderName substringFromIndex: 6]];
    }
  else
    representation = [super _imapFolderNameRepresentation: subfolderName];

  return representation;
}

- (NSArray *) folderKeysMatchingQualifier: (EOQualifier *) qualifier
                         andSortOrderings: (NSArray *) sortOrderings
{
  NSMutableArray *subfolderKeys;
  SOGoMailAccount *account;

  if (usesAltNameSpace)
    {
      if (qualifier)
        [self errorWithFormat: @"qualifier is not used for folders"];
      if (sortOrderings)
        [self errorWithFormat: @"sort orderings are not used for folders"];

      account = [(SOGoMailFolder *) sogoObject mailAccountFolder];
      subfolderKeys
        = [[account toManyRelationshipKeysWithNamespaces: NO]
            mutableCopy];
      [subfolderKeys removeObject: @"folderINBOX"];

      [self _cleanupSubfolderKeys: subfolderKeys];
    }
  else
    subfolderKeys = [[super folderKeysMatchingQualifier: qualifier
                                       andSortOrderings: sortOrderings]
                      mutableCopy];

  /* TODO: remove special folders */

  [subfolderKeys autorelease];

  return subfolderKeys;
}

- (id) lookupFolder: (NSString *) childKey
{
  id childObject = nil;
  SOGoMailAccount *account;
  SOGoMailFolder *childFolder;

  if (usesAltNameSpace)
    {
      [self folderKeys];
      if ([folderKeys containsObject: childKey])
        {
          account = [(SOGoMailFolder *) sogoObject mailAccountFolder];
          childFolder = [account lookupName: childKey inContext: nil
                                    acquire: NO];
          childObject = [MAPIStoreMailFolder mapiStoreObjectWithSOGoObject: childFolder
                                                               inContainer: self];
        }
    }
  else
    childObject = [super lookupFolder: childKey];

  return childObject;
}

@end

@implementation MAPIStoreSentItemsFolder : MAPIStoreMailFolder

- (SOGoMailFolder *) specialFolderFromAccount: (SOGoMailAccount *) accountFolder
                                    inContext: (WOContext *) woContext
{
  return [accountFolder sentFolderInContext: woContext];
}

@end

@implementation MAPIStoreDraftsFolder : MAPIStoreMailFolder

- (SOGoMailFolder *) specialFolderFromAccount: (SOGoMailAccount *) accountFolder
                                    inContext: (WOContext *) woContext
{
  return [accountFolder draftsFolderInContext: woContext];
}

@end

// @implementation MAPIStoreDeletedItemsFolder : MAPIStoreMailFolder

// - (SOGoMailFolder *) specialFolderFromAccount: (SOGoMailAccount *) accountFolder
//                                     inContext: (WOContext *) woContext
// {
//   return [accountFolder trashFolderInContext: woContext];
// }

// @end


//
//
//
@implementation MAPIStoreOutboxFolder : MAPIStoreMailFolder

+ (void) initialize
{
  MAPIStoreDraftsMessageK = [MAPIStoreDraftsMessage class];
}

- (SOGoMailFolder *) specialFolderFromAccount: (SOGoMailAccount *) accountFolder
                                    inContext: (WOContext *) woContext
{
  return [accountFolder draftsFolderInContext: woContext];
}

- (Class) messageClass
{
  return MAPIStoreDraftsMessageK;
}

- (MAPIStoreMessage *) createMessage
{
  MAPIStoreDraftsMessage *newMessage;
  SOGoDraftObject *newDraft;

  newDraft = [sogoObject newDraft];
  newMessage
    = [MAPIStoreDraftsMessage mapiStoreObjectWithSOGoObject: newDraft
                                                inContainer: self];
  
  return newMessage;
}

@end
