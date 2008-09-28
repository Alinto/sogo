/* vcardtest.m - this file is part of $PROJECT_NAME_HERE$
 *
 * Copyright (C) 2006 Inverse inc.
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

#import <Foundation/Foundation.h>

#import "CardElement.h"
#import "CardGroup.h"

#import "unittest.h"

@interface subtest: unittest
{
  CardElement *element;
}
@end

@implementation subtest: unittest

- (void) setUp
{
  element = [CardElement new];
}

- (void) tearDown
{
  [element release];
}

- (BOOL) testSimpleElementWithTag_value
{
  CardElement *testElement;
  NSArray *values;

  testElement = [CardElement simpleElementWithTag: @"pouet"
                             value: @"tutu"];
  testStringsEqual([testElement tag], @"pouet");

  values = [testElement values];
  testNotEqual(values, nil);
  testEqual([values count], 1);
  testStringsEqual([values objectAtIndex: 0], @"tutu");

  return YES;
}

- (BOOL) testSimpleElementWithTag_singleType_value
{
  CardElement *testElement;
  NSArray *values, *keys;
  NSDictionary *attrs;

  testElement = [CardElement simpleElementWithTag: @"pouet"
                             singleType: @"coucou"
                             value: @"tutu"];
  testStringsEqual([testElement tag], @"pouet");

  values = [testElement values];
  testNotEqual(values, nil);
  testEqual([values count], 1);
  testStringsEqual([values objectAtIndex: 0], @"tutu");

  attrs = [testElement attributes];
  keys = [attrs allKeys];
  testEqual([keys count], 1);
  testStringsEqual([[keys objectAtIndex: 0] uppercaseString], @"TYPE");
  
  return YES;
}

- (BOOL) testElementWithTag_attributes_values
{
  NSMutableDictionary *addedAttrs;
  NSMutableArray *addedValues;
  NSArray *rValues, *keys;
  NSDictionary *rAttrs;
  CardElement *testElement;

  addedAttrs = [NSMutableDictionary new];
  [addedAttrs setObject: [NSMutableArray arrayWithObjects:
                                           @"value1", @"blabla", nil]
              forKey: @"key1"];
  [addedAttrs setObject: [NSMutableArray arrayWithObject: @"test2"]
              forKey: @"key2"];
  addedValues = [NSMutableArray new];
  [addedValues addObject: @"value1"];
  [addedValues addObject: @"pouetpouet2"];

  testElement = [CardElement elementWithTag: @"pouet"
                             attributes: addedAttrs
                             values: addedValues];


  testStringsEqual([testElement tag], @"pouet");
  rValues = [testElement values];
  rAttrs = [testElement attributes];
  keys = [rAttrs allKeys];

  testNotEqual(rValues, nil);
  testNotEqual(rAttrs, nil);
  testEqual([rValues count], 2);
  testEqual([keys count], 2);
  testNotEqual(addedValues, rValues);
  testNotEqual(addedAttrs, rAttrs);

  testStringsEqual([rValues objectAtIndex: 0], @"value1");
  testStringsEqual([rValues objectAtIndex: 1], @"pouetpouet2");
  testNotEqual([rAttrs objectForKey: @"key1"], nil);
  testNotEqual([rAttrs objectForKey: @"key2"], nil);
  testEqual([[rAttrs objectForKey: @"key1"] count], 2);
  testEqual([[rAttrs objectForKey: @"key2"] count], 1);

  testStringsEqual([[rAttrs objectForKey: @"key1"] objectAtIndex: 0],
                   @"value1");
  testStringsEqual([[rAttrs objectForKey: @"key1"] objectAtIndex: 1],
                   @"blabla");
  testStringsEqual([[rAttrs objectForKey: @"key2"] objectAtIndex: 0],
                   @"test2");

  return YES;
}

- (BOOL) testAddValue
{
  NSArray *values;

  values = [element values];
  testEqual([values count], 0);
  [element addValue: @"test"];
  testEqual([values count], 1);
  testStringsEqual([values objectAtIndex: 0], @"test");
  [element addValue: @"coucou"];
  testEqual([values count], 2);
  testStringsEqual([values objectAtIndex: 0], @"test");
  testStringsEqual([values objectAtIndex: 1], @"coucou");

  return YES;
}

- (BOOL) testAddValues
{
  NSArray *values;

  values = [element values];
  [element addValue: @"cuicui"];
  testEqual([values count], 1);

  [element addValues: [NSArray arrayWithObject: @"coucou"]];
  testEqual([values count], 2);

  [element addValue: @"cuicui2"];
  testEqual([values count], 3);
  testStringsEqual([values objectAtIndex: 1], @"coucou");
  testStringsEqual([values objectAtIndex: 2], @"cuicui2");

  return YES;
}

- (BOOL) testAddType
{
  NSMutableDictionary *attrs;
  NSArray *types;

  attrs = (NSMutableDictionary *) [element attributes];
  testEqual([attrs objectForKey: @"TYPE"], nil);
  [element addType: @"INTERNET"];
  types = [attrs objectForKey: @"type"];
  testNotEqual(types, nil);
  testEqual([types count], 1);
  testStringsEqual([types objectAtIndex: 0],
                   @"INTERNET");

  [element addType: @"pref"];
  testEqual([types count], 2);
  testStringsEqual([types objectAtIndex: 0],
                   @"INTERNET");
  testStringsEqual([types objectAtIndex: 1],
                   @"pref");

  return YES;
}

- (BOOL) testAddAttribute_value
{
  NSMutableDictionary *attrs;

  attrs = (NSMutableDictionary *) [element attributes];
  testEqual([attrs objectForKey: @"attr1"], nil);
  [element addAttribute: @"attr1" value: @"value1"];
  testNotEqual([attrs objectForKey: @"attr1"], nil);
  testEqual([[attrs objectForKey: @"attr1"] count], 1);
  testStringsEqual([[attrs objectForKey: @"attr1"] objectAtIndex: 0],
                   @"value1");

  [element addAttribute: @"attr1" value: @"value2"];
  testEqual([[attrs objectForKey: @"attr1"] count], 2);
  testStringsEqual([[attrs objectForKey: @"attr1"] objectAtIndex: 0],
                   @"value1");
  testStringsEqual([[attrs objectForKey: @"attr1"] objectAtIndex: 1],
                   @"value2");

  return YES;
}

- (BOOL) testAddAttributes
{
  NSMutableDictionary *attrs, *addedAttrs;
  NSArray *keys;

  attrs = (NSMutableDictionary *) [element attributes];
  keys = [attrs allKeys];
  testEqual([keys count], 0);

  [attrs setObject: [NSMutableArray arrayWithObject: @"test1"]
         forKey: @"key1"];
  keys = [attrs allKeys];
  testEqual([keys count], 1);

  addedAttrs = [NSMutableDictionary new];
  [addedAttrs setObject: [NSMutableArray arrayWithObject: @"test2"]
              forKey: @"key2"];
  [element addAttributes: addedAttrs];
  [addedAttrs release];
  keys = [attrs allKeys];
  testEqual([keys count], 2);
  testNotEqual([attrs objectForKey: @"key2"], nil);
  testStringsEqual([[attrs objectForKey: @"key2"] objectAtIndex: 0],
                   @"test2");

  testNotEqual([attrs objectForKey: @"key1"], nil);
  testStringsEqual([[attrs objectForKey: @"key1"] objectAtIndex: 0],
                   @"test1");
  testEqual([[attrs objectForKey: @"key1"] count], 1);
  addedAttrs = [NSMutableDictionary new];
  [addedAttrs setObject: [NSMutableArray arrayWithObject: @"test3"]
              forKey: @"key1"];
  [element addAttributes: addedAttrs];
  [addedAttrs release];
  testStringsEqual([[attrs objectForKey: @"key1"] objectAtIndex: 1],
                   @"test3");

  return YES;
}

- (BOOL) testSetValue_To
{
  NSArray *values;

  values = [element values];
  testEqual([values count], 0);

  [element setValue: 2 to: @"coucou"];
  testStringsEqual([values objectAtIndex: 0], @"");
  testStringsEqual([values objectAtIndex: 1], @"");
  testStringsEqual([values objectAtIndex: 2], @"coucou");

  [element setValue: 0 to: @"cuicui"];
  testStringsEqual([values objectAtIndex: 0], @"cuicui");
  testStringsEqual([values objectAtIndex: 1], @"");
  testStringsEqual([values objectAtIndex: 2], @"coucou");

  return YES;
}

// BEGIN:VCALENDAR
// CALSCALE:GREGORIAN
// X-WR-TIMEZONE;VALUE=TEXT:Europe/Berlin
// PRODID:-//Apple Computer\, Inc//iCal 1.0//EN
// X-WR-CALNAME;VALUE=TEXT:shire-cal1
// X-WR-RELCALID;VALUE=TEXT:C3CBA0E4-DBCC-11D6-A381-00039340AF4A
// VERSION:2.0
// BEGIN:VEVENT
// DTSTAMP:20021008T155243Z
// SUMMARY:work
// UID:C3CB87C0-DBCC-11D6-A381-00039340AF4A
// DTSTART;TZID=Europe/Berlin:20021009T120000
// DURATION:PT3H45M
// END:VEVENT
// BEGIN:VEVENT
// ATTENDEE;CN=Anja Berlin:mailto:anja.berlin@regiocom.net
// ATTENDEE;CN=Marcus Müller:mailto:mm@codeon.de
// DTSTAMP:20021009T211904Z
// SUMMARY:trink
// UID:C3CB8E9A-DBCC-11D6-A381-00039340AF4A
// ORGANIZER;CN=Helge Heß:mailto:helge.hess@skyrix.com
// DTSTART;TZID=Europe/Berlin:20021010T190000
// DURATION:PT45M
// BEGIN:VALARM
// TRIGGER;VALUE=DURATION:-PT15M
// ACTION:DISPLAY
// DESCRIPTION:Event reminder
// END:VALARM
// BEGIN:VALARM
// ATTACH;VALUE=URI:Ping
// TRIGGER;VALUE=DURATION:-PT15M
// ACTION:AUDIO
// END:VALARM
// END:VEVENT
// BEGIN:VEVENT
// DTSTAMP:20021008T155256Z
// SUMMARY:Zahnarzt
// DTEND;TZID=Europe/Berlin:20021009T110000
// UID:C3CB92B0-DBCC-11D6-A381-00039340AF4A
// DTSTART;TZID=Europe/Berlin:20021009T094500
// END:VEVENT
// BEGIN:VTODO
// DTSTAMP:20021009T154221Z
// SUMMARY:testjob
// UID:C3CB96C7-DBCC-11D6-A381-00039340AF4A
// DUE;TZID=Europe/Berlin:20021011T175228
// PRIORITY:5
// DTSTART;TZID=Europe/Berlin:20021008T175228
// END:VTODO
// BEGIN:VTODO
// UID:C3CB9A9F-DBCC-11D6-A381-00039340AF4A
// DTSTART;TZID=Europe/Berlin:20021010T000000
// DTSTAMP:20021009T154205Z
// SUMMARY:testjob2
// END:VTODO
// END:VCALENDAR

@end

int main (int argc, char **argv, char **env)
{
  NSAutoreleasePool *pool;
  subtest *test;
  int rc;

  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY  
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  test = [subtest new];
  if (test) {
    NS_DURING
      [test run];
    NS_HANDLER
      abort();
    NS_ENDHANDLER;
    
    [test release];
  }
  else
    rc = 1;
  
  [pool release];

  return rc;
}
