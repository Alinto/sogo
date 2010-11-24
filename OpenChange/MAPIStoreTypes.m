/* MAPIStoreTypes.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
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

#undef DEBUG
#include <talloc.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
#include <libmapi/libmapi.h>
#include <libmapiproxy.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSString.h>

#import "NSData+MAPIStore.h"
#import "NSCalendarDate+MAPIStore.h"

#import "MAPIStoreTypes.h"

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
      result = [NSNumber numberWithLong: value->value.l];
      break;
    case PT_BOOLEAN:
      result = [NSNumber numberWithBool: value->value.b];
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
		// lpProps->value.bin = *((const struct Binary_r *)data);

      result
        = [NSData dataWithBinary:
                    (const struct Binary_r *) &(value->value.bin)];
      break;
    default:
// #define	PT_UNSPECIFIED		0x0
// #define	PT_I2			0x2
// #define	PT_CURRENCY		0x6
// #define	PT_APPTIME		0x7
// #define	PT_ERROR		0xa
// #define	PT_OBJECT		0xd
// #define	PT_I8			0x14
// #define	PT_CLSID		0x48
// #define	PT_SVREID		0xFB
// #define	PT_SRESTRICT		0xFD
// #define	PT_ACTIONS		0xFE
      result = [NSNull null];
      NSLog (@"object type not handled: %d (0x.4x)", valueType, valueType);
    }

  return result;
}

void
MAPIStoreDumpMessageProperties (NSDictionary *properties)
{
  NSNumber *key;
  NSArray *allKeys;
  NSUInteger keyAsInt, count, max;
  const char *name;
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
          name = get_proptag_name (keyAsInt);
          if (!name)
            name = "unknown";
          NSLog (@"  0x%.8x (%s): %@ (%@)",
                 keyAsInt, name,
                 value, NSStringFromClass ([value class]));
        }
    }
}
