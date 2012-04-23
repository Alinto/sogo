/*
  Copyright (C) 2004-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess
  Copyright (C) 2010 Inverse inc.
  
  This file is part of SOPE.
  
  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.
  
  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.
  
  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSString.h>
#import <NGExtensions/NSCalendarDate+misc.h>

#import "iCalRecurrenceCalculator.h"

@interface iCalMonthlyRecurrenceCalculator : iCalRecurrenceCalculator
@end

#import <NGExtensions/NGCalendarDateRange.h>
#import "iCalRecurrenceRule.h"
#import "iCalByDayMask.h"
#import "NSCalendarDate+ICal.h"

#import <string.h>

@interface iCalRecurrenceCalculator (PrivateAPI)

- (NSCalendarDate *) lastInstanceStartDate;

@end

// #define HEAVY_DEBUG 1

@implementation iCalMonthlyRecurrenceCalculator

typedef BOOL NGMonthSet[12];
typedef BOOL NGMonthDaySet[32]; // 0 is unused

static inline void
NGMonthDaySet_clear (NGMonthDaySet *daySet)

{
  memset (daySet, 0, sizeof (NGMonthDaySet));
}

static void
NGMonthDaySet_copyOrUnion (NGMonthDaySet *base, NGMonthDaySet *new,
			   BOOL doCopy)

{
  register unsigned i;

  if (doCopy)
    memcpy (base, new, sizeof (NGMonthDaySet));
  else 
    {
      for (i = 1; i <= 31; i++) 
	{
	  if (! (*new)[i])
	    (*base)[i] = NO;
	}
    }
}

/**
 * This method fills split the positions of the BYMONTHDAY constraints
 * into two separate arrays: one for the positive positions and one for the
 * negatives positions (converted to their absolute values).
 */
static BOOL NGMonthDaySet_fillWithByMonthDay (NGMonthDaySet *positiveDaySet, 
					      NGMonthDaySet *negativeDaySet,
					      NSArray *byMonthDay)
{
  unsigned i, count;
  BOOL ok;
  
  NGMonthDaySet_clear (positiveDaySet);
  NGMonthDaySet_clear (negativeDaySet);

  for (i = 0, count = [byMonthDay count], ok = YES; i < count; i++) 
    {
      int dayInMonth; /* -31..-1 and 1..31 */
        
      if ((dayInMonth = [[byMonthDay objectAtIndex: i] intValue]) == 0) 
	{
	  ok = NO;
	  continue; /* invalid value */
	}
      if (dayInMonth > 31) 
	{
	  ok = NO;
	  continue; /* error, value to large */
	}
      if (dayInMonth < -31)
	{
	  ok = NO;
	  continue; /* error, value to large */
	}
    
      /* adjust negative days */
        
      if (dayInMonth < 0) 
	(*negativeDaySet)[abs(dayInMonth)] = YES;
      else
	(*positiveDaySet)[dayInMonth] = YES;
    }
  return ok;
}

static inline unsigned iCalDoWForNSDoW (int dow) 
{
  switch (dow)
    {
    case 0: return iCalWeekDaySunday;
    case 1: return iCalWeekDayMonday;
    case 2: return iCalWeekDayTuesday;
    case 3: return iCalWeekDayWednesday;
    case 4: return iCalWeekDayThursday;
    case 5: return iCalWeekDayFriday;
    case 6: return iCalWeekDaySaturday;
    case 7: return iCalWeekDaySunday;
    default: return 0;
    }
}

- (BOOL) _addInstanceWithStartDate: (NSCalendarDate *)_startDate
			 limitDate: (NSCalendarDate *)_until
			limitRange: (NGCalendarDateRange *)_r
			   toArray: (NSMutableArray *)_ranges

{
  NGCalendarDateRange *r;
  NSCalendarDate *end;
  
  /* check whether we are still in the limits */

  if (_until != nil)
    {
      /* Note: the 'until' in the rrule is inclusive as per spec */
      if ([_until compare: _startDate] == NSOrderedAscending)
	/* start after until */
	return NO; /* Note: we assume that the algorithm is sequential */
    }

  /* create end date */

  end = [_startDate addTimeInterval: [firstRange duration]];
  [end setTimeZone: [_startDate timeZone]];
    
  /* create range and check whether its in the requested range */
  
  r = [[NGCalendarDateRange alloc] initWithStartDate: _startDate endDate: end];
  if ([_r containsDateRange: r])
    [_ranges addObject: r];
  [r release];
  r = nil;
  
  return YES;
}

  /**
   * TODO : Unsupported conditions for MONTHLY recurrences :
   *
   *   BYYEAR
   *   BYYEARDAY
   *   BYWEEKNO
   *   BYHOUR
   *   BYMINUTE
   *
   * There's no GUI to defined such conditions, so there's no
   * problem for now.
   */
