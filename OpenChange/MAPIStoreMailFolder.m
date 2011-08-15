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
#import <Mailer/SOGoSentFolder.h>
#import <Mailer/SOGoTrashFolder.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSString+Utilities.h>

#import "MAPIApplication.h"
#import "MAPIStoreAppointmentWrapper.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreDraftsMessage.h"
#import "MAPIStoreMailMessage.h"
#import "MAPIStoreMailMessageTable.h"
#import "MAPIStoreTypes.h"
#import "NSString+MAPIStore.h"
#import "SOGoMAPIFSMessage.h"

#import "MAPIStoreMailFolder.h"

static Class MAPIStoreDraftsMessageK;
static Class MAPIStoreMailMessageK;
static Class SOGoMailFolderK;

#undef DEBUG
#include <libmapi/libmapi.h>
#include <mapistore/mapistore.h>

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

          [mapping setObject: modseq forKey: changeNumber];

          if (!lastModseq
              || ([lastModseq compare: modseq] == NSOrderedAscending))
            lastModseq = modseq;
        }

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
