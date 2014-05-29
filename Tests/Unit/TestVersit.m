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
  NSString *error;

  renderer = [CardVersitRenderer new];
  [renderer autorelease];

  /* 1. simple value */
  element = [CardElement elementWithTag: @"elem"];
  [element setSingleValue: @"value" forKey: @""];
  result = [renderer render: element];
  testEquals(result, @"ELEM:value\r\n");

  /* 2. two values */
  element = [CardElement elementWithTag: @"elem"];
  [element setSingleValue: @"value2" atIndex: 1
                   forKey: @""];
  [element setSingleValue: @"value1" atIndex: 0
                   forKey: @""];
  result = [renderer render: element];
  testEquals(result, @"ELEM:value1;value2\r\n");

  /* 3. one value with commma */
  element = [CardElement elementWithTag: @"elem"];
  [element setSingleValue: @"value1, with a comma" forKey: @""];
  result = [renderer render: element];
  testEquals(result, @"ELEM:value1\\, with a comma\r\n");

  /* 4. one value with a semicolon */
  element = [CardElement elementWithTag: @"elem"];
  [element setSingleValue: @"value1; with a semi-colon" forKey: @""];
  result = [renderer render: element];
  testEquals(result, @"ELEM:value1\\; with a semi-colon\r\n");

  /* 5. 3 named values:
       1. with multiple subvalues
       2. with commas
       3. with semicolon */
  element = [CardElement elementWithTag: @"elem"];
  [element setValues: [NSArray arrayWithObjects: @"1", @"2", @"3", nil]
           atIndex: 0 forKey: @"named1"];
  [element setSingleValue: @"1,2,3" forKey: @"named2"];
  [element setSingleValue: @"text1;text2" forKey: @"named3"];
  result = [renderer render: element];
  error = [NSString stringWithFormat: @"string '%@' elements not the same as in 'ELEM:NAMED1=1,2,3;NAMED2=1\\,2\\,3;NAMED3=text1\\;text2'",
                    result];
  testWithMessage([result isEqual: @"ELEM:NAMED1=1,2,3;NAMED2=1\\,2\\,3;NAMED3=text1\\;text2\r\n"]
                  || [result isEqual: @"ELEM:NAMED3=text1\\;text2;NAMED1=1,2,3;NAMED2=1\\,2\\,3\r\n"],
                  error);

  /* 6. values with 1 ordered value with a whitespace starting subvalues */
  element = [CardElement elementWithTag: @"elem"];
  [element setValues: [NSArray arrayWithObjects: @"", @"1", nil]
           atIndex: 0 forKey: @""];
  result = [renderer render: element];
  testEquals(result, @"ELEM:1\r\n");

  /* 7. values with 1 ordered value with a subvalue, a whitespace and another subvalue */
  element = [CardElement elementWithTag: @"elem"];
  [element setValues: [NSArray arrayWithObjects: @"1", @"", @"2", nil]
           atIndex: 0 forKey: @""];
  result = [renderer render: element];
  testEquals(result, @"ELEM:1,2\r\n");

  /* 8.a. values with 1 empty ordered value and another non-empty one */
  element = [CardElement elementWithTag: @"elem"];
  [element setValues: [NSArray arrayWithObjects: nil]
           atIndex: 0 forKey: @""];
  [element setValues: [NSArray arrayWithObjects: @"1", nil]
           atIndex: 1 forKey: @""];
  result = [renderer render: element];
  testEquals(result, @"ELEM:;1\r\n");

  /* 8.b. a variant thereof: array with spaces */
  [element setValues: [NSArray arrayWithObjects: @"", @"", nil]
           atIndex: 0 forKey: @""];
  result = [renderer render: element];
  testEquals(result, @"ELEM:;1\r\n");
  
  /* 8.c. a variant thereof: nil array */
  [element setValues: nil atIndex: 0 forKey: @""];
  result = [renderer render: element];
  testEquals(result, @"ELEM:;1\r\n");
  
  /* 9. values with 1 non-empty ordered value and another empty one */
  element = [CardElement elementWithTag: @"elem"];
  [element setValues: [NSArray arrayWithObjects: @"1", nil]
           atIndex: 0 forKey: @""];
  [element setValues: [NSArray arrayWithObjects: nil]
           atIndex: 1 forKey: @""];
  result = [renderer render: element];
  testEquals(result, @"ELEM:1\r\n");

  /* 10. named values with 1 nil value, 1 empty value and another non-nil one */
  element = [CardElement elementWithTag: @"elem"];
  [element setSingleValue: nil forKey: @"empty"];
  [element setSingleValue: nil forKey: @"empty2"];
  [element setSingleValue: @"coucou" forKey: @"nonempty"];
  result = [renderer render: element];
  testEquals(result, @"ELEM:NONEMPTY=coucou\r\n");

  /** tests about parameters handling could be nice */
}

