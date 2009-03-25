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
  NSCalendarDate *firStart, *startDate, *endDate, *currentStartDate, *currentEndDate;
  long i;
  unsigned interval;

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
				    * ([rrule repeatCount] - 1))];
    
      if ([lastDate compare: startDate] == NSOrderedAscending)
	// Range starts after last occurrence
	return nil;
      
      if ([lastDate compare: endDate] == NSOrderedAscending)
	// Range ends after last occurence; adjust end date
	endDate = lastDate;
    }

  currentStartDate = [firStart copy];
  [currentStartDate autorelease];
  ranges = [NSMutableArray array];
  i = 1;

  while ([currentStartDate compare: endDate] == NSOrderedAscending ||
	 [currentStartDate compare: endDate] == NSOrderedSame)
    {
      if ([startDate compare: currentStartDate] == NSOrderedAscending ||
	  [startDate compare: currentStartDate] == NSOrderedSame)
	{
	  BOOL wrongDay = NO;
	  unsigned int mask;
	  NGCalendarDateRange *r;

	  if ([rrule byDayMask])
	    {
	      mask = ([currentStartDate dayOfWeek]
		      ? (unsigned int) 1 << ([currentStartDate dayOfWeek])
		      : iCalWeekDaySunday);
	      if (([rrule byDayMask] & mask) != mask)
		wrongDay = YES;
	    }

	  if (wrongDay == NO)
	    {
	      currentEndDate = [currentStartDate addTimeInterval: [firstRange duration]];
	      r = [NGCalendarDateRange calendarDateRangeWithStartDate: currentStartDate
				       endDate: currentEndDate];
	      if ([_r containsDateRange: r])
		[ranges addObject: r];
	    }
	}
      
      currentStartDate = [firStart dateByAddingYears: 0 months: 0
				   days: (interval * i)];
      i++;
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
					       * ([rrule repeatCount] - 1))];
    }
  else
    lastInstanceStartDate = [super lastInstanceStartDate];

  return lastInstanceStartDate;
}

@end /* iCalDailyRecurrenceCalculator */
