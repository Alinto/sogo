/* NSCalendarDate+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2019 Inverse inc.
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

#import <Foundation/NSTimeZone.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSCalendarDate+misc.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import "NSCalendarDate+SOGo.h"

static NSString *rfc822Days[] = {@"Sun", @"Mon", @"Tue", @"Wed", @"Thu",
			         @"Fri", @"Sat"};
static NSString *rfc822Months[] = {@"", @"Jan", @"Feb", @"Mar", @"Apr",
				   @"May", @"Jun", @"Jul", @"Aug" , @"Sep",
				   @"Oct", @"Nov", @"Dec"};

@implementation NSCalendarDate (SOGoExtensions)

+ (id) dateFromShortDateString: (NSString *) dateString
            andShortTimeString: (NSString *) timeString
                    inTimeZone: (NSTimeZone *) timeZone
{
  unsigned int year, month, day, hour, minute, total;
  NSCalendarDate *cDate, *tmpDate;

  if (timeString && [timeString length] == 4)
    {
      total = [timeString intValue];
      hour = total / 100;
      minute = total - (hour * 100);
    }
  else
    {
      hour = 12;
      minute = 0;
    }

  if (dateString && [dateString length] == 8)
    {
      total = [dateString intValue];
      year = total / 10000;
      total -= year * 10000;
      month = total / 100;
      day = total - (month * 100);
      cDate = [self dateWithYear: year month: month day: day
                    hour: hour minute: minute second: 0
                    timeZone: timeZone];
    }
  else
    {
      tmpDate = [NSCalendarDate calendarDate];
      [tmpDate setTimeZone: timeZone];
      cDate = [self dateWithYear: [tmpDate yearOfCommonEra]
                    month: [tmpDate monthOfYear]
                    day: [tmpDate dayOfMonth]
                    hour: hour minute: minute second: 0
                    timeZone: timeZone];
    }

  return cDate;
}

- (BOOL) isDateInSameMonth: (NSCalendarDate *) _other
{
  return (([_other yearOfCommonEra] == [self yearOfCommonEra]) &&
          ([_other monthOfYear] == [self monthOfYear]));
}

- (NSString *) shortDateString
{
  NSString *str;

  str = [NSString stringWithFormat: @"%.4d%.2d%.2d",
                  (int)[self yearOfCommonEra],
                  (int)[self monthOfYear],
                  (int)[self dayOfMonth]];

  return str;
}

- (NSCalendarDate *) beginOfDayForUser: (SOGoUser *) user
{
  NSCalendarDate *date;
  NSTimeZone *timeZone;
  SOGoUserDefaults *ud;

  ud = [user userDefaults];
  timeZone = [ud timeZone];
  [self setTimeZone: timeZone];
  date = [self beginOfDay];
  date = [date addYear: 0
                 month: 0
                   day: 0
                  hour: 0 - [date hourOfDay] + [ud dayStartHour]
                minute: 0 - [date minuteOfHour]
                second: 0];

  return date;
}

- (NSString *) rfc822DateString
{
  int timeZoneShift, tzSeconds;

  tzSeconds = [[self timeZone] secondsFromGMT];
  timeZoneShift = (tzSeconds / 3600);
  tzSeconds -= timeZoneShift * 3600;
  timeZoneShift *= 100;
  timeZoneShift += tzSeconds / 60;

  return
    [NSString stringWithFormat: @"%@, %.2d %@ %d %.2d:%.2d:%.2d %+.4d",
	      rfc822Days[[self dayOfWeek]], (int)[self dayOfMonth],
	      rfc822Months[[self monthOfYear]], (int)[self yearOfCommonEra],
	      (int)[self hourOfDay], (int)[self minuteOfHour], (int)[self secondOfMinute],
	      timeZoneShift];
}

- (NSString *) iso8601DateString
{
  NSNumber *day, *month, *year, *hour, *minute;
  int timeZoneHourShift, timeZoneMinuteShift, tzSeconds;
  char buf[23];

  day = [NSNumber numberWithInt: [self dayOfMonth]];
  month = [NSNumber numberWithInt: [self monthOfYear]];
  year = [NSNumber numberWithInt: [self yearOfCommonEra]];
  hour = [NSNumber numberWithInt: [self hourOfDay]];
  minute = [NSNumber numberWithInt: [self minuteOfHour]];
  memset(buf, 0, 23);

  tzSeconds = [[self timeZone] secondsFromGMT];
  timeZoneHourShift = (tzSeconds / 3600);
  tzSeconds -= timeZoneHourShift * 3600;
  timeZoneMinuteShift = tzSeconds / 60;

  snprintf(buf, 23, "%04d-%02d-%02dT%02d:%02d%+.2d:%02d",
           [year intValue],
           [month intValue],
           [day intValue],
           [hour intValue],
           [minute intValue],
           timeZoneHourShift,
           timeZoneMinuteShift);

  return [NSString stringWithCString: buf];
}

#define secondsOfDistantFuture 1073741823.0
#define secondsOfDistantPast -1073741823.0

+ (id) distantFuture
{
  static NSCalendarDate *date = nil;

  if (!date)
    date
      = [[self alloc] initWithTimeIntervalSinceReferenceDate: secondsOfDistantFuture];

  return date;
}

+ (id) distantPast
{
  static NSCalendarDate *date = nil;

  if (!date)
    date
      = [[self alloc] initWithTimeIntervalSinceReferenceDate: secondsOfDistantPast];

  return date;
}

@end
