/* TestiCalTimeZonePeriod.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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

#import <Foundation/NSString.h>

#import <NGExtensions/NSCalendarDate+misc.h>

#import <NGCards/iCalRecurrenceRule.h>
#import <NGCards/iCalTimeZonePeriod.h>
#import <NGCards/NSString+NGCards.h>

#import "SOGoTest.h"

@interface iCalTimeZonePeriod (private)

- (NSCalendarDate *) _occurrenceForDate: (NSCalendarDate *) refDate
                                byRRule: (iCalRecurrenceRule *) rrule;

@end

@interface TestiCalTimeZonePeriod : SOGoTest
@end

@implementation TestiCalTimeZonePeriod

/* TODO: this test fails for obscure reasons, but test__occurrenceForDate_byRRule_ does not, which
   is a good sign */
- (void) test_occurrenceForDate_
{
  NSString *periods[] = { (@"BEGIN:DAYLIGHT\r\n"
                           @"TZOFFSETFROM:-0500\r\n"
                           @"TZOFFSETTO:-0400\r\n"
                           @"TZNAME:EDT\r\n"
                           @"DTSTART:19700308T020000\r\n"
                           @"RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU\r\n"
                           @"END:DAYLIGHT"),
                          (@"BEGIN:STANDARD\r\n"
                           @"TZOFFSETFROM:-0400\r\n"
                           @"TZOFFSETTO:-0500\r\n"
                           @"TZNAME:EST\r\n"
                           @"DTSTART:19701101T020000\r\n"
                           @"RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU\r\n"
                           @"END:STANDARD") };
  NSString *dateStrings[] = { @"20100314T050000Z", @"20101107T050000Z" };
  // with TZ=America/Montreal:
  //   date --date="2010-03-14 01:59" +"%s" -> 1268549940
  //   date --date="2010-03-14 02:00" +"%s" -> invalid
  //   date --date="2010-03-14 03:00" +"%s" -> 1268550000
  //   date --date="2010-11-07 01:59" +"%s" -> 1289109540
  //   date --date="2010-11-07 02:00" +"%s" -> 1289113200
  NSInteger occurrenceSeconds[] = { 1268550000, 1289113200 };
  NSInteger count, delta;
  iCalTimeZonePeriod *period;
  NSCalendarDate *testDate;

  for (count = 0; count < 2; count++)
    {
      period = [iCalTimeZonePeriod parseSingleFromSource: periods[count]];
      testDate = [period occurrenceForDate: [dateStrings[count] asCalendarDate]];
      delta = (NSInteger) [testDate timeIntervalSince1970] - occurrenceSeconds[count];
      testWithMessage ((NSInteger) [testDate timeIntervalSince1970]
                       == occurrenceSeconds[count],
                       ([NSString stringWithFormat:
                                    @"test %d: seconds do not match:"
                                  @" delta = %d", count, delta]));
    }
}

- (void) test__occurrenceForDate_byRRule_
{
  /* all rules are happening on 2010-03-14 */
  NSString *periods[] = { @"20100307T120000Z",
                          (@"BEGIN:DAYLIGHT\r\n"
                           @"TZOFFSETFROM:+0100\r\n"
                           @"TZOFFSETTO:+0200\r\n"
                           @"TZNAME:CEST\r\n"
                           @"DTSTART:20040307T020000\r\n"
                           @"RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=1SU\r\n"
                           @"END:DAYLIGHT\r\n"),
                          @"20100314T120000Z",
                          (@"BEGIN:DAYLIGHT\r\n"
                           @"TZOFFSETFROM:+0100\r\n"
                           @"TZOFFSETTO:+0200\r\n"
                           @"TZNAME:CEST\r\n"
                           @"DTSTART:20040314T020000\r\n"
                           @"RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU\r\n"
                           @"END:DAYLIGHT\r\n"),
                          @"20100314T120000Z",
                          (@"BEGIN:DAYLIGHT\r\n"
                           @"TZOFFSETFROM:+0100\r\n"
                           @"TZOFFSETTO:+0200\r\n"
                           @"TZNAME:CEST\r\n"
                           @"DTSTART:20040314T020000\r\n"
                           @"RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-3SU\r\n"
                           @"END:DAYLIGHT\r\n"),
                          @"20100328T120000Z",
                          (@"BEGIN:DAYLIGHT\r\n"
                           @"TZOFFSETFROM:+0100\r\n"
                           @"TZOFFSETTO:+0200\r\n"
                           @"TZNAME:CEST\r\n"
                           @"DTSTART:20040328T020000\r\n"
                           @"RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU\r\n"
                           @"END:DAYLIGHT\r\n"),
                          NULL };
  NSString *dates[] = { @"20100201T120000Z", /* far before */
                        @"20100225T120000Z", /* at least one week before */
                        @"20100303T120000Z", /* less than one week before */
                        @"20100314T120000Z", /* the day of the time change */
                        @"20100315T120000Z", /* the next day */
                        @"20100318T120000Z", /* less than one week after */
                        @"20100323T120000Z", /* more than one week after */
                        @"20100501T120000Z", /* far after */
                        NULL };
  NSString **currentTCDate, **currentPeriod, **currentDate, *error;
  iCalTimeZonePeriod *testPeriod;
  NSCalendarDate *timeChangeDate, *testDate, *resultDate;

  currentTCDate = periods;
  currentPeriod = periods + 1;
  while (*currentTCDate)
    {
      timeChangeDate = [*currentTCDate asCalendarDate]; /* "expected result" */
      testPeriod = [iCalTimeZonePeriod parseSingleFromSource: *currentPeriod];
      currentDate = dates;
      while (*currentDate)
        {
          testDate = [*currentDate asCalendarDate];
          resultDate = [testPeriod _occurrenceForDate: testDate
                                              byRRule: (iCalRecurrenceRule *) [testPeriod uniqueChildWithTag: @"rrule"]];
          
          error = [NSString stringWithFormat: @"time change date for date '%@' does not occur on expected date (result: %@, exp.: %@)",
                            *currentDate, resultDate, timeChangeDate];
          testWithMessage([timeChangeDate isDateOnSameDay: resultDate], error);
          currentDate++;
        }
      currentPeriod += 2;
      currentTCDate += 2;
    }
}

@end
