/* MAPIStorePermissionsTable.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <SOGo/SOGoFolder.h>
#import <SOGo/SOGoObject.h>
#import <SOGo/SOGoUser.h>

#import "MAPIStoreContext.h"
#import "MAPIStoreFolder.h"
#import "MAPIStoreTypes.h"
#import "MAPIStoreSamDBUtils.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStorePermissionsTable.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

@implementation MAPIStorePermissionEntry

+ (id) entryWithUserId: (NSString *) newUserId
           andMemberId: (uint64_t) newMemberId
             forFolder: (MAPIStoreFolder *) newFolder
{
  MAPIStorePermissionEntry *newEntry;

  newEntry = [[self alloc] initWithUserId: newUserId andMemberId: newMemberId
                                forFolder: newFolder];
  [newEntry autorelease];

  return newEntry;
}

- (id) initWithUserId: (NSString *) newUserId
          andMemberId: (uint64_t) newMemberId
            forFolder: (MAPIStoreFolder *) newFolder
{
  if ((self = [self initInContainer: newFolder]))
    {
      ASSIGN (userId, newUserId);
      memberId = newMemberId;
    }

  return self;
}

- (void) dealloc
{
  [userId release];
  [super dealloc];
}

- (NSString *) userId
{
  return userId;
}

- (uint64_t) memberId
{
  return memberId;
}

- (int) getPidTagMemberId: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongLongValue (memCtx, memberId);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagEntryId: (void **) data
                inMemCtx: (TALLOC_CTX *) memCtx
{
  NSData *entryId;
  struct mapistore_connection_info *connInfo;

  if (memberId == 0 || memberId == ULLONG_MAX)
    entryId = [NSData data];
  else
    {
      connInfo = [(MAPIStoreContext *) [container context] connectionInfo];
      entryId = MAPIStoreInternalEntryId (connInfo->sam_ctx, userId);
    }
  *data = [entryId asBinaryInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagMemberName: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *displayName;

  if (memberId == 0)
    displayName = @"";
  else if (memberId == ULLONG_MAX)
    displayName = @"Anonymous";
  else
    displayName = [[SOGoUser userWithLogin: userId] cn];
  
  *data = [displayName asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagMemberRights: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  uint32_t rights;
  NSArray *roles;

  roles = [[(MAPIStoreFolder *) container aclFolder] aclsForUser: userId];
  rights = [(MAPIStoreFolder *) container exchangeRightsForRoles: roles];

  *data = MAPILongValue (memCtx, rights);

  return MAPISTORE_SUCCESS;
}

@end

@implementation MAPIStorePermissionsTable

- (void) dealloc
{
  [entries release];
  [super dealloc];
}

- (void) _fetchEntries
{
  NSArray *permEntries;
  NSUInteger count, max;
  MAPIStorePermissionEntry *entry;

  entries = [NSMutableDictionary new];
  permEntries = [(MAPIStoreFolder *) container permissionEntries];
  max = [permEntries count];
  for (count = 0; count < max; count++)
    {
      entry = [permEntries objectAtIndex: count];
      [entries setObject: entry forKey: [entry userId]];
    }

  childKeys = [entries allKeys];
  [childKeys retain];
}

- (NSArray *) childKeys
{
  if (!entries)
    [self _fetchEntries];

  return childKeys;
}

- (NSArray *) restrictedChildKeys
{
  return [self childKeys];
}

- (id) lookupChild: (NSString *) childKey
{
  if (!entries)
    [self _fetchEntries];

  return [entries objectForKey: childKey];
}

@end
