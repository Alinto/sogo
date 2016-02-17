/* iCalTimeZone+MAPIStore.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Inverse inc
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
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>
#import <NGCards/iCalByDayMask.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalTimeZonePeriod.h>
#import <NGCards/iCalRecurrenceRule.h>

#import "NSString+MAPIStore.h"
#import "NSData+MAPIStore.h"
#import "NSDate+MAPIStore.h"

#include <stdbool.h>
#include <stdint.h>
#include <talloc.h>
#undef DEBUG
#include <libmapi/libmapi.h>

#import "iCalTimeZone+MAPIStore.h"
#import "MAPIStoreTypes.h"

@interface iCalTimeZonePeriod (MAPIStorePropertiesPrivate)

- (void) _fillTZDate: (struct SYSTEMTIME *) tzData;

@end

@implementation iCalTimeZonePeriod (MAPIStorePropertiesPrivate)

- (void) _fillTZDate: (struct SYSTEMTIME *) tzData
{
  iCalRecurrenceRule *rrule;
  NSArray *byMonth;
  iCalByDayMask *mask;
  NSCalendarDate *dateValue;
  int16_t wDay;

  rrule = [self recurrenceRule];
  byMonth = [rrule byMonth];
  if ([byMonth count] > 0)
    {
      tzData->wMonth = [[byMonth objectAtIndex: 0] intValue];
      mask = [rrule byDayMask];
      tzData->wDayOfWeek = [mask firstDay];
      wDay = [mask firstOccurrence];
      if (wDay < 0)
          /* [MS-OXOCAL] the wDay field is set to indicate the
             occurrence of the day of the week within the month (1 to
             5, where 5 indicates the final occurrence during the
             month if that day of the week does not occur 5 times). */
          wDay += 6;
      tzData->wDay = (uint16_t) wDay;

      dateValue = [self startDate];
      tzData->wHour = [dateValue hourOfDay];
      tzData->wMinute = [dateValue minuteOfHour];
      tzData->wSecond = [dateValue secondOfMinute];
    }
}

@end

@implementation iCalTimeZone (MAPIStoreProperties)

- (iCalTimeZonePeriod *) _mostRecentPeriodWithName: (NSString *) periodName
{
  NSArray *periods;
  iCalTimeZonePeriod *period;
  NSUInteger max;

  periods = [self childrenWithTag: periodName];
  max = [periods count];
  if (max > 0)
    {
      periods = [periods sortedArrayUsingSelector: @selector (compare:)];
      period = (iCalTimeZonePeriod *) [periods objectAtIndex: (max - 1)];
    }
  else
    period = nil;

  return period;
}

- (struct Binary_r *) asTimeZoneStructInMemCtx: (TALLOC_CTX *) memCtx
{
  iCalTimeZonePeriod *period;
  struct TimeZoneStruct tz;
  int32_t lBias, dlBias;

  memset (&tz, 0, sizeof (struct TimeZoneStruct));
  period = [self _mostRecentPeriodWithName: @"STANDARD"];
  lBias = -[period secondsOffsetFromGMT] / 60;
  tz.lBias = lBias;
  [period _fillTZDate: &tz.stStandardDate];
  period = [self _mostRecentPeriodWithName: @"DAYLIGHT"];
  if (!period)
    tz.stStandardDate.wMonth = 0;
  dlBias = -([period secondsOffsetFromGMT] / 60) - lBias;
  tz.lDaylightBias = dlBias;
  [period _fillTZDate: &tz.stDaylightDate];
  tz.wStandardYear = tz.stStandardDate.wYear;
  tz.wDaylightYear = tz.stDaylightDate.wYear;

  return set_TimeZoneStruct (memCtx, &tz);
}

- (struct Binary_r *) asZoneTimeDefinitionWithFlags: (enum TZRuleFlag) flags
                                           inMemCtx: (TALLOC_CTX *) memCtx
{
  iCalTimeZonePeriod *period;
  struct TimeZoneDefinition definition;
  struct TZRule rule;
  NSString *tzId;
  int lBias, dlBias;

  memset (&definition, 0, sizeof (struct TimeZoneDefinition));
  
  definition.major = 0x02;
  definition.minor = 0x01;
  definition.reserved = 0x0002;

  tzId = [self tzId];
  definition.keyName = [tzId asUnicodeInMemCtx: memCtx];
  definition.cbHeader = 6 + [tzId length] * 2;
  
  definition.cRules = 1;
  definition.TZRules = &rule;

  memset (&rule, 0, sizeof (struct TZRule));
  rule.major = 0x02;
  rule.minor = 0x01;
  rule.reserved = 0x003e;
  rule.flags = flags;

  period = [self _mostRecentPeriodWithName: @"STANDARD"];
  rule.wYear = [[period startDate] yearOfCommonEra];
  lBias = -[period secondsOffsetFromGMT] / 60;
  rule.lBias = lBias;
  [period _fillTZDate: &rule.stStandardDate];
  period = [self _mostRecentPeriodWithName: @"DAYLIGHT"];
  if (!period)
    rule.stStandardDate.wMonth = 0;
  dlBias = -([period secondsOffsetFromGMT] / 60) - lBias;
  rule.lDaylightBias = dlBias;
  [period _fillTZDate: &rule.stDaylightDate];


  return set_TimeZoneDefinition (memCtx, &definition);
}

