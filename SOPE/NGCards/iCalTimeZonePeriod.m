/* iCalTimeZonePeriod.m - this file is part of SOPE
 *
 * Copyright (C) 2006-2009 Inverse inc.
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
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>

#import "iCalDateTime.h"
#import "iCalRecurrenceRule.h"
#import "iCalByDayMask.h"
#import "iCalUTCOffset.h"

#import "iCalTimeZonePeriod.h"

@implementation iCalTimeZonePeriod

- (Class) classForTag: (NSString *) classTag
{
  Class tagClass;

  if ([classTag isEqualToString: @"RRULE"])
    tagClass = [iCalRecurrenceRule class];
  else if ([classTag isEqualToString: @"DTSTART"])
    tagClass = [iCalDateTime class];
  else if ([classTag isEqualToString: @"TZOFFSETFROM"]
           || [classTag isEqualToString: @"TZOFFSETTO"])
    tagClass = [iCalUTCOffset class];
  else if ([classTag isEqualToString: @"TZNAME"])
    tagClass = [CardElement class];
  else
    tagClass = [super classForTag: classTag];

  return tagClass;
}

- (int) _secondsOfOffset: (NSString *) offsetName
{
  NSString *offsetTo;
  BOOL negative;
  NSRange cursor;
  unsigned int length;
  unsigned int seconds;

  seconds = 0;

  offsetTo = [[self uniqueChildWithTag: offsetName]
               flattenedValuesForKey: @""];
  length = [offsetTo length];
  negative = [offsetTo hasPrefix: @"-"];
  if (negative)
    {
      length--;
      cursor = NSMakeRange(1, 2);
    }
  else if ([offsetTo hasPrefix: @"+"])
    {
      length--;
      cursor = NSMakeRange(1, 2);
    }
  else
    cursor = NSMakeRange(0, 2);

  seconds = 3600 * [[offsetTo substringWithRange: cursor] intValue];
  cursor.location += 2;
  seconds += 60 * [[offsetTo substringWithRange: cursor] intValue];
  if (length == 6)
    {
      cursor.location += 2;
      seconds += [[offsetTo substringWithRange: cursor] intValue];
    }

  return ((negative) ? -seconds : seconds);
}

// - (unsigned int) dayOfWeekFromRruleDay: (iCalWeekDay) day
// {
//   unsigned int dayOfWeek;

//   dayOfWeek = 0;
//   while (day >> (dayOfWeek + 1))
//     dayOfWeek++;

//   return dayOfWeek;
// }

- (NSCalendarDate *) startDate
{
  return [(iCalDateTime *) [self uniqueChildWithTag: @"dtstart"]
			   dateTime];
}

- (iCalRecurrenceRule *) recurrenceRule
{
  return (iCalRecurrenceRule *) [self firstChildWithTag: @"rrule"];
}

/**
 * This method returns the date corresponding for to the start of the period
 * in the year of the reference date.
 * We assume that a RRULE for a timezone will always be YEARLY with a BYMONTH
 * and a BYDAY rule.
 */
- (NSCalendarDate *) _occurrenceForDate: (NSCalendarDate *) refDate
                                byRRule: (iCalRecurrenceRule *) rrule
{
  NSCalendarDate *tmpDate;
  iCalByDayMask *byDayMask;
  int dayOfWeek, dateDayOfWeek, offset, pos;
  NSCalendarDate *tzStart;

  byDayMask = [rrule byDayMask];
  dayOfWeek = 0;

  if (byDayMask == nil)
    {
      dayOfWeek = 0;
      pos = 1;
    }
  else
    {
      dayOfWeek = (int)[byDayMask firstDay];
      pos = [byDayMask firstOccurrence];
    }
  
  tzStart = [self startDate];

  [tzStart setTimeZone: [NSTimeZone timeZoneWithName: @"GMT"]];
  tmpDate = [NSCalendarDate dateWithYear: [refDate yearOfCommonEra]
                                   month: [[[rrule byMonth] objectAtIndex: 0] intValue]
                                     day: 1 hour: [tzStart hourOfDay]
                                  minute: [tzStart minuteOfHour] second: 0
                                timeZone: [NSTimeZone timeZoneWithName: @"GMT"]];
  tmpDate = [tmpDate addYear: 0 month: ((pos > 0) ? 0 : 1)
                         day: 0 hour: 0 minute: 0
                      second: 0];
  
  /* If the day of the time change is "-XSU", we need to determine whether the
     first day of next month is in the same week. In practice, as most time
     changes occurs on sundays, it will be false only when that first day is a
     sunday, but we want to remain algorithmically exact. */
  dateDayOfWeek = [tmpDate dayOfWeek];
  if (dateDayOfWeek > dayOfWeek && pos < 0)
    pos++;

  offset = (dayOfWeek - dateDayOfWeek) + (pos * 7);
  tmpDate = [tmpDate addYear: 0 month: 0 day: offset
                        hour: 0 minute: 0 second: 0];
  
  return tmpDate;
}

- (NSCalendarDate *) occurrenceForDate: (NSCalendarDate *) refDate;
{
  NSCalendarDate *tmpDate;
  iCalRecurrenceRule *rrule;

  tmpDate = nil;
  rrule = (iCalRecurrenceRule *) [self uniqueChildWithTag: @"rrule"];

  if ([rrule isVoid])
    tmpDate
      = [(iCalDateTime *) [self uniqueChildWithTag: @"dtstart"] dateTime];
  else if ([rrule untilDate] == nil || [refDate compare: [rrule untilDate]] == NSOrderedAscending)
    tmpDate = [self _occurrenceForDate: refDate byRRule: rrule];

  return tmpDate;
}

- (int) secondsOffsetFromGMT
{
  return [self _secondsOfOffset: @"tzoffsetto"];
}

- (NSComparisonResult) compare: (iCalTimeZonePeriod *) otherPeriod
{
  return [[self startDate] compare: [otherPeriod startDate]];
}

@end
