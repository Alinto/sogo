/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2012 Inverse inc.

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

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>

#import <NGExtensions/NGCalendarDateRange.h>

#import "NSCalendarDate+NGCards.h"
#import "NSString+NGCards.h"
#import "iCalDateTime.h"
#import "iCalEvent.h"
#import "iCalTimeZone.h"
#import "iCalTimeZonePeriod.h"
#import "iCalRecurrenceRule.h"
#import "iCalRecurrenceCalculator.h"
#import "iCalRepeatableEntityObject.h"

@implementation iCalRepeatableEntityObject

- (Class) classForTag: (NSString *) classTag
{
  Class tagClass;

  if ([classTag isEqualToString: @"RRULE"])
    tagClass = [iCalRecurrenceRule class];
  else if ([classTag isEqualToString: @"EXDATE"])
    tagClass = [iCalDateTime class];
  else
    tagClass = [super classForTag: classTag];

  return tagClass;
}

/* Accessors */

- (void) removeAllRecurrenceRules
{
  [self removeChildren: [self recurrenceRules]];
}

- (void) addToRecurrenceRules: (id) _rrule
{
  [self addChild: _rrule];
}

- (void) setRecurrenceRules: (NSArray *) _rrules
{
  [children removeObjectsInArray: [self childrenWithTag: @"rrule"]];
  [self addChildren: _rrules];
}

- (BOOL) hasRecurrenceRules
{
  return ([[self childrenWithTag: @"rrule"] count] > 0);
}

- (NSArray *) recurrenceRules
{
  return [self childrenWithTag: @"rrule"];
}

- (NSArray *) recurrenceRulesWithTimeZone: (id) timezone
{
  NSArray *rules;

  rules = [self recurrenceRules];
  return [self rules: rules withTimeZone: timezone];
}

- (void) removeAllExceptionRules
{
  [self removeChildren: [self exceptionRules]];
}

- (void) addToExceptionRules: (id) _rrule
{
  [self addChild: _rrule];
}

- (void) setExceptionRules: (NSArray *) _rrules
{
  [children removeObjectsInArray: [self childrenWithTag: @"exrule"]];
  [self addChildren: _rrules];
}

- (BOOL) hasExceptionRules
{
  return ([[self childrenWithTag: @"exrule"] count] > 0);
}

- (NSArray *) exceptionRules
{
  return [self childrenWithTag: @"exrule"];
}

- (NSArray *) exceptionRulesWithTimeZone: (id) timezone
{
  NSArray *rules;

  rules = [self exceptionRules];
  return [self rules: rules withTimeZone: timezone];
}

/**
 * Returns a new set of rules, but with "until dates" adjusted to the 
 * specified timezone.
 * Used when calculating a recurrence/exception rule.
 * @param theRules the iCalRecurrenceRule instances
 * @param theTimeZone the timezone of the entity.
 * @see recurrenceRulesWithTimeZone:
 * @see exceptionRulesWithTimeZone:
 * @return a new array of iCalRecurrenceRule instances, adjusted for the timezone.
 */
- (NSArray *) rules: (NSArray *) theRules withTimeZone: (id) theTimeZone
{
  NSArray *rules;
  NSCalendarDate *untilDate;
  NSMutableArray *fixedRules;
  iCalRecurrenceRule *currentRule;
  int offset;
  unsigned int max, count;

  rules = theRules;
  if (theTimeZone)
    {
      max = [rules count];
      if (max)
	{
	  fixedRules = [NSMutableArray arrayWithCapacity: max];
	  for (count = 0; count < max; count++)
	    {
	      currentRule = [rules objectAtIndex: count];
	      untilDate = [currentRule untilDate];
	      if (untilDate)
		{
                  if ([theTimeZone isKindOfClass: [iCalTimeZone class]])
                    untilDate = [(iCalTimeZone *) theTimeZone computedDateForDate: untilDate];
                  else
                    {
                      offset = [(NSTimeZone *) theTimeZone secondsFromGMTForDate: untilDate];
                      untilDate = (NSCalendarDate *) [untilDate dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
                                                                          seconds:-offset];
                    }
		  [currentRule setUntilDate: untilDate];
		}
	      [fixedRules addObject: currentRule];
	    }
	  rules = fixedRules;
	}
    }

  return rules;
}

