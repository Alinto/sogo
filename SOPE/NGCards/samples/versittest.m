/* versittest.m - this file is part of $PROJECT_NAME_HERE$
 *
 * Copyright (C) 2006 Inverse groupe conseil
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
#import "CardVersitRenderer.h"
#import "NSString+NGCards.h"

#import "unittest.h"

@interface versittest : unittest

@end

@implementation versittest

- (BOOL) testRendering
{
  NSLog (@"rendering>");
  CardVersitRenderer *renderer;
  CardGroup *g, *g2;
  CardElement *e;

  g = [CardGroup groupWithTag: @"VCALENDAR"];
  e = [CardElement simpleElementWithTag: @"CALSCALE"
                   value: @"GREGORIAN"];
  [g addChild: e];
  e = [CardElement simpleElementWithTag: @"X-WR-TIMEZONE"
                   value: @"Europe/Berlin"];
  [e addAttribute: @"VALUE" value: @"TEXT"];
  [g addChild: e];
  e = [CardElement simpleElementWithTag: @"PRODID"
                   value: @"-//Apple Computer, Inc//iCal 1.0//EN"];
  [g addChild: e];
  e = [CardElement simpleElementWithTag: @"X-WR-CALNAME"
                   value: @"shire-cal1"];
  [e addAttribute: @"VALUE" value: @"TEXT"];
  [e setGroup: @"item1"];
  [g addChild: e];
  e = [CardElement simpleElementWithTag: @"X-WR-RELCALID"
                   value: @"C3CBA0E4-DBCC-11D6-A381-00039340AF4A"];
  [e addAttribute: @"VALUE" value: @"TEXT"];
  [g addChild: e];
  e = [CardElement simpleElementWithTag: @"VERSION"
                   value: @"2.0"];
  [g addChild: e];

  g2 = [CardGroup groupWithTag: @"VEVENT"];
  e = [CardElement simpleElementWithTag: @"DTSTAMP"
                   value: @"20021008T155243Z"];
  [g2 addChild: e];
  e = [CardElement simpleElementWithTag: @"SUMMARY"
                   value: @"work"];
  [g2 addChild: e];
  e = [CardElement simpleElementWithTag: @"UID"
                   value: @"C3CB87C0-DBCC-11D6-A381-00039340AF4A"];
  [g2 addChild: e];
  e = [CardElement simpleElementWithTag: @"DTSTART"
                   value: @"20021009T120000"];
  [e addAttribute: @"TZID" value: @"Europe/Berlin"];
  [g2 addChild: e];
  e = [CardElement simpleElementWithTag: @"DURATION"
                   value: @"PT3H45M"];
  [g2 addChild: e];
  [g addChild: g2];

  g2 = [CardGroup groupWithTag: @"VEVENT"];
  e = [CardElement simpleElementWithTag: @"ATTENDEE"
                   value: @"mailto:anja.berlin@regiocom.net"];
  [e addAttribute: @"CN" value: @"Anja Berlin"];
  [g2 addChild: e];
  e = [CardElement simpleElementWithTag: @"ATTENDEE"
                   value: @"mailto:mm@codeon.de"];
  [e addAttribute: @"CN" value: @"Marcus Müller"];
  [g2 addChild: e];
  e = [CardElement simpleElementWithTag: @"DTSTAMP"
                   value: @"20021009T211904Z"];
  [g2 addChild: e];
  e = [CardElement simpleElementWithTag: @"SUMMARY"
                   value: @"trink"];
  [g2 addChild: e];
  e = [CardElement simpleElementWithTag: @"UID"
                   value: @"C3CB8E9A-DBCC-11D6-A381-00039340AF4A"];
  [g2 addChild: e];
  e = [CardElement simpleElementWithTag: @"ORGANIZER"
                   value: @"mailto:helge.hess@skyrix.com"];
  [e addAttribute: @"CN" value: @"Helge Heß"];
  [g2 addChild: e];
  e = [CardElement simpleElementWithTag: @"DTSTART"
                   value: @"20021010T190000"];
  [e addAttribute: @"TZID" value: @"Europe/Berlin"];
  [g2 addChild: e];
  e = [CardElement simpleElementWithTag: @"DURATION"
                   value: @"PT45M"];
  [g2 addChild: e];
  [g addChild: g2];

  renderer = [CardVersitRenderer new];
  NSLog (@"\n\n%@\n", [renderer render: g]);
  [renderer release];

  NSLog (@"<done");

  return YES;
}

- (BOOL) testNSStringFoldedForVersitCards
{
  NSString *shortString, *longString, *foldedString;

  shortString = @"PATATE";
  testStringsEqual(shortString, [shortString foldedForVersitCards]);
  
  longString = @"blabla PATATE blabla PATATE blabla PATATE blabla PATATE blabla PATATE blabl"
    @"a PATATE blabla PATATE blabla PATATE blabla PATATE blabla PATATE blabla PA"
    @"TATE blabla PATATE blabla PATATE blabla PATATE blabla PATATE blabla PATATE"
    @"blabla PATATE blabla PATATE blabla PATATE";

  foldedString = @"blabla PATATE blabla PATATE blabla PATATE blabla PATATE blabla PATATE blabl\r\n"
    @" a PATATE blabla PATATE blabla PATATE blabla PATATE blabla PATATE blabla PA\r\n"
    @" TATE blabla PATATE blabla PATATE blabla PATATE blabla PATATE blabla PATATE\r\n"
    @" blabla PATATE blabla PATATE blabla PATATE";

  testStringsEqual(foldedString, [longString foldedForVersitCards]);

  return YES;
}

- (BOOL) testNSStringAsCardValues
{
  NSString *values[5];
  NSArray *array[5];
  NSArray *testarray[5];
  unsigned int i, count, max;

// patate,pouetpouet
  values[0] = @"patate,pouetpouet";
// patate\,pouetpouet
  values[1] = @"patate\\,pouetpouet";
// patate\\,pouetpouet
  values[2] = @"patate\\\\,pouetpouet";
// patate\\\,pouetpouet
  values[3] = @"patate\\\\\\,pouetpouet";
// patate,pouetpouet
  values[4] = @"patate, pouetpouet";

  testarray[0] = [NSArray arrayWithObjects: @"patate", @"pouetpouet", nil];
  testarray[1] = [NSArray arrayWithObjects: @"patate,pouetpouet", nil];
// should give [ @"patate\\", @"pouetpouet" ] instead...:
  testarray[2] = [NSArray arrayWithObjects: @"patate\\,pouetpouet", nil];
  testarray[3] = [NSArray arrayWithObjects: @"patate\\\\,pouetpouet", nil];
  testarray[4] = [NSArray arrayWithObjects: @"patate", @"pouetpouet", nil];

  for (i = 0; i < (sizeof(values) / sizeof(NSString *)); i++)
    {
      array[i] = [values[i] asCardAttributeValues];
      max = [testarray[i] count];
      for (count = 0; count < max; count++)
        testStringsEqual([testarray[i] objectAtIndex: count],
                         [array[i] objectAtIndex: count]);
    }

  return YES;
}

@end

int main (int argc, char **argv, char **env)
{
  NSAutoreleasePool *pool;
  versittest *test;
  int rc;

  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY  
  [NSProcessInfo initializeWithArguments: argv
                 count: argc
                 environment: env];
#endif
  
  test = [versittest new];
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
