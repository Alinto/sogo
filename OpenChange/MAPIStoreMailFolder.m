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
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <EOControl/EOQualifier.h>
#import <NGExtensions/NSObject+Logs.h>
#import <Mailer/SOGoDraftsFolder.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailAccounts.h>
#import <Mailer/SOGoMailFolder.h>
#import <Mailer/SOGoSentFolder.h>
#import <Mailer/SOGoTrashFolder.h>
#import <SOGo/NSArray+Utilities.h>

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

@implementation MAPIStoreMailFolder

+ (void) initialize
{
  MAPIStoreMailMessageK = [MAPIStoreMailMessage class];
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

- (SOGoMailFolder *) specialFolderFromAccount: (SOGoMailAccount *) accountFolder
                                    inContext: (WOContext *) woContext
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (MAPIStoreMessageTable *) messageTable
{
  return [MAPIStoreMailMessageTable tableForContainer: self];
}

- (Class) messageClass
{
  return MAPIStoreMailMessageK;
}

- (NSString *) createFolder: (struct SRow *) aRow
{
  return nil;
  // NSString *newFolderURL;
  // NSString *folderName, *nameInContainer;
  // SOGoFolder *parentFolder, *newFolder;
  // int i;

  // newFolderURL = nil;

  // folderName = nil;
  // for (i = 0; !folderName && i < aRow->cValues; i++)
  //   {
  //     if (aRow->lpProps[i].ulPropTag == PR_DISPLAY_NAME_UNICODE)
  //       folderName = [NSString stringWithUTF8String: aRow->lpProps[i].value.lpszW];
  //     else if (aRow->lpProps[i].ulPropTag == PR_DISPLAY_NAME)
  //       folderName = [NSString stringWithUTF8String: aRow->lpProps[i].value.lpszA];
  //   }

  // if (folderName)
  //   {
  //     parentFolder = [self lookupObject: parentFolderURL];
  //     if (parentFolder)
  //       {
  //         if ([parentFolder isKindOfClass: SOGoMailAccountK]
  //             || [parentFolder isKindOfClass: SOGoMailFolderK])
  //           {
  //             nameInContainer = [NSString stringWithFormat: @"folder%@",
  //                                         [folderName asCSSIdentifier]];
  //             newFolder = [SOGoMailFolderK objectWithName: nameInContainer
  //                                             inContainer: parentFolder];
  //             if ([newFolder create])
  //               newFolderURL = [NSString stringWithFormat: @"%@/%@",
  //                                        parentFolderURL,
  //                                        [nameInContainer stringByEscapingURL]];
  //           }
  //       }
  //   }

  // return newFolderURL;
}

- (enum MAPISTATUS) getProperty: (void **) data
                        withTag: (enum MAPITAGS) propTag
{
  enum MAPISTATUS rc;
  EOQualifier *searchQualifier;
  uint32_t intValue;
  
  rc = MAPI_E_SUCCESS;
  switch (propTag)
    {
    case PR_CONTENT_UNREAD:
      searchQualifier
        = [EOQualifier qualifierWithQualifierFormat: @"flags = %@", @"unseen"];
      intValue = [[sogoObject fetchUIDsMatchingQualifier: searchQualifier
                                            sortOrdering: nil] count];
      *data = MAPILongValue (memCtx, intValue);
      break;
    case PR_CONTAINER_CLASS_UNICODE:
      *data = [@"IPF.Note" asUnicodeInMemCtx: memCtx];
      break;
    default:
      rc = [super getProperty: data withTag: propTag];
    }
  
  return rc;
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

@implementation MAPIStoreDeletedItemsFolder : MAPIStoreMailFolder

- (SOGoMailFolder *) specialFolderFromAccount: (SOGoMailAccount *) accountFolder
                                    inContext: (WOContext *) woContext
{
  return [accountFolder trashFolderInContext: woContext];
}

@end

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
