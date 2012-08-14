/* iCalTimeZone+MAPIStore.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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
#import <NGCards/iCalByDayMask.h>
#import <NGCards/iCalTimeZonePeriod.h>
#import <NGCards/iCalRecurrenceRule.h>

#include <stdbool.h>
#include <stdint.h>
#include <talloc.h>
#undef DEBUG
#include <libmapi/libmapi.h>

#import "iCalTimeZone+MAPIStore.h"

@interface iCalTimeZonePeriod (MAPIStorePropertiesPrivate)

- (void) _fillTZDate: (struct SYSTEMTIME *) tzData;

@end

@implementation iCalTimeZonePeriod (MAPIStorePropertiesPrivate)

- (void) _fillTZDate: (struct SYSTEMTIME *) tzData
{
  iCalRecurrenceRule *rrule;
  NSArray *byMonth;
  iCalByDayMask *mask;
  NSCalendarDate *dateValue;

  rrule = [self recurrenceRule];
  byMonth = [rrule byMonth];
  if ([byMonth count] > 0)
    {
      tzData->wMonth = [[byMonth objectAtIndex: 0] intValue];
      mask = [rrule byDayMask];
      tzData->wDayOfWeek = [mask firstDay];
      tzData->wDay = [mask firstOccurrence];

      dateValue = [self startDate];
      tzData->wHour = [dateValue hourOfDay];
      tzData->wMinute = [dateValue minuteOfHour];
      tzData->wSecond = [dateValue secondOfMinute];
    }
}

@end

@implementation iCalTimeZone (MAPIStoreProperties)

- (iCalTimeZonePeriod *) _mostRecentPeriodWithName: (NSString *) periodName
{
  NSArray *periods;
  iCalTimeZonePeriod *period;
  NSUInteger max;

  periods = [self childrenWithTag: periodName];
  max = [periods count];
  if (max > 0)
    {
      periods = [periods sortedArrayUsingSelector: @selector (compare:)];
      period = (iCalTimeZonePeriod *) [periods objectAtIndex: (max - 1)];
    }
  else
    period = nil;

  return period;
}

- (struct Binary_r *) asTimeZoneStructInMemCtx: (TALLOC_CTX *) memCtx
{
  iCalTimeZonePeriod *period;
  struct TimeZoneStruct tz;
  int lBias, dlBias;

  memset (&tz, 0, sizeof (struct TimeZoneStruct));
  period = [self _mostRecentPeriodWithName: @"STANDARD"];
  lBias = -[period secondsOffsetFromGMT] / 60;
  tz.lBias = (uint32_t) lBias;
  [period _fillTZDate: &tz.stStandardDate];
  period = [self _mostRecentPeriodWithName: @"DAYLIGHT"];
  if (!period)
    tz.stStandardDate.wMonth = 0;
  dlBias = -([period secondsOffsetFromGMT] / 60) - lBias;
  tz.lDaylightBias = (uint32_t) (dlBias);
  [period _fillTZDate: &tz.stDaylightDate];
  tz.wStandardYear = tz.stStandardDate.wYear;
  tz.wDaylightYear = tz.stDaylightDate.wYear;

  return set_TimeZoneStruct (memCtx, &tz);
}

@end
