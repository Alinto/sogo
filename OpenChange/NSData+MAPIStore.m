/* NSData+MAPIStore.m - this file is part of SOGo
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

#import "NSString+MAPIStore.h"

#import "NSData+MAPIStore.h"

#undef DEBUG
#include <stdbool.h>
#include <talloc.h>
#include <util/time.h>
#include <gen_ndr/exchange.h>

@implementation NSData (MAPIStoreDataTypes)

+ (id) dataWithBinary: (const struct Binary_r *) binData
{
  return [NSData dataWithBytes: binData->lpb length: binData->cb];
}

- (struct Binary_r *) asBinaryInMemCtx: (void *) memCtx
{
  struct Binary_r *binary;
  uint8_t *lpb;

  binary = talloc_zero (memCtx, struct Binary_r);
  binary->cb = [self length];
  lpb = talloc_array (binary, uint8_t, binary->cb);
  [self getBytes: lpb];
  binary->lpb = lpb;

  return binary;
}

+ (id) dataWithShortBinary: (const struct SBinary_short *) binData
{
  return [NSData dataWithBytes: binData->lpb length: binData->cb];
}

- (struct SBinary_short *) asShortBinaryInMemCtx: (void *) memCtx
{
  struct SBinary_short *binary;
  uint8_t *lpb;

  binary = talloc_zero (memCtx, struct SBinary_short);
  binary->cb = [self length];
  lpb = talloc_array (binary, uint8_t, binary->cb);
  [self getBytes: lpb];
  binary->lpb = lpb;

  return binary;
}

+ (id) dataWithFlatUID: (const struct FlatUID_r *) flatUID
{
  return [NSData dataWithBytes: flatUID->ab length: 16];
}

- (struct FlatUID_r *) asFlatUIDInMemCtx: (void *) memCtx
{
  struct FlatUID_r *flatUID;

  flatUID = talloc_zero (memCtx, struct FlatUID_r);
  [self getBytes: flatUID->ab];

  return flatUID;
}

static void _fillFlatUIDWithGUID (struct FlatUID_r *flatUID, const struct GUID *guid)
{
  flatUID->ab[0] = (guid->time_low & 0xFF);
  flatUID->ab[1] = ((guid->time_low >> 8)  & 0xFF);
  flatUID->ab[2] = ((guid->time_low >> 16) & 0xFF);
  flatUID->ab[3] = ((guid->time_low >> 24) & 0xFF);
  flatUID->ab[4] = (guid->time_mid & 0xFF);
  flatUID->ab[5] = ((guid->time_mid >> 8)  & 0xFF);
  flatUID->ab[6] = (guid->time_hi_and_version & 0xFF);
  flatUID->ab[7] = ((guid->time_hi_and_version >> 8) & 0xFF);
  memcpy (flatUID->ab + 8,  guid->clock_seq, sizeof (uint8_t) * 2);
  memcpy (flatUID->ab + 10, guid->node, sizeof (uint8_t) * 6);
}

+ (id) dataWithGUID: (const struct GUID *) guid
{
  struct FlatUID_r flatUID;

  _fillFlatUIDWithGUID (&flatUID, guid);

  return [self dataWithFlatUID: &flatUID];
}

- (void) _extractGUID: (struct GUID *) guid
{
  uint8_t *bytes;

  bytes = (uint8_t *) [self bytes];

  guid->time_low = (bytes[3] << 24 | bytes[2] << 16
                    | bytes[1] << 8 | bytes[0]);
  guid->time_mid = (bytes[5] << 8 | bytes[4]);
  guid->time_hi_and_version = (bytes[7] << 8 | bytes[6]);
  memcpy (guid->clock_seq, bytes + 8, sizeof (uint8_t) * 2);
  memcpy (guid->node, bytes + 10, sizeof (uint8_t) * 6);
}

- (struct GUID *) asGUIDInMemCtx: (void *) memCtx
{
  struct GUID *guid;

  guid = talloc_zero (memCtx, struct GUID);
  [self _extractGUID: guid];

  return guid;
}

+ (id) dataWithXID: (const struct XID *) xid
{
  NSMutableData *xidData;
  struct FlatUID_r flatUID;

  _fillFlatUIDWithGUID (&flatUID, &xid->GUID);

  xidData = [NSMutableData dataWithCapacity: 16 + xid->Size];
  [xidData appendBytes: flatUID.ab length: 16];
  [xidData appendBytes: xid->Data length: xid->Size];

  return xidData;
}

- (struct XID *) asXIDInMemCtx: (void *) memCtx
{
  struct XID *xid;
  NSUInteger max;

  max = [self length];
  if (max > 16)
    {
      xid = talloc_zero (memCtx, struct XID);

      [self _extractGUID: &xid->GUID];

      xid->Size = max - 16;
      xid->Data = talloc_memdup (xid, [self bytes] + 16, xid->Size);
    }
  else
    {
      xid = NULL;
      abort ();
    }

  return xid;
}

+ (id) dataWithChangeKeyGUID: (NSString *) guidString
                      andCnt: (NSData *) globCnt;
{
  NSMutableData *changeKey;
  struct GUID guid;

  changeKey = [NSMutableData dataWithCapacity: 16 + [globCnt length]];

  [guidString extractGUID: &guid];
  [changeKey appendData: [NSData dataWithGUID: &guid]];
  [changeKey appendData: globCnt];

  return changeKey;
}

@end

@implementation NSMutableData (MAPIStoreDataTypes)

- (void) appendUInt8: (uint8_t) value
{
  [self appendBytes: (char *) &value length: 1];
}

- (void) appendUInt16: (uint16_t) value
{
  NSUInteger count;
  char bytes[2];

  for (count = 0; count < 2; count++)
    {
      bytes[count] = value & 0xff;
      value >>= 8;
    }

  [self appendBytes: bytes length: 2];
}

- (void) appendUInt32: (uint32_t) value
{
  NSUInteger count;
  char bytes[4];

  for (count = 0; count < 4; count++)
    {
      bytes[count] = value & 0xff;
      value >>= 8;
    }

  [self appendBytes: bytes length: 4];
}

@end
