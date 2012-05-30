/*
  Copyright (C) 2008-2011 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>

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

- (NGCalendarDateRange *) firstOccurenceRange
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (unsigned int) occurenceInterval
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
  id firstStartDate, firstEndDate, timeZone;
  BOOL doesOccur;
  int offset;

  doesOccur = [self isRecurrent];
  if (doesOccur)
    {
      // Retrieve the range of the first event
      firstRange = [self firstOccurenceRange];

      // Set the range to check with respect to the event timezone (extracted from the start date)
      firstStartDate = (iCalDateTime *)[self uniqueChildWithTag: @"dtstart"];
      timeZone = [(iCalDateTime *)firstStartDate timeZone];
      if (timeZone)
        {
          startDate = [(iCalTimeZone *)timeZone computedDateForDate: theOccurenceDate];
        }
      else
	{
	  startDate = theOccurenceDate;
	  if ([self isKindOfClass: [iCalEvent class]] && [(iCalEvent *) self isAllDay])
	    {
	      // The event lasts all-day and has no timezone (floating); we convert the range of the first event
	      // to the occurence's timezone.
	      timeZone = [theOccurenceDate timeZone];
	      offset = [(NSTimeZone *)timeZone secondsFromGMTForDate: [firstRange startDate]];
	      firstStartDate = (NSCalendarDate *)[[firstRange startDate] dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
										   seconds:-offset];
	      firstEndDate = (NSCalendarDate *)[[firstRange endDate] dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
									       seconds:-offset];
	      [(NSCalendarDate *)firstStartDate setTimeZone: timeZone];
	      [(NSCalendarDate *)firstEndDate setTimeZone: timeZone];

	      firstRange = [NGCalendarDateRange calendarDateRangeWithStartDate: firstStartDate
								       endDate: firstEndDate];
	    }
	}
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
