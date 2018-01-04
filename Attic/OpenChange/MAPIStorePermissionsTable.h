/* MAPIStorePermissionsTable.h - this file is part of SOGo
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

#ifndef MAPISTOREPERMISSIONSTABLE_H
#define MAPISTOREPERMISSIONSTABLE_H

#import "MAPIStoreTable.h"

struct ldb_context;

@interface MAPIStorePermissionEntry : MAPIStoreObject
{
  NSString *userId;
  uint64_t memberId;
}

+ (id) entryWithUserId: (NSString *) newUserId
           andMemberId: (uint64_t) newMemberId
             forFolder: (MAPIStoreFolder *) newFolder;
- (id) initWithUserId: (NSString *) newUserId
          andMemberId: (uint64_t) newMemberId
            forFolder: (MAPIStoreFolder *) newFolder;

- (NSString *) userId;
- (uint64_t) memberId;

@end

@interface MAPIStorePermissionsTable : MAPIStoreTable
{
  NSMutableDictionary *entries;
}

@end

#endif /* MAPISTOREPERMISSIONSTABLE_H */
