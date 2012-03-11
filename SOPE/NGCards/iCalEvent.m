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

#import <Foundation/NSDictionary.h>

#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NGCalendarDateRange.h>

#import "NSCalendarDate+NGCards.h"
#import "NSString+NGCards.h"

#import "iCalEventChanges.h"
#import "iCalDateTime.h"
#import "iCalRecurrenceRule.h"
#import "iCalRecurrenceCalculator.h"

#import "iCalEvent.h"

@implementation iCalEvent

- (Class) classForTag: (NSString *) classTag
{
  Class tagClass;

  if ([classTag isEqualToString: @"DURATION"]
      || [classTag isEqualToString: @"TRANSP"])
    tagClass = [CardElement class];
  else if ([classTag isEqualToString: @"DTEND"])
    tagClass = [iCalDateTime class];
  else
    tagClass = [super classForTag: classTag];

  return tagClass;
}

/* accessors */
- (void) setAllDayWithStartDate: (NSCalendarDate *) newStartDate
		       duration: (unsigned int) days
{
  NSCalendarDate *endDate;
  CardElement *c;

  [(iCalDateTime *) [self uniqueChildWithTag: @"dtstart"]
		    setDate: newStartDate];
  // HACK: we add 1 hour to avoid losing a day on time shift dates
  endDate = [newStartDate dateByAddingYears: 0 months: 0 days: days
				hours: 1 minutes: 0 seconds: 0];
  [endDate setTimeZone: [newStartDate timeZone]];
  [(iCalDateTime *) [self uniqueChildWithTag: @"dtend"]
		    setDate: endDate];

  c = [self uniqueChildWithTag: @"duration"];
  if (c)
    [self removeChild: c];
}

- (void) setEndDate: (NSCalendarDate *) newEndDate
{
  [(iCalDateTime *) [self uniqueChildWithTag: @"dtend"]
		    setDateTime: newEndDate];
}

- (NSCalendarDate *) endDate
{
  NSCalendarDate *endDate;
  NSString *duration;

  endDate = [(iCalDateTime *) [self uniqueChildWithTag: @"dtend"]
			      dateTime];
  if (!endDate)
    {
      endDate = [self startDate];
      duration = [self duration];
      if ([duration length])
	endDate
	  = [endDate addTimeInterval: [duration durationAsTimeInterval]];
    }

  return endDate;
}

- (BOOL) hasEndDate
{
  return ([[self childrenWithTag: @"dtend"] count] > 0);
}

- (void) setDuration: (NSString *) _value
{
  [[self uniqueChildWithTag: @"duration"] setSingleValue: _value forKey: @""];
}

- (NSString *) duration
{
  return [[self uniqueChildWithTag: @"duration"] flattenedValuesForKey: @""];
}

- (BOOL) hasDuration
{
  return ([[self duration] length] > 0);
}

- (NSTimeInterval) durationAsTimeInterval
{
  /*
    eg: DURATION:PT1H
    P      - "period"
    P2H30M - "2 hours 30 minutes"

     dur-value  = (["+"] / "-") "P" (dur-date / dur-time / dur-week)

     dur-date   = dur-day [dur-time]
     dur-time   = "T" (dur-hour / dur-minute / dur-second)
     dur-week   = 1*DIGIT "W"
     dur-hour   = 1*DIGIT "H" [dur-minute]
     dur-minute = 1*DIGIT "M" [dur-second]
     dur-second = 1*DIGIT "S"
     dur-day    = 1*DIGIT "D"
  */
  NSTimeInterval interval;

  if ([self hasDuration])
    interval = [[self duration] durationAsTimeInterval];
  else if ([self hasEndDate] && [self hasStartDate])
    /* calculate duration using enddate */
    interval = [[self endDate] timeIntervalSinceDate: [self startDate]];
  else
    interval = 0.0;

  return interval;
}

- (void) setTransparency: (NSString *) _value
{
  [[self uniqueChildWithTag: @"transp"] setSingleValue: _value forKey: @""];
}

