/* NSString+MAPIStore.m - this file is part of SOGo
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

#include <talloc.h>
#include <stdbool.h>

#import <Foundation/NSData.h>

#import "NSString+MAPIStore.h"

#undef DEBUG
#include <mapistore/mapistore.h>

@implementation NSString (MAPIStoreDataTypes)

+ (id) stringWithGUID: (const struct GUID *) guid
{
  char *guidString;
  NSString *newString;

  guidString = GUID_string (NULL, guid);
  newString = [self stringWithUTF8String: guidString];
  talloc_free (guidString);

  return newString;
}

- (void) extractGUID: (struct GUID *) guid
{
  GUID_from_string ([self UTF8String], guid);
}

- (char *) asUnicodeInMemCtx: (void *) memCtx
{
  char *unicode;
  NSData *encoded;

  if ([self length] > 0)
    {
      encoded = [self dataUsingEncoding: NSUTF8StringEncoding];
      unicode = talloc_strndup (memCtx, [encoded bytes], [encoded length]);
    }
  else
    unicode = talloc_memdup (memCtx, "", 1);

  return unicode;
}

- (BOOL) _decodeHexByte: (uint8_t *) byte
                  atPos: (NSUInteger) pos
{
  BOOL error = NO;
  unichar byteChar;

  byteChar = [self characterAtIndex: pos];
  if (byteChar >= 48 && byteChar <= 57)
    *byte = (uint8_t) byteChar - 48;
  else if (byteChar >= 65 && byteChar <= 70)
    *byte = (uint8_t) byteChar - 55;
  else if (byteChar >= 97 && byteChar <= 102)
    *byte = (uint8_t) byteChar - 87;
  else
    error = YES;

  return error;
}

- (BOOL) _decodeHexPair: (uint8_t *) byte
                  atPos: (NSUInteger) pos
{
  BOOL error;
  uint8_t lowValue, highValue;

  error = [self _decodeHexByte: &highValue atPos: pos];
  if (!error)
    {
      error = [self _decodeHexByte: &lowValue atPos: pos + 1];
      if (!error)
        *byte = highValue << 4 | lowValue;
    }

  return error;
}

- (NSData *) convertHexStringToBytes
{
  NSUInteger count, strLen, bytesLen;
  uint8_t *bytes, *currentByte;
  NSData *decoded = nil;
  BOOL error = NO;

  strLen = [self length];
  if ((strLen % 2) == 0)
    {
      bytesLen = strLen / 2;
      bytes = NSZoneCalloc (NULL, bytesLen, sizeof (uint8_t));
      currentByte = bytes;
      for (count = 0; !error && count < strLen; count += 2)
        {
          error = [self _decodeHexPair: currentByte atPos: count];
          currentByte++;
        }
      if (error)
        NSZoneFree (NULL, bytes);
      else
        decoded = [NSData dataWithBytesNoCopy: bytes
                                       length: bytesLen
                                 freeWhenDone: YES];
    }

  return decoded;
}

@end
