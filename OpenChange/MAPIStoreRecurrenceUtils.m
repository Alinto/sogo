/* MAPIStoreRecurrenceUtils.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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
#import <Foundation/NSString.h>

#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGCards/iCalRepeatableEntityObject.h>
#import <NGCards/iCalRecurrenceRule.h>
#import <NGCards/iCalByDayMask.h>

#import "NSDate+MAPIStore.h"
#import "MAPIStoreRecurrenceUtils.h"

#include <stdbool.h>
#include <talloc.h>
#include <util/time.h>
#include <gen_ndr/property.h>

@implementation iCalCalendar (MAPIStoreRecurrence)

- (void) setupRecurrenceWithMasterEntity: (iCalRepeatableEntityObject *) entity
                   fromRecurrencePattern: (struct RecurrencePattern *) rp
{
  NSCalendarDate *startDate, *olEndDate, *untilDate;
  NSString *monthDay, *month;
  iCalRecurrenceRule *rule;
  iCalByDayMask *byDayMask;
  iCalWeekOccurrence weekOccurrence;
  iCalWeekOccurrences dayMaskDays;
  NSUInteger count;
  NSInteger bySetPos;
  unsigned char maskValue;

  [entity removeAllRecurrenceRules];
  [entity removeAllExceptionRules];
  [entity removeAllExceptionDates];

  rule = [iCalRecurrenceRule elementWithTag: @"rrule"];
  [entity addToRecurrenceRules: rule];

  startDate = [entity startDate];
  // DEBUG(5, ("From client:\n"));
  // NDR_PRINT_DEBUG(AppointmentRecurrencePattern, pattern);

  memset (&dayMaskDays, 0, sizeof (iCalWeekOccurrences));
  if (rp->PatternType == PatternType_Day)
    {
      [rule setFrequency: iCalRecurrenceFrequenceDaily];
      [rule setRepeatInterval: rp->Period / SOGoMinutesPerDay];
    }
  else if (rp->PatternType == PatternType_Week)
    {
      [rule setFrequency: iCalRecurrenceFrequenceWeekly];
      [rule setRepeatInterval: rp->Period];
      /* MAPI values for days are the same as in NGCards */
      for (count = 0; count < 7; count++)
        {
          maskValue = 1 << count;
          if ((rp->PatternTypeSpecific.WeekRecurrencePattern & maskValue))
            dayMaskDays[count] = iCalWeekOccurrenceAll;
        }
      byDayMask = [iCalByDayMask byDayMaskWithDays: dayMaskDays];
      [rule setByDayMask: byDayMask];
    }
  else
    {
      if (rp->RecurFrequency
          == RecurFrequency_Monthly)
        {
          [rule setFrequency: iCalRecurrenceFrequenceMonthly];
          [rule setRepeatInterval: rp->Period];
        }
      else if (rp->RecurFrequency
               == RecurFrequency_Yearly)
        {
          [rule setFrequency: iCalRecurrenceFrequenceYearly];
          [rule setRepeatInterval: rp->Period / 12];
          month = [NSString stringWithFormat: @"%d", [startDate monthOfYear]];
          [rule setSingleValue: month forKey: @"bymonth"];
        }
      else
        [self errorWithFormat:
                @"unhandled frequency case for Month pattern type: %d",
              rp->RecurFrequency];

      if ((rp->PatternType & 3) == 3)
        {
          /* HjMonthNth and MonthNth */
          if (rp->PatternTypeSpecific.MonthRecurrencePattern.WeekRecurrencePattern
              == 0x7f)
            {
              /* firsts or last day of month */
              if (rp->PatternTypeSpecific.MonthRecurrencePattern.N
                  == RecurrenceN_Last)
                monthDay = @"-1";
              else
                monthDay = [NSString stringWithFormat: @"%d",
                                     rp->PatternTypeSpecific.MonthRecurrencePattern.N];
              [rule setSingleValue: monthDay forKey: @"bymonthday"];
            }
          else if ((rp->PatternTypeSpecific.MonthRecurrencePattern.WeekRecurrencePattern
                    == 0x3e) /* Nth week day */
                   || (rp->PatternTypeSpecific.MonthRecurrencePattern.WeekRecurrencePattern
                       == 0x41)) /* Nth week-end day */
            {
              for (count = 0; count < 7; count++)
                {
                  maskValue = 1 << count;
                  if ((rp->PatternTypeSpecific.MonthRecurrencePattern.WeekRecurrencePattern
                       & maskValue))
                    dayMaskDays[count] = iCalWeekOccurrenceAll;
                }
              byDayMask = [iCalByDayMask byDayMaskWithDays: dayMaskDays];
              [rule setByDayMask: byDayMask];

              if (rp->PatternTypeSpecific.MonthRecurrencePattern.N
                  == RecurrenceN_Last)
                bySetPos = -1;
              else
                bySetPos = rp->PatternTypeSpecific.MonthRecurrencePattern.N;
              
              [rule
                setSingleValue: [NSString stringWithFormat: @"%d", bySetPos]
                        forKey: @"bysetpos"];
            }
          else 
            {
              if (rp->PatternTypeSpecific.MonthRecurrencePattern.N
                  < RecurrenceN_Last)
                weekOccurrence = (1
                                  << (rp->PatternTypeSpecific.MonthRecurrencePattern.N
                                      - 1));
              else
                weekOccurrence = iCalWeekOccurrenceLast;
              
              for (count = 0; count < 7; count++)
                {
                  maskValue = 1 << count;
                  if ((rp->PatternTypeSpecific.MonthRecurrencePattern.WeekRecurrencePattern
                       & maskValue))
                    dayMaskDays[count] = weekOccurrence;
                }
              byDayMask = [iCalByDayMask byDayMaskWithDays: dayMaskDays];
              [rule setByDayMask: byDayMask];
            }
        }
      else if ((rp->PatternType & 2) == 2
               || (rp->PatternType & 4) == 4)
        {
          /* MonthEnd, HjMonth and HjMonthEnd */
          [rule
            setSingleValue: [NSString stringWithFormat: @"%d",
                                      rp->PatternTypeSpecific.Day]
                    forKey: @"bymonthday"];
        }
      else
        [self errorWithFormat: @"invalid value for PatternType: %.4x",
              rp->PatternType];
    }

  switch (rp->EndType)
    {
    case END_NEVER_END:
    case NEVER_END:
      break;
    case END_AFTER_N_OCCURRENCES:
      [rule setRepeatCount: rp->OccurrenceCount];
      break;
    case END_AFTER_DATE:
      olEndDate = [NSCalendarDate dateFromMinutesSince1601: rp->EndDate];
      untilDate = [NSCalendarDate dateWithYear: [olEndDate yearOfCommonEra]
                                       month: [olEndDate monthOfYear]
                                         day: [olEndDate dayOfMonth]
                                        hour: [startDate hourOfDay]
                                      minute: [startDate minuteOfHour]
                                      second: [startDate secondOfMinute]
                                    timeZone: [startDate timeZone]];
      [rule setUntilDate: untilDate];
      break;
    default:
      [self errorWithFormat: @"invalid value for EndType: %.4x",
            rp->EndType];
    }
}

