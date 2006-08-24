/*
  Copyright (C) 2004 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id: UIxCalDayView.m 663 2005-07-05 18:13:24Z znek $

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <EOControl/EOQualifier.h>

#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NGCalendarDateRange.h>

#import <SOGoUI/SOGoDateFormatter.h>

#import "UIxCalDayView.h"

@interface UIxCalDayView (PrivateAPI)
- (BOOL)isCurrentDateInApt:(id)_apt;
- (NSArray *)_getDatesFrom:(NSCalendarDate *)_from to:(NSCalendarDate *)_to;
@end

@implementation UIxCalDayView

- (void) dealloc
{
  [self->currentDate release];
  [super dealloc];
}

- (void) setCurrentDate: (NSCalendarDate *) _date
{
  ASSIGN(self->currentDate, _date);
}

- (NSCalendarDate *) currentDate
{
  return self->currentDate;
}

- (BOOL) isCurrentDateInApt
{
  return [self isCurrentDateInApt: [self appointment]];
}

- (BOOL) isCurrentDateInApt: (id) _apt
{
  NSCalendarDate *dateStart, *dateEnd, *aptStart, *aptEnd;
  NGCalendarDateRange *dateRange, *aptRange;
    
  dateStart = self->currentDate;
  dateEnd   = [dateStart dateByAddingYears:0 months:0 days:0
                         hours:1 minutes:0 seconds:0];
  dateRange = [NGCalendarDateRange calendarDateRangeWithStartDate:dateStart
                                   endDate:dateEnd];
  aptStart = [self->appointment valueForKey:@"startDate"];
  aptEnd   = [self->appointment valueForKey:@"endDate"];
  aptRange = [NGCalendarDateRange calendarDateRangeWithStartDate:aptStart
                                  endDate:aptEnd];

  return [dateRange doesIntersectWithDateRange:aptRange];
}

- (NSArray *) dateRange
{
  /* default range is from dayStartHour to dayEndHour. Any values before
     or after are also fine */

  NSCalendarDate *min, *max;
  NSArray        *aptDateRanges;

  min = [[self startDate] hour:[self dayStartHour] minute:0];
  max = [[self startDate] hour:[self dayEndHour]   minute:0];

  aptDateRanges = [[self appointments] valueForKey: @"startDate"];
  if([aptDateRanges count] != 0) {
    NSCalendarDate *d;

    aptDateRanges
      = [aptDateRanges sortedArrayUsingSelector: @selector(compareAscending:)];
    d   = [aptDateRanges objectAtIndex:0];
    if ([d isDateOnSameDay:min])
      min = (NSCalendarDate *)[d earlierDate:min];
    d   = [aptDateRanges objectAtIndex:[aptDateRanges count] - 1];
    if ([d isDateOnSameDay:max])
      max = (NSCalendarDate *)[d laterDate:max];
  }
  
  return [self _getDatesFrom:min to:max];
}

- (NSArray *) _getDatesFrom: (NSCalendarDate *) _from
                         to: (NSCalendarDate *) _to
{
  NSMutableArray *dates;
  unsigned       i, count, offset;

  offset = [_from hourOfDay];
  count  = ([_to hourOfDay] + 1) - offset;
  dates  = [[NSMutableArray alloc] initWithCapacity:count];
  for(i = 0; i < count; i++) {
    NSCalendarDate *date;
        
    date = [_from hour:offset + i minute:0];
    [dates addObject:date];
  }
  return [dates autorelease];
}

/* URLs */

- (NSDictionary *) dayBeforePrevDayQueryParameters
{
  return [self _dateQueryParametersWithOffset: -2];
}

- (NSDictionary *) prevDayQueryParameters
{
  return [self _dateQueryParametersWithOffset: -1];
}

- (NSDictionary *) nextDayQueryParameters
{
  return [self _dateQueryParametersWithOffset: 1];
}

- (NSDictionary *) dayAfterNextDayQueryParameters
{
  return [self _dateQueryParametersWithOffset: 2];
}

- (NSDictionary *) currentDateQueryParameters
{
  NSMutableDictionary *qp;
  NSString *hmString;
  NSCalendarDate *date;
    
  date = [self currentDate];
  hmString = [NSString stringWithFormat:@"%02d%02d",
                       [date hourOfDay], [date minuteOfHour]];
  qp = [[self queryParameters] mutableCopy];
  [self setSelectedDateQueryParameter:date inDictionary:qp];
  [qp setObject:hmString forKey:@"hm"];
  return [qp autorelease];
}

/* fetching */

- (NSCalendarDate *) startDate
{
  return [[self selectedDate] beginOfDay];
}

- (NSCalendarDate *) endDate
{
  return [[self selectedDate] endOfDay];
}

/* appointments */

- (NSArray *) appointments
{
  return [self fetchCoreInfos];
}

- (NSArray *)aptsForCurrentDate {
  NSArray        *apts;
  NSMutableArray *filtered;
  unsigned       i, count;
  NSCalendarDate *start, *end;

  start = self->currentDate;
  end   = [start dateByAddingYears:0
                            months:0
                              days:0
                             hours:0
                           minutes:59
                           seconds:59];
  
  apts     = [self appointments];
  filtered = [[NSMutableArray alloc] initWithCapacity:1];
  count    = [apts count];
  for (i = 0; i < count; i++) {
    id apt;
    NSCalendarDate *aptStartDate;
    
    apt = [apts objectAtIndex:i];
    aptStartDate = [apt valueForKey:@"startDate"];
    if([aptStartDate isGreaterThanOrEqualTo:start] &&
       [aptStartDate isLessThan:end])
    {
      [filtered addObject:apt];
    }
  }
  
  return [filtered autorelease];
}

- (NSArray *)allDayApts {
  NSCalendarDate *start;
  NSArray        *apts;
  NSMutableArray *filtered;
  unsigned       i, count;
  
  if (self->allDayApts)
    return self->allDayApts;

  start    = [self startDate];
  apts     = [self appointments];
  filtered = [[NSMutableArray alloc] initWithCapacity:1];
  count    = [apts count];
  for (i = 0; i < count; i++) {
    id       apt;
    NSNumber *bv;
    
    apt = [apts objectAtIndex:i];
    bv  = [apt valueForKey:@"isallday"];
    if ([bv boolValue]) {
      [filtered addObject:apt];
    }
    else {
      NSCalendarDate *aptStartDate;

      aptStartDate = [apt valueForKey:@"startDate"];
      if([aptStartDate isLessThan:start]) {
        [filtered addObject:apt];
      }
    }
  }
  
  ASSIGN(self->allDayApts, filtered);
  [filtered release];
  return self->allDayApts;
}

- (BOOL) hasAptsForCurrentDate
{
  return [[self aptsForCurrentDate] count] != 0;
}

- (NSString *) _dayNameWithOffsetFromToday: (int) offset
{
  NSCalendarDate *date;

  date = [[self selectedDate] dateByAddingYears: 0
                              months: 0
                              days: offset];

  return [self localizedNameForDayOfWeek: [date dayOfWeek]];
}

- (NSString *) dayBeforeYesterdayName
{
  return [self _dayNameWithOffsetFromToday: -2];
}

- (NSString *) yesterdayName
{
  return [self _dayNameWithOffsetFromToday: -1];
}

- (NSString *) currentDayName
{
  return [self _dayNameWithOffsetFromToday: 0];
}

- (NSString *) tomorrowName
{
  return [self _dayNameWithOffsetFromToday: 1];
}

- (NSString *) dayAfterTomorrowName
{
  return [self _dayNameWithOffsetFromToday: 2];
}

@end
