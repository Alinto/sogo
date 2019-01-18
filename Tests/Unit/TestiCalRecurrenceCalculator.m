/* TestiCalRecurrenceCalculator.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2019 Inverse inc.
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


#import <NGCards/iCalRecurrenceRule.h>
#import <NGCards/iCalRecurrenceCalculator.h>
#import <NGCards/NSString+NGCards.h>

#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NSCalendarDate+misc.h>

#import "SOGoTest.h"

@interface TestiCalWeeklyRecurrenceCalculator : SOGoTest
@end

@implementation TestiCalWeeklyRecurrenceCalculator

- (void) test_recurrenceRangesWithinCalendarDateRange_
{
  NSArray *rules = [NSArray arrayWithObjects:
			      // Every other week on Monday, Wednesday and Friday until December 24,
			      // 1997, but starting on Tuesday, September 2, 1997
			      [NSArray arrayWithObjects: @"19970902T090000Z",
				       @"FREQ=WEEKLY;INTERVAL=2;UNTIL=19971224T000000Z;WKST=SU;BYDAY=MO,WE,FR",
				       @"19970902T090000Z",
				       @"19970903T090000Z",
				       @"19970905T090000Z",
				       @"19970915T090000Z",
				       @"19970917T090000Z",
				       @"19970919T090000Z",
				       @"19970929T090000Z",
				       @"19971001T090000Z",
				       @"19971003T090000Z",
				       @"19971013T090000Z",
				       @"19971015T090000Z",
				       @"19971017T090000Z",
				       @"19971027T090000Z",
				       @"19971029T090000Z",
				       @"19971031T090000Z",
				       @"19971110T090000Z",
				       @"19971112T090000Z",
				       @"19971114T090000Z",
				       @"19971124T090000Z",
				       @"19971126T090000Z",
				       @"19971128T090000Z",
				       @"19971208T090000Z",
				       @"19971210T090000Z",
				       @"19971212T090000Z",
				       @"19971222T090000Z",
				       nil],
			    nil];

  NSString *dateFormat = @"%a %Y-%m-%d %H:%M";
  NSString *error;
  NGCalendarDateRange *firRange, *range;
  NSEnumerator *rulesList;
  NSArray *currentRule, *occurrences;
  int i, j;
  NSCalendarDate *startDate, *endDate, *currentOccurrence;
  iCalRecurrenceRule *recurrenceRule;
  iCalRecurrenceCalculator *calculator;

  rulesList = [rules objectEnumerator];
  while ((currentRule = [rulesList nextObject]))
    {
      startDate = [[currentRule objectAtIndex: 0] asCalendarDate];
      endDate = [startDate dateByAddingYears: 0 months: 0 days: 0 hours: 1 minutes: 0 seconds: 0];
      recurrenceRule = [iCalRecurrenceRule recurrenceRuleWithICalRepresentation: [currentRule objectAtIndex: 1]];

      firRange = [NGCalendarDateRange calendarDateRangeWithStartDate: startDate
							     endDate: endDate];
      calculator = [iCalRecurrenceCalculator recurrenceCalculatorForRecurrenceRule: recurrenceRule
						withFirstInstanceCalendarDateRange: firRange];
      range = [NGCalendarDateRange calendarDateRangeWithStartDate: startDate
							  endDate: [NSCalendarDate distantFuture]];
      occurrences = [calculator recurrenceRangesWithinCalendarDateRange: range];
      for (i = 2, j = 0; i < [currentRule count] && j < [occurrences count]; i++, j++)
	{
	  currentOccurrence = [[currentRule objectAtIndex: i] asCalendarDate];
	  error = [NSString stringWithFormat: @"Invalid occurrence for recurrence rule %@: %@ (expected date was %@)",
			    [currentRule objectAtIndex: 1],
			    [[[occurrences objectAtIndex: j] startDate] descriptionWithCalendarFormat: dateFormat],
			    [currentOccurrence descriptionWithCalendarFormat: dateFormat]];
	  testWithMessage([currentOccurrence isDateOnSameDay: [[occurrences objectAtIndex: j] startDate]], error);
	}
      error = [NSString stringWithFormat: @"Unexpected number of occurrences for recurrence rule %@ (found %ld, expected %ld)",
			[currentRule objectAtIndex: 1],
			[occurrences count],
			[currentRule count] - 2];
      testWithMessage([currentRule count] - [occurrences count] == 2, error);
    }
}

@end

@interface TestiCalMonthlyRecurrenceCalculator : SOGoTest
@end

@implementation TestiCalMonthlyRecurrenceCalculator

- (void) test_recurrenceRangesWithinCalendarDateRange_
{
  NSArray *rules = [NSArray arrayWithObjects:
			    //  Monthly on the 1st Friday for ten occurrences
			    [NSArray arrayWithObjects: @"19970905T090000Z",
				     @"FREQ=MONTHLY;COUNT=10;BYDAY=1FR",
				     @"19970905T090000Z",
				     @"19971003T090000Z",
				     @"19971107T090000Z",
				     @"19971205T090000Z",
				     @"19980102T090000Z",
				     @"19980206T090000Z",
				     @"19980306T090000Z",
				     @"19980403T090000Z",
				     @"19980501T090000Z",
				     @"19980605T090000Z",
				     nil],
			    // Every other month on the 1st and last Sunday of the month for 10
			    // occurrences
			    [NSArray arrayWithObjects: @"19970907T090000Z",
				     @"FREQ=MONTHLY;INTERVAL=2;COUNT=4;BYDAY=1SU,-1SU",
				     @"19970907T090000Z",
				     @"19970928T090000Z",
				     @"19971102T090000Z",
				     @"19971130T090000Z",
				     nil],
			    // Monthly on the third to the last day of the month, until Feb 26 1998
			    [NSArray arrayWithObjects: @"19970928T090000Z",
				     @"FREQ=MONTHLY;BYMONTHDAY=-3;UNTIL=19980226T090000Z",
				     @"19970928T090000Z",
				     @"19971029T090000Z",
				     @"19971128T090000Z",
				     @"19971229T090000Z",
				     @"19980129T090000Z",
				     @"19980226T090000Z",
				     nil],
			    // Second friday of the month, until Feb 26 1998
			    [NSArray arrayWithObjects: @"19980101T090000Z",
				     @"FREQ=MONTHLY;BYDAY=FR;BYSETPOS=2;UNTIL=19980428T090000Z",
                                     @"19980101T090000Z",
				     @"19980109T090000Z",
				     @"19980213T090000Z",
				     @"19980313T090000Z",
				     @"19980410T090000Z",
				     nil],
			    // Last friday of the month, until Feb 26 1998
			    [NSArray arrayWithObjects: @"19980101T090000Z",
				     @"FREQ=MONTHLY;BYDAY=MO,WE;BYSETPOS=-2;UNTIL=19980331T090000Z",
                                     @"19980101T090000Z",
				     @"19980126T090000Z",
				     @"19980223T090000Z",
				     @"19980325T090000Z",
				     nil],
			    nil];

  NSString *dateFormat = @"%a %Y-%m-%d %H:%M";
  NSString *error;
  NGCalendarDateRange *firRange, *range;
  NSEnumerator *rulesList;
  NSArray *currentRule, *occurrences;
  int i, j;
  NSCalendarDate *startDate, *endDate, *currentOccurrence;
  iCalRecurrenceRule *recurrenceRule;
  iCalRecurrenceCalculator *calculator;

  rulesList = [rules objectEnumerator];
  while ((currentRule = [rulesList nextObject]))
    {
      startDate = [[currentRule objectAtIndex: 0] asCalendarDate];
      endDate = [startDate dateByAddingYears: 0 months: 0 days: 0 hours: 1 minutes: 0 seconds: 0];
      recurrenceRule = [iCalRecurrenceRule recurrenceRuleWithICalRepresentation: [currentRule objectAtIndex: 1]];
//       NSLog(@"%@: %@", startDate, recurrenceRule);

      firRange = [NGCalendarDateRange calendarDateRangeWithStartDate: startDate
							     endDate: endDate];
      calculator = [iCalRecurrenceCalculator recurrenceCalculatorForRecurrenceRule: recurrenceRule
						withFirstInstanceCalendarDateRange: firRange];
      range = [NGCalendarDateRange calendarDateRangeWithStartDate: startDate
							  endDate: [NSCalendarDate distantFuture]];
      occurrences = [calculator recurrenceRangesWithinCalendarDateRange: range];
      for (i = 2, j = 0; i < [currentRule count] && j < [occurrences count]; i++, j++)
	{
	  currentOccurrence = [[currentRule objectAtIndex: i] asCalendarDate];
	  error = [NSString stringWithFormat: @"Invalid occurrence for recurrence rule %@: %@ (expected date was %@)",
			    [currentRule objectAtIndex: 1],
			    [[[occurrences objectAtIndex: j] startDate] descriptionWithCalendarFormat: dateFormat],
			    [currentOccurrence descriptionWithCalendarFormat: dateFormat]];
	  testWithMessage([currentOccurrence isDateOnSameDay: [[occurrences objectAtIndex: j] startDate]], error);
	}
      error = [NSString stringWithFormat: @"Unexpected number of occurrences for recurrence rule %@ (found %ld, expected %ld)",
			[currentRule objectAtIndex: 1],
			[occurrences count],
			[currentRule count] - 2];
      testWithMessage([currentRule count] - [occurrences count] == 2, error);
    }
}

@end

@interface TestiCalYearlyRecurrenceCalculator : SOGoTest
@end

@implementation TestiCalYearlyRecurrenceCalculator

- (void) test_recurrenceRangesWithinCalendarDateRange_
{
  NSArray *rules = [NSArray arrayWithObjects:
                            [NSArray arrayWithObjects: @"20190104T090000Z",
                                     @"20181201T000000Z",
                                     @"FREQ=YEARLY;COUNT=0;UNTIL=20200123T090000Z;BYMONTH=1;BYDAY=4TH",
                                     @"20190104T090000Z",
                                     @"20190124T090000Z",
                                     @"20200123T090000Z",
                                     nil],
			    // Every other year on January, February, and March for 10 occurrences
			    [NSArray arrayWithObjects: @"19970310T090000Z",
                                     @"19970310T090000Z",
				     @"FREQ=YEARLY;INTERVAL=2;COUNT=10;BYMONTH=1,2,3",
				     @"19970310T090000Z",
				     @"19990110T090000Z",
				     @"19990210T090000Z",
				     @"19990310T090000Z",
				     @"20010110T090000Z",
				     @"20010210T090000Z",
				     @"20010310T090000Z",
				     @"20030110T090000Z",
				     @"20030210T090000Z",
				     @"20030310T090000Z",
				     nil],
			    // Everyday in January, for 3 years
			    [NSArray arrayWithObjects: @"19980101T090000Z",
                                     @"19980101T090000Z",
				     @"FREQ=YEARLY;UNTIL=20000131T090000Z;BYMONTH=1;BYDAY=SU,MO,TU,WE,TH,FR,SA",
					 //     RRULE:FREQ=DAILY;UNTIL=20000131T090000Z;BYMONTH=1
				     @"19980101T090000Z",
				     @"19980102T090000Z",
				     @"19980103T090000Z",
				     @"19980104T090000Z",
				     @"19980105T090000Z",
				     @"19980106T090000Z",
				     @"19980107T090000Z",
				     @"19980108T090000Z",
				     @"19980109T090000Z",
				     @"19980110T090000Z",
				     @"19980111T090000Z",
				     @"19980112T090000Z",
				     @"19980113T090000Z",
				     @"19980114T090000Z",
				     @"19980115T090000Z",
				     @"19980116T090000Z",
				     @"19980117T090000Z",
				     @"19980118T090000Z",
				     @"19980119T090000Z",
				     @"19980120T090000Z",
				     @"19980121T090000Z",
				     @"19980122T090000Z",
				     @"19980123T090000Z",
				     @"19980124T090000Z",
				     @"19980125T090000Z",
				     @"19980126T090000Z",
				     @"19980127T090000Z",
				     @"19980128T090000Z",
				     @"19980129T090000Z",
				     @"19980130T090000Z",
				     @"19980131T090000Z",
				     @"19990101T090000Z",
				     @"19990102T090000Z",
				     @"19990103T090000Z",
				     @"19990104T090000Z",
				     @"19990105T090000Z",
				     @"19990106T090000Z",
				     @"19990107T090000Z",
				     @"19990108T090000Z",
				     @"19990109T090000Z",
				     @"19990110T090000Z",
				     @"19990111T090000Z",
				     @"19990112T090000Z",
				     @"19990113T090000Z",
				     @"19990114T090000Z",
				     @"19990115T090000Z",
				     @"19990116T090000Z",
				     @"19990117T090000Z",
				     @"19990118T090000Z",
				     @"19990119T090000Z",
				     @"19990120T090000Z",
				     @"19990121T090000Z",
				     @"19990122T090000Z",
				     @"19990123T090000Z",
				     @"19990124T090000Z",
				     @"19990125T090000Z",
				     @"19990126T090000Z",
				     @"19990127T090000Z",
				     @"19990128T090000Z",
				     @"19990129T090000Z",
				     @"19990130T090000Z",
				     @"19990131T090000Z",
				     @"20000101T090000Z",
				     @"20000102T090000Z",
				     @"20000103T090000Z",
				     @"20000104T090000Z",
				     @"20000105T090000Z",
				     @"20000106T090000Z",
				     @"20000107T090000Z",
				     @"20000108T090000Z",
				     @"20000109T090000Z",
				     @"20000110T090000Z",
				     @"20000111T090000Z",
				     @"20000112T090000Z",
				     @"20000113T090000Z",
				     @"20000114T090000Z",
				     @"20000115T090000Z",
				     @"20000116T090000Z",
				     @"20000117T090000Z",
				     @"20000118T090000Z",
				     @"20000119T090000Z",
				     @"20000120T090000Z",
				     @"20000121T090000Z",
				     @"20000122T090000Z",
				     @"20000123T090000Z",
				     @"20000124T090000Z",
				     @"20000125T090000Z",
				     @"20000126T090000Z",
				     @"20000127T090000Z",
				     @"20000128T090000Z",
				     @"20000129T090000Z",
				     @"20000130T090000Z",
				     @"20000131T090000Z",
				     nil],
			    nil];

  NSString *dateFormat = @"%a %Y-%m-%d %H:%M";
  NSString *error;
  NGCalendarDateRange *firRange, *range;
  NSEnumerator *rulesList;
  NSArray *currentRule, *occurrences;
  int i, j;
  NSCalendarDate *startDate, *endDate, *rangeStartDate, *currentOccurrence;
  iCalRecurrenceRule *recurrenceRule;
  iCalRecurrenceCalculator *calculator;

  rulesList = [rules objectEnumerator];
  while ((currentRule = [rulesList nextObject]))
    {
      startDate = [[currentRule objectAtIndex: 0] asCalendarDate];
      endDate = [startDate dateByAddingYears: 0 months: 0 days: 0 hours: 1 minutes: 0 seconds: 0];
      rangeStartDate = [[currentRule objectAtIndex: 1] asCalendarDate];
      recurrenceRule = [iCalRecurrenceRule recurrenceRuleWithICalRepresentation: [currentRule objectAtIndex: 2]];

      firRange = [NGCalendarDateRange calendarDateRangeWithStartDate: startDate
							     endDate: endDate];
      calculator = [iCalRecurrenceCalculator recurrenceCalculatorForRecurrenceRule: recurrenceRule
						withFirstInstanceCalendarDateRange: firRange];
      range = [NGCalendarDateRange calendarDateRangeWithStartDate: rangeStartDate
							  endDate: [NSCalendarDate distantFuture]];
      occurrences = [calculator recurrenceRangesWithinCalendarDateRange: range];
      for (i = 3, j = 0; i < [currentRule count] && j < [occurrences count]; i++, j++)
	{
	  currentOccurrence = [[currentRule objectAtIndex: i] asCalendarDate];
	  error = [NSString stringWithFormat: @"Invalid occurrence for recurrence rule %@: %@ (expected date was %@)",
			    [currentRule objectAtIndex: 2],
			    [[[occurrences objectAtIndex: j] startDate] descriptionWithCalendarFormat: dateFormat],
			    [currentOccurrence descriptionWithCalendarFormat: dateFormat]];
	  testWithMessage([currentOccurrence isDateOnSameDay: [[occurrences objectAtIndex: j] startDate]], error);
	}
      error = [NSString stringWithFormat: @"Unexpected number of occurrences for recurrence rule %@ (found %ld, expected %ld)",
			[currentRule objectAtIndex: 2],
			[occurrences count],
			[currentRule count] - 3];
      testWithMessage([currentRule count] - [occurrences count] == 3, error);
    }
}

@end