- (void) removeAllExceptionDates
{
  [self removeChildren: [self childrenWithTag: @"exdate"]];
}

- (void) addToExceptionDates: (NSCalendarDate *) _rdate
{
  iCalDateTime *dateTime;

  dateTime = [iCalDateTime new];
  [dateTime setTag: @"exdate"];
  if ([self isKindOfClass: [iCalEvent class]] && [(iCalEvent *)self isAllDay])
    [dateTime setDate: _rdate];
  else
    [dateTime setDateTime: _rdate];
  [self addChild: dateTime];
  [dateTime release];
}

//- (void) setExceptionDates: (NSArray *) _rdates
//{
//  [children removeObjectsInArray: [self childrenWithTag: @"exdate"]];
//  [self addChildren: _rdates];
//}

- (BOOL) hasExceptionDates
{
  return ([[self childrenWithTag: @"exdate"] count] > 0);
}

/**
 * Return the exception dates of the entity in GMT.
 * @return an array of strings.
 */
- (NSArray *) exceptionDates
{
  NSArray *exDates;
  NSMutableArray *dates;
  NSEnumerator *dateList;
  NSCalendarDate *exDate;
  NSString *dateString;
  unsigned i;

  dates = [NSMutableArray array];
  dateList = [[self childrenWithTag: @"exdate"] objectEnumerator];
  
  while ((dateString = [dateList nextObject]))
    {
      exDates = [(iCalDateTime*) dateString dateTimes];
      for (i = 0; i < [exDates count]; i++)
	{
	  exDate = [exDates objectAtIndex: i];
	  dateString = [NSString stringWithFormat: @"%@Z",
				 [exDate iCalFormattedDateTimeString]];
	  [dates addObject: dateString];
	}
    }

  return dates;
}

/**
 * Returns the exception dates for the entity, but adjusted to the entity timezone.
 * Used when calculating a recurrence rule.
 * @param theTimeZone the timezone of the entity.
 * @see [iCalTimeZone computedDatesForStrings:]
 * @return the exception dates, adjusted to the timezone.
 */
- (NSArray *) exceptionDatesWithTimeZone: (id) theTimeZone
{
  NSArray *dates, *exDates;
  NSEnumerator *dateList;
  NSCalendarDate *exDate;
  NSString *dateString;
  int offset;
  unsigned i;

  if (theTimeZone)
    {
      dates = [NSMutableArray array];
      dateList = [[self childrenWithTag: @"exdate"] objectEnumerator];
      
      while ((dateString = [dateList nextObject]))
	{
          exDates = [(iCalDateTime*) dateString dateTimes];
          for (i = 0; i < [exDates count]; i++)
	    {
	      exDate = [exDates objectAtIndex: i];

              // Example: timezone is -0400, date is 2012-05-24 (00:00:00 +0000),
              //                      and changes to 2012-05-24 04:00:00 +0000
              if ([theTimeZone isKindOfClass: [iCalTimeZone class]])
                {
                    exDate = [(iCalTimeZone *) theTimeZone computedDateForDate: exDate];
                }
              else
                {
                  offset = [(NSTimeZone *) theTimeZone secondsFromGMTForDate: exDate];
                  exDate = (NSCalendarDate *) [exDate dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
                                                               seconds:-offset];
                }
	      [(NSMutableArray *) dates addObject: exDate];
   	    }
	}
    }
  else
    dates = [self exceptionDates];

  return dates;
}

/* Convenience */

- (BOOL) isRecurrent
{
  return [self hasRecurrenceRules];
}

/* Matching */

- (BOOL) isWithinCalendarDateRange: (NGCalendarDateRange *) _range
    firstInstanceCalendarDateRange: (NGCalendarDateRange *) _fir
{
  NSArray *ranges;
  
  ranges = [self recurrenceRangesWithinCalendarDateRange:_range
                 firstInstanceCalendarDateRange:_fir];
  return [ranges count] > 0;
}

