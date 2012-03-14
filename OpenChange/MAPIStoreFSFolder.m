/* MAPIStoreFSFolder.m - this file is part of SOGo
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

#include <inttypes.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <NGExtensions/NSObject+Logs.h>
#import <EOControl/EOQualifier.h>
#import <SOGo/SOGoUser.h>
#import "EOQualifier+MAPI.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreFSFolderTable.h"
#import "MAPIStoreFSMessage.h"
#import "MAPIStoreFSMessageTable.h"
#import "MAPIStoreTypes.h"
#import "MAPIStoreUserContext.h"
#import "SOGoMAPIFSFolder.h"
#import "SOGoMAPIFSMessage.h"

#import "MAPIStoreFSFolder.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

static Class EOKeyValueQualifierK;

static NSString *MAPIStoreRightReadItems = @"RightsReadItems";
static NSString *MAPIStoreRightCreateItems = @"RightsCreateItems";
static NSString *MAPIStoreRightEditOwn = @"RightsEditOwn";
static NSString *MAPIStoreRightEditAll = @"RightsEditAll";
static NSString *MAPIStoreRightDeleteOwn = @"RightsDeleteOwn";
static NSString *MAPIStoreRightDeleteAll = @"RightsDeleteAll";
static NSString *MAPIStoreRightCreateSubfolders = @"RightsCreateSubfolders";
static NSString *MAPIStoreRightFolderOwner = @"RightsFolderOwner";
static NSString *MAPIStoreRightFolderContact = @"RightsFolderContact";

@implementation MAPIStoreFSFolder

+ (void) initialize
{
  EOKeyValueQualifierK = [EOKeyValueQualifier class];
}

- (MAPIStoreMessageTable *) messageTable
{
  return [MAPIStoreFSMessageTable tableForContainer: self];
}

- (MAPIStoreFolderTable *) folderTable
{
  return [MAPIStoreFSFolderTable tableForContainer: self];
}

- (enum mapistore_error) createFolder: (struct SRow *) aRow
                              withFID: (uint64_t) newFID
                               andKey: (NSString **) newKeyP
{
  NSString *newKey, *urlString;
  NSURL *childURL;
  SOGoMAPIFSFolder *childFolder;

  newKey = [NSString stringWithFormat: @"0x%.16"PRIx64, (unsigned long long) newFID];

  urlString = [NSString stringWithFormat: @"%@/%@", [self url], newKey];
  childURL = [NSURL URLWithString: [urlString stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]];
  childFolder = [SOGoMAPIFSFolder folderWithURL: childURL
                                   andTableType: MAPISTORE_MESSAGE_TABLE];
  [childFolder ensureDirectory];
  *newKeyP = newKey;

  return MAPISTORE_SUCCESS;
}

- (MAPIStoreMessage *) createMessage
{
  MAPIStoreMessage *newMessage;
  SOGoMAPIFSMessage *fsObject;
  NSString *newKey;

  newKey = [NSString stringWithFormat: @"%@.plist",
                     [SOGoObject globallyUniqueObjectId]];
  fsObject = [SOGoMAPIFSMessage objectWithName: newKey
                                   inContainer: sogoObject];
  newMessage = [MAPIStoreFSMessage mapiStoreObjectWithSOGoObject: fsObject
                                                     inContainer: self];

  return newMessage;
}

- (NSArray *) messageKeysMatchingQualifier: (EOQualifier *) qualifier
                          andSortOrderings: (NSArray *) sortOrderings
{
  NSArray *keys;
  SOGoUser *ownerUser;

  ownerUser = [[self userContext] sogoUser];
  if ([[context activeUser] isEqual: ownerUser]
      || [self subscriberCanReadMessages])
    keys = [(SOGoMAPIFSFolder *) sogoObject
              toOneRelationshipKeysMatchingQualifier: qualifier
                                    andSortOrderings: sortOrderings];
  else
    keys = [NSArray array];

  return keys;
}

- (NSArray *) folderKeysMatchingQualifier: (EOQualifier *) qualifier
                         andSortOrderings: (NSArray *) sortOrderings
{
  NSArray *entries;
  NSMutableArray *filteredEntries;
  NSUInteger count, max;
  MAPIStoreFSFolder *subfolder;
  SOGoMAPIFSMessage *propertiesMessage;
  NSString *subfolderKey;

  entries = [(SOGoMAPIFSFolder *) sogoObject toManyRelationshipKeys];
  if (qualifier)
    {
      max = [entries count];
      filteredEntries = [NSMutableArray arrayWithCapacity: max];
      for (count = 0; count < max; count++)
        {
          subfolderKey = [entries objectAtIndex: count];
          subfolder = [self lookupFolder: subfolderKey];
          propertiesMessage = [subfolder propertiesMessage];
          if ([qualifier evaluateMAPIVolatileMessage: propertiesMessage])
            [filteredEntries addObject: subfolderKey];
        }
      entries = filteredEntries;
    }
  if (sortOrderings)
    [self errorWithFormat: @"sort orderings are not used for folders"];

  return entries;
}

- (NSDate *) lastMessageModificationTime
{
  NSUInteger count, max;
  NSDate *date, *fileDate;
  MAPIStoreFSMessage *msg;
  NSArray *messageKeys;

  messageKeys = [self messageKeys];

  date = [NSCalendarDate date];
  [self logWithFormat: @"current date: %@", date];

  max = [messageKeys count];
  for (count = 0; count < max; count++)
    {
      msg = [self lookupMessage: [messageKeys objectAtIndex: count]];
      fileDate = [msg lastModificationTime];
      if ([date laterDate: fileDate] == fileDate)
        {
          [self logWithFormat: @"current date: %@", date];
          
          date = fileDate;
        }
    }

  return date;
}

- (SOGoFolder *) aclFolder
{
  return propsFolder;
}

- (NSArray *) rolesForExchangeRights: (uint32_t) rights
{
  NSMutableArray *roles;

  roles = [NSMutableArray arrayWithCapacity: 9];
  if (rights & RightsReadItems)
    [roles addObject: MAPIStoreRightReadItems];
  if (rights & RightsCreateItems)
    [roles addObject: MAPIStoreRightCreateItems];
  if (rights & RightsEditOwn)
    [roles addObject: MAPIStoreRightEditOwn];
  if (rights & RightsDeleteOwn)
    [roles addObject: MAPIStoreRightDeleteOwn];
  if (rights & RightsEditAll)
    [roles addObject: MAPIStoreRightEditAll];
  if (rights & RightsDeleteAll)
    [roles addObject: MAPIStoreRightDeleteAll];
  if (rights & RightsCreateSubfolders)
    [roles addObject: MAPIStoreRightCreateSubfolders];
  if (rights & RightsFolderOwner)
    [roles addObject: MAPIStoreRightFolderOwner];
  if (rights & RightsFolderContact)
    [roles addObject: MAPIStoreRightFolderContact];

  return roles;
}

- (uint32_t) exchangeRightsForRoles: (NSArray *) roles
{
  uint32_t rights = 0;

  if ([roles containsObject: MAPIStoreRightReadItems])
    rights |= RightsReadItems;
  if ([roles containsObject: MAPIStoreRightCreateItems])
    rights |= RightsCreateItems;
  if ([roles containsObject: MAPIStoreRightEditOwn])
    rights |= RightsEditOwn;
  if ([roles containsObject: MAPIStoreRightDeleteOwn])
    rights |= RightsDeleteOwn;
  if ([roles containsObject: MAPIStoreRightEditAll])
    rights |= RightsEditAll;
  if ([roles containsObject: MAPIStoreRightDeleteAll])
    rights |= RightsDeleteAll;
  if ([roles containsObject: MAPIStoreRightCreateSubfolders])
    rights |= RightsCreateSubfolders;
  if ([roles containsObject: MAPIStoreRightFolderOwner])
    rights |= RightsFolderOwner;
  if ([roles containsObject: MAPIStoreRightFolderContact])
    rights |= RightsFolderContact;
  if (rights != 0)
    rights |= RoleNone; /* actually "folder visible" */
 
  return rights;
}

- (BOOL) _testRoleForActiveUser: (const NSString *) role
{
  SOGoUser *activeUser;
  NSArray *roles;

  activeUser = [[self context] activeUser];

  roles = [[self aclFolder] aclsForUser: [activeUser login]];

  return [roles containsObject: role];
}

- (BOOL) subscriberCanCreateMessages
{
  return [self _testRoleForActiveUser: MAPIStoreRightCreateItems];
}

- (BOOL) subscriberCanModifyMessages
{
  return ([self _testRoleForActiveUser: MAPIStoreRightEditAll]
          || [self _testRoleForActiveUser: MAPIStoreRightEditOwn]);
}

- (BOOL) subscriberCanReadMessages
{
  return [self _testRoleForActiveUser: MAPIStoreRightReadItems];
}

- (BOOL) subscriberCanDeleteMessages
{
  return ([self _testRoleForActiveUser: MAPIStoreRightDeleteAll]
          || [self _testRoleForActiveUser: MAPIStoreRightDeleteOwn]);
}

- (BOOL) subscriberCanCreateSubFolders
{
  return [self _testRoleForActiveUser: MAPIStoreRightCreateSubfolders];
}

- (BOOL) supportsSubFolders
{
  return YES;
}

@end
