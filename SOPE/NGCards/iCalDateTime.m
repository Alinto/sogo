/* iCalDateTime.m - this file is part of SOPE
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

#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>

#import "NSCalendarDate+NGCards.h"
#import "NSString+NGCards.h"

#import "iCalCalendar.h"
#import "iCalTimeZone.h"

#import "iCalDateTime.h"

// static NSTimeZone *localTimeZone = nil;

@implementation iCalDateTime

// + (void) initialize
// {
//   if (!localTimeZone)
//     {
//       localTimeZone = [NSTimeZone defaultTimeZone];
//       [localTimeZone retain];
//     }
// }

// + (void) setLocalTimeZone: (NSTimeZone *) aTimeZone
// {
//   [localTimeZone release];
//   localTimeZone = aTimeZone;
//   [localTimeZone retain];
// }

- (void) setTimeZone: (iCalTimeZone *) iTZ
{
  iCalCalendar *calendar;
  NSCalendarDate *dateTime;
  NSString *newTZId;

  dateTime = [self dateTime];
  if (iTZ)
    {
      calendar
        = (iCalCalendar *) [self searchParentOfClass: [iCalCalendar class]];
      if (calendar)
        [calendar addTimeZone: iTZ];
      newTZId = [iTZ tzId];
    }
  [self setValue: 0 ofAttribute: @"tzid" to: newTZId];
  [self setDateTime: dateTime];
}

- (iCalTimeZone *) timeZone
{
  iCalCalendar *calendar;
  NSString *tzId;
  iCalTimeZone *timeZone;

  tzId = [self value: 0 ofAttribute: @"tzid"];
  calendar
    = (iCalCalendar *) [self searchParentOfClass: [iCalCalendar class]];
  if ([tzId length] && calendar)
    timeZone = [calendar timeZoneWithId: tzId];
  else
    timeZone = nil;

  return timeZone;
}

/* TODO: should implement the case where the TZ would be implicitly local
   (no TZID and no UTC) */
- (void) _setDateTime: (NSCalendarDate *) dateTime
      forAllDayEntity: (BOOL) forAllDayEntity
{
  NSCalendarDate *tmpTime;
  NSTimeZone *utcTZ;
  NSString *timeString, *fmtTimeString;
  iCalTimeZone *tz;

  if (dateTime)
    {
      tz = [self timeZone];
      if (tz)
        timeString = [tz dateTimeStringForDate: dateTime];
      else
        {
          utcTZ = [NSTimeZone timeZoneWithName: @"GMT"];

          tmpTime = [dateTime copy];
          [tmpTime setTimeZone: utcTZ];
	  if (forAllDayEntity)
	    fmtTimeString = [tmpTime iCalFormattedDateString];
	  else
	    fmtTimeString = [tmpTime iCalFormattedDateTimeString];
	  timeString = [NSString stringWithFormat: @"%@Z", fmtTimeString];
          [tmpTime release];
        }
    }
  else
    timeString = @"";

  [self setValue: 0 to: timeString];
}

- (void) setDateTime: (NSCalendarDate *) dateTime
{
  [self _setDateTime: dateTime forAllDayEntity: NO];
}

- (void) setDate: (NSCalendarDate *) dateTime
{
  [self _setDateTime: dateTime forAllDayEntity: YES];
}

- (NSCalendarDate *) dateTime
{
  iCalTimeZone *iTZ;
  NSString *date;
  NSCalendarDate *initialDate, *dateTime;
  NSTimeZone *tz;

  date = [self value: 0];
  iTZ = [self timeZone];
  if (iTZ)
    dateTime = [iTZ dateForDateTimeString: date];
  else
    {
      initialDate = [date asCalendarDate];
      if (initialDate)
        {
          if ([date hasSuffix: @"Z"] || [date hasSuffix: @"z"])
            dateTime = initialDate;
          else
            {
              /* same TODO as above */
              tz = [NSTimeZone defaultTimeZone];
              dateTime = [initialDate addYear: 0 month: 0 day: 0
                                      hour: 0 minute: 0
                                      second: -[tz secondsFromGMT]];
            }
        }
      else
        dateTime = nil;
    }

  return dateTime;
}

- (BOOL) isAllDay
{
  return [[self value: 0] isAllDayDate];
}

@end
