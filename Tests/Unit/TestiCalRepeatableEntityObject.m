/* TestiCalRepeatableEntityObject.m - this file is part of SOGo
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

#import <NGCards/iCalAlarm.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEntityObject.h>
#import <NGCards/iCalRepeatableEntityObject.h>
#import <NGCards/iCalTrigger.h>

#import "SOGoTest.h"

@interface TestiCalRepeatableEntityObject : SOGoTest
@end

@implementation TestiCalRepeatableEntityObject

- (void) test_removeDuplicateRecurrenceRules
{
  iCalCalendar *calendar;
  iCalRepeatableEntityObject *event;
  NSArray *rules;
  NSString *versit;

  versit = @"BEGIN:VCALENDAR\r\n"
    @"VERSION:2.0\r\n"
    @"BEGIN:VEVENT\r\n"
    @"UID:duplicate-rrule\r\n"
    @"DTSTART:20260211T123000Z\r\n"
    @"RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=WE\r\n"
    @"RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=WE\r\n"
    @"RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=FR\r\n"
    @"END:VEVENT\r\n"
    @"END:VCALENDAR";
  calendar = [iCalCalendar parseSingleFromSource: versit];
  event = (iCalRepeatableEntityObject *) [calendar firstChildWithTag: @"vevent"];

  test([event removeDuplicateRecurrenceRules]);

  rules = [event recurrenceRules];
  testWithMessage([rules count] == 2,
                  ([NSString stringWithFormat: @"expected 2 recurrence rules, got %lu",
                             (unsigned long) [rules count]]));
  testEquals([[rules objectAtIndex: 0] versitString],
             @"RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=WE");
  testEquals([[rules objectAtIndex: 1] versitString],
             @"RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=FR");
  failIf([event removeDuplicateRecurrenceRules]);
}

/* Alarms that differ must survive. */
- (void) test_removeDuplicateAlarmsKeepsDistinctAlarms
{
  iCalCalendar *calendar;
  iCalEntityObject *event;
  NSArray *alarms;
  NSString *versit;

  versit = @"BEGIN:VCALENDAR\r\n"
    @"VERSION:2.0\r\n"
    @"BEGIN:VEVENT\r\n"
    @"UID:duplicate-valarm\r\n"
    @"DTSTART:20260211T123000Z\r\n"
    @"BEGIN:VALARM\r\n"
    @"ACTION:DISPLAY\r\n"
    @"TRIGGER:-PT10M\r\n"
    @"DESCRIPTION:ten minutes\r\n"
    @"END:VALARM\r\n"
    @"BEGIN:VALARM\r\n"
    @"ACTION:DISPLAY\r\n"
    @"TRIGGER:-P1D\r\n"
    @"DESCRIPTION:one day\r\n"
    @"END:VALARM\r\n"
    @"BEGIN:VALARM\r\n"
    @"ACTION:DISPLAY\r\n"
    @"TRIGGER:-PT10M\r\n"
    @"DESCRIPTION:ten minutes\r\n"
    @"END:VALARM\r\n"
    @"BEGIN:VALARM\r\n"
    @"ACTION:DISPLAY\r\n"
    @"TRIGGER:-PT2H\r\n"
    @"DESCRIPTION:two hours\r\n"
    @"END:VALARM\r\n"
    @"BEGIN:VALARM\r\n"
    @"ACTION:DISPLAY\r\n"
    @"TRIGGER:-P1D\r\n"
    @"DESCRIPTION:one day\r\n"
    @"END:VALARM\r\n"
    @"BEGIN:VALARM\r\n"
    @"ACTION:DISPLAY\r\n"
    @"TRIGGER:-PT10M\r\n"
    @"DESCRIPTION:ten minutes\r\n"
    @"END:VALARM\r\n"
    @"END:VEVENT\r\n"
    @"END:VCALENDAR";
  calendar = [iCalCalendar parseSingleFromSource: versit];
  event = (iCalEntityObject *) [calendar firstChildWithTag: @"vevent"];

  test([event removeDuplicateAlarms]);

  /* Check which alarms survive because the count alone does not prove that
     every distinct alarm remains. */
  alarms = [event alarms];
  testWithMessage([alarms count] == 3,
                  ([NSString stringWithFormat: @"expected 3 alarms, got %lu",
                             (unsigned long) [alarms count]]));
  testEquals([[[alarms objectAtIndex: 0] trigger] flattenedValuesForKey: @""],
             @"-PT10M");
  testEquals([[[alarms objectAtIndex: 1] trigger] flattenedValuesForKey: @""],
             @"-P1D");
  testEquals([[[alarms objectAtIndex: 2] trigger] flattenedValuesForKey: @""],
             @"-PT2H");
  failIf([event removeDuplicateAlarms]);
}

