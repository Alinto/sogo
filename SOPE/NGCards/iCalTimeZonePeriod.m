/* iCalTimeZonePeriod.m - this file is part of SOPE
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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>

#import "iCalDateTime.h"
#import "iCalRecurrenceRule.h"

#import "iCalTimeZonePeriod.h"

@implementation iCalTimeZonePeriod

- (Class) classForTag: (NSString *) classTag
{
  Class tagClass;

  if ([classTag isEqualToString: @"RRULE"])
    tagClass = [iCalRecurrenceRule class];
  else if ([classTag isEqualToString: @"DTSTART"])
    tagClass = [iCalDateTime class];
  else if ([classTag isEqualToString: @"TZNAME"]
           || [classTag isEqualToString: @"TZOFFSETFROM"]
           || [classTag isEqualToString: @"TZOFFSETTO"])
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
               value: 0];
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

- (unsigned int) dayOfWeekFromRruleDay: (iCalWeekDay) day
{
  unsigned int dayOfWeek;

  dayOfWeek = 0;
  while (day >> (dayOfWeek + 1))
    dayOfWeek++;

  return dayOfWeek;
}

- (NSCalendarDate *) _occurenceForDate: (NSCalendarDate *) refDate
			       byRRule: (iCalRecurrenceRule *) rrule
{
  NSCalendarDate *tmpDate;
  NSString *byDay;
  int dayOfWeek, dateDayOfWeek, offset, pos;

  byDay = [rrule namedValue: @"byday"];
  dayOfWeek = [self dayOfWeekFromRruleDay: [rrule byDayMask]];
  pos = [[byDay substringToIndex: 2] intValue];
  if (!pos)
    pos = 1;

  tmpDate = [NSCalendarDate dateWithYear: [refDate yearOfCommonEra]
			    month: [[rrule namedValue: @"bymonth"] intValue]
			    day: 1 hour: 0 minute: 0 second: 0
			    timeZone: [NSTimeZone timeZoneWithName: @"GMT"]];
  tmpDate = [tmpDate addYear: 0 month: ((pos > 0) ? 0 : 1)
		     day: 0 hour: 0 minute: 0
		     second: -[self _secondsOfOffset: @"tzoffsetfrom"]];
  dateDayOfWeek = [tmpDate dayOfWeek];
// #warning FIXME
  offset = (dayOfWeek - dateDayOfWeek) + ((pos -1 ) * 7);
  tmpDate = [tmpDate addYear: 0 month: 0 day: offset
		     hour: 0 minute: 0 second: 0];

  return tmpDate;
}

- (NSCalendarDate *) occurenceForDate: (NSCalendarDate *) refDate;
{
  NSCalendarDate *tmpDate;
  iCalRecurrenceRule *rrule;

  rrule = (iCalRecurrenceRule *) [self uniqueChildWithTag: @"rrule"];
  if ([rrule isVoid])
    tmpDate
      = [(iCalDateTime *) [self uniqueChildWithTag: @"dtstart"] dateTime];
  else
    tmpDate = [self _occurenceForDate: refDate byRRule: rrule];

  return tmpDate;
}

- (int) secondsOffsetFromGMT
{
  return [self _secondsOfOffset: @"tzoffsetto"];
}

@end
