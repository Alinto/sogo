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

#ifndef	__NGCards_iCalRepeatableEntityObject_H_
#define	__NGCards_iCalRepeatableEntityObject_H_

#import "iCalEntityObject.h"

/*
 iCalRepeatableEntityObject

 Specifies an iCal entity object which can bear a (possibly complex) set
 of recurrence rules and exceptions thereof. According to RFC 2445 these
 are VEVENT, VTODO and VJOURNAL.
*/

@class NSMutableArray, NGCalendarDateRange;

@interface iCalRepeatableEntityObject : iCalEntityObject
// {
//   NSMutableArray *rRules;
//   NSMutableArray *exRules;
//   NSMutableArray *exDates;
// }

- (void)removeAllRecurrenceRules;
- (void)addToRecurrenceRules:(id)_rrule;
- (void)setRecurrenceRules:(id)_rrule;
- (BOOL)hasRecurrenceRules;
- (NSArray *)recurrenceRules;

- (void)removeAllExceptionRules;
- (void)addToExceptionRules:(id)_rrule;
- (BOOL)hasExceptionRules;
- (NSArray *)exceptionRules;

- (void)removeAllExceptionDates;
- (void)addToExceptionDates:(id)_date;
- (BOOL)hasExceptionDates;
- (NSArray *)exceptionDates;

- (BOOL)isRecurrent;
- (BOOL)isWithinCalendarDateRange:(NGCalendarDateRange *)_range
  firstInstanceCalendarDateRange:(NGCalendarDateRange *)_fir;
- (NSArray *)recurrenceRangesWithinCalendarDateRange:(NGCalendarDateRange *)_r
  firstInstanceCalendarDateRange:(NGCalendarDateRange *)_fir;

/* this is the outmost bound possible, not necessarily the real last date */
- (NSCalendarDate *)lastPossibleRecurrenceStartDateUsingFirstInstanceCalendarDateRange:(NGCalendarDateRange *)_r;

@end

#endif	/* __NGCards_iCalRepeatableEntityObject_H_ */
