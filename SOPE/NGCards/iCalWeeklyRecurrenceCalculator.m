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

#import <NGExtensions/NSCalendarDate+misc.h>

#import "iCalRecurrenceCalculator.h"

@interface iCalWeeklyRecurrenceCalculator : iCalRecurrenceCalculator
@end

#import <NGExtensions/NGCalendarDateRange.h>
#import "iCalRecurrenceRule.h"
#import "NSCalendarDate+ICal.h"

@interface iCalRecurrenceCalculator (PrivateAPI)

- (NSCalendarDate *) lastInstanceStartDate;

- (unsigned) offsetFromSundayForJulianNumber: (long) _jn;
- (unsigned) offsetFromSundayForWeekDay: (iCalWeekDay) _weekDay;
- (unsigned) offsetFromSundayForCurrentWeekStart;
 
- (iCalWeekDay) weekDayForJulianNumber: (long) _jn;

@end

/*
  TODO: If BYDAY is specified, lastInstanceStartDate and recurrences will
  differ significantly!
*/
@implementation iCalWeeklyRecurrenceCalculator

- (NSArray *) recurrenceRangesWithinCalendarDateRange: (NGCalendarDateRange *) _r
{
  NSMutableArray *ranges;
  NSCalendarDate *firStart, *startDate, *endDate, *currentStartDate, *currentEndDate;
  long i;
  unsigned interval, byDayMask;

  firStart = [firstRange startDate];
  startDate = [_r startDate];
  endDate = [_r endDate];

  if ([endDate compare: firStart] == NSOrderedAscending)
    // Range ends before first occurrence
    return nil;
  
  interval = [rrule repeatInterval];
 
  // If rule is bound, check the bounds
  if (![rrule isInfinite]) 
    {
      NSCalendarDate *until, *lastDate;
 
      until = [rrule untilDate];
      if (until)
	lastDate = until;
      else 
	lastDate = [firStart dateByAddingYears: 0 months: 0
			     days: (interval
				    * ([rrule repeatCount] - 1) * 7)];
      
      if ([lastDate compare: startDate] == NSOrderedAscending)
	// Range starts after last occurrence
	return nil;
      if ([lastDate compare: endDate] == NSOrderedAscending)
	// Range ends after last occurence; adjust end date
	endDate = lastDate;
    }
 
  currentStartDate = [firStart copy];
  ranges = [NSMutableArray array];
  byDayMask = [rrule byDayMask];
  i = 1;
  if (!byDayMask) 
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
	  currentStartDate = [firStart dateByAddingYears: 0
				       months: 0
				       days: (interval * i * 7)];
	  i++;
	}
    }
  else
    {
      unsigned dayOfWeek;
      NGCalendarDateRange *r;
      
      while ([currentStartDate compare: endDate] == NSOrderedAscending ||
	     [currentStartDate compare: endDate] == NSOrderedSame)
	{
	  if ([startDate compare: currentStartDate] == NSOrderedAscending ||
	      [startDate compare: currentStartDate] == NSOrderedSame)
	    {
	      unsigned int days, week;
	      
	      [currentStartDate years:NULL months:NULL days:&days hours:NULL
				minutes:NULL seconds:NULL sinceDate:firStart];
	      week = days / 7;
	      
	      if ((week % interval) == 0)
		{
		  // Date is in the proper week with respect to the
		  // week interval
		  BOOL isRecurrence = NO;
		  
		  if ([currentStartDate compare: firStart] == NSOrderedSame)
		    // Always add the event of the start date of
		    // the recurring event.
		    isRecurrence = YES;
		  else
		    {
		      // Only consider events that matches the day mask.
		      dayOfWeek = ([currentStartDate dayOfWeek]
				   ? (unsigned int) 1 << [currentStartDate dayOfWeek]
				   : iCalWeekDaySunday);
		      if (dayOfWeek & [rrule byDayMask])
			isRecurrence = YES;
		    }
		  if (isRecurrence)
		    {
		      currentEndDate = [currentStartDate addTimeInterval: [firstRange duration]];
		      r = [NGCalendarDateRange calendarDateRangeWithStartDate: currentStartDate
					       endDate: currentEndDate];
		      if ([_r containsDateRange: r])
			[ranges addObject: r];
		    }
		}
	    }
	  currentStartDate = [currentStartDate dateByAddingYears: 0
					       months: 0
					       days: 1];
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
					days: (7 * [rrule repeatInterval]
					       * ([rrule repeatCount] - 1))];
    }
  else
    lastInstanceStartDate = [super lastInstanceStartDate];

  return lastInstanceStartDate;
}

@end /* iCalWeeklyRecurrenceCalculator */
