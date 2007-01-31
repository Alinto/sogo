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

#include "iCalRecurrenceCalculator.h"

@interface iCalYearlyRecurrenceCalculator : iCalRecurrenceCalculator
@end

#include <NGExtensions/NGCalendarDateRange.h>
#include "iCalRecurrenceRule.h"
#include "NSCalendarDate+ICal.h"
#include "common.h"

@interface iCalRecurrenceCalculator(PrivateAPI)
- (NSCalendarDate *)lastInstanceStartDate;
@end

@implementation iCalYearlyRecurrenceCalculator

- (NSArray *)recurrenceRangesWithinCalendarDateRange:(NGCalendarDateRange *)_r{
  NSMutableArray *ranges;
  NSCalendarDate *firStart, *rStart, *rEnd, *until;
  unsigned       i, count, interval;
  int            diff;
  
  firStart = [self->firstRange startDate];
  rStart   = [_r startDate];
  rEnd     = [_r endDate];
  interval = [self->rrule repeatInterval];
  until    = [self lastInstanceStartDate];
  
  if (until) {
    if ([until compare:rStart] == NSOrderedAscending)
      return nil;
    if ([until compare:rEnd] == NSOrderedDescending)
      rEnd = until;
  }
  
  diff   = [firStart yearsBetweenDate:rStart];
  if ((diff != 0) && [rStart compare:firStart] == NSOrderedAscending)
    diff = -diff;

  count  = [rStart yearsBetweenDate:rEnd] + 1;
  ranges = [NSMutableArray arrayWithCapacity:count];
  for (i = 0 ; i < count; i++) {
    int test;

    test = diff + i;
    if ((test >= 0) && (test % interval) == 0) {
      NSCalendarDate      *start, *end;
      NGCalendarDateRange *r;
      
      start = [firStart dateByAddingYears:diff + i
                        months:0
                        days:0];
      [start setTimeZone:[firStart timeZone]];
      end   = [start addTimeInterval:[self->firstRange duration]];
      r     = [NGCalendarDateRange calendarDateRangeWithStartDate:start
                                   endDate:end];
      if ([_r containsDateRange:r])
        [ranges addObject:r];
    }
  }
  return ranges;
}

- (NSCalendarDate *)lastInstanceStartDate {
  if ([self->rrule repeatCount] > 0) {
    NSCalendarDate *until;
    unsigned       years, interval;
    
    interval = [self->rrule repeatInterval];
    years    = [self->rrule repeatCount] * interval;
    until    = [[self->firstRange startDate] dateByAddingYears:years
                                             months:0
                                             days:0];
    return until;
  }
  return [super lastInstanceStartDate];
}

@end /* iCalYearlyRecurrenceCalculator */
