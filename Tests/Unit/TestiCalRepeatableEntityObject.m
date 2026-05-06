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

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalRepeatableEntityObject.h>

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

@end
