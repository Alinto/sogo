/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2006-2010 Inverse inc.

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
#import "iCalByDayMask.h"

@interface iCalDailyRecurrenceCalculator : iCalRecurrenceCalculator
@end

@interface iCalRecurrenceCalculator (PrivateAPI)
- (NSCalendarDate *) lastInstanceStartDate;
@end

@implementation iCalDailyRecurrenceCalculator

  /**
   * TODO : Unsupported conditions for DAILY recurrences :
   *
   *   BYYEAR
   *   BYYEARDAY
   *   BYWEEKNO
   *   BYMONTH
   *   BYMONTHDAY
   *   BYHOUR
   *   BYMINUTE
   *
   * There's no GUI to defined such conditions, so there's no
   * problem for now.
   */
- (NSArray *)
 recurrenceRangesWithinCalendarDateRange: (NGCalendarDateRange *) _r
{
  NSMutableArray *ranges;
  NSCalendarDate *firStart, *startDate, *endDate, *currentStartDate, *currentEndDate;
  iCalByDayMask *dayMask;
  long i, count, repeatCount;
  unsigned interval;

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
	{
	  lastDate = until;
	}
      else
	{
	  repeatCount = [rrule repeatCount];
 	  if (dayMask == nil)
 	    // If there's no day mask, we can compute the date of the last
 	    // occurrence of the recurrent rule.
 	    lastDate = [firStart dateByAddingYears: 0 months: 0
 					      days: (interval
 						     * (repeatCount - 1))];
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
  i = 1;
  count = 0;
 
  while ([currentStartDate compare: endDate] == NSOrderedAscending ||
	 [currentStartDate compare: endDate] == NSOrderedSame)
    {
      BOOL wrongDay, isFirStart;

      wrongDay = NO;
      isFirStart = NO;

      if (i == 1)
	{
	  isFirStart = YES;
	  count++;
	}
      else if (repeatCount > 0 && dayMask)
	{
	  // If the rule count is defined, stop once the count is reached.
	  if ([dayMask occursOnDay: [currentStartDate dayOfWeek]])
	    count++;
	  else
	    wrongDay = YES;
	  
	  if (count > repeatCount)
	    break;
	}
      
      if (wrongDay == NO)
        {
          currentEndDate = [currentStartDate addTimeInterval: [firstRange duration]];
	  if ([startDate compare: currentStartDate] == NSOrderedAscending ||
              [startDate compare: currentStartDate] == NSOrderedSame ||
              [startDate compare: currentEndDate] == NSOrderedAscending)
            {
              NGCalendarDateRange *r;

              if (isFirStart == NO && dayMask && repeatCount == 0)
                {
                  if (![dayMask occursOnDay: [currentStartDate dayOfWeek]])
                    wrongDay = YES;
                }
              
              if (isFirStart == YES || wrongDay == NO)
                {
                  r = [NGCalendarDateRange calendarDateRangeWithStartDate: currentStartDate
                                                                  endDate: currentEndDate];
                  if ([_r containsDateRange: r] || [_r doesIntersectWithDateRange: r])
                    [ranges addObject: r];
                }
            }
	}
      
      currentStartDate = [firStart dateByAddingYears: 0 months: 0
				   days: (interval * i)];
      
      if (repeatCount > 0 && count == repeatCount)
	// The count variable is only usefull when a BYDAY constraint is
	// defined; when there's no BYDAY constraint, the endDate has been
	// adjusted to match the repeat count, if defined.
	break;
      
      i++;
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
      if ([rrule hasByMask])
	{
	  // Must perform the complete calculation
	  r = [NGCalendarDateRange calendarDateRangeWithStartDate: firStart
							  endDate: [NSCalendarDate distantFuture]];
	  instances = [self recurrenceRangesWithinCalendarDateRange: r];
	  if ([instances count])
	    lastInstanceStartDate = [(NGCalendarDateRange *)[instances lastObject] startDate];
	}
      else
	{
	  // No BYxxx mask
	  lastInstanceStartDate = [firStart dateByAddingYears: 0 months: 0
							 days: ([rrule repeatInterval]
								* ([rrule repeatCount] - 1))];
	}
    }
  else
    lastInstanceStartDate = [super lastInstanceStartDate];

  return lastInstanceStartDate;
}

@end /* iCalDailyRecurrenceCalculator */