- (void) test_parsing
{
  CardGroup *group;
  CardElement *element;
  NSString *versit;

  versit = @"BEGIN:GROUP1\r\nELEMENT:value\r\nEND:GROUP1";
  group = [CardGroup parseSingleFromSource: versit];
  testEquals([group versitString], versit);
  element = [group firstChildWithTag: @"element"];
  testEquals([element flattenedValueAtIndex: 0 forKey: @""], @"value");

  versit = @"BEGIN:GROUP1\r\nN:value1;value2\r\nEND:GROUP1";
  group = [CardGroup parseSingleFromSource: versit];
  testEquals([group versitString], versit);
  element = [group firstChildWithTag: @"n"];
  testEquals([element flattenedValueAtIndex: 0 forKey: @""], @"value1");
  testEquals([element flattenedValueAtIndex: 1 forKey: @""], @"value2");

  versit = @"BEGIN:GROUP1\r\nELEMENT:value\\, with comma\r\nEND:GROUP1";
  group = [CardGroup parseSingleFromSource: versit];
  testEquals([group versitString], versit);
  element = [group firstChildWithTag: @"element"];
  testEquals([element flattenedValueAtIndex: 0 forKey: @""], @"value, with comma");

  versit = @"BEGIN:GROUP1\r\nELEMENT:value,with comma\r\nEND:GROUP1";
  group = [CardGroup parseSingleFromSource: versit];
  testEquals([group versitString], versit);
  element = [group firstChildWithTag: @"element"];
  testEquals([element valuesAtIndex: 0 forKey: @""], ([NSArray arrayWithObjects: @"value", @"with comma", nil]));

  versit = @"BEGIN:GROUP1\r\nN:NAMED1=subvalue;NAMED2=subvalue1,subvalue2\r\nEND:GROUP1";
  group = [CardGroup parseSingleFromSource: versit];
  /* we avoid this test here as nothing guarantees that the order of named
     values will be preserved... */
  // testEquals([group versitString], versit);
  element = [group firstChildWithTag: @"n"];
  testEquals([element flattenedValueAtIndex: 0 forKey: @"NAMED1"], @"subvalue");
  testEquals([element valuesAtIndex: 0 forKey: @"named2"],
             ([NSArray arrayWithObjects: @"subvalue1", @"subvalue2", nil]));

  versit = @"BEGIN:GROUP1\r\nELEMENT;PARAM1=test:value\r\nEND:GROUP1";
  group = [CardGroup parseSingleFromSource: versit];
  testEquals([group versitString], versit);
  element = [group firstChildWithTag: @"element"];
  testEquals([element flattenedValueAtIndex: 0 forKey: @""], @"value");
  testEquals([element value: 0 ofAttribute: @"param1"], @"test");

  versit = @"BEGIN:GROUP1\r\nELEMENT;PARAM1=paramvalue1,paramvalue2:value\r\nEND:GROUP1";
  group = [CardGroup parseSingleFromSource: versit];
  testEquals([group versitString], versit);
  element = [group firstChildWithTag: @"element"];
  testEquals([element flattenedValueAtIndex: 0 forKey: @""], @"value");
  testEquals([element value: 0 ofAttribute: @"param1"], @"paramvalue1");
  testEquals([element value: 1 ofAttribute: @"param1"], @"paramvalue2");

  versit = @"BEGIN:GROUP1\r\nELEMENT;PARAM1=paramvalue1\\, with comma:value\r\nEND:GROUP1";
  group = [CardGroup parseSingleFromSource: versit];
  testEquals([group versitString], versit);
  element = [group firstChildWithTag: @"element"];
  testEquals([element flattenedValueAtIndex: 0 forKey: @""], @"value");
  testEquals([element value: 0 ofAttribute: @"param1"], @"paramvalue1, with comma");
}

@end
