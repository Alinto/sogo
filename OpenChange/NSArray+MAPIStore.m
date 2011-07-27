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

- (struct WStringArray_r *) asArrayOfUnicodeStringsInCtx: (void *) memCtx
{
  struct WStringArray_r *list;
  NSInteger count, max;

  max = [self count];

  list = talloc_zero(memCtx, struct WStringArray_r);
  list->cValues = max;
  list->lppszW = talloc_array(list, const char *, max);

  for (count = 0; count < max; count++)
    list->lppszW[count] = [[self objectAtIndex: count] asUnicodeInMemCtx: list->lppszW];

  return list;
}

@end