- (NSString *) transparency
{
  return [[self uniqueChildWithTag: @"transp"] flattenedValuesForKey: @""];
}

/* convenience */

- (BOOL) isOpaque
{
  NSString *s;
  
  s = [[self transparency] uppercaseString];

  return (![s isEqualToString: @"TRANSPARENT"]);
}

- (BOOL) isAllDay
{
  return [(iCalDateTime *) [self uniqueChildWithTag: @"dtstart"] isAllDay];
}

- (BOOL) isWithinCalendarDateRange: (NGCalendarDateRange *) _range
{
  NGCalendarDateRange *r;
  NSCalendarDate *startDate, *endDate;
  NGCalendarDateRange *fir;

  startDate = [self startDate];
  endDate = [self endDate];

  if (![self isRecurrent])
    {
      if ([self hasStartDate] && [self hasEndDate])
        {
          r = [NGCalendarDateRange calendarDateRangeWithStartDate: startDate
                                   endDate: endDate];
          return [_range containsDateRange: r];
        }
      else
        return [_range containsDate: startDate];
    }
  else
    {
      fir = [NGCalendarDateRange calendarDateRangeWithStartDate:startDate
                                 endDate: endDate];
    
      return [self isWithinCalendarDateRange: _range
                   firstInstanceCalendarDateRange: fir];
    }

  return NO;
}

- (NSArray *) recurrenceRangesWithinCalendarDateRange: (NGCalendarDateRange *)_r
{
  NGCalendarDateRange *fir;
  
  if (![self isRecurrent])
    return nil;

  fir = [NGCalendarDateRange calendarDateRangeWithStartDate: [self startDate]
                             endDate: [self endDate]];
  return [self recurrenceRangesWithinCalendarDateRange:_r
               firstInstanceCalendarDateRange:fir];
}

- (NSCalendarDate *) lastPossibleRecurrenceStartDate
{
  NGCalendarDateRange *fir;

  if (![self isRecurrent])
    return nil;

  fir = [NGCalendarDateRange calendarDateRangeWithStartDate: [self startDate]
                             endDate: [self endDate]];

  return [self lastPossibleRecurrenceStartDateUsingFirstInstanceCalendarDateRange: fir];
}

/* ical typing */

- (NSString *) entityName
{
  return @"vevent";
}

/* descriptions */

// - (NSString *) description {
//   NSMutableString *ms;

//   ms = [NSMutableString stringWithCapacity:128];
//   [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

//   if (uid)       [ms appendFormat:@" uid=%@", uid];
//   if (startDate) [ms appendFormat:@" from=%@", startDate];
//   if (endDate)   [ms appendFormat:@" to=%@", endDate];
//   if (summary)   [ms appendFormat:@" summary=%@", summary];
  
//   if (organizer)
//     [ms appendFormat:@" organizer=%@", organizer];
//   if (attendees)
//     [ms appendFormat:@" attendees=%@", attendees];
  
//   if ([self hasAlarms])
//     [ms appendFormat:@" alarms=%@", alarms];
  
//   [ms appendString:@">"];
//   return ms;
// }

/* changes */

- (iCalEventChanges *) getChangesRelativeToEvent: (iCalEvent *) _event
{
  return [iCalEventChanges changesFromEvent: _event
                           toEvent: self];
}

- (id) propertyValue: (NSString *) property
{
  static NSDictionary *propertyMethods = nil;
  NSString *method;

  if (!propertyMethods)
    {
      propertyMethods = [NSDictionary dictionaryWithObjectsAndKeys:
                                        @"durationAsTimeInterval", @"duration",
                                      @"recurrenceRules", @"rrule",
                                      @"exceptionRules", @"exrule",
                                      @"exceptionDates", @"exdate",
                                      nil];
      [propertyMethods retain];
    }
  method = [propertyMethods objectForKey: property];
  if (!method)
    method = property;

  return [self performSelector: NSSelectorFromString (method)];
}

- (NSCalendarDate *) firstRecurrenceStartDate
{
  return [self firstRecurrenceStartDateWithEndDate: [self endDate]];
}


@end /* iCalEvent */
