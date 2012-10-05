/* NSArray+MAPIStore.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2012 Inverse inc.
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

#import "NSDate+MAPIStore.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "NSArray+MAPIStore.h"

#undef DEBUG
#include <stdbool.h>
#include <talloc.h>
#include <util/time.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>

@implementation NSArray (MAPIStoreFolders)

+ (id) arrayFromMAPIMVLong: (struct mapi_MV_LONG_STRUCT *) mvLong
{
  NSUInteger count;
  NSNumber *subObject;
  NSMutableArray *mvResult;

  mvResult = [NSMutableArray arrayWithCapacity: mvLong->cValues];
  for (count = 0; count < mvLong->cValues; count++)
    {
      subObject = [NSNumber numberWithLong: mvLong->lpl[count]];
      [mvResult addObject: subObject];
    }

  return mvResult;
}

+ (id) arrayFromMAPIMVUnicode: (struct mapi_SLPSTRArrayW *) mvUnicode
{
  NSUInteger count;
  NSString *subObject;
  NSMutableArray *mvResult;

  mvResult = [NSMutableArray arrayWithCapacity: mvUnicode->cValues];
  for (count = 0; count < mvUnicode->cValues; count++)
    {
      subObject
        = [NSString stringWithUTF8String: mvUnicode->strings[count].lppszW];
      [mvResult addObject: subObject];
    }

  return mvResult;
}

+ (id) arrayFromMAPIMVString: (struct mapi_SLPSTRArray *) mvString
{
  NSUInteger count;
  id subObject;
  NSMutableArray *mvResult;

  mvResult = [NSMutableArray arrayWithCapacity: mvString->cValues];
  for (count = 0; count < mvString->cValues; count++)
    {
      subObject = [NSString stringWithUTF8String: mvString->strings[count].lppszA];
      [mvResult addObject: subObject];
    }

  return mvResult;
}

+ (id) arrayFromMAPIMVBinary: (struct mapi_SBinaryArray *) mvBinary
{
  NSUInteger count;
  id subObject;
  NSMutableArray *mvResult;

  mvResult = [NSMutableArray arrayWithCapacity: mvBinary->cValues];
  for (count = 0; count < mvBinary->cValues; count++)
    {
      subObject = [NSData dataWithShortBinary: mvBinary->bin + count];
      [mvResult addObject: subObject];
    }

  return mvResult;
}

+ (id) arrayFromMAPIMVGuid: (struct mapi_SGuidArray *) mvGuid
{
  NSUInteger count;
  id subObject;
  NSMutableArray *mvResult;

  mvResult = [NSMutableArray arrayWithCapacity: mvGuid->cValues];
  for (count = 0; count < mvGuid->cValues; count++)
    {
      subObject = [NSData dataWithGUID: mvGuid->lpguid + count];
      [mvResult addObject: subObject];
    }

  return mvResult;
}

+ (id) arrayFromMVShort: (const struct ShortArray_r *) mvShort
{
  NSUInteger count;
  NSNumber *subObject;
  NSMutableArray *mvResult;

  mvResult = [NSMutableArray arrayWithCapacity: mvShort->cValues];
  for (count = 0; count < mvShort->cValues; count++)
    {
      subObject = [NSNumber numberWithShort: mvShort->lpi[count]];
      [mvResult addObject: subObject];
    }

  return mvResult;
}

+ (id) arrayFromMVLong: (const struct LongArray_r *) mvLong
{
  NSUInteger count;
  NSNumber *subObject;
  NSMutableArray *mvResult;

  mvResult = [NSMutableArray arrayWithCapacity: mvLong->cValues];
  for (count = 0; count < mvLong->cValues; count++)
    {
      subObject = [NSNumber numberWithLong: mvLong->lpl[count]];
      [mvResult addObject: subObject];
    }

  return mvResult;
}

- (struct LongArray_r *) asMVLongInMemCtx: (void *) memCtx
{
  struct LongArray_r *list;
  NSNumber *number;
  NSInteger count, max;

  max = [self count];

  list = talloc_zero (memCtx, struct LongArray_r);
  list->cValues = max;
  list->lpl = talloc_array (list, uint32_t, max);
  for (count = 0; count < max; count++)
    {
      number = [self objectAtIndex: count];
      list->lpl[count] = [number longValue];
    }

  return list;
}

+ (id) arrayFromMVUI8: (const struct UI8Array_r *) mvUI8
{
  NSUInteger count;
  NSNumber *subObject;
  NSMutableArray *mvResult;

  mvResult = [NSMutableArray arrayWithCapacity: mvUI8->cValues];
  for (count = 0; count < mvUI8->cValues; count++)
    {
      subObject = [NSNumber numberWithLongLong: mvUI8->lpui8[count]];
      [mvResult addObject: subObject];
    }

  return mvResult;
}

+ (id) arrayFromMVUnicode: (const struct StringArrayW_r *) mvUnicode
{
  NSUInteger count;
  NSString *subObject;
  NSMutableArray *mvResult;

  mvResult = [NSMutableArray arrayWithCapacity: mvUnicode->cValues];
  for (count = 0; count < mvUnicode->cValues; count++)
    {
      subObject = [NSString stringWithUTF8String: mvUnicode->lppszW[count]];
      [mvResult addObject: subObject];
    }

  return mvResult;
}

- (struct StringArrayW_r *) asMVUnicodeInMemCtx: (void *) memCtx
{
  struct StringArrayW_r *list;
  NSInteger count, max;

  max = [self count];

  list = talloc_zero (memCtx, struct StringArrayW_r);
  list->cValues = max;
  list->lppszW = talloc_array (list, const char *, max);

  for (count = 0; count < max; count++)
    list->lppszW[count] = [[self objectAtIndex: count] asUnicodeInMemCtx: list->lppszW];

  return list;
}

+ (id) arrayFromMVString: (const struct StringArray_r *) mvString
{
  NSUInteger count;
  id subObject;
  NSMutableArray *mvResult;

  mvResult = [NSMutableArray arrayWithCapacity: mvString->cValues];
  for (count = 0; count < mvString->cValues; count++)
    {
      subObject = [NSString stringWithUTF8String: mvString->lppszA[count]];
      [mvResult addObject: subObject];
    }

  return mvResult;
}

+ (id) arrayFromMVBinary: (const struct BinaryArray_r *) mvBinary
{
  NSUInteger count;
  id subObject;
  NSMutableArray *mvResult;

  mvResult = [NSMutableArray arrayWithCapacity: mvBinary->cValues];
  for (count = 0; count < mvBinary->cValues; count++)
    {
      subObject = [NSData dataWithBinary: mvBinary->lpbin + count];
      [mvResult addObject: subObject];
    }

  return mvResult;
}

- (struct BinaryArray_r *) asMVBinaryInMemCtx: (void *) memCtx
{
  struct BinaryArray_r *list;
  NSData *data;
  NSInteger count, max;

  max = [self count];

  list = talloc_zero (memCtx,struct BinaryArray_r);
  list->cValues = max;
  list->lpbin = talloc_array (list, struct Binary_r, max);

  for (count = 0; count < max; count++)
    {
      data = [self objectAtIndex: count];
      list->lpbin[count].cb = [data length];
      list->lpbin[count].lpb = talloc_memdup (list->lpbin, [data bytes], list->lpbin[count].cb);
    }

  return list;
}

+ (id) arrayFromMVGuid: (const struct FlatUIDArray_r *) mvGuid
{
  NSUInteger count;
  id subObject;
  NSMutableArray *mvResult;

  mvResult = [NSMutableArray arrayWithCapacity: mvGuid->cValues];
  for (count = 0; count < mvGuid->cValues; count++)
    {
      subObject = [NSData dataWithFlatUID: mvGuid->lpguid[count]];
      [mvResult addObject: subObject];
    }

  return mvResult;
}

+ (id) arrayFromMVFileTime: (const struct DateTimeArray_r *) mvFileTime
{
  NSUInteger count;
  id subObject;
  NSMutableArray *mvResult;

  mvResult = [NSMutableArray arrayWithCapacity: mvFileTime->cValues];
  for (count = 0; count < mvFileTime->cValues; count++)
    {
      subObject = [NSDate dateFromFileTime: mvFileTime->lpft + count];
      [mvResult addObject: subObject];
    }

  return mvResult;
}

@end
