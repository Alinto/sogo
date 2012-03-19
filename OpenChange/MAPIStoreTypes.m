/* MAPIStoreTypes.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSString.h>

#import "NSArray+MAPIStore.h"
#import "NSData+MAPIStore.h"
#import "NSDate+MAPIStore.h"

#import "MAPIStoreTypes.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

uint8_t *
MAPIBoolValue (void *memCtx, BOOL value)
{
  uint8_t *boolValue;

  boolValue = talloc_zero (memCtx, uint8_t);
  *boolValue = value;

  return boolValue;
}

uint32_t *
MAPILongValue (void *memCtx, uint32_t value)
{
  uint32_t *longValue;

  longValue = talloc_zero (memCtx, uint32_t);
  *longValue = value;

  return longValue;
}

uint64_t *
MAPILongLongValue (void *memCtx, uint64_t value)
{
  uint64_t *llongValue;

  llongValue = talloc_zero (memCtx, uint64_t);
  *llongValue = value;

  return llongValue;
}

double *
MAPIDoubleValue (void *memCtx, double value)
{
  double *doubleValue;

  doubleValue = talloc_zero (memCtx, double);
  *doubleValue = value;

  return doubleValue;
}

id
NSObjectFromMAPISPropValue (const struct mapi_SPropValue *value)
{
  short int valueType;
  id result;

  valueType = (value->ulPropTag & 0xffff);
  switch (valueType)
    {
    case PT_NULL:
      result = [NSNull null];
      break;
    case PT_SHORT:
      result = [NSNumber numberWithUnsignedShort: value->value.i];
      break;
    case PT_LONG:
    case PT_ERROR:
      result = [NSNumber numberWithUnsignedLong: value->value.l];
      break;
    case PT_I8:
      result = [NSNumber numberWithUnsignedLongLong: value->value.d];
      break;
    case PT_BOOLEAN:
      result = [NSNumber numberWithBool: (value->value.b ? YES : NO)];
      break;
    case PT_DOUBLE:
      result = [NSNumber numberWithDouble: value->value.dbl];
      break;
    case PT_UNICODE:
      result = [NSString stringWithUTF8String: value->value.lpszW];
      break;
    case PT_STRING8:
      result = [NSString stringWithUTF8String: value->value.lpszA];
      break;
    case PT_SYSTIME:
      result = [NSCalendarDate dateFromFileTime: &(value->value.ft)];
      break;
    case PT_BINARY:
    case PT_SVREID:
      result = [NSData dataWithShortBinary: &value->value.bin];
      break;
    case PT_CLSID:
      result = [NSData dataWithGUID: &value->value.lpguid];
      break;

    case PT_MV_LONG:
      result = [NSArray arrayFromMAPIMVLong: &value->value.MVl];
      break;
    case PT_MV_STRING8:
      result = [NSArray arrayFromMAPIMVString: &value->value.MVszA];
      break;
    case PT_MV_UNICODE:
      result = [NSArray arrayFromMAPIMVUnicode: &value->value.MVszW];
      break;
    case PT_MV_CLSID:
      result = [NSArray arrayFromMAPIMVGuid: &value->value.MVguid];
      break;
    case PT_MV_BINARY:
      result = [NSArray arrayFromMAPIMVBinary: &value->value.MVbin];
      break;

    default:
// #define	PT_UNSPECIFIED		0x0
// #define	PT_I2			0x2
// #define	PT_CURRENCY		0x6
// #define	PT_APPTIME		0x7
// #define	PT_ERROR		0xa
// #define	PT_OBJECT		0xd
// #define	PT_I8			0x14
// #define	PT_SRESTRICT		0xFD
// #define	PT_ACTIONS		0xFE
      result = [NSNull null];
      abort();
      NSLog (@"%s: object type not handled: %d (0x%.4x)",
             __PRETTY_FUNCTION__, valueType, valueType);
    }

  return result;
}

id
NSObjectFromSPropValue (const struct SPropValue *value)
{
  short int valueType;
  id result;

  valueType = (value->ulPropTag & 0xffff);
  switch (valueType)
    {
    case PT_NULL:
      result = [NSNull null];
      break;
    case PT_SHORT:
      result = [NSNumber numberWithShort: value->value.i];
      break;
    case PT_LONG:
    case PT_ERROR:
      result = [NSNumber numberWithLong: value->value.l];
      break;
    case PT_I8:
      result = [NSNumber numberWithUnsignedLongLong: value->value.d];
      break;
    case PT_BOOLEAN:
      result = [NSNumber numberWithBool: (value->value.b ? YES : NO)];
      break;
    case PT_DOUBLE:
      result = [NSNumber numberWithDouble: value->value.dbl];
      break;
    case PT_UNICODE:
      result = (value->value.lpszW
                ? [NSString stringWithUTF8String: value->value.lpszW]
                : (id) @"");
      break;
    case PT_STRING8:
      result = (value->value.lpszA
                ? [NSString stringWithUTF8String: value->value.lpszA]
                : (id) @"");
      break;
    case PT_SYSTIME:
      result = [NSCalendarDate dateFromFileTime: &(value->value.ft)];
      break;
    case PT_BINARY:
    case PT_SVREID:
		// lpProps->value.bin = *((const struct Binary_r *)data);

      result
        = [NSData dataWithBinary:
                    (const struct Binary_r *) &(value->value.bin)];
      break;
    case PT_CLSID:
      result = [NSData dataWithFlatUID: value->value.lpguid];
      break;
    case PT_MV_SHORT:
      result = [NSArray arrayFromMVShort: &value->value.MVi];
      break;
    case PT_MV_LONG:
      result = [NSArray arrayFromMVLong: &value->value.MVl];
      break;
    case PT_MV_I8:
      result = [NSArray arrayFromMVI8: &value->value.MVi8];
      break;
    case PT_MV_STRING8:
      result = [NSArray arrayFromMVString: &value->value.MVszA];
      break;
    case PT_MV_UNICODE:
      result = [NSArray arrayFromMVUnicode: &value->value.MVszW];
      break;
    case PT_MV_CLSID:
      result = [NSArray arrayFromMVGuid: &value->value.MVguid];
      break;
    case PT_MV_BINARY:
      result = [NSArray arrayFromMVBinary: &value->value.MVbin];
      break;
    case PT_MV_SYSTIME:
      result = [NSArray arrayFromMVFileTime: &value->value.MVft];
      break;

    default:
// #define	PT_UNSPECIFIED		0x0
// #define	PT_I2			0x2
// #define	PT_CURRENCY		0x6
// #define	PT_APPTIME		0x7
// #define	PT_ERROR		0xa
// #define	PT_OBJECT		0xd
// #define	PT_I8			0x14
// #define	PT_SRESTRICT		0xFD
// #define	PT_ACTIONS		0xFE
      result = [NSNull null];
      abort();
      NSLog (@"%s: object type not handled: %d (0x%.4x)",
             __PRETTY_FUNCTION__, valueType, valueType);
    }

  return result;
}

id
NSObjectFromValuePointer (enum MAPITAGS propTag, const void *data)
{
  struct SPropValue sPropValue;
  id result;

  if (set_SPropValue_proptag(&sPropValue, propTag, data))
    result = NSObjectFromSPropValue (&sPropValue);
  else
    result = nil;

  return result;
}

static uint64_t
_reverseCN (uint64_t cn)
{
  return ((cn & UINT64_C (0x00000000000000ff)) << 56
          | (cn & UINT64_C (0x000000000000ff00)) << 40
          | (cn & UINT64_C (0x0000000000ff0000)) << 24
          | (cn & UINT64_C (0x00000000ff000000)) << 8
          | (cn & UINT64_C (0x000000ff00000000)) >> 8
          | (cn & UINT64_C (0x0000ff0000000000)) >> 24
          | (cn & UINT64_C (0x00ff000000000000)) >> 40
          | (cn & UINT64_C (0xff00000000000000)) >> 56);
}

NSComparisonResult
MAPICNCompare (uint64_t cn1, uint64_t cn2, void *unused)
{
  NSComparisonResult result;

  if (cn1 == cn2)
    result = NSOrderedSame;
  else if (_reverseCN (cn1) < _reverseCN (cn2))
    result = NSOrderedAscending;
  else
    result = NSOrderedDescending;

  return result;
}

NSComparisonResult MAPIChangeKeyGUIDCompare (NSData *ck1, NSData *ck2, void *unused)
{
  NSUInteger count;
  const unsigned char *ptr1, *ptr2;
  NSComparisonResult result = NSOrderedSame;

  if ([ck1 length] < 16)
    {
      NSLog (@"ck1 has a length < 16");
      abort ();
    }
  if ([ck2 length] < 16)
    {
      NSLog (@"ck2 has a length < 16");
      abort ();
    }

  ptr1 = [ck1 bytes];
  ptr2 = [ck2 bytes];
  for (count = 0; result == NSOrderedSame && count < 16; count++)
    {
      if (*ptr1 < *ptr2)
        result = NSOrderedAscending;
      else if (*ptr1 > *ptr2)
        result = NSOrderedDescending;
      else
        {
          ptr1++;
          ptr2++;
        }
    }

  return result;
}

void
MAPIStoreDumpMessageProperties (NSDictionary *properties)
{
  NSNumber *key;
  NSArray *allKeys;
  NSUInteger keyAsInt, count, max;
  id value;

  allKeys = [properties allKeys];
  max = [allKeys count];

  NSLog (@"message properties (%d):", max);

  value = [properties objectForKey: @"recipients"];
  if (value)
    NSLog (@"  recipients: %@", value);

  for (count = 0; count < max; count++)
    {
      key = [allKeys objectAtIndex: count];
      if ([key isKindOfClass: [NSNumber class]])
        {
          keyAsInt = [key intValue];
          value = [properties objectForKey: key];
          NSLog (@"  0x%.4x: %@ (%@)",
                 keyAsInt, value,
		 NSStringFromClass ([value class]));
        }
    }
}
