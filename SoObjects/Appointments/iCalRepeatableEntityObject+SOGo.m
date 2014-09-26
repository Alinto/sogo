/* iCalRepeatableEntityObject+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2014 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSValue.h>

#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalRecurrenceRule.h>
#import <NGCards/iCalRecurrenceCalculator.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/NSString+NGCards.h>
#import <NGCards/NSDictionary+NGCards.h>

#import <NGExtensions/NGCalendarDateRange.h>

#import "iCalRepeatableEntityObject+SOGo.h"

@implementation iCalRepeatableEntityObject (SOGoExtensions)

- (NSArray *) _indexedRules: (NSArray *) rules
{
  NSMutableArray *ma;
  NSUInteger i, count;
  NSMutableString *ruleString;
  iCalRecurrenceRule *rule;

#warning we could return an NSArray instead and feed it as such to the iCalRecurrenceRule in SOGoAppointmentFolder...

  ma = nil;

  count = [rules count];
  if (count > 0)
    {
      ma = [NSMutableArray arrayWithCapacity: count];
      for (i = 0; i < count; i++)
	{
	  rule = [rules objectAtIndex:i];
          ruleString = [NSMutableString new];
          [[rule values] versitRenderInString: ruleString
                              withKeyOrdering: [rule orderOfValueKeys]
                                 asAttributes: NO];
	  [ma addObject: ruleString];
          [ruleString release];
	}
    }

  return ma;
}

- (NSString *) cycleInfo
{
  NSArray *rules;
  NSString *value;
  NSMutableDictionary *cycleInfo;

  if ([self isRecurrent])
    {
      cycleInfo = [NSMutableDictionary dictionaryWithCapacity: 3];

      /* rules */
      rules = [self _indexedRules: [self recurrenceRules]];
      if (rules)
	[cycleInfo setObject: rules forKey: @"rules"];
      
      rules = [self _indexedRules: [self exceptionRules]];
      if (rules)
	[cycleInfo setObject: rules forKey: @"exRules"];

      rules = [self exceptionDates];
      if ([rules count])
	[cycleInfo setObject: rules forKey: @"exDates"];

      value = [cycleInfo description];
    }
  else
    value = nil;

  return value;
}

/**
 * Extract the start and end dates from the event, from which all recurrence
 * calculations will be based on.
 * @return the range of the first occurrence.
 */
- (NGCalendarDateRange *) firstOccurenceRange
{
  NSCalendarDate *start, *end;
  NGCalendarDateRange *firstRange;
  NSArray *dates;

  firstRange = nil;

  dates = [[[self uniqueChildWithTag: @"dtstart"] valuesForKey: @""] lastObject];
  if ([dates count] > 0)
    {
      start = [[dates lastObject] asCalendarDate]; // ignores timezone
      end = [start addTimeInterval: [self occurenceInterval]];

      firstRange = [NGCalendarDateRange calendarDateRangeWithStartDate: start
                                                               endDate: end];
    }
  
  return firstRange;
}

- (NSTimeInterval) occurenceInterval
{
  [self subclassResponsibility: _cmd];

  return 0;
}

/**
 * Checks if a date is part of the recurring entity.
 * @param theOccurrenceDate the date to verify.
 * @see [SOGoAppointmentFolder _flattenCycleRecord:forRange:intoArray:]
 * @return true if the occurence date is part of the recurring entity.
 */
- (BOOL) doesOccurOnDate: (NSCalendarDate *) theOccurenceDate
{
  NSArray *ranges;
  NGCalendarDateRange *checkRange, *firstRange;
  NSCalendarDate *startDate, *endDate;
  id firstStartDate, timeZone;
  BOOL doesOccur;

  doesOccur = [self isRecurrent];
  if (doesOccur)
    {
      // Retrieve the range of the first event
      firstRange = [self firstOccurenceRange]; // returns GMT dates

      // Set the range to check with respect to the event timezone (extracted from the start date)
      firstStartDate = (iCalDateTime *)[self uniqueChildWithTag: @"dtstart"];
      timeZone = [(iCalDateTime *)firstStartDate timeZone];
      if (timeZone)
          startDate = [(iCalTimeZone *)timeZone computedDateForDate: theOccurenceDate];
      else
	  startDate = theOccurenceDate;
      endDate = [startDate addTimeInterval: [self occurenceInterval]];
      checkRange = [NGCalendarDateRange calendarDateRangeWithStartDate: startDate
							       endDate: endDate];

      // Calculate the occurrences for the given date
      ranges = [iCalRecurrenceCalculator recurrenceRangesWithinCalendarDateRange: checkRange
						  firstInstanceCalendarDateRange: firstRange
								 recurrenceRules: [self recurrenceRulesWithTimeZone: timeZone]
								  exceptionRules: [self exceptionRulesWithTimeZone: timeZone]
								  exceptionDates: [self exceptionDatesWithTimeZone: timeZone]];
      doesOccur = [ranges dateRangeArrayContainsDate: startDate];
    }

  return doesOccur;
}

@end
