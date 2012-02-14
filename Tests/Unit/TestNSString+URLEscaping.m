/* TestNSString+URLEscaping.m - this file is part of $PROJECT_NAME_HERE$
 *
 * Copyright (C) 2011 Inverse inc
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

/* This file is encoded in utf-8. */

#import <NGExtensions/NSString+misc.h>

#import "SOGoTest.h"

@interface TestNSString_plus_URLEscaping : SOGoTest
@end

@implementation TestNSString_plus_URLEscaping

- (void) test_stringByEscapingURL
{
  const char *inStrings[] = { "éléphant", "2š", "sogo+test", NULL };
  const char **inString;
  NSString *outStrings[] = { @"%C3%A9l%C3%A9phant", @"2%C5%A1", @"sogo+test" };
  NSString **outString;
  NSString *result, *error;

  inString = inStrings;
  outString = outStrings;
  while (*inString)
    {
      result = [[NSString stringWithUTF8String: *inString] stringByEscapingURL];
      error = [NSString stringWithFormat:
                          @"string '%s' badly escaped: '%@' (expected '%@')",
                        *inString, result, *outString];
      testWithMessage([result isEqualToString: *outString], error);
      inString++;
      outString++;
    }
}

@end
