/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2006-2022 Inverse inc.

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

#import <NGExtensions/NGCalendarDateRange.h>
#import "iCalRecurrenceRule.h"
#import "NSCalendarDate+ICal.h"

@interface iCalYearlyRecurrenceCalculator : iCalRecurrenceCalculator
@end

@interface iCalMonthlyRecurrenceCalculator : iCalRecurrenceCalculator
@end

@interface iCalRecurrenceCalculator (PrivateAPI)
- (NSCalendarDate *) lastInstanceStartDate;
@end

@implementation iCalYearlyRecurrenceCalculator

- (NSArray *) recurrenceRangesWithinCalendarDateRange: (NGCalendarDateRange *) _r
{
  NSMutableArray *ranges;
  NSArray *byMonth;
  NSCalendarDate *firStart, *firEnd, *lastStartDate, *lastEndDate, *rStart, *rEnd, *until, *referenceDate, *rTemp;
  NSInteger *hoursOfOffset;
  iCalMonthlyRecurrenceCalculator *monthlyCalc;
  unsigned j, yearIdxInRange, numberOfYearsInRange, count, interval, monthDiff;
  int diff, repeatCount, currentMonth, origNbDaysInMonth;

  firStart = [firstRange startDate];
  firEnd = [firstRange endDate];
  rStart = [_r startDate];
  rEnd = [_r endDate];
  interval = [rrule repeatInterval];
  byMonth = [rrule byMonth];
  diff = 0;
  repeatCount = 0;
  count = 0;
  referenceDate = nil;

  if (!firstRange)
    // Can happen when event/todo has a rrule with no dtstart
    return nil;

  if ([rEnd compare: firStart] == NSOrderedAscending)
    // Range ends before first occurrence
    return nil;

  // If rule is bound, check the bounds
  if (![rrule isInfinite])
    {
      lastStartDate = nil;
      lastEndDate = nil;
      until = [rrule untilDate];
      repeatCount = [rrule repeatCount];

      if (until)
        {
          lastStartDate = until;
          lastEndDate = until;
        }
      if (repeatCount > 0)
        {
          if (lastStartDate == nil && ![rrule hasByMask])
          {
            // When there's no BYxxx mask, we can find the date of the last
            // occurrence.
            lastStartDate = [firStart dateByAddingYears: (interval * (repeatCount - 1))
                                            months: 0
                                              days: 0];
            lastEndDate = [firEnd dateByAddingYears: (interval * (repeatCount - 1))
                                            months: 0
                                              days: 0];
          }
          referenceDate = firStart;
        }

      if (lastStartDate != nil)
        {
          if ([lastEndDate compare: rStart] == NSOrderedAscending)
            // Range starts after last occurrence
            return nil;
          if ([lastStartDate compare: rEnd] == NSOrderedAscending)
            // Range ends after last occurence; adjust end date
            rEnd = [lastStartDate addTimeInterval: [firstRange duration]];
        }
    }

  if (referenceDate == nil)
    {
      diff = [firStart yearsBetweenDate: rStart];
      if ((diff != 0) && [rStart compare: firStart] == NSOrderedAscending)
        diff = -diff;
      referenceDate = rStart;
    }

  // Initialize array to return with an approximation of the number total
  // number of possible matches, ie the number of years spawned by the period.
  numberOfYearsInRange = [referenceDate yearsBetweenDate: rEnd] + 1;
  ranges = [NSMutableArray arrayWithCapacity: numberOfYearsInRange];

  if (byMonth)
    {
      /*
       * WARNING/TODO : if there's no BYMONTH rule but there's a BYMONTHDAY
       * rule we should implicitely define a BYMONTH rule by extracting the
       * month from the DTSTART field. However, this kind of definition is
       * uncommon.
       */

      // Instantiate a MONTHLY calculator
      // Fool the monthly calculator, otherwise it will verify the COUNT
      // constraint and perform the calculation from the first occurence of
      // the recurrence. This calculation is performed by the current method.
      // The interval must be ignored as well since it refers to the years.
      [rrule setRepeatCount: 0];
      [rrule setInterval: @"1"];

      // There's a bug in GNUstep in [NSCalendarDate dateByAddingYears:months:days:]
      // that causes errors when adding subsequently a month. For this reason,
      // we set the day of the reference date to 1.
      referenceDate = [NSCalendarDate dateWithYear: [referenceDate yearOfCommonEra]
                                             month: [referenceDate monthOfYear]
                                               day: 1
                                              hour: [referenceDate hourOfDay]
                                            minute: [referenceDate minuteOfHour]
                                            second: 0
                                          timeZone: [referenceDate timeZone]];

      // If the BYMONTH constraints exclude the month of the event DTSTART, we
      // add the corresponding range manually if it is included in the period.
      // Otherwise, it will be included by the monthly calculator in the loop
      // bellow.
      int month = [firStart monthOfYear];
      if (![byMonth containsObject: [NSString stringWithFormat: @"%i", month]])
        {
          count++;
          if ([_r containsDateRange: firstRange])
            {
              [ranges addObject: firstRange];
            }
        }
    }

  monthDiff = 0;
  currentMonth = [referenceDate monthOfYear];
  for (yearIdxInRange = 0 ; yearIdxInRange < numberOfYearsInRange; yearIdxInRange++)
    {
      int k, test;

      test = diff + yearIdxInRange;
      if ((test >= 0) && (test % interval) == 0)
        {
          if (byMonth)
            {
              monthlyCalc = [[iCalMonthlyRecurrenceCalculator alloc]
                                        initWithRecurrenceRule: rrule
                                firstInstanceCalendarDateRange: firstRange];
              [monthlyCalc autorelease];

              // When there's a BYMONTH constraint, evaluate each month of the constraint using
              // the monthly calculator.
              for (j = 0; currentMonth < 13 && j <= 12; j++, currentMonth++, monthDiff++)
                {
                  if ([byMonth containsObject: [NSString stringWithFormat: @"%i", currentMonth]])
                    {
                      NGCalendarDateRange *rangeForMonth;
                      NSArray *rangesInMonth;

                      rStart = [referenceDate dateByAddingYears: 0
                                                         months: monthDiff
                                                           days: 0];


                      //Due to the bug with dateByAddingYears, we may take the previous day (see line 133)
                      hoursOfOffset = [rStart hourOfDay];
                      origNbDaysInMonth = [rStart numberOfDaysInMonth];
                      if(hoursOfOffset > 12) {
                        //If rStart is 1st 22:00, we should start at the previous day 22:00
                        rTemp = [NSCalendarDate dateWithYear: [rStart yearOfCommonEra]
                                          month: 1+([rStart monthOfYear]-2)%12
                                            day: 1
                                          hour: [rStart hourOfDay]
                                        minute: [rStart minuteOfHour]
                                        second: 0
                                      timeZone: [rStart timeZone]];
                        rStart = [NSCalendarDate dateWithYear: [rStart yearOfCommonEra]
                                          month: 1+([rStart monthOfYear]-2)%12
                                            day: [rTemp numberOfDaysInMonth]
                                          hour: [rStart hourOfDay]
                                        minute: [rStart minuteOfHour]
                                        second: 0
                                      timeZone: [rStart timeZone]];
                      }

                      
                      rEnd = [rStart dateByAddingYears: 0
                                                months: 0
                                                  days: origNbDaysInMonth];
                      
                      
                      rangeForMonth = [NGCalendarDateRange calendarDateRangeWithStartDate: rStart
                                                                                  endDate: rEnd];
                      rangesInMonth = [monthlyCalc recurrenceRangesWithinCalendarDateRange: rangeForMonth];

                      for (k = 0; k < [rangesInMonth count] && (repeatCount == 0 || count < repeatCount); k++) {
                        //NSLog(@"*** YEARLY found %@ (count = %i)", [[rangesInMonth objectAtIndex: k] startDate], count);
                        count++;
                        if ([_r doesIntersectWithDateRange: [rangesInMonth objectAtIndex: k]])
                          {
                            [ranges addObject: [rangesInMonth objectAtIndex: k]];
                            //NSLog(@"*** YEARLY adding %@ (count = %i)", [[rangesInMonth objectAtIndex: k] startDate], count);
                          }
                      }
                    }
                }
              // Done with the current year; start the next iteration from January
              currentMonth = 1;
            }
          else
            {
              // No BYxxx mask
              NSCalendarDate *start, *end;
              NGCalendarDateRange *r;

              start = [firStart dateByAddingYears: diff + yearIdxInRange
                                           months: 0
                                             days: 0];
              [start setTimeZone: [firStart timeZone]];
              if ([start compare: rEnd] == NSOrderedAscending ||
                  ([firstRange duration] == 0 && [start compare: rEnd] == NSOrderedSame))
                {
                  end = [start addTimeInterval: [firstRange duration]];
                  r = [NGCalendarDateRange calendarDateRangeWithStartDate: start
                                                                  endDate: end];
                  if ([_r doesIntersectWithDateRange: r] && (repeatCount == 0 || count < repeatCount))
                    {
                      [ranges addObject: r];
                      count++;
                    }
                }
            }
        }
      else
        {
          // Year was skipped, jump to following year
          monthDiff += (13 - currentMonth);
          currentMonth = 1;
        }
    }

  if (byMonth)
    {
      // Restore the repeat count and interval
      if (repeatCount > 0)
        [rrule setRepeatCount: repeatCount];
      [rrule setRepeatInterval: interval];
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
          lastInstanceStartDate = [firStart dateByAddingYears: ([rrule repeatInterval]
                                                                * ([rrule repeatCount] - 1))
                                                       months: 0
                                                         days: 0];
        }
    }
  else
    lastInstanceStartDate = [super lastInstanceStartDate];

  return lastInstanceStartDate;
}

@end /* iCalYearlyRecurrenceCalculator */
