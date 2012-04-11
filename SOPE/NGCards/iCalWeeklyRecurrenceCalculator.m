/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2006-2012 Inverse inc.
 
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

#import <NGExtensions/NSCalendarDate+misc.h>

#import "iCalRecurrenceCalculator.h"

@interface iCalWeeklyRecurrenceCalculator : iCalRecurrenceCalculator
@end

#import <NGExtensions/NGCalendarDateRange.h>
#import "iCalRecurrenceRule.h"
#import "iCalByDayMask.h"
#import "NSCalendarDate+ICal.h"

@interface iCalRecurrenceCalculator (PrivateAPI)

- (NSCalendarDate *) lastInstanceStartDate;

- (unsigned) offsetFromSundayForJulianNumber: (long) _jn;
- (unsigned) offsetFromSundayForWeekDay: (iCalWeekDay) _weekDay;
- (unsigned) offsetFromSundayForCurrentWeekStart;
 
- (iCalWeekDay) weekDayForJulianNumber: (long) _jn;

@end

@implementation iCalWeeklyRecurrenceCalculator

  /**
   * TODO : Unsupported conditions for WEEKLY recurrences :
   *
   *   BYYEAR
   *   BYYEARDAY
   *   BYWEEKNO
   *   BYMONTH
   *   BYMONTHDAY
   *   BYHOUR
   *   BYMINUTE
   *   WKST
   *
   * There's no GUI to defined such conditions, so there's no
   * problem for now.
   */
- (NSArray *) recurrenceRangesWithinCalendarDateRange: (NGCalendarDateRange *) _r
{
  NSMutableArray *ranges;
  NSCalendarDate *firStart, *startDate, *endDate, *currentStartDate, *currentEndDate;
  long i, repeatCount, count;
  unsigned interval;
  iCalByDayMask *dayMask;

  firStart = [firstRange startDate];
  startDate = [_r startDate];
  endDate = [_r endDate];
  dayMask = nil;
  repeatCount = 0;

  if ([endDate compare: firStart] == NSOrderedAscending)
    // Range ends before first occurrence
    return nil;
  
  interval = [rrule repeatInterval];
 
  if ([[rrule byDay] length])
    dayMask = [rrule byDayMask];

  // If rule is bound, check the bounds
  if (![rrule isInfinite])
    {
      NSCalendarDate *until, *lastDate;
 
      lastDate = nil;
      until = [rrule untilDate];
      if (until)
	lastDate = until;
      else
	{
	  repeatCount = [rrule repeatCount];
	  if (dayMask == nil)
	    // When there's no BYxxx mask, we can find the date of the last
	    // occurrence.
	    lastDate = [firStart dateByAddingYears: 0 months: 0
					      days: (interval
						     * (repeatCount - 1) * 7)];
	}
      
      if (lastDate != nil)
	{
	  if ([lastDate compare: startDate] == NSOrderedAscending)
	    // Range starts after last occurrence
	    return nil;
	  if ([lastDate compare: endDate] == NSOrderedAscending)
	    // Range ends after last occurence; adjust end date
	    endDate = lastDate;
	}
    }
 
  currentStartDate = [firStart copy];
  [currentStartDate autorelease];
  ranges = [NSMutableArray array];
  i = 0;
  count = 0;

  if (dayMask == nil)
    {
      while ([currentStartDate compare: endDate] == NSOrderedAscending ||
	     [currentStartDate compare: endDate] == NSOrderedSame)
	{
	  if ([startDate compare: currentStartDate] == NSOrderedAscending ||
	      [startDate compare: currentStartDate] == NSOrderedSame)
	    {
	      NGCalendarDateRange *r;
	      
	      currentEndDate = [currentStartDate addTimeInterval: [firstRange duration]];
	      r = [NGCalendarDateRange calendarDateRangeWithStartDate: currentStartDate
				       endDate: currentEndDate];
	      if ([_r containsDateRange: r])
		[ranges addObject: r];
	    }
	  i++;
	  currentStartDate = [firStart dateByAddingYears: 0
				       months: 0
				       days: (interval * i * 7)];
	}
    }
  else
    {
      NGCalendarDateRange *r;
      
      while ([currentStartDate compare: endDate] == NSOrderedAscending ||
	     [currentStartDate compare: endDate] == NSOrderedSame)
	{
	  BOOL isRecurrence = NO;
	  NSInteger week;

	  if (repeatCount > 0 ||
	      [startDate compare: currentStartDate] == NSOrderedAscending ||
	      [startDate compare: currentStartDate] == NSOrderedSame)
	    {
	      // If the rule count is defined, stop once the count is reached.
	      if (i == 0)
		{
		  // Always add the start date of the recurring event if within
		  // the lookup range.
		  isRecurrence = YES;
		}
	      else 
		{
		  // The following always set the first day of the week as the day
		  // of the master event start date, ie WKST is ignored.
		  week = i / 7;
                  
		  if ((week % interval) == 0 &&
		      [dayMask occursOnDay: [currentStartDate dayOfWeek]])
		    isRecurrence = YES;
		}

	      if (isRecurrence)
		{
		  count++;
		  if (repeatCount > 0 && count > repeatCount)
		    break;
		  currentEndDate = [currentStartDate addTimeInterval: [firstRange duration]];
		  r = [NGCalendarDateRange calendarDateRangeWithStartDate: currentStartDate
								  endDate: currentEndDate];

		  if ([_r doesIntersectWithDateRange: r])
		    [ranges addObject: r];
		}
	    }
	  currentStartDate = [currentStartDate dateByAddingYears: 0
							  months: 0
							    days: 1];
	  i++;
	}
    }

  return ranges;
}

- (NSCalendarDate *) lastInstanceStartDate
{
  NSCalendarDate *firStart, *lastInstanceStartDate;
  NGCalendarDateRange *r;
  NSArray *instances;

  lastInstanceStartDate = nil;
  if ([rrule repeatCount] > 0)
    {
      firStart = [firstRange startDate];
      r = [NGCalendarDateRange calendarDateRangeWithStartDate: firStart
						      endDate: [NSCalendarDate distantFuture]];
      instances = [self recurrenceRangesWithinCalendarDateRange: r];
      if ([instances count])
	lastInstanceStartDate = [(NGCalendarDateRange *)[instances lastObject] startDate];
    }
  else
    lastInstanceStartDate = [super lastInstanceStartDate];

  return lastInstanceStartDate;
}

@end /* iCalWeeklyRecurrenceCalculator */
