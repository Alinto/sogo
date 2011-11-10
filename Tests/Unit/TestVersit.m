/* TestVersit.m - this file is part of $PROJECT_NAME_HERE$
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

#import <Foundation/NSArray.h>
#import <NGCards/CardVersitRenderer.h>
#import <NGCards/CardElement.h>
#import <NGCards/CardGroup.h>

#import "SOGoTest.h"

@interface TestVersit : SOGoTest
@end

@implementation TestVersit

- (void) test_rendering
{
  CardElement *element;
  CardVersitRenderer *renderer;
  NSString *result;

  renderer = [CardVersitRenderer new];
  [renderer autorelease];

  /* 1. simple value */
  element = [CardElement elementWithTag: @"elem"];
  [element setValue: 0 to: @"value"];
  result = [renderer render: element];
  testEquals(result, @"ELEM:value\r\n");

  /* 2. two values */
  element = [CardElement elementWithTag: @"elem"];
  [element setValue: 0 to: @"value1"];
  [element setValue: 1 to: @"value2"];
  result = [renderer render: element];
  testEquals(result, @"ELEM:value1;value2\r\n");

  /* 3. one value with commma */
  element = [CardElement elementWithTag: @"elem"];
  [element setValue: 0 to: @"value1, with a comma"];
  result = [renderer render: element];
  testEquals(result, @"ELEM:value1\\, with a comma\r\n");

  /* 4. one value with a semicolon */
  element = [CardElement elementWithTag: @"elem"];
  [element setValue: 0 to: @"value1; with a semi-colon"];
  result = [renderer render: element];
  testEquals(result, @"ELEM:value1\\; with a semi-colon\r\n");

  /* 4. 3 named values:
       1. with multiple subvalues
       2. with commas
       3. with semicolon */
  element = [CardElement elementWithTag: @"elem"];
  [element setNamedValue: @"named1"
                      to: [NSArray arrayWithObjects: @"1", @"2", @"3", nil]];
  [element setNamedValue: @"named2"
                      to: @"1,2,3"];
  [element setNamedValue: @"named3"
                      to: @"text1;text2"];
  result = [renderer render: element];
  testEquals(result, @"ELEM:NAMED1=1,2,3;NAMED2=1\\,2\\,3;NAMED3:text1\\;text2\r\n");
}

- (void) test_parsing
{
  CardGroup *group;
  CardElement *element;
  NSString *versit;

  versit = @"BEGIN:group1\r\nELEMENT:value\r\nEND:group1\r\n";
  group = [CardGroup parseSingleFromSource: versit];
  element = [group firstChildWithTag: @"element"];
  testEquals([element value: 0], @"value");

  versit = @"BEGIN:group1\r\nELEMENT:value1;value2\r\nEND:group1\r\n";
  group = [CardGroup parseSingleFromSource: versit];
  element = [group firstChildWithTag: @"element"];
  testEquals([element value: 0], @"value1");
  testEquals([element value: 1], @"value2");

  versit = @"BEGIN:group1\r\nELEMENT:value\\, with comma\r\nEND:group1\r\n";
  group = [CardGroup parseSingleFromSource: versit];
  element = [group firstChildWithTag: @"element"];
  testEquals([element value: 0], @"value, with comma");

  versit = @"BEGIN:group1\r\nELEMENT:value,with comma\r\nEND:group1\r\n";
  group = [CardGroup parseSingleFromSource: versit];
  element = [group firstChildWithTag: @"element"];
  testEquals([element value: 0], ([NSArray arrayWithObjects: @"value", @"with comma", nil]));

  versit = @"BEGIN:group1\r\nELEMENT:NAMED1=subvalue;NAMED2=subvalue1,subvalue2\r\nEND:group1\r\n";
  group = [CardGroup parseSingleFromSource: versit];
  element = [group firstChildWithTag: @"element"];
  testEquals([element namedValue: @"named1"], @"subvalue");
  testEquals([element namedValue: @"named2"],
             ([NSArray arrayWithObjects: @"subvalue1", @"subvalue2", nil]));

  versit = @"BEGIN:group1\r\nELEMENT;PARAM1=test:value\r\nEND:group1\r\n";
  group = [CardGroup parseSingleFromSource: versit];
  element = [group firstChildWithTag: @"element"];
  testEquals([element value: 0], @"value");
  testEquals([element value: 0 ofAttribute: @"param1"], @"test");

  versit = @"BEGIN:group1\r\nELEMENT;PARAM1=paramvalue1,paramvalue2:value\r\nEND:group1\r\n";
  group = [CardGroup parseSingleFromSource: versit];
  element = [group firstChildWithTag: @"element"];
  testEquals([element value: 0], @"value");
  testEquals([element value: 0 ofAttribute: @"param1"], @"paramvalue1");
  testEquals([element value: 1 ofAttribute: @"param1"], @"paramvalue2");

  versit = @"BEGIN:group1\r\nELEMENT;PARAM1=\"paramvalue1, with comma\":value\r\nEND:group1\r\n";
  group = [CardGroup parseSingleFromSource: versit];
  element = [group firstChildWithTag: @"element"];
  testEquals([element value: 0], @"value");
  testEquals([element value: 0 ofAttribute: @"param1"], @"value1, with comma");
}

@end
