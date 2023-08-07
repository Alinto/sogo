/* iCalRepeatableEntityObject+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2022 Inverse inc.
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

#import <Foundation/NSTimeZone.h>
#import <Foundation/NSValue.h>

#import <NGCards/iCalByDayMask.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalRecurrenceCalculator.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/NSString+NGCards.h>
#import <NGCards/NSDictionary+NGCards.h>

#import <NGExtensions/NGCalendarDateRange.h>

#import <SoObjects/SOGo/CardElement+SOGo.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoUserDefaults.h>
#import <SoObjects/SOGo/WOContext+SOGo.h>

#import <SOGo/NSCalendarDate+SOGo.h>

#import "iCalRepeatableEntityObject+SOGo.h"
#import "iCalCalendar+SOGo.h"

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

/**
 * @see [iCalEntityObject+SOGo attributes]
 * @see [iCalEvent+SOGo attributes]
 * @see [UIxAppointmentEditor viewAction]
 */
- (NSDictionary *) attributesInContext: (WOContext *) context
{
  NSArray *allComponents, *rules, *dates;
  NSCalendarDate *untilDate;
  NSMutableDictionary *data, *repeat;
  NSString *frequency;
  NSTimeZone *timeZone;
  SOGoUserDefaults *ud;
  iCalEvent *masterComponent;
  iCalRecurrenceRule *rule;
  NSInteger i, count;

  data = [NSMutableDictionary dictionaryWithDictionary: [super attributesInContext: context]];

  if ([self recurrenceId])
    {
      // If the component is an occurrence of a recurrent component,
      // consider the recurrence rules of the master component.
      if ([self isKindOfClass: [iCalEvent class]])
        allComponents = [[self parent] events];
      else
        allComponents = [[self parent] todos];
      masterComponent = [allComponents objectAtIndex: 0];
      rules = [masterComponent recurrenceRules];
      dates = [masterComponent recurrenceDates];
    }
  else
    {
      rules = [self recurrenceRules];
      dates = [self recurrenceDates];
    }

  if ([rules count] > 0)
    {
      // Consider first rule only
      rule = [rules objectAtIndex: 0];
      frequency = [rule frequencyForValue: [rule frequency]];

      repeat = [NSMutableDictionary dictionary];
      [repeat setObject: [frequency lowercaseString] forKey: @"frequency"];
      [repeat setObject: [NSNumber numberWithInt: [rule repeatInterval]] forKey: @"interval"];
      if ([rule repeatCount])
        [repeat setObject: [NSNumber numberWithInt: [rule repeatCount]] forKey: @"count"];
      if ((untilDate = [rule untilDate]))
        {
          ud = [[context activeUser] userDefaults];
          timeZone = [ud timeZone];
          [untilDate setTimeZone: timeZone];

          if ([(iCalEvent *)self isAllDay])
            {
              NSInteger offset;

              // Convert the dates to the user's timezone
              offset = [timeZone secondsFromGMTForDate: untilDate];
              untilDate = [untilDate dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
                                               seconds:-offset];
            }

          [repeat setObject: [untilDate iso8601DateString] forKey: @"until"];
        }
      if ([[rule byDay] length])
        [repeat setObject: [[rule byDayMask] asRuleArray] forKey: @"days"];
      if ([[rule byMonthDay] count])
        {
          NSMutableArray *byMonthDay = [NSMutableArray arrayWithArray: [rule byMonthDay]];
          NSMutableArray *byDay = [NSMutableArray array];
          count = [byMonthDay count];
          for (i = count - 1; i >= 0; i--)
            {
              NSString *day = [byMonthDay objectAtIndex: i];
              if ([day intValue] < 0)
                {
                  // Relative BYMONTHDAY mask are moved to the "days" array
                  [byDay addObject: [NSDictionary dictionaryWithObjectsAndKeys:
                                                    @"relative", @"day",
                                                  day, @"occurrence",
                                                  nil]];
                  [byMonthDay removeObjectAtIndex: i];
                }
            }
          if ([byMonthDay count])
            [repeat setObject: byMonthDay forKey: @"monthdays"];
          if ([byDay count])
            [repeat setObject: byDay forKey: @"days"];
        }
      if ([[rule byMonth] count])
        [repeat setObject: [rule byMonth] forKey: @"months"];
      [data setObject: repeat forKey: @"repeat"];
    }

  if ([dates count] > 0)
    {
      NSMutableArray *rDates = [NSMutableArray array];
      NSCalendarDate *rDate;
      ud = [[context activeUser] userDefaults];
      timeZone = [ud timeZone];
      count = [dates count];
      for (i = 0; i < count; i++)
        {
          rDate = [dates objectAtIndex: i];
          [rDate setTimeZone: timeZone];
          [rDates addObject: [rDate iso8601DateString]];
        }
      [data setObject: [NSDictionary dictionaryWithObject: rDates forKey: @"dates"] forKey: @"repeat"];
    }

  return data;
}

/**
 * @see [iCalEntityObject+SOGo setAttributes:inContext:]
 * @see [UIxAppointmentEditor saveAction]
 */