@end

@implementation iCalRecurrenceRule (MAPIStoreRecurrence)

- (void) fillRecurrencePattern: (struct RecurrencePattern *) rp
                 withStartDate: (NSCalendarDate *) startDate
                    andEndDate: (NSCalendarDate *) endDate
{
  iCalRecurrenceFrequency freq;
  iCalByDayMask *byDayMask;
  NSString *byMonthDay, *bySetPos;
  NSCalendarDate *untilDate, *beginOfWeek, *minimumDate, *moduloDate, *midnight;
  iCalWeekOccurrences *days;
  NSInteger dayOfWeek, repeatInterval, repeatCount, count, firstOccurrence;
  uint32_t nbrMonths, mask;

  rp->ReaderVersion = 0x3004;
  rp->WriterVersion = 0x3004;

  rp->StartDate = [[startDate beginOfDay] asMinutesSince1601];

  untilDate = [self untilDate];
  if (untilDate)
    {
      rp->EndDate = [untilDate asMinutesSince1601];
      rp->EndType = END_AFTER_DATE;
    }
  else
    {
      repeatCount = [self repeatCount];
      if (repeatCount > 0)
        {
          rp->EndDate = [endDate asMinutesSince1601];
          rp->OccurrenceCount = repeatCount;
          rp->EndType = END_AFTER_N_OCCURRENCES;
        }
      else
        {
          rp->EndDate = 0x5ae980df;
          rp->EndType = END_NEVER_END;
        }
    }

  freq = [self frequency];
  repeatInterval = [self repeatInterval];
  if (freq == iCalRecurrenceFrequenceDaily)
    {
      rp->RecurFrequency = RecurFrequency_Daily;
      rp->PatternType = PatternType_Day;
      rp->Period = repeatInterval * SOGoMinutesPerDay;
      rp->FirstDateTime = rp->StartDate % rp->Period;
    }
  else if (freq == iCalRecurrenceFrequenceWeekly)
    {
      rp->RecurFrequency = RecurFrequency_Weekly;
      rp->PatternType = PatternType_Week;
      rp->Period = repeatInterval;
      mask = 0;
      byDayMask = [self byDayMask];
      for (count = 0; count < 7; count++)
        if ([byDayMask occursOnDay: count])
          mask |= 1 << count;
      rp->PatternTypeSpecific.WeekRecurrencePattern = mask;

      /* FirstDateTime */
      dayOfWeek = [startDate dayOfWeek];
      if (dayOfWeek)
        beginOfWeek = [startDate dateByAddingYears: 0 months: 0
                                              days: -dayOfWeek
                                             hours: 0 minutes: 0
                                           seconds: 0];
      else
        beginOfWeek = startDate;
      rp->FirstDateTime = ([[beginOfWeek beginOfDay] asMinutesSince1601]
                           % (repeatInterval * 10080));
    }
  else
    {
      if (freq == iCalRecurrenceFrequenceMonthly)
        {
          rp->RecurFrequency = RecurFrequency_Monthly;
          rp->Period = repeatInterval;
        }
      else if (freq == iCalRecurrenceFrequenceYearly)
        {
          rp->RecurFrequency = RecurFrequency_Yearly;
          rp->Period = 12;
          if (repeatInterval != 1)
            [self errorWithFormat:
                    @"yearly interval '%d' cannot be converted",
                  repeatInterval];
        }
      else
        [self errorWithFormat: @"frequency '%d' cannot be converted", freq];

      /* FirstDateTime */
      midnight = [[startDate firstDayOfMonth] beginOfDay];
      minimumDate = [NSCalendarDate dateFromMinutesSince1601: 0];
      nbrMonths = (([midnight yearOfCommonEra]
                    - [minimumDate yearOfCommonEra]) * 12
                   + [midnight monthOfYear] - 1);
      moduloDate = [minimumDate dateByAddingYears: 0
                                           months: (nbrMonths % rp->Period)
                                             days: 0 hours: 0 minutes: 0
                                          seconds: 0];
      rp->FirstDateTime = [moduloDate asMinutesSince1601];

      byMonthDay = [[self byMonthDay] objectAtIndex: 0];
      if (!byMonthDay && (freq == iCalRecurrenceFrequenceYearly))
        {
          byMonthDay = [NSString stringWithFormat: @"%d", [startDate dayOfMonth]];
          [self warnWithFormat: @"no month day specified in yearly"
                @" recurrence: we deduce it from the start date: %@",
                byMonthDay];
        }

      if (byMonthDay)
        {
          if ([byMonthDay intValue]  < 0)
            {
              /* This means we cannot handle values of BYMONTHDAY that are <
                 -7. */
              rp->PatternType = PatternType_MonthNth;
              rp->PatternTypeSpecific.MonthRecurrencePattern.WeekRecurrencePattern = 0x7f;
              rp->PatternTypeSpecific.MonthRecurrencePattern.N = RecurrenceN_Last;
            }
          else
            {
              rp->PatternType = PatternType_Month;
              rp->PatternTypeSpecific.Day = [byMonthDay intValue];
            }
        }
      else
        {
          rp->PatternType = PatternType_MonthNth;
          byDayMask = [self byDayMask];
          mask = 0;
          days = [byDayMask weekDayOccurrences];
          if (days)
            {
              for (count = 0; count < 7; count++)
                if (days[0][count])
                  mask |= 1 << count;
            }
          if (mask)
            {
              rp->PatternTypeSpecific.MonthRecurrencePattern.WeekRecurrencePattern = mask;
              bySetPos = [self flattenedValuesForKey: @"bysetpos"];
              if ([bySetPos length])
                rp->PatternTypeSpecific.MonthRecurrencePattern.N
                  = ([bySetPos hasPrefix: @"-"]
                     ? RecurrenceN_Last : [bySetPos intValue]);
              else
                {
                  firstOccurrence = [byDayMask firstOccurrence];
                  if (firstOccurrence)
                    rp->PatternTypeSpecific.MonthRecurrencePattern.N
                      = ((firstOccurrence > -1)
                         ? firstOccurrence : RecurrenceN_Last);
                }
            }
          else
            [self errorWithFormat: @"rule for an event that never occurs"];
        }
    }
}

@end
