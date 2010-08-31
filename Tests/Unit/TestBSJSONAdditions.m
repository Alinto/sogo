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
#import <Foundation/NSValue.h>

#import "SOGo/NSScanner+BSJSONAdditions.h"
#import "SOGo/NSDictionary+BSJSONAdditions.h"

#import "SOGo/NSString+Utilities.h"

#import "SOGoTest.h"

@interface TestNSScannerBSJSONAdditions : SOGoTest
@end

@implementation TestNSScannerBSJSONAdditions

- (void) test_scanJSONString
{
  NSScanner *testScanner;
  NSString *currentString, *expected, *error;
  NSMutableString *resultString;
  int count;
  NSString *testStrings[] = { @"\"\\\\\"", @"\\",
                              @"\"\\u0041\"", @"A",
                              @"\"\\u000A\"", @"\n",
                              @"\"\\u000a\"", @"\n",
                              nil };

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

- (void) test_scanJSONNumber
{
  NSScanner *testScanner;
  NSNumber *result;

  testScanner = [NSScanner scannerWithString: @""];
  [testScanner scanJSONNumber: &result];
  testEquals (result, nil);

  testScanner = [NSScanner scannerWithString: @"0"];
  [testScanner scanJSONNumber: &result];
  testEquals (result, [NSNumber numberWithInt: 0]);
                              
  testScanner = [NSScanner scannerWithString: @"-1"];
  [testScanner scanJSONNumber: &result];
  testEquals (result, [NSNumber numberWithInt: -1]);
                              
  testScanner = [NSScanner scannerWithString: @"12.3456"];
  [testScanner scanJSONNumber: &result];
  testEquals (result, [NSNumber numberWithDouble: 12.3456]);

  testScanner = [NSScanner scannerWithString: @"-312.3456"];
  [testScanner scanJSONNumber: &result];
  testEquals (result, [NSNumber numberWithDouble: -312.3456]);
}

@end

@interface TestNSDictionaryBSJSONAdditions : SOGoTest

@end

@implementation TestNSDictionaryBSJSONAdditions

- (void) test_jsonStringForString
{
  NSDictionary *testDictionary;
  NSString *currentString, *resultString, *expected, *error;
  int count;
  NSString *testStrings[] = { @"\n", @"\"\\n\"",
                              @"\\", @"\"\\\\\"",
                              nil };

  testDictionary = [NSDictionary dictionary];
  count = 0;
  while ((currentString = testStrings[count * 2]))
    {
      resultString = [testDictionary jsonStringForString: currentString];
      expected = testStrings[count * 2 + 1];
      error = [NSString stringWithFormat:
                          @"objects '%@' and '%@' differs (count: %d)",
                        expected, resultString, count];
      testEqualsWithMessage(expected, resultString, error);
      count++;
    }
}

@end

