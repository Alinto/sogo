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

#ifndef	__NGiCal_iCalRecurrenceCalculator_H_
#define	__NGiCal_iCalRecurrenceCalculator_H_

#import <Foundation/NSObject.h>

/*
  iCalRecurrenceCalculator
 
  Provides an API for performing common calculations performed in conjunction
  with iCalRecurrenceRule objects.

  TODO: rather move this functionality to iCalRecurrenceRule?
*/

@class NSArray;
@class iCalRecurrenceRule, NGCalendarDateRange;

@interface iCalRecurrenceCalculator : NSObject
{
  NGCalendarDateRange *firstRange;
  iCalRecurrenceRule  *rrule;
}

+ (NSArray *)
 recurrenceRangesWithinCalendarDateRange: (NGCalendarDateRange *) _r
          firstInstanceCalendarDateRange: (NGCalendarDateRange *) _fir
                         recurrenceRules: (NSArray *) _rRules
                          exceptionRules: (NSArray *) _exRules
                          exceptionDates: (NSArray *) _exDates;

+ (id) recurrenceCalculatorForRecurrenceRule: (iCalRecurrenceRule *) _rrule
          withFirstInstanceCalendarDateRange: (NGCalendarDateRange *) _range;

- (id)    initWithRecurrenceRule: (iCalRecurrenceRule *) _rrule
  firstInstanceCalendarDateRange: (NGCalendarDateRange *) _range;

- (NSArray *)
 recurrenceRangesWithinCalendarDateRange: (NGCalendarDateRange *)_r;
- (BOOL) doesRecurrWithinCalendarDateRange: (NGCalendarDateRange *) _range;

- (NGCalendarDateRange *) firstInstanceCalendarDateRange;
- (NGCalendarDateRange *) lastInstanceCalendarDateRange; /* might be nil */
  
@end

#endif	/* __NGiCal_iCalRecurrenceCalculator_H_ */
