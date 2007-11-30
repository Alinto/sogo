/* NSCalendarDate+SOGo.m - this file is part of SOGo
   Copyright (C) 2000-2004 SKYRIX Software AG

   This file is part of OGo

   OGo is free software; you can redistribute it and/or modify it under
   the terms of the GNU Lesser General Public License as published by the
   Free Software Foundation; either version 2, or (at your option) any
   later version.

   OGo is distributed in the hope that it will be useful, but WITHOUT ANY
   WARRANTY; without even the implied warranty of MERCHANTABILITY or
   FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
   License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with OGo; see the file COPYING.  If not, write to the
   Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
   02111-1307, USA.
*/

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSTimeZone.h>
#import <NGExtensions/NSCalendarDate+misc.h>

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

- (NSCalendarDate *) dayOfWeeK: (unsigned) _day 
              offsetFromSunday: (unsigned) _offset
{
  unsigned dayOfWeek, distance;
    
  /* perform "locale" correction */
  dayOfWeek = (7 + [self dayOfWeek] - _offset) % 7;

  _day = (_day % 7);
  if(_day == dayOfWeek)
    return self;

  distance = _day - dayOfWeek;
  return [self dateByAddingYears:0 months:0 days:distance];
}

/* this implies that monday is the start of week! */

- (NSCalendarDate *) sundayOfWeek
{
  return [self dayOfWeeK:6 offsetFromSunday:1];
}

- (NSString *) shortDateString
{
  NSString *str;

  str = [NSString stringWithFormat: @"%.4d%.2d%.2d",
                  [self yearOfCommonEra],
                  [self monthOfYear],
                  [self dayOfMonth]];

  return str;
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
	      rfc822Days[[self dayOfWeek]], [self dayOfMonth],
	      rfc822Months[[self monthOfYear]], [self yearOfCommonEra],
	      [self hourOfDay], [self minuteOfHour], [self secondOfMinute],
	      timeZoneShift];
}

#define secondsOfDistantFuture 63113990400.0
#define secondsOfDistantPast -63113817600.0

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
