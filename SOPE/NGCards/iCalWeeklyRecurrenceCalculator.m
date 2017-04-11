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
#import <NGExtensions/NSObject+Logs.h>

#import "iCalRecurrenceCalculator.h"

@interface iCalWeeklyRecurrenceCalculator : iCalRecurrenceCalculator
@end

#import <NGExtensions/NGCalendarDateRange.h>
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
  BOOL hasRepeatCount;

  //[self logWithFormat: @"Recurrence rule is %@", rrule];

  firStart = [firstRange startDate];
  startDate = [_r startDate];
  endDate = [_r endDate];
  dayMask = nil;
  repeatCount = 0;
  hasRepeatCount = [rrule hasRepeatCount];

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
            endDate = [lastDate addTimeInterval: [firstRange duration]];
        }
    }

  currentStartDate = [firStart copy];
  [currentStartDate autorelease];
  ranges = [NSMutableArray array];
  count = 0;

  if (dayMask == nil)
    {
      i = 0;
      while ([currentStartDate compare: endDate] == NSOrderedAscending ||
             [currentStartDate compare: endDate] == NSOrderedSame)
        {
          currentEndDate = [currentStartDate addTimeInterval: [firstRange duration]];
          if ([startDate compare: currentEndDate] == NSOrderedAscending)
            {
              NGCalendarDateRange *r;

              r = [NGCalendarDateRange calendarDateRangeWithStartDate: currentStartDate
                                                              endDate: currentEndDate];
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

      i = [currentStartDate dayOfWeek]; // Set the first day of the week as Sunday and ignore WKST
      while ([currentStartDate compare: endDate] == NSOrderedAscending ||
             [currentStartDate compare: endDate] == NSOrderedSame)
        {
          BOOL isRecurrence = NO;
          NSInteger week;

          currentEndDate = [currentStartDate addTimeInterval: [firstRange duration]];
          if (hasRepeatCount ||
              [startDate compare: currentEndDate] == NSOrderedAscending)
            {
              // If the rule count is defined, stop once the count is reached.
              if ([currentStartDate compare: firStart] == NSOrderedSame)
                {
                  // Always add the start date of the recurring event if within
                  // the lookup range.
                  isRecurrence = YES;
                }
              else
                {
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
                  r = [NGCalendarDateRange calendarDateRangeWithStartDate: currentStartDate
                                                                  endDate: currentEndDate];
                  if ([_r doesIntersectWithDateRange: r])
                    {
                      [ranges addObject: r];
                      // [self logWithFormat: @"Add range %@ - %@", [r startDate], [r endDate]];
                    }
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
