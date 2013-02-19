/* NSString+MAPIStore.m - this file is part of SOGo
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

#include <talloc.h>
#include <stdbool.h>

#import <Foundation/NSData.h>

#import "NSString+MAPIStore.h"

#undef DEBUG
#include <talloc.h>
#include <util/time.h>
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

- (char) _decodeHexByte: (char) byteChar
{
  char newByte;

  if (byteChar >= 48 && byteChar <= 57)
    newByte = (uint8_t) byteChar - 48;
  else if (byteChar >= 65 && byteChar <= 70)
    newByte = (uint8_t) byteChar - 55;
  else if (byteChar >= 97 && byteChar <= 102)
    newByte = (uint8_t) byteChar - 87;
  else
    newByte = -1;

  return newByte;
}

- (BOOL) _decodeHexByte: (uint8_t *) byte
                  atPos: (NSUInteger) pos
{
  BOOL error = NO;
  char newByte;
  unichar byteChar;

  byteChar = [self characterAtIndex: pos];
  if (byteChar < 256)
    {
      newByte = [self _decodeHexByte: (char) byteChar];
      if (newByte == -1)
        error = YES;
      else
        *byte = newByte;
    }
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

- (NSString *) stringByReplacingPercentEscapesUsingEncoding: (NSStringEncoding) encoding
{
  NSString *newString;
  NSData *data;
  NSUInteger count, length, newCount;
  const char *bytes;
  char *newBytes;
  char newByte0, newByte1;

  data = [self dataUsingEncoding: NSASCIIStringEncoding];
  if (data)
    {
      length = [data length];
      bytes = [data bytes];
      newBytes = NSZoneMalloc (NULL, sizeof (char) * length);
      newCount = 0;
      for (count = 0; count < length; count++)
        {
          if (bytes[count] == '%')
            {
              newByte0 = [self _decodeHexByte: bytes[count+1]];
              newByte1 = [self _decodeHexByte: bytes[count+2]];
              if ((newByte0 != -1) && (newByte1 != -1))
                {
                  newBytes[newCount] = (((newByte0 << 4) & 0xf0)
                                        | (newByte1 & 0x0f));
                  count += 2;
                }
              else
                newBytes[newCount] = bytes[count];
            }
          else
            newBytes[newCount] = bytes[count];
          newCount++;
        }

      data = [NSData dataWithBytesNoCopy: newBytes length: newCount freeWhenDone: YES];
      newString = [[NSString alloc]
                    initWithData: data encoding: encoding];
      [newString autorelease];
    }
  else
    newString = nil;

  return newString;
}

@end