- (NSString *) _offsetStringFromOffset: (NSInteger) offset
{
  NSInteger offsetHours, offsetMins;
  NSString *offsetSign;

  /* The offset format is, eg, "+0200" for 2 hours 0 minutes ahead */
  if (offset < 0)
    offsetSign = @"-";
  else
    offsetSign = @"+";
  offsetHours = abs (offset) / 60;
  offsetMins = abs (offset) % 60;

  return [NSString stringWithFormat:  @"%@%d%d%d%d",
           offsetSign, offsetHours / 10, offsetHours % 10,
           offsetMins / 10, offsetMins % 10];

}

- (NSString *) _rRuleStringFromSystemTime: (struct SYSTEMTIME) date
{
  NSString *result, *byDay;

  /* The conversion tables between the SYSTEMTIME fields and the RRULE ones
     can be found at [MS-OXCICAL] 2.1.3.2.1 */
  if (date.wDay == 5)
    byDay = @"-1";
  else
    byDay = [NSString stringWithFormat: @"%d", date.wDay];

  switch (date.wDayOfWeek)
    {
    case iCalWeekDaySunday:
      byDay = [byDay stringByAppendingString: @"SU"];
      break;
    case iCalWeekDayMonday:
      byDay = [byDay stringByAppendingString: @"MO"];
      break;
    case iCalWeekDayTuesday:
      byDay = [byDay stringByAppendingString: @"TU"];
      break;
    case iCalWeekDayWednesday:
      byDay = [byDay stringByAppendingString: @"WE"];
      break;
    case iCalWeekDayThursday:
      byDay = [byDay stringByAppendingString: @"TH"];
      break;
    case iCalWeekDayFriday:
      byDay = [byDay stringByAppendingString: @"FR"];
      break;
    case iCalWeekDaySaturday:
      byDay = [byDay stringByAppendingString: @"SA"];
      break;
    }

  result = [NSString stringWithFormat: @"FREQ=YEARLY;BYDAY=%@;BYMONTH=%d", byDay, date.wMonth];

  return result;
}