- (void) setAttributes: (NSDictionary *) data
             inContext: (WOContext *) context
{
  iCalRecurrenceRule *rule;
  iCalRecurrenceFrequency frequency;
  NSArray *rdates;
  NSCalendarDate *date;
  SOGoUserDefaults *ud;
  NSInteger i;
  BOOL isAllDay;
  id repeat, o;

  [super setAttributes: data inContext: context];

  if ([self recurrenceId])
    // Occurrence of a recurrent object can't have a recurrence rule
    return;

  repeat = [data objectForKey: @"repeat"];
  isAllDay = [[data objectForKey: @"isAllDay"] boolValue];
  if ([repeat isKindOfClass: [NSDictionary class]])
    {
      rule = [iCalRecurrenceRule new];
      [rule setInterval: @"1"];

      frequency = 0;
      o = [repeat objectForKey: @"frequency"];
      if ([o isKindOfClass: [NSString class]])
        {
          frequency = [rule valueForFrequency: o];
          if (!frequency)
            {
              if ([o caseInsensitiveCompare: @"BI-WEEKLY"] == NSOrderedSame)
                {
                  frequency = iCalRecurrenceFrequenceWeekly;
                  [rule setInterval: @"2"];
                }
              else if ([o caseInsensitiveCompare: @"EVERY WEEKDAY"] == NSOrderedSame)
                {
                  frequency = iCalRecurrenceFrequenceDaily;
                  [rule setByDayMask: [iCalByDayMask byDayMaskWithWeekDays]];
                }
              else if ([o caseInsensitiveCompare: @"CUSTOM"] == NSOrderedSame)
                {
                  [self removeAllRecurrenceDates];
                  o = [repeat objectForKey: @"dates"];
                  if ([o isKindOfClass: [NSArray class]])
                    {
                      rdates = o;
                      for (i = 0; i < [rdates count]; i++)
                        {
                          o = [rdates objectAtIndex: i];
                          if ([o isKindOfClass: [NSDictionary class]])
                            {
                              date = [self dateFromString: [o objectForKey: @"date"] inContext: context];
                              if (!isAllDay)
                                [self adjustDate: &date withTimeString: [o objectForKey: @"time"] inContext: context];
                              [self addToRecurrenceDates: date];
                            }
                        }
                    }
                }
	    }
          else
            {
              o = [repeat objectForKey: @"interval"];
              if ([o isKindOfClass: [NSNumber class]])
                [rule setInterval: [NSString stringWithFormat: @"%i", [o intValue]]];

              o = [repeat objectForKey: @"count"];
              if ([o isKindOfClass: [NSNumber class]])
                [rule setRepeatCount: [o intValue]];

              o = [repeat objectForKey: @"until"];
              if ([o isKindOfClass: [NSString class]])
                {
                  date = [NSCalendarDate dateWithString: o
                                         calendarFormat: @"%Y-%m-%d"];
                  if (date)
                    {
                      if (isAllDay)
                        {
                          [rule setUntil: [date descriptionWithCalendarFormat: @"%Y%m%d"]];
                        }
                      else
                        {
                          // Adjust timezone
                          ud = [[context activeUser] userDefaults];
                          date = [NSCalendarDate dateWithYear: [date yearOfCommonEra]
                                                        month: [date monthOfYear]
                                                          day: [date dayOfMonth]
                                                         hour: 0 minute: 0 second: 0
                                                     timeZone: [ud timeZone]];
                          [rule setUntilDate: date];
                        }
                    }
                }

              o = [repeat objectForKey: @"days"];
              if ([o isKindOfClass: [NSArray class]])
                [rule setByDayMask: [iCalByDayMask byDayMaskWithDaysAndOccurrences: o]];

              o = [repeat objectForKey: @"monthdays"];
              if ([o isKindOfClass: [NSArray class]])
                [rule setValues: o atIndex: 0 forKey: @"bymonthday"];

              o = [repeat objectForKey: @"months"];
              if ([o isKindOfClass: [NSArray class]])
                [rule setValues: o atIndex: 0 forKey: @"bymonth"];
            }

          if (frequency)
            {
              [rule setFrequency: frequency];
              [self setRecurrenceRules: [NSArray arrayWithObject: rule]];
            }

	  [rule release];
        }
    }
  else if ([self hasRecurrenceRules])
    {
      [self removeAllRecurrenceRules];
    }
  else if ([self hasRecurrenceDates])
    {
      [self removeAllRecurrenceDates];
    }
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

      /* recurrence dates */
      rules = [self recurrenceDates];
      if ([rules count])
	[cycleInfo setObject: rules forKey: @"rDates"];

      /* exception dates */
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
  NSMutableArray *ranges;
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
    ranges = [NSMutableArray arrayWithArray:
                          [iCalRecurrenceCalculator recurrenceRangesWithinCalendarDateRange: checkRange
                                                             firstInstanceCalendarDateRange: firstRange
                                                                            recurrenceRules: [self recurrenceRulesWithTimeZone: timeZone]
                                                                             exceptionRules: [self exceptionRulesWithTimeZone: timeZone]
                                                                            recurrenceDates: [self recurrenceDatesWithTimeZone: timeZone]
                                                                             exceptionDates: [self exceptionDatesWithTimeZone: timeZone]]];

    // Add the master occurrence when dealing with RDATES.
    // However, the master event must not be flagged with X-MOZ-FAKED-MASTER.
    if ([self hasRecurrenceDates] &&
          ![[[self uniqueChildWithTag: @"x-moz-faked-master"] flattenedValuesForKey: @""] isEqualToString: @"1"] &&
            [checkRange doesIntersectWithDateRange: firstRange])
    {
      [ranges insertObject: firstRange atIndex: 0];
    }

    doesOccur = [ranges dateRangeArrayContainsDate: startDate];
  }

  return doesOccur;
}

@end
