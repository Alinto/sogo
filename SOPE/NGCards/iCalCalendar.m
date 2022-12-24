/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSObject+Logs.h>

#import "iCalEvent.h"
#import "iCalToDo.h"
#import "iCalJournal.h"
#import "iCalFreeBusy.h"
#import "iCalTimeZone.h"

#import "iCalCalendar.h"

@interface iCalCalendar (Privates)
- (void) addToTimezones: (iCalTimeZone *) _tz;
- (void) addToTodos: (iCalToDo *) _todo;
- (void) addToJournals: (iCalJournal *) _obj;
- (void) addToFreeBusys: (iCalFreeBusy *) _obj;
@end

@implementation iCalCalendar

+ (NSArray *) parseFromSource: (id) source
{
  NSArray *result;
  NSMutableString *content;

  result = [super parseFromSource: source];

  // If parsing doesn't return any card, check if the opening tag is present but the ending tag
  // missing. Add the ending tag and parse the source again in this case.
  if ([result count] == 0 &&
      [source length] &&
      [source hasPrefix: @"BEGIN:VCALENDAR"] &&
      !([source hasSuffix: @"END:VCALENDAR\r\n"] || [source hasSuffix: @"END:VCALENDAR"]))
    {
      content = [NSMutableString stringWithString: source];
      [content appendString: @"END:VCALENDAR"];
      result = [super parseFromSource: content];
      if ([result count] > 0)
        [self logWithFormat: @"Successfully repaired VCALENDAR by adding ending tag"];
    }

  return result;
}

/* class mapping */
- (Class) classForTag: (NSString *) classTag
{
  Class tagClass;

  tagClass = Nil;
  if ([classTag isEqualToString: @"VEVENT"])
    tagClass = [iCalEvent class];
  else if ([classTag isEqualToString: @"VTODO"])
    tagClass = [iCalToDo class];
  else if ([classTag isEqualToString: @"VJOURNAL"])
    tagClass = [iCalJournal class];
  else if ([classTag isEqualToString: @"VFREEBUSY"])
    tagClass = [iCalFreeBusy class];
  else if ([classTag isEqualToString: @"VTIMEZONE"])
    tagClass = [iCalTimeZone class];
  else if ([classTag isEqualToString: @"METHOD"]
           || [classTag isEqualToString: @"PRODID"]
           || [classTag isEqualToString: @"VERSION"])
    tagClass = [CardElement class];
  else
    tagClass = [super classForTag: classTag];

  return tagClass;
}

/* accessors */

- (void) setCalscale: (NSString *) _value
{
  [[self uniqueChildWithTag: @"calscale"] setSingleValue: _value forKey: @""];
}

- (NSString *) calscale
{
  return [[self uniqueChildWithTag: @"calscale"] flattenedValuesForKey: @""];
}

- (void) setVersion: (NSString *) _value
{
  [[self uniqueChildWithTag: @"version"] setSingleValue: _value forKey: @""];
}

- (NSString *) version
{
  return [[self uniqueChildWithTag: @"version"] flattenedValuesForKey: @""];
}

- (void) setProdID: (NSString *) _value
{
  [[self uniqueChildWithTag: @"prodid"] setSingleValue: _value forKey: @""];
}

- (NSString *) prodId
{
  return [[self uniqueChildWithTag: @"prodid"] flattenedValuesForKey: @""];
}

- (void) setMethod: (NSString *) _value
{
  [[self uniqueChildWithTag: @"method"]
    setSingleValue: [_value uppercaseString]
            forKey: @""];
}

- (NSString *) method
{
  return [[self uniqueChildWithTag: @"method"] flattenedValuesForKey: @""];
} 

- (NSCalendarDate *) startDate
{
  // Parse all dtstart to find the earlier
  NSCalendarDate *calendarDate, *tmpCalendarDate;
  NSUInteger i;

  calendarDate = nil;
  if ([[self allObjects] count] > 0) {
    calendarDate = [[[[self allObjects] objectAtIndex: 0] uniqueChildWithTag: @"dtstart"] dateTime];
    for (i = 0U ; i < [[self allObjects] count] ; i++) {
      tmpCalendarDate = [[[[self allObjects] objectAtIndex: i] uniqueChildWithTag: @"dtstart"] dateTime];
      if ([tmpCalendarDate timeIntervalSince1970] < [calendarDate timeIntervalSince1970]) calendarDate = tmpCalendarDate;
    }
  }
  
  return calendarDate;
}


- (void) addToEvents: (iCalEvent *) _event
{
  [self addChild: _event];
}

- (NSArray *) events
{
  return [self childrenWithTag: @"vevent"];
}

- (void) addToTimezones: (iCalTimeZone *) _tz
{
  [self addChild: _tz];
}

- (NSArray *) timezones
{
  return [self childrenWithTag: @"vtimezone"];
}

- (void) addToTodos: (iCalToDo *) _todo
{
  [self addChild: _todo];
}

- (NSArray *) todos
{
  return [self childrenWithTag: @"vtodo"];
}

- (void) addToJournals: (iCalJournal *) _todo
{
  [self addChild: _todo];
}

- (NSArray *) journals
{
  return [self childrenWithTag: @"vjournal"];
}

- (void) addToFreeBusys: (iCalFreeBusy *) _fb
{
  [self addChild: _fb];
}

- (NSArray *) freeBusys
{
  return [self childrenWithTag: @"vfreebusy"];
}

- (BOOL) addTimeZone: (iCalTimeZone *) iTZ
{
  iCalTimeZone *possibleTz;

  possibleTz = [self timeZoneWithId: [iTZ tzId]];
  if (!possibleTz)
    [self addChild: iTZ];

  return (!possibleTz);
}

- (iCalTimeZone *) timeZoneWithId: (NSString *) tzId
{
  NSArray *matchingTimeZones;
  iCalTimeZone *timeZone;

  matchingTimeZones = [self childrenGroupWithTag: @"vtimezone"
                            withChild: @"tzid"
                            havingSimpleValue: tzId];
  if ([matchingTimeZones count])
    timeZone = [matchingTimeZones objectAtIndex: 0];
  else
    timeZone = nil;

  return timeZone;
}

/* collection */

#warning should we return timezones too?
- (NSArray *) allObjects
{
  NSMutableArray *ma;

  ma = [NSMutableArray array];
  [ma addObjectsFromArray: [self events]];
  [ma addObjectsFromArray: [self todos]];
  [ma addObjectsFromArray: [self journals]];
  [ma addObjectsFromArray: [self freeBusys]];

  return ma;
}

- (NSString *) versitString
{
  [self setVersion: @"2.0"];

  return [super versitString];
}

- (NSArray *) orderOfElements
{
  return [NSArray arrayWithObjects: @"prodid", @"version", @"method", @"calscale",
                  @"vtimezone", @"vevent", @"vtodo", @"vjournal", @"vfreebusy", nil];
}


/* ical typing */

- (NSString *) entityName
{
  return @"vcalendar";
}

@end /* iCalCalendar */
