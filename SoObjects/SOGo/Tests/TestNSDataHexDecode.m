/* TestNSDataHexDecode.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published
 * by the Free Software Foundation; either version 2, or (at your option)
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

#include <Foundation/Foundation.h>
#include <stdio.h>

#include "NSData+Crypto.h"

static int
Check (int condition, const char *message)
{
  if (!condition)
    {
      printf ("FAIL: %s\n", message);
      return 1;
    }

  return 0;
}

int
main (void)
{
  NSAutoreleasePool *pool;
  NSMutableString *longHex;
  NSData *result;
  int failures = 0;
  int i;

  pool = [[NSAutoreleasePool alloc] init];

  result = [NSData decodeDataFromHexString: @"00ff10"];
  failures += Check (result != nil, "valid hex input must decode");
  failures += Check ((int)[result length] == 3, "3 input bytes expected");
  failures += Check ([[NSData encodeDataAsHexString: result]
                      isEqualToString: @"00ff10"],
                     "decode/encode round-trip must be stable");

  result = [NSData decodeDataFromHexString: @"00FFaB"];
  failures += Check ([[NSData encodeDataAsHexString: result]
                      isEqualToString: @"00ffab"],
                     "uppercase hex must decode like lowercase");

  result = [NSData decodeDataFromHexString: @"zz"];
  failures += Check (result == nil, "invalid hex must return nil");

  result = [NSData decodeDataFromHexString: @"0g"];
  failures += Check (result == nil, "half-valid hex must return nil");

  result = [NSData decodeDataFromHexString: @"0"];
  failures += Check ((int)[result length] == 0,
                     "odd-length input decodes its full bytes only");

  longHex = [NSMutableString stringWithCapacity: 256];
  for (i = 0; i < 64; i++)
    [longHex appendString: @"ab"];

  result = [NSData decodeDataFromHexString: longHex];
  failures += Check ((int)[result length] == 64,
                     "long input must decode without overflow");
  failures += Check ([[NSData encodeDataAsHexString: result]
                      isEqualToString: [longHex lowercaseString]],
                     "long input round-trip must be stable");

  [longHex appendString: @"cd"];
  result = [NSData decodeDataFromHexString: longHex];
  failures += Check ((int)[result length] == 65,
                     "odd long input decodes its full bytes only");

  [pool release];

  if (failures)
    printf ("%d failure(s)\n", failures);
  else
    printf ("all tests passed\n");

  return failures ? 1 : 0;
}
