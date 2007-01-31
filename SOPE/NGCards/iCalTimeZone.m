/* iCalTimeZone.m - this file is part of SOPE
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

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSCalendarDate.h>

#import "NSCalendarDate+NGCards.h"
#import "NSString+NGCards.h"
#import "iCalTimeZonePeriod.h"

#import "iCalTimeZone.h"

@implementation iCalTimeZone

- (Class) classForTag: (NSString *) classTag
{
  Class tagClass;

  if ([classTag isEqualToString: @"STANDARD"]
      || [classTag isEqualToString: @"DAYLIGHT"])
    tagClass = [iCalTimeZonePeriod class];
  else if ([classTag isEqualToString: @"TZID"])
    tagClass = [CardElement class];
  else
    tagClass = [super classForTag: classTag];

  return tagClass;
}

- (void) setTzId: (NSString *) tzId
{
  [[self uniqueChildWithTag: @"tzid"] setValue: 0 to: tzId];
}

- (NSString *) tzId
{
  return [[self uniqueChildWithTag: @"tzid"] value: 0];
}

- (NSCalendarDate *) _occurenceForPeriodNamed: (NSString *) pName
                                      forDate: (NSCalendarDate *) aDate
{
  NSArray *periods;
  iCalTimeZonePeriod *period;
  NSCalendarDate *occurence;

  periods = [self childrenWithTag: pName];
  if ([periods count])
    {
      period = (iCalTimeZonePeriod *) [periods objectAtIndex: 0];
      occurence = [period occurenceForDate: aDate];
    }
  else
    occurence = nil;

  return occurence;
}

- (iCalTimeZonePeriod *) periodForDate: (NSCalendarDate *) date
{
  NSCalendarDate *daylightOccurence, *standardOccurence;
  iCalTimeZonePeriod *period;

  /* FIXME, this could cause crashes when timezones are not properly
     specified, but let's say it won't happen often... */

  daylightOccurence = [self _occurenceForPeriodNamed: @"daylight"
                            forDate: date];
  standardOccurence = [self _occurenceForPeriodNamed: @"standard"
                            forDate: date];
  if ([date earlierDate: daylightOccurence] == date
      || [date earlierDate: standardOccurence] == standardOccurence)
    period = (iCalTimeZonePeriod *) [self uniqueChildWithTag: @"standard"];
  else
    period = (iCalTimeZonePeriod *) [self uniqueChildWithTag: @"daylight"];

  NSLog (@"chosen period: '%@'", [period tag]);

  return period;
}

- (NSString *) dateTimeStringForDate: (NSCalendarDate *) date
{
  NSCalendarDate *tmpDate;
  NSTimeZone *utc;

  utc = [NSTimeZone timeZoneWithName: @"GMT"];
  tmpDate = [date copy];
  [tmpDate autorelease];
  [tmpDate setTimeZone: utc];
  tmpDate
    = [tmpDate addYear: 0 month: 0 day: 0
               hour: 0 minute: 0
               second: [[self periodForDate: date] secondsOffsetFromGMT]];

  return [tmpDate iCalFormattedDateTimeString];
}

- (NSCalendarDate *) dateForDateTimeString: (NSString *) string
{
  NSCalendarDate *tmpDate;
  iCalTimeZonePeriod *period;

  tmpDate = [string asCalendarDate];
  period = [self periodForDate: tmpDate];

  return [tmpDate addYear: 0 month: 0 day: 0
                  hour: 0 minute: 0
                  second: -[period secondsOffsetFromGMT]];
}

@end
