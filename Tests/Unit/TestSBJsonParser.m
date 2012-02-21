/* TestSBJsonParser.m - this file is part of SOGo
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

#import <SBJson/SBJsonParser.h>

#import "SOGo/NSString+Utilities.h"

#import "SOGoTest.h"

@interface TestSBJsonParser : SOGoTest
@end

@implementation TestSBJsonParser

- (void) test_parseJSONString
{
  SBJsonParser *parser;
  NSString *currentString, *error;
  NSArray *expected;
  NSObject *resultObject;
  int count;
  NSString *testStrings[] = { @"\"\\\\\"", @"\\",
                              @"\"\\u0041\"", @"A",
                              @"\"\\u000A\"", @"\n",
                              @"\"\\u000a\"", @"\n",
                              @"\"weird data \\\\ ' \\\"; ^\"", @"weird data \\ ' \"; ^",
                              nil };

  parser = [SBJsonParser new];
  [parser autorelease];

  count = 0;
  while ((currentString = testStrings[count]))
    {
      resultObject = [parser objectWithString: [NSString stringWithFormat:
                                                           @"[%@]",
                                                         currentString]];
      expected = [NSArray arrayWithObject: testStrings[count + 1]];
      error = [NSString stringWithFormat:
                          @"objects '%@' and '%@' differs (count: %d)",
                        expected, resultObject, count];
      testEqualsWithMessage(expected, resultObject, error);
      count += 2;
    }
}

- (void) test_parseJSONNumber
{
  SBJsonParser *parser;
  NSObject *result;

  parser = [SBJsonParser new];
  [parser autorelease];

  result = [parser objectWithString: @""];
  testEquals (result, nil);

  result = [parser objectWithString: @"[ 0 ]"];
  testEquals (result, [NSArray arrayWithObject: [NSNumber numberWithInt: 0]]);
                              
  result = [parser objectWithString: @"[ -1 ]"];
  testEquals (result, [NSArray arrayWithObject: [NSNumber numberWithInt: -1]]);
  
  /* TODO: the 2 following fail because NSDecimalNumber does not implement
     "compare:" */
  result = [parser objectWithString: @"[ 12.3456 ]"];
  testEquals (result, [NSArray arrayWithObject: [NSNumber numberWithDouble: 12.3456]]);

  result = [parser objectWithString: @"[ -312.3456 ]"];
  testEquals (result, [NSArray arrayWithObject: [NSNumber numberWithDouble: -312.3456]]);
}

@end

