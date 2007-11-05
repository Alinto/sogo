/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#ifndef	__NGiCal_iCalRecurrenceRule_H_
#define	__NGiCal_iCalRecurrenceRule_H_

#import "CardElement.h"

/*
  iCalRecurrenceRule
 
  Encapsulates a (probably complex) recurrence rule by offering
  a high level API.
 
  NOTE: as of now, only a very limited subset of RFC2445 is implemented.
        Please see the unit tests for what is covered.
*/

// TODO: we could use string constants?
typedef enum {
  iCalRecurrenceFrequenceSecondly = 1,
  iCalRecurrenceFrequenceMinutely = 2,
  iCalRecurrenceFrequenceHourly   = 3,
  iCalRecurrenceFrequenceDaily    = 4,
  iCalRecurrenceFrequenceWeekly   = 5,
  iCalRecurrenceFrequenceMonthly  = 6,
  iCalRecurrenceFrequenceYearly   = 7,
} iCalRecurrenceFrequency;

typedef enum {
  iCalWeekDayMonday    = 1,
  iCalWeekDayTuesday   = 2,
  iCalWeekDayWednesday = 4,
  iCalWeekDayThursday  = 8,
  iCalWeekDayFriday    = 16,
  iCalWeekDaySaturday  = 32,
  iCalWeekDaySunday    = 64,
} iCalWeekDay;

@class NSString, NSCalendarDate, NGCalendarDateRange, NSArray;

@interface iCalRecurrenceRule : CardElement
// {
//   iCalRecurrenceFrequency frequency;
//   int            interval;
//   unsigned       repeatCount;
//   NSCalendarDate *untilDate;
//   struct {
//     unsigned weekStart: 7;
//     unsigned mask:      7;
//     unsigned useOccurence:1;
//     unsigned reserved:1;
//   } byDay;
//   int byDayOccurence1;
//   NSArray        *byMonthDay;
  
//   NSString       *rrule;
// }

+ (id) recurrenceRuleWithICalRepresentation: (NSString *) _iCalRep;
- (id) initWithString: (NSString *) _str;

/* accessors */

- (void) setFrequency: (iCalRecurrenceFrequency) _frequency;
- (iCalRecurrenceFrequency) frequency;
- (iCalRecurrenceFrequency) valueForFrequency: (NSString *) value;

- (void) setRepeatInterval: (int) _repeatInterval;
- (int) repeatInterval;

- (void) setInterval: (NSString *) _interval;

- (void) setWeekStart: (iCalWeekDay) _weekStart;
- (iCalWeekDay) weekStart;

- (void) setByDayMask: (unsigned int) _mask;
- (unsigned int) byDayMask;
- (int) byDayOccurence1;

- (NSArray *) byMonthDay;
  
/* count and untilDate are mutually exclusive */

- (void) setRepeatCount: (int) _repeatCount;
- (int) repeatCount;

- (void) setUntilDate: (NSCalendarDate *) _untilDate;
- (NSCalendarDate *) untilDate;

- (BOOL) isInfinite;

/* parse complete iCal RRULE */

- (void) setRrule: (NSString *) _rrule; // TODO: weird name? (better: RRule?)

// - (NSString *)iCalRepresentation;

@end

#endif	/* __NGiCal_iCalRecurrenceRule_H_ */