- (NSArray *)
 recurrenceRangesWithinCalendarDateRange: (NGCalendarDateRange *) _r
{
  // TODO: check whether this is OK for multiday-events!
  NSMutableArray *ranges;
  NSTimeZone     *timeZone;
  NSCalendarDate *eventStartDate, *rStart, *rEnd, *until, *referenceDate;
  int            eventDayOfMonth;
  unsigned       monthIdxInRange, numberOfMonthsInRange, interval, repeatCount;
  int            diff, count;
  NGMonthSet byMonthList = {
    // Enable all months of the year
    YES, YES, YES, YES, YES, YES, 
    YES, YES, YES, YES, YES, YES
  };
  NSArray       *byMonth, *byMonthDay, *bySetPos; // array of ints (-31..-1 and 1..31)
  NGMonthDaySet byPositiveMonthDaySet, byNegativeMonthDaySet;
  iCalByDayMask *byDayMask;
  
  eventStartDate  = [firstRange startDate];
  eventDayOfMonth = [eventStartDate dayOfMonth];
  timeZone        = [eventStartDate timeZone];
  rStart          = [_r startDate];
  rEnd            = [_r endDate];
  interval        = [rrule repeatInterval];
  until           = nil;
  repeatCount     = [rrule repeatCount];
  byMonth         = [rrule byMonth];
  byMonthDay      = [rrule byMonthDay];
  byDayMask       = [rrule byDayMask];
  bySetPos        = [rrule bySetPos];              
  diff            = 0;

  if (![rrule isInfinite])
    {
      if (repeatCount > 0 && ![rrule hasByMask])
	{
	  // When there's no BYxxx mask, we can find the date of the last
	  // occurrence.
	  until = [eventStartDate dateByAddingYears: 0
					     months: (interval * (repeatCount - 1))
					       days: 0];
	}
      else
	{
	  until = [rrule untilDate];
	}
    }

  if (until != nil)
    {
      if ([until compare: rStart] == NSOrderedAscending)
	// Range starts after last occurrence
	return nil;
      if ([until compare: rEnd] == NSOrderedAscending)
	// Range ends after last occurence; adjust end date
	rEnd = until;
    }
  
  if (byMonth && [byMonth count] > 0)
     {
       int i;
       for (i = 0; i < 12; i++)
 	byMonthList[i] = [byMonth containsObject: [NSString stringWithFormat: @"%i", i + 1]];
     }

  /* precalculate month days */

  if (byMonthDay)
    {
      NGMonthDaySet_fillWithByMonthDay (&byPositiveMonthDaySet, &byNegativeMonthDaySet, byMonthDay);
    }
  
  if (repeatCount > 0)
    {
      numberOfMonthsInRange  = [eventStartDate monthsBetweenDate: rEnd] + 1;
    }
  else
    {
      diff = [eventStartDate monthsBetweenDate: rStart];
      if ((diff != 0) && [rStart compare: eventStartDate] == NSOrderedAscending)
	diff = -diff;

      numberOfMonthsInRange  = [rStart monthsBetweenDate: rEnd] + 1;
    }

  ranges = [NSMutableArray arrayWithCapacity: numberOfMonthsInRange];
  
  // There's a bug in GNUstep in [NSCalendarDate dateByAddingYears:months:days:]
  // that causes errors when adding subsequently a month. For this reason,
  // we set the day of the reference date to 1.
  referenceDate = [NSCalendarDate dateWithYear: [eventStartDate yearOfCommonEra]
					 month: [eventStartDate monthOfYear]
					   day: 1
					  hour: [eventStartDate hourOfDay]
					minute: [eventStartDate minuteOfHour]
					second: 0
				      timeZone: [eventStartDate timeZone]];

  for (monthIdxInRange = 0, count = 0;
       monthIdxInRange < numberOfMonthsInRange; 
       monthIdxInRange++) 
    {
      NSCalendarDate *cursor;
      unsigned       numDaysInMonth;
      int            monthIdxInRecurrence, dom;
      NGMonthDaySet  monthDays;
      BOOL           didByFill, doCont;
    
      monthIdxInRecurrence = diff + monthIdxInRange;
    
      if (monthIdxInRecurrence < 0)
	continue;
    
      /* first check whether we are in the interval */

      if ((monthIdxInRecurrence % interval) != 0)
	continue;

      cursor = [referenceDate dateByAddingYears: 0
					 months: monthIdxInRecurrence
					   days: 0];
      [cursor setTimeZone: timeZone];
      numDaysInMonth = [cursor numberOfDaysInMonth];
      
      /* check whether we match the BYMONTH constraint */
    
      if (!byMonthList[[cursor monthOfYear] - 1])
	continue;
    
      /* check whether we match the BYMONTHDAY and BYDAY constraints */
    
      didByFill = NO;

      if (byMonthDay)
	{
	  // Initialize the monthDays array with the positive days positions
	  NGMonthDaySet_copyOrUnion (&monthDays, &byPositiveMonthDaySet, !didByFill);

	  // Add to the array the days matching the negative days positions
	  int i;
	  for (i = 1; i <= 31; i++)
	    if (byNegativeMonthDaySet[i])
	      monthDays[numDaysInMonth - i + 1] = YES;
	  didByFill = YES;
	}
    
      if (byDayMask)
	{
          if (!didByFill)
            NGMonthDaySet_clear (&monthDays);

          if (bySetPos)
            {
              NSUInteger monthDay;
              NSInteger currentPos;
              iCalWeekDay currentWeekDay;

              currentWeekDay = [[cursor firstDayOfMonth] dayOfWeek];
              currentPos = 1;
              for (monthDay = 0; monthDay <= numDaysInMonth; monthDay++)
                {
                  if ([byDayMask occursOnDay: currentWeekDay])
                    {
                      if ([bySetPos containsObject:
                                      [NSString stringWithFormat: @"%d", currentPos]])
                        monthDays[monthDay+1] = YES;
                      currentPos++;
                    }
                  currentWeekDay = (currentWeekDay + 1) % 7;
                }

              currentWeekDay = [[cursor lastDayOfMonth] dayOfWeek];
              currentPos = -1;
              for (monthDay = numDaysInMonth; monthDay > 0; monthDay--)
                {
                  if ([byDayMask occursOnDay: currentWeekDay])
                    {
                      if ([bySetPos containsObject:
                                      [NSString stringWithFormat: @"%d", currentPos]])
                        monthDays[monthDay] = YES;
                      currentPos--;
                    }
                  if (currentWeekDay > 0)
                    currentWeekDay--;
                  else
                    currentWeekDay = 6;
                }
            }
          else
            {
              unsigned int firstDoWInMonth, currentWeekDay;
              unsigned int weekDaysCount[7], currentWeekDaysCount[7];
              int i, positiveOrder, negativeOrder;

              firstDoWInMonth = [[cursor firstDayOfMonth] dayOfWeek];

              // Fill weekDaysCount to handle negative positions
              currentWeekDay = firstDoWInMonth;
              memset(weekDaysCount, 0, 7 * sizeof(unsigned int));
              for (i = 1; i <= numDaysInMonth; i++)
                {
                  weekDaysCount[currentWeekDay]++;
                  currentWeekDay = (currentWeekDay + 1) % 7;
                }

              currentWeekDay = firstDoWInMonth;
              memset(currentWeekDaysCount, 0, 7 * sizeof(unsigned int));
              for (i = 1; i <= numDaysInMonth; i++)
                {
                  if (!didByFill || monthDays[i])
                    {
                      positiveOrder = currentWeekDaysCount[currentWeekDay] + 1;
                      negativeOrder = currentWeekDaysCount[currentWeekDay] - weekDaysCount[currentWeekDay];
                      monthDays[i] = (([byDayMask occursOnDay: (iCalWeekDay)currentWeekDay
                                                  withWeekNumber: positiveOrder]) ||
                                      ([byDayMask occursOnDay: (iCalWeekDay)currentWeekDay
                                                  withWeekNumber: negativeOrder]));
                    }
                  currentWeekDaysCount[currentWeekDay]++;
                  currentWeekDay = (currentWeekDay + 1) % 7;
                }
            }
          didByFill = YES;
	}
    
      if (didByFill)
	{
	  if (diff + monthIdxInRange == 0)
	    {
	      // When dealing with the month of the first occurence, remove days
	      // that occur before the first occurrence.
              memset (monthDays, NO, sizeof (BOOL) * eventDayOfMonth);
	      // The first occurrence must always be included.
	      monthDays[eventDayOfMonth] = YES;
	    }
	}
      else
	{
	  // No rules applied, take the dayOfMonth of the startDate
	  NGMonthDaySet_clear (&monthDays);
	  monthDays[eventDayOfMonth] = YES;
	}
    
      /* 
	 Next step is to create NSCalendarDate instances from our 'monthDays'
	 set. We walk over each day of the 'monthDays' set. If its flag isn't
	 set, we continue.
	 If its set, we add the date to the instance.
       
	 The 'cursor' is the *startdate* of the event (not necessarily a
	 component of the sequence!) plus the currently processed month.
	 Eg: 
         startdate: 2007-01-30
	 cursor[1]: 2007-01-30
	 cursor[2]: 2007-02-28 <== Note: we have February!
      */
    
      for (dom = 1, doCont = YES; dom <= numDaysInMonth && doCont; dom++)
	{
	  NSCalendarDate *start;
      
	  if (!monthDays[dom])
	    continue;

	  start = [cursor dateByAddingYears: 0 months: 0 days: (dom - 1)];
	  doCont = [self _addInstanceWithStartDate: start
					 limitDate: until
					limitRange: _r
					   toArray: ranges];
	  //NSLog(@"*** MONTHLY [%i/%i] adding %@%@ (count = %i)", dom, numDaysInMonth, start, (doCont?@"":@" .. NOT!"), count);
	  if (repeatCount > 0)
	    {
	      count++;
	      //NSLog(@"MONTHLY count = %i/%i", count, repeatCount);
	      doCont = (count < repeatCount);
	    }
	}
      if (!doCont) break; /* reached some limit */
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
	  lastInstanceStartDate = [firStart dateByAddingYears: 0
						       months: ([rrule repeatInterval]
								* ([rrule repeatCount] - 1))
							 days: 0];
	}
    }
  else
    lastInstanceStartDate = [super lastInstanceStartDate];

  return lastInstanceStartDate;
}

@end /* iCalMonthlyRecurrenceCalculator */
