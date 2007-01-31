/*
  Copyright (C) 2000-2005 SKYRIX Software AG

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

#include "common.h"

@class NGCalendarDateRange;
@class iCalRecurrenceRule;

@interface iCalRecurrenceCalculatorTests : SenTestCase
{
  NSTimeZone          *gmt;
  NGCalendarDateRange *fir;
  NGCalendarDateRange *tr1;
  NGCalendarDateRange *dr1;
}

- (iCalRecurrenceRule *)ruleWithICalString:(NSString *)_rule;

@end

#include "iCalRecurrenceRule.h"
#include "iCalRecurrenceCalculator.h"

@implementation iCalRecurrenceCalculatorTests

/* Setup / Teardown */

- (void)setUp {
  NSCalendarDate *sd, *ed;

  gmt = [[NSTimeZone timeZoneForSecondsFromGMT:0] retain];

  sd = [NSCalendarDate dateWithYear:2005
                       month:2
                       day:6
                       hour:12
                       minute:0
                       second:0
                       timeZone:self->gmt];
  ed = [NSCalendarDate dateWithYear:2005
                       month:2
                       day:6
                       hour:15
                       minute:30
                       second:0
                       timeZone:self->gmt];

  self->fir = [[NGCalendarDateRange calendarDateRangeWithStartDate:sd
                                    endDate:ed] retain];

  sd = [NSCalendarDate dateWithYear:2005
                       month:2
                       day:11
                       hour:0
                       minute:0
                       second:0
                       timeZone:self->gmt];
  ed = [NSCalendarDate dateWithYear:2005
                       month:2
                       day:13
                       hour:23
                       minute:59
                       second:59
                       timeZone:self->gmt];
  
  self->tr1 = [[NGCalendarDateRange calendarDateRangeWithStartDate:sd
                                    endDate:ed] retain];
  

  sd = [NSCalendarDate dateWithYear:2005
                       month:2
                       day:6
                       hour:0
                       minute:0
                       second:0
                       timeZone:self->gmt];
  ed = [NSCalendarDate dateWithYear:2005
                       month:2
                       day:13
                       hour:23
                       minute:59
                       second:59
                       timeZone:self->gmt];
  
  self->dr1 = [[NGCalendarDateRange calendarDateRangeWithStartDate:sd
                                    endDate:ed] retain];
}

- (void)tearDown {
  [self->gmt release];
  [self->fir release];
  [self->tr1 release];
  [self->dr1 release];
}

/* Private Helper */

- (iCalRecurrenceRule *)ruleWithICalString:(NSString *)_rule {
  iCalRecurrenceRule *rule;
  
  rule = [[[iCalRecurrenceRule alloc] init] autorelease];
  [rule setRrule:_rule];
  return rule;
}

- (void)testUnboundDailyRecurrence {
  iCalRecurrenceRule       *rule;
  iCalRecurrenceCalculator *calc;
  BOOL                     result;
  
  /* recurrence occurs within range, 02/14/2005 */
  rule = [self ruleWithICalString:@"FREQ=DAILY;INTERVAL=2"];
  calc = [iCalRecurrenceCalculator recurrenceCalculatorForRecurrenceRule:rule
                                   withFirstInstanceCalendarDateRange:fir];
  result = [calc doesRecurrWithinCalendarDateRange:self->tr1];
  STAssertTrue(result, @"missed recurrence!");
  
  /* recurrence outside of range */
  rule = [self ruleWithICalString:@"FREQ=DAILY;INTERVAL=4"];
  calc = [iCalRecurrenceCalculator recurrenceCalculatorForRecurrenceRule:rule
                                   withFirstInstanceCalendarDateRange:fir];
  result = [calc doesRecurrWithinCalendarDateRange:self->tr1];
  
  STAssertFalse(result, @"recurrence unexpected!");
}

- (void)testBoundDailyRecurrence {
  iCalRecurrenceRule       *rule;
  iCalRecurrenceCalculator *calc;
  BOOL                     result;
  NSArray                  *ranges;

  /* recurrence outside of range */
  rule = [self ruleWithICalString:@"FREQ=DAILY;INTERVAL=2;COUNT=2"];
  calc = [iCalRecurrenceCalculator recurrenceCalculatorForRecurrenceRule:rule
                                   withFirstInstanceCalendarDateRange:fir];
  result = [calc doesRecurrWithinCalendarDateRange:self->tr1];
  STAssertFalse(result, @"recurrence!");
  
  /* recurrence within range */
  rule = [self ruleWithICalString:@"FREQ=DAILY;INTERVAL=2;UNTIL=20050212T120000Z"];
  calc = [iCalRecurrenceCalculator recurrenceCalculatorForRecurrenceRule:rule
                                   withFirstInstanceCalendarDateRange:fir];
  result = [calc doesRecurrWithinCalendarDateRange:self->tr1];
  STAssertTrue(result, @"didn't spot expected recurrence!");
  ranges = [calc recurrenceRangesWithinCalendarDateRange:self->tr1];
  STAssertTrue([ranges count] == 1, @"didn't spot expected recurrence!");
  ranges = [calc recurrenceRangesWithinCalendarDateRange:self->dr1];
  STAssertTrue([ranges count] == 4, @"didn't spot expected recurrence!");
}


- (void)testBoundWeeklyRecurrence {
  iCalRecurrenceRule       *rule;
  iCalRecurrenceCalculator *calc;
  BOOL                     result;
  
  /* recurrence outside of range */
  rule = [self ruleWithICalString:@"FREQ=WEEKLY;INTERVAL=1;UNTIL=20050210T225959Z;BYDAY=WE;WKST=MO"];
  calc = [iCalRecurrenceCalculator recurrenceCalculatorForRecurrenceRule:rule
                                   withFirstInstanceCalendarDateRange:fir];
  result = [calc doesRecurrWithinCalendarDateRange:self->tr1];
  STAssertFalse(result, @"recurrence!");
  
  /* recurrence outside of range */
  rule = [self ruleWithICalString:@"FREQ=WEEKLY;INTERVAL=1;COUNT=3;BYDAY=WE"];
  calc = [iCalRecurrenceCalculator recurrenceCalculatorForRecurrenceRule:rule
                                   withFirstInstanceCalendarDateRange:fir];
  result = [calc doesRecurrWithinCalendarDateRange:self->tr1];
  STAssertFalse(result, @"recurrence!");
}

@end