- (iCalTimeZone *) iCalTimeZoneFromDefinition: (NSData *) value
                              withDescription: (NSString *) description
                                     inMemCtx: (TALLOC_CTX *) memCtx
{
  BOOL daylightDefined = NO, ruleFound = NO;
  iCalDateTime *daylightStart, *standardStart;
  iCalRecurrenceRule *daylightRRule, *standardRRule;
  iCalTimeZone *tz = nil;
  iCalTimeZonePeriod *daylight, *standard;
  NSCalendarDate *dlStartValue, *stStartValue;
  NSString *strOffsetFrom, *strOffsetTo, *tzID;
  char *keyName;
  struct Binary_r *binValue;
  struct SYSTEMTIME initDate;
  struct TimeZoneDefinition *definition;
  struct TZRule rule;
  uint16_t count;

  binValue = [value asBinaryInMemCtx: memCtx];
  definition = get_TimeZoneDefinition (memCtx, binValue);

  if (!definition)
    return nil;

  if (!definition->cRules)
    goto end;

  for (count = 0; count < definition->cRules; count++)
    {
      /* ([MS-OXCICAL] 2.1.3.1.1.19) The TZRule with the
         TZRULE_FLAG_EFFECTIVE_TZREG bit set in the TZRule flags field
         is the one that MUST be exported */
      if (definition->TZRules[count].flags & TZRULE_FLAG_EFFECTIVE_TZREG)
        {
          rule = definition->TZRules[count];
          ruleFound = YES;
          break;
        }
    }

  if (!ruleFound)
    goto end;

  if (!description)
    {
      /* The cbHeader field contains the size, in bytes of the Reserved (2b),
         cchKeyName (2b) keyName (variable Unicode string) and cRules (2b)
         ([MS-OXOCAL] 2.2.1.41). The keyName field is a non-NULL-terminated
         char array. */
      keyName = talloc_strndup (memCtx, definition->keyName, (definition->cbHeader - 6) / 2);
      tzID = [NSString stringWithCString: keyName
                                encoding: [NSString defaultCStringEncoding]];
      talloc_free (keyName);
    }
  else
    tzID = [NSString stringWithString: description];

  tz = [iCalTimeZone groupWithTag: @"vtimezone"];
  [tz addChild: [CardElement simpleElementWithTag: @"tzid"
                                            value: tzID]];

  if (rule.stStandardDate.wMonth != 0)
    daylightDefined = YES;

  /* STANDARD TIME ([MS-OXCICAL] 2.1.3.1.1.19.2) */
  standard = [iCalTimeZonePeriod groupWithTag: @"standard"];

  /* TZOFFSETFROM = -1 * (PidLidTimeZoneStruct.lBias + PidLidTimeZoneStruct.lDaylightBias) */
  strOffsetFrom = [self _offsetStringFromOffset: -1 * (rule.lBias + rule.lDaylightBias)];
  [standard addChild: [CardElement simpleElementWithTag: @"tzoffsetfrom"
                                                  value: strOffsetFrom]];

  /* TZOFFSETTO = -1 * (PidLidTimeZoneStruct.lBias + PidLidTimeZoneStruct.lStandardBias) */
  strOffsetTo = [self _offsetStringFromOffset: -1 * (rule.lBias + rule.lStandardBias)];
  [standard addChild: [CardElement simpleElementWithTag: @"tzoffsetto"
                                                  value: strOffsetTo]];

  /* DTSTART & RRULE are derived from the stStandardDate and wYear properties */
  standardStart = [iCalDateTime elementWithTag: @"dtstart"];

  initDate = rule.stStandardDate;
  stStartValue = [NSCalendarDate dateFromSystemTime: initDate
                                        andRuleYear: rule.wYear];

  [standardStart setDateTime: stStartValue];
  [standard addChild: standardStart];

  if (daylightDefined)
    {
      standardRRule = [[iCalRecurrenceRule alloc] initWithString: [self _rRuleStringFromSystemTime: initDate]];
      [standard addChild: standardRRule];

      /* DAYLIGHT SAVING TIME ([MS-OXCICAL] 2.1.3.1.1.19.3) */
      daylight = [iCalTimeZonePeriod groupWithTag: @"daylight"];
      /* TZOFFSETFROM = -1 * (PidLidTimeZoneStruct.lBias + PidLidTimeZoneStruct.lStandardBias) */
      [daylight addChild: [CardElement simpleElementWithTag: @"tzoffsetfrom"
                                                      value: strOffsetTo]];
      /* TZOFFSETTO = -1 * (PidLidTimeZoneStruct.lBias + PidLidTimeZoneStruct.lDaylightBias) */
      [daylight addChild: [CardElement simpleElementWithTag: @"tzoffsetto"
                                                      value: strOffsetFrom]];

      /* DTSTART & RRULE are derived from the stDaylightDate and wYear properties */
      daylightStart = [iCalDateTime elementWithTag: @"dtstart"];
      initDate = rule.stDaylightDate;
      dlStartValue = [NSCalendarDate dateFromSystemTime: initDate
                                            andRuleYear: rule.wYear];

      [daylightStart setDateTime: dlStartValue];
      [daylight addChild: daylightStart];

      daylightRRule = [[iCalRecurrenceRule alloc] initWithString: [self _rRuleStringFromSystemTime: initDate]];
      [daylight addChild: daylightRRule];
      [tz addChild: daylight];
    }
  [tz addChild: standard];

end:

  talloc_free (definition);
  return tz;
}

/**
 * Adjust a date in this vTimeZone to its representation in UTC
 * Example: Timezone is +0001, the date is 2015-12-15 00:00:00 +0000
 *                              it returns 2015-12-14 23:00:00 +0000
 * @param date the date to adjust to the timezone.
 * @return a new GMT date adjusted with the offset of the timezone.
 */
- (NSCalendarDate *) shiftedCalendarDateForDate: (NSCalendarDate *) date
{
  NSCalendarDate *tmpDate;

  tmpDate = [date copy];
  [tmpDate autorelease];

  [tmpDate setTimeZone: utcTZ];

  return [tmpDate addYear: 0 month: 0 day: 0
                     hour: 0 minute: 0
                   second: -[[self periodForDate: tmpDate] secondsOffsetFromGMT]];
}

@end
