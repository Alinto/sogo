/*
  Copyright (C) 2004-2005 SKYRIX Software AG
 
  This file is part of SOPE.
 
  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.
 
  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public
  License for more details.
 
  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING. If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSDate.h>
#import <Foundation/NSArray.h>

#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NGCalendarDateRange.h>

#import "NSCalendarDate+ICal.h"

#import "iCalRecurrenceCalculator.h"
#import "iCalRecurrenceRule.h"

@interface iCalDailyRecurrenceCalculator : iCalRecurrenceCalculator
@end

@interface iCalRecurrenceCalculator (PrivateAPI)
- (NSCalendarDate *) lastInstanceStartDate;
@end

@implementation iCalDailyRecurrenceCalculator

- (NSArray *)
 recurrenceRangesWithinCalendarDateRange: (NGCalendarDateRange *) _r
{
  NSMutableArray *ranges;
  NSCalendarDate *firStart;
  long i, jnFirst, jnStart, jnEnd, startEndCount;
  unsigned interval;

  firStart = [firstRange startDate];
  jnFirst = [firStart julianNumber];
  jnEnd = [[_r endDate] julianNumber];
 
  if (jnFirst > jnEnd)
    return nil;
 
  jnStart = [[_r startDate] julianNumber];
  interval = [rrule repeatInterval];
 
  /* if rule is bound, check the bounds */
  if (![rrule isInfinite]) 
    {
      NSCalendarDate *until;
      long jnRuleLast;
 
      until = [rrule untilDate];
      if (until) 
	{
	  if ([until compare: [_r startDate]] == NSOrderedAscending)
	    return nil;
	  jnRuleLast = [until julianNumber];
	}
      else 
	{
	  jnRuleLast = (interval * [rrule repeatCount])
	    + jnFirst - 1;
	    if (jnRuleLast < jnStart)
	      return nil;
	}
      /* jnStart < jnRuleLast < jnEnd ? */
      if (jnEnd > jnRuleLast)
	jnEnd = jnRuleLast;
    }

  startEndCount = (jnEnd - jnStart) + 1;
  ranges = [NSMutableArray arrayWithCapacity:startEndCount];
  for (i = 0 ; i < startEndCount; i++) 
    {
      long jnCurrent;
 
      jnCurrent = jnStart + i;
      if (jnCurrent >= jnFirst) 
	{
	  long jnTest;
 
	  jnTest = jnCurrent - jnFirst;
	  if ((jnTest % interval) == 0) 
	    {
	      NSCalendarDate *start, *end;
	      NGCalendarDateRange *r;
	      unsigned int mask;

	      start = [NSCalendarDate dateForJulianNumber:jnCurrent];
	      [start setTimeZone: [firStart timeZone]];
	      start = [start hour: [firStart hourOfDay]
			     minute: [firStart minuteOfHour]
			     second: [firStart secondOfMinute]];
	      end = [start addTimeInterval: [firstRange duration]];

	      // We check if our start date is within the byDayMask 
	      // FIXME: Should we also check the end date? We might want
	      // to check if the end date is also within it.
	      if ([rrule byDayMask]) 
		{
		  mask = ([start dayOfWeek]
			  ? (unsigned int) 1 << ([start dayOfWeek])
			  : iCalWeekDaySunday);
		  if (([rrule byDayMask]&mask) != mask) continue;
		}

	      r = [NGCalendarDateRange calendarDateRangeWithStartDate:start
				       endDate:end];
	      if ([_r containsDateRange:r])
		[ranges addObject:r];
	    }
	}
    }
  return ranges;
}

- (NSCalendarDate *) lastInstanceStartDate
{
  NSCalendarDate *firStart, *lastInstanceStartDate;

  if ([rrule repeatCount] > 0) 
    {
      firStart = [firstRange startDate];

      lastInstanceStartDate = [firStart dateByAddingYears: 0 months: 0
					days: ([rrule repeatInterval]
					       * [rrule repeatCount])];
    }
  else
    lastInstanceStartDate = [super lastInstanceStartDate];

  return lastInstanceStartDate;
}

@end /* iCalDailyRecurrenceCalculator */
