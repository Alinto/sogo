/* NSArray+MAPIStore.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
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

#import <Foundation/NSValue.h>

#import "NSString+MAPIStore.h"

#import "NSArray+MAPIStore.h"

#undef DEBUG
#include <talloc.h>
#include <mapistore/mapistore.h>

@implementation NSArray (MAPIStoreFolders)

- (struct indexing_folders_list *) asFoldersListInCtx: (void *) memCtx
{
  struct indexing_folders_list *flist;
  NSInteger count, max;

  max = [self count];

  flist = talloc_zero(memCtx, struct indexing_folders_list);
  flist->folderID = talloc_array(flist, uint64_t, max);
  flist->count = max;

  for (count = 0; count < max; count++)
    *(flist->folderID + count) = [[self objectAtIndex: count] unsignedLongLongValue];

  return flist;
}

- (struct mapi_SPLSTRArrayW *) asArrayOfUnicodeStringsInCtx: (void *) memCtx
{
  struct mapi_SPLSTRArrayW *list;
  NSInteger count, max;

  max = [self count];

  list = talloc_zero(memCtx, struct mapi_SPLSTRArrayW);
  list->cValues = max;
  list->strings = talloc_array(memCtx, struct mapi_LPWSTR, max);

  for (count = 0; count < max; count++)
    (list->strings + count)->lppszW = [[self objectAtIndex: count] asUnicodeInMemCtx: memCtx];

  return list;
}

@end