- (NSArray *) recurrenceRangesWithinCalendarDateRange: (NGCalendarDateRange *)_r
                       firstInstanceCalendarDateRange: (NGCalendarDateRange *)_fir
{
  return [iCalRecurrenceCalculator recurrenceRangesWithinCalendarDateRange: _r
                                   firstInstanceCalendarDateRange: _fir
                                   recurrenceRules: [self recurrenceRules]
                                   exceptionRules: [self exceptionRules]
                                   exceptionDates: [self exceptionDates]];
}


/* this is the outmost bound possible, not necessarily the real last date */
-    (NSCalendarDate *)
lastPossibleRecurrenceStartDateUsingFirstInstanceCalendarDateRange: (NGCalendarDateRange *)_r
{
  NSCalendarDate *date;
  NSEnumerator *rRules;
  iCalRecurrenceRule *rule;
  iCalRecurrenceCalculator *calc;
  NSCalendarDate *rdate;

  date  = nil;

  rRules = [[self recurrenceRules] objectEnumerator];
  rule = [rRules nextObject];
  while (rule && ![rule isInfinite] & !date)
    {
      calc = [iCalRecurrenceCalculator
               recurrenceCalculatorForRecurrenceRule: rule
               withFirstInstanceCalendarDateRange: _r];
      rdate = [[calc lastInstanceCalendarDateRange] startDate];
      if (!date
          || ([date compare: rdate] == NSOrderedAscending))
        date = rdate;
      else
        rule = [rRules nextObject];
    }

  return date;
}

- (NSCalendarDate *) firstRecurrenceStartDateWithEndDate: (NSCalendarDate *) endDate
{
  NSCalendarDate *startDate, *firstOccurrenceStartDate, *endOfFirstRange;
  NGCalendarDateRange *range, *firstInstanceRange;
  iCalRecurrenceFrequency frequency;
  iCalRecurrenceRule *rule;
  NSArray *rules, *recurrences;
  uint32_t units;

  firstOccurrenceStartDate = nil;

  rules = [self recurrenceRules];
  if ([rules count] > 0)
    {
      rule = [rules objectAtIndex: 0];
      frequency = [rule frequency];
      units = [rule repeatInterval];

      startDate = [self startDate];
      switch (frequency)
        {
          /* second-based units */
        case iCalRecurrenceFrequenceWeekly:
          units *= 7;
        case iCalRecurrenceFrequenceDaily:
          units *= 24;
        case iCalRecurrenceFrequenceHourly:
          units *= 60;
        case iCalRecurrenceFrequenceMinutely:
          units *= 60;
        case iCalRecurrenceFrequenceSecondly:
          endOfFirstRange = [startDate dateByAddingYears: 0 months: 0 days: 0
                                                   hours: 0 minutes: 0
                                                 seconds: units];
          break;

          /* month-based units */
        case iCalRecurrenceFrequenceYearly:
          units *= 12;
        case iCalRecurrenceFrequenceMonthly:
          endOfFirstRange = [startDate dateByAddingYears: 0 months: (units + 1)
                                                    days: 0
                                                   hours: 0 minutes: 0
                                                 seconds: 0];
          break;

        default:
          endOfFirstRange = nil;
        }

      if (endOfFirstRange)
        {
          range = [NGCalendarDateRange calendarDateRangeWithStartDate: startDate
                                                              endDate: endOfFirstRange];
          firstInstanceRange = [NGCalendarDateRange calendarDateRangeWithStartDate: startDate
                                                                           endDate: endDate];
          recurrences = [iCalRecurrenceCalculator recurrenceRangesWithinCalendarDateRange: range
                                                           firstInstanceCalendarDateRange: firstInstanceRange
                                                                          recurrenceRules: rules
                                                                           exceptionRules: nil
                                                                           exceptionDates: nil];
          if ([recurrences count] > 0)
            firstOccurrenceStartDate = [[recurrences objectAtIndex: 0]
                                         startDate];
        }
    }

  return firstOccurrenceStartDate;
}

@end
