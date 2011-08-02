/* MAPIStorePermissionsTable.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import "MAPIStoreObject.h"
#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStorePermissionsTable.h"

#include <mapistore/mapistore_errors.h>

@interface MAPIStorePermissionEntry : MAPIStoreObject
{
  NSString *userId;
}

+ (id) entryWithUserId: (NSString *) newUserId;
- (id) initWithUserId: (NSString *) newUserId;

@end

@implementation MAPIStorePermissionEntry

+ (id) entryWithUserId: (NSString *) newUserId
{
  MAPIStorePermissionEntry *newEntry;

  newEntry = [[self alloc] initWithUserId: newUserId];
  [newEntry autorelease];

  return newEntry;
}

- (id) initWithUserId: (NSString *) newUserId
{
  if ((self = [self init]))
    {
      ASSIGN (userId, newUserId);
    }

  return self;
}

- (void) dealloc
{
  [userId release];
  [super dealloc];
}

- (int) getPrMemberId: (void **) data
             inMemCtx: (TALLOC_CTX *) memCtx
{
  uint64_t value = 0;

  if ([userId isEqualToString: @"anonymous"])
    value = 0xffffffffffffffff;

  *data = MAPILongLongValue (memCtx, value);

  return MAPISTORE_SUCCESS;
}

- (int) getPrEntryid: (void **) data
            inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[NSData data] asBinaryInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrMemberName: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [userId asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrMemberRights: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0);

  return MAPISTORE_SUCCESS;
}

@end

@implementation MAPIStorePermissionsTable

- (NSArray *) childKeys
{
  return [NSArray arrayWithObjects: @"default", @"anonymous", nil];
}

- (NSArray *) restrictedChildKeys
{
  return [self childKeys];
}

- (id) lookupChild: (NSString *) childKey
{
  return [MAPIStorePermissionEntry entryWithUserId: childKey];
}

@end
