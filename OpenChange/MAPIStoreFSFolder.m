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
#import "EOQualifier+MAPI.h"
#import "MAPIStoreFSFolderTable.h"
#import "MAPIStoreFSMessage.h"
#import "MAPIStoreFSMessageTable.h"
#import "MAPIStoreTypes.h"
#import "SOGoMAPIFSFolder.h"
#import "SOGoMAPIFSMessage.h"

#import "MAPIStoreFSFolder.h"

#undef DEBUG
#include <mapistore/mapistore.h>
// #include <mapistore/mapistore_errors.h>
// #include <libmapiproxy.h>
// #include <param.h>

static Class EOKeyValueQualifierK;

@implementation MAPIStoreFSFolder

+ (void) initialize
{
  EOKeyValueQualifierK = [EOKeyValueQualifier class];
}

- (id) initWithURL: (NSURL *) newURL
         inContext: (MAPIStoreContext *) newContext
{
  if ((self = [super initWithURL: newURL
                       inContext: newContext]))
    {
      sogoObject = [SOGoMAPIFSFolder folderWithURL: newURL
                                      andTableType: MAPISTORE_MESSAGE_TABLE];
      [sogoObject retain];
    }

  return self;
}

- (MAPIStoreMessageTable *) messageTable
{
  return [MAPIStoreFSMessageTable tableForContainer: self];
}

- (MAPIStoreFolderTable *) folderTable
{
  return [MAPIStoreFSFolderTable tableForContainer: self];
}

- (NSString *) createFolder: (struct SRow *) aRow
                    withFID: (uint64_t) newFID
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

  return newKey;
}

- (MAPIStoreMessage *) createMessage
{
  MAPIStoreMessage *newMessage;
  SOGoMAPIFSMessage *fsObject;
  NSString *newKey;

  newKey = [NSString stringWithFormat: @"%@.plist",
                     [SOGoObject globallyUniqueObjectId]];
  fsObject = [SOGoMAPIFSMessage objectWithName: newKey inContainer: sogoObject];
  newMessage = [MAPIStoreFSMessage mapiStoreObjectWithSOGoObject: fsObject
                                                     inContainer: self];

  
  return newMessage;
}

- (NSArray *) messageKeysMatchingQualifier: (EOQualifier *) qualifier
                          andSortOrderings: (NSArray *) sortOrderings
{
  return [(SOGoMAPIFSFolder *) sogoObject
           toOneRelationshipKeysMatchingQualifier: qualifier
                                 andSortOrderings: sortOrderings];
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

- (id) lookupFolder: (NSString *) childKey
{
  id childObject = nil;
  SOGoMAPIFSFolder *childFolder;

  [self folderKeys];
  if ([folderKeys containsObject: childKey])
    {
      childFolder = [sogoObject lookupName: childKey inContext: nil
                                   acquire: NO];
      childObject = [MAPIStoreFSFolder mapiStoreObjectWithSOGoObject: childFolder
                                                         inContainer: self];
    }

  return childObject;
}

- (NSDate *) lastMessageModificationTime
{
  NSUInteger count, max;
  NSDate *date, *fileDate;
  MAPIStoreFSMessage *msg;

  [self messageKeys];

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
    [roles addObject: @"RightsReadItems"];
  if (rights & RightsCreateItems)
    [roles addObject: @"RightsCreateItems"];
  if (rights & RightsEditOwn)
    [roles addObject: @"RightsEditOwn"];
  if (rights & RightsDeleteOwn)
    [roles addObject: @"RightsDeleteOwn"];
  if (rights & RightsEditAll)
    [roles addObject: @"RightsEditAll"];
  if (rights & RightsDeleteAll)
    [roles addObject: @"RightsDeleteAll"];
  if (rights & RightsCreateSubfolders)
    [roles addObject: @"RightsCreateSubfolders"];
  if (rights & RightsFolderOwner)
    [roles addObject: @"RightsFolderOwner"];
  if (rights & RightsFolderContact)
    [roles addObject: @"RightsFolderContact"];

  return roles;
}

- (uint32_t) exchangeRightsForRoles: (NSArray *) roles
{
  uint32_t rights = 0;

  if ([roles containsObject: @"RightsReadItems"])
    rights |= RightsReadItems;
  if ([roles containsObject: @"RightsCreateItems"])
    rights |= RightsCreateItems;
  if ([roles containsObject: @"RightsEditOwn"])
    rights |= RightsEditOwn;
  if ([roles containsObject: @"RightsDeleteOwn"])
    rights |= RightsDeleteOwn;
  if ([roles containsObject: @"RightsEditAll"])
    rights |= RightsEditAll;
  if ([roles containsObject: @"RightsDeleteAll"])
    rights |= RightsDeleteAll;
  if ([roles containsObject: @"RightsCreateSubfolders"])
    rights |= RightsCreateSubfolders;
  if ([roles containsObject: @"RightsFolderOwner"])
    rights |= RightsFolderOwner;
  if ([roles containsObject: @"RightsFolderContact"])
    rights |= RightsFolderContact;
  if (rights != 0)
    rights |= RoleNone; /* actually "folder visible" */
 
  return rights;
}

@end