/* An acknowledged alarm must not be dropped in favour of an identical-looking
   one that was never dismissed, or RFC 9074 section 6.1 suppression is lost and
   the alarm fires again. Sharing a UID is not enough to call them the same. */
- (void) test_removeDuplicateAlarmsKeepsAcknowledgedAlarm
{
  iCalCalendar *calendar;
  iCalEntityObject *event;
  NSString *versit;

  versit = @"BEGIN:VCALENDAR\r\n"
    @"VERSION:2.0\r\n"
    @"BEGIN:VEVENT\r\n"
    @"UID:shared-alarm-uid\r\n"
    @"DTSTART:20260211T123000Z\r\n"
    @"BEGIN:VALARM\r\n"
    @"UID:37e0f1a4-6d0c-4a0e-9d3b-6b6f0f5c1a22\r\n"
    @"ACTION:DISPLAY\r\n"
    @"TRIGGER:-PT10M\r\n"
    @"DESCRIPTION:ten minutes\r\n"
    @"END:VALARM\r\n"
    @"BEGIN:VALARM\r\n"
    @"UID:37e0f1a4-6d0c-4a0e-9d3b-6b6f0f5c1a22\r\n"
    @"ACTION:DISPLAY\r\n"
    @"TRIGGER:-PT10M\r\n"
    @"DESCRIPTION:ten minutes\r\n"
    @"ACKNOWLEDGED:20260211T121500Z\r\n"
    @"END:VALARM\r\n"
    @"BEGIN:VALARM\r\n"
    @"UID:37e0f1a4-6d0c-4a0e-9d3b-6b6f0f5c1a22\r\n"
    @"ACTION:DISPLAY\r\n"
    @"TRIGGER:-PT10M\r\n"
    @"DESCRIPTION:ten minutes\r\n"
    @"ACKNOWLEDGED:20260211T121500Z\r\n"
    @"END:VALARM\r\n"
    @"END:VEVENT\r\n"
    @"END:VCALENDAR";
  calendar = [iCalCalendar parseSingleFromSource: versit];
  event = (iCalEntityObject *) [calendar firstChildWithTag: @"vevent"];

  test([event removeDuplicateAlarms]);
  testWithMessage([[event alarms] count] == 2,
                  ([NSString stringWithFormat: @"expected 2 alarms, got %lu",
                             (unsigned long) [[event alarms] count]]));
  failIf([event removeDuplicateAlarms]);
}

/* A difference in any serialized property makes alarms distinct. */
- (void) test_removeDuplicateAlarmsKeepsExtensionDifferences
{
  iCalCalendar *calendar;
  iCalEntityObject *event;
  NSString *versit;

  versit = @"BEGIN:VCALENDAR\r\n"
    @"VERSION:2.0\r\n"
    @"BEGIN:VEVENT\r\n"
    @"UID:clean-valarm\r\n"
    @"DTSTART:20260211T123000Z\r\n"
    @"BEGIN:VALARM\r\n"
    @"ACTION:DISPLAY\r\n"
    @"TRIGGER:-PT10M\r\n"
    @"DESCRIPTION:popup\r\n"
    @"X-ALARM-COLOR:RED\r\n"
    @"END:VALARM\r\n"
    @"BEGIN:VALARM\r\n"
    @"ACTION:DISPLAY\r\n"
    @"TRIGGER:-PT10M\r\n"
    @"DESCRIPTION:popup\r\n"
    @"X-ALARM-COLOR:BLUE\r\n"
    @"END:VALARM\r\n"
    @"END:VEVENT\r\n"
    @"END:VCALENDAR";
  calendar = [iCalCalendar parseSingleFromSource: versit];
  event = (iCalEntityObject *) [calendar firstChildWithTag: @"vevent"];

  failIf([event removeDuplicateAlarms]);
  testWithMessage([[event alarms] count] == 2,
                  ([NSString stringWithFormat: @"expected 2 alarms, got %lu",
                             (unsigned long) [[event alarms] count]]));
  testWithMessage([[[[event alarms] objectAtIndex: 0] versitString]
                    rangeOfString: @"X-ALARM-COLOR:RED"].location != NSNotFound,
                  @"red alarm was not preserved");
  testWithMessage([[[[event alarms] objectAtIndex: 1] versitString]
                    rangeOfString: @"X-ALARM-COLOR:BLUE"].location != NSNotFound,
                  @"blue alarm was not preserved");
}

@end
