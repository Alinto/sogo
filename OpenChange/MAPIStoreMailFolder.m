/* MAPIStoreMailFolder.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <EOControl/EOQualifier.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <Mailer/SOGoDraftsFolder.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailAccounts.h>
#import <Mailer/SOGoMailFolder.h>
#import <Mailer/SOGoSentFolder.h>
#import <Mailer/SOGoTrashFolder.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSString+Utilities.h>

#import "MAPIApplication.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreDraftsMessage.h"
#import "MAPIStoreMailMessage.h"
#import "MAPIStoreMailMessageTable.h"
#import "MAPIStoreMailFolderTable.h"
#import "MAPIStoreTypes.h"
#import "NSString+MAPIStore.h"

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

      [self logWithFormat: @"sogoObject: %@", sogoObject];
    }

  return self;
}

- (void) dealloc
{
  [messageTable release];
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
  if (!messageTable)
    {
      ASSIGN (messageTable, [MAPIStoreMailMessageTable tableForContainer: self]);
      [self logWithFormat: @"new message table"];
    }

  return messageTable;
}

- (Class) messageClass
{
  return MAPIStoreMailMessageK;
}

- (NSString *) createFolder: (struct SRow *) aRow
                    withFID: (uint64_t) newFID
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
                                      inContainer: sogoObject];
      if (![newFolder create])
        nameInContainer = nil;
    }

  return nameInContainer;
}

- (int) getPrContentUnread: (void **) data
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
{
  *data = [@"IPF.Note" asUnicodeInMemCtx: memCtx];
  
  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageClass: (void **) data
{
  *data = [@"IPM.Note" asUnicodeInMemCtx: memCtx];
  
  return MAPISTORE_SUCCESS;
}

- (NSArray *) childKeysMatchingQualifier: (EOQualifier *) qualifier
                        andSortOrderings: (NSArray *) sortOrderings
{
  NSArray *uidKeys;
  EOQualifier *fetchQualifier, *deletedQualifier;
  static EOQualifier *nonDeletedQualifier = nil;

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

  if (!sortOrderings)
    sortOrderings = [NSArray arrayWithObject: @"ARRIVAL"];

  if (qualifier)
    {
      fetchQualifier = [[EOAndQualifier alloc]
                         initWithQualifiers: nonDeletedQualifier, qualifier,
                         nil];
      [fetchQualifier autorelease];
    }
  else
    fetchQualifier = nonDeletedQualifier;

  uidKeys = [sogoObject fetchUIDsMatchingQualifier: fetchQualifier
                                      sortOrdering: sortOrderings];
  return [uidKeys stringsWithFormat: @"%@.eml"];
}

- (NSArray *) folderKeys
{
  if (!folderKeys)
    folderKeys = [[sogoObject toManyRelationshipKeys] mutableCopy];

  return folderKeys;
}

- (MAPIStoreFAIMessageTable *) folderTable
{
  return [MAPIStoreMailFolderTable tableForContainer: self];
}

- (id) lookupChild: (NSString *) childKey
{
  id childObject;
  SOGoMailFolder *childFolder;

  [self folderKeys];
  if ([folderKeys containsObject: childKey])
    {
      childFolder = [sogoObject lookupName: childKey inContext: nil
                                   acquire: NO];
      childObject = [MAPIStoreMailFolder mapiStoreObjectWithSOGoObject: childFolder
                                                           inContainer: self];
    }
  else
    childObject = [super lookupChild: childKey];

  return childObject;
}

- (NSCalendarDate *) creationTime
{
  return [NSCalendarDate dateWithTimeIntervalSince1970: 0x4dbb2dbe]; /* oc_version_time */
}

- (NSDate *) lastMessageModificationTime
{
  return [sogoObject mostRecentMessageDate];
}

@end

@implementation MAPIStoreInboxFolder : MAPIStoreMailFolder

- (SOGoMailFolder *) specialFolderFromAccount: (SOGoMailAccount *) accountFolder
                                    inContext: (WOContext *) woContext
{
  return [accountFolder inboxFolderInContext: woContext];
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
