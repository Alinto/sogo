/* MAPIStoreDBFolder.m - this file is part of SOGo
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

#include <inttypes.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <NGExtensions/NSObject+Logs.h>
#import <EOControl/EOQualifier.h>
#import <SOGo/SOGoFolder.h>
#import <SOGo/SOGoUser.h>
#import "EOQualifier+MAPI.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreDBFolderTable.h"
#import "MAPIStoreDBMessage.h"
#import "MAPIStoreDBMessageTable.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreTypes.h"
#import "MAPIStoreUserContext.h"
#import "SOGoMAPIDBFolder.h"
#import "SOGoMAPIDBMessage.h"

#import "MAPIStoreDBFolder.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

static Class EOKeyValueQualifierK, SOGoMAPIDBFolderK, MAPIStoreDBFolderK;

static NSString *MAPIStoreRightReadItems = @"RightsReadItems";
static NSString *MAPIStoreRightCreateItems = @"RightsCreateItems";
static NSString *MAPIStoreRightEditOwn = @"RightsEditOwn";
static NSString *MAPIStoreRightEditAll = @"RightsEditAll";
static NSString *MAPIStoreRightDeleteOwn = @"RightsDeleteOwn";
static NSString *MAPIStoreRightDeleteAll = @"RightsDeleteAll";
static NSString *MAPIStoreRightCreateSubfolders = @"RightsCreateSubfolders";
static NSString *MAPIStoreRightFolderOwner = @"RightsFolderOwner";
static NSString *MAPIStoreRightFolderContact = @"RightsFolderContact";

@implementation MAPIStoreDBFolder

+ (void) initialize
{
  EOKeyValueQualifierK = [EOKeyValueQualifier class];
  SOGoMAPIDBFolderK = [SOGoMAPIDBFolder class];
  MAPIStoreDBFolderK = [MAPIStoreDBFolder class];
}

- (void) setupAuxiliaryObjects
{
  [super setupAuxiliaryObjects];
  ASSIGN (sogoObject, dbFolder);
}

- (MAPIStoreMessageTable *) messageTable
{
  return [MAPIStoreDBMessageTable tableForContainer: self];
}

- (MAPIStoreFolderTable *) folderTable
{
  return [MAPIStoreDBFolderTable tableForContainer: self];
}

- (enum mapistore_error) createFolder: (struct SRow *) aRow
                              withFID: (uint64_t) newFID
                               andKey: (NSString **) newKeyP
{
  enum mapistore_error rc;
  NSString *folderName, *nameInContainer;
  SOGoMAPIDBFolder *newFolder;
  struct SPropValue *value;

  value = get_SPropValue_SRow (aRow, PidTagDisplayName);
  if (value)
    folderName = [NSString stringWithUTF8String: value->value.lpszW];
  else
    {
      value = get_SPropValue_SRow (aRow, PidTagDisplayName_string8);
      if (value)
        folderName = [NSString stringWithUTF8String: value->value.lpszA];
      else
        folderName = nil;
    }

  if (folderName)
    {
      nameInContainer = [NSString stringWithFormat: @"0x%.16"PRIx64,
                                  (unsigned long long) newFID];
      newFolder = [SOGoMAPIDBFolderK objectWithName: nameInContainer
                                        inContainer: sogoObject];
      [newFolder reloadIfNeeded];
      [[newFolder properties] setObject: folderName
                                 forKey: MAPIPropertyKey (PidTagDisplayName)];
      [newFolder save];
      *newKeyP = nameInContainer;
      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = MAPISTORE_ERR_INVALID_PARAMETER;

  return rc;
}

- (enum mapistore_error) moveCopyToFolder: (MAPIStoreFolder *) targetFolder
                              withNewName: (NSString *) newFolderName
                                   isMove: (BOOL) isMove
                              isRecursive: (BOOL) isRecursive
{
  enum mapistore_error rc;
  NSString *path, *pathComponent, *targetPath, *newPath;
  NSString *newURL;
  MAPIStoreMapping *mapping;
  NSRange slashRange;

  if (isMove && [targetFolder isKindOfClass: MAPIStoreDBFolderK])
    {
      path = [sogoObject path];
      slashRange = [path rangeOfString: @"/" options: NSBackwardsSearch];
      if (slashRange.location == NSNotFound)
        [NSException raise: @"MAPIStoreIOException"
                    format: @"db folder path must start with a '/'"];
      else
        pathComponent = [path substringFromIndex: slashRange.location + 1];
      targetPath = [[targetFolder sogoObject] path];
      newPath = [NSString stringWithFormat: @"%@/%@",
                          targetPath, pathComponent];
      [dbFolder changePathTo: newPath];
      
      mapping = [self mapping];
      newURL = [NSString stringWithFormat: @"%@%@/",
                         [targetFolder url], pathComponent];
      [mapping updateID: [self objectId]
                withURL: newURL];

      [targetFolder cleanupCaches];

      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = [super moveCopyToFolder: targetFolder withNewName: newFolderName
                          isMove: isMove
                     isRecursive: isRecursive];

  return rc;
}

- (MAPIStoreMessage *) createMessage
{
  MAPIStoreMessage *newMessage;
  SOGoMAPIDBMessage *fsObject;
  NSString *newKey;

  newKey = [NSString stringWithFormat: @"%@.plist",
                     [SOGoObject globallyUniqueObjectId]];
  fsObject = [SOGoMAPIDBMessage objectWithName: newKey
                                   inContainer: sogoObject];
  [fsObject setObjectType: MAPIDBObjectTypeMessage];
  [fsObject reloadIfNeeded];
  newMessage = [MAPIStoreDBMessage mapiStoreObjectWithSOGoObject: fsObject
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
    keys = [(SOGoMAPIDBFolder *) sogoObject childKeysOfType: MAPIDBObjectTypeMessage
                                             includeDeleted: NO
                                          matchingQualifier: qualifier
                                           andSortOrderings: sortOrderings];
  else
    keys = [NSArray array];

  return keys;
}

- (NSArray *) folderKeysMatchingQualifier: (EOQualifier *) qualifier
                         andSortOrderings: (NSArray *) sortOrderings
{
  return [dbFolder childKeysOfType: MAPIDBObjectTypeFolder
                    includeDeleted: NO
                 matchingQualifier: qualifier
                  andSortOrderings: sortOrderings];
}

/* TODO: now that we are DB-based, this method can easily be implemented

- (NSArray *) getDeletedKeysFromChangeNumber: (uint64_t) changeNum
                                       andCN: (NSNumber **) cnNbrs
                                 inTableType: (enum mapistore_table_type) tableType
{
}
*/

- (NSDate *) lastMessageModificationTime
{
  NSUInteger count, max;
  NSDate *date, *fileDate;
  MAPIStoreDBMessage *msg;
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
  return sogoObject;
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
