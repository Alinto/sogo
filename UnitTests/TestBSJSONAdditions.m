/* BSJSONAdditions.m - this file is part of SOGo
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

#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

#import <SOGo/NSScanner+BSJSONAdditions.h>

#import "SOGoTest.h"

@interface TestBSJSONAdditions : SOGoTest
@end

@implementation TestBSJSONAdditions

- (void) test_scanJSONString
{
  NSScanner *testScanner;
  NSString *testStrings[] = { @"\"\\\\\"", @"\\",
                              @"\"\\u0041\"", @"A",
                              @"\"\\u000A\"", @"\n",
                              @"\"\\u000a\"", @"\n",
                              nil };
  NSString *currentString, *expected, *error;
  NSMutableString *resultString;
  int count;

  count = 0;
  while ((currentString = testStrings[count * 2]))
    {
      resultString = [NSMutableString string];
      testScanner = [NSScanner scannerWithString: currentString];
      [testScanner scanJSONString: &resultString];
      expected = testStrings[count * 2 + 1];
      error = [NSString stringWithFormat:
                          @"objects '%@' and '%@' differs (count: %d)",
                        expected, resultString, count];
      testEqualsWithMessage(expected, resultString, error);
      count++;
    }
}

@end
