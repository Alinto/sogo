/* iCalByDayMask.h - this file is part of SOPE
 *
 * Copyright (C) 2010-2015 Inverse inc.
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

#ifndef ICALBYDAYMASK_H
#define ICALBYDAYMASK_H

#import <Foundation/NSObject.h>

#import "iCalRecurrenceRule.h"

typedef enum {
  iCalWeekOccurrenceFirst      = 0x001, // order
  iCalWeekOccurrenceSecond     = 0x002, // 2^(order - 1)
  iCalWeekOccurrenceThird      = 0x004,
  iCalWeekOccurrenceFourth     = 0x008,
  iCalWeekOccurrenceFifth      = 0x010,
  iCalWeekOccurrenceAll        = 0x3ff,
  iCalWeekOccurrenceLast       = 0x020, // 2^(order - 1) >> 5
  iCalWeekOccurrenceSecondLast = 0x040,
  iCalWeekOccurrenceThirdLast  = 0x080,
  iCalWeekOccurrenceFourthLast = 0x100,
  iCalWeekOccurrenceFifthLast  = 0x200,
} iCalWeekOccurrence;

typedef iCalWeekOccurrence iCalWeekOccurrences[7];

// extern NSString *iCalWeekOccurrenceString[];

@interface iCalByDayMask : NSObject
{
  iCalWeekOccurrences days;
}

+ (id) byDayMaskWithDays: (iCalWeekOccurrences) theDays;
+ (id) byDayMaskWithWeekDays;
- (id) initWithDays: (iCalWeekOccurrences) theDays;
+ (id) byDayMaskWithRuleString: (NSString *) byDayRule;
- (id) initWithRuleString: (NSString *) byDayRule;
+ (id) byDayMaskWithDaysAndOccurrences: (NSArray *) values;
- (id) initWithDaysAndOccurrences: (NSArray *) values;

- (BOOL) occursOnDay: (iCalWeekDay) weekDay;
- (BOOL) occursOnDay: (iCalWeekDay) weekDay
  withWeekOccurrence: (iCalWeekOccurrence) occurrence;
- (BOOL) occursOnDay: (iCalWeekDay) weekDay
      withWeekNumber: (int) week;
- (BOOL) isWeekDays;

//- (iCalWeekOccurrences *) allDays;
- (iCalWeekDay) firstDay;
- (int) firstOccurrence;

- (iCalWeekOccurrences *) weekDayOccurrences;

- (NSString *) asRuleString;
- (NSString *) asRuleStringWithIntegers;
- (NSArray *) asRuleArray;

@end

#endif /* ICALBYDAYMASK_H */
