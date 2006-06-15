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
// $Id: UIxCalWeekChartview.m 663 2005-07-05 18:13:24Z znek $


#include "UIxCalWeekView.h"

@interface UIxCalWeekChartview : UIxCalWeekView
{
  int day;
  int hour;
  NSArray *hours;
}

- (NSCalendarDate *)currentDate;
@end

#include "common.h"
#include <NGExtensions/NGCalendarDateRange.h>
#include <sys/param.h> // MIN, MAX
#include <SOGoUI/SOGoAptFormatter.h>

@implementation UIxCalWeekChartview

- (void)dealloc {
  [self->hours release];
  [super dealloc];
}

- (void)setDay:(int)_day {
  NSCalendarDate *date;

  self->day = _day;

  date = [[self startDate] dateByAddingYears:0 months:0 days:_day];
  [self setCurrentDay:date];
}
- (int)day {
  return self->day;
}

- (void)setHour:(int)_hour {
  self->hour = _hour;
}
- (int)hour {
  return self->hour;
}

- (NSCalendarDate *)currentDate {
  NSCalendarDate *date;
  
  date = [[self startDate] beginOfDay];
  date = [date dateByAddingYears:0 months:0 days:[self day]
                                    hours:[self hour] minutes:0 seconds:0];
  return date;
}

/* columns */

- (NSArray *)columns {
  static NSMutableArray *columns = nil;

  if(!columns) {
    unsigned i, count;
    
    count = [self shouldDisplayWeekend] ? 7 : 5;
    columns = [[NSMutableArray alloc] initWithCapacity:count];
    for(i = 0; i < count; i++) {
      [columns addObject:[NSNumber numberWithInt:i]];
    }
  }
  return columns;
}

/* tests */

/* row is active, if apt intersects hour range */
- (BOOL)isRowActive {
  NSCalendarDate *aptStart, *aptEnd, *date;
  int            aptStartHour, aptEndHour;
  BOOL           isStartOnSameDay, isEndOnSameDay;

  aptStart         = [self->appointment valueForKey:@"startDate"];
  aptEnd           = [self->appointment valueForKey:@"endDate"];
  date             = [self currentDay];
  isStartOnSameDay = [aptStart isDateOnSameDay:date];
  isEndOnSameDay   = [aptEnd   isDateOnSameDay:date];

  if (!isStartOnSameDay && !isEndOnSameDay)
    return YES;
  aptStartHour  = [aptStart hourOfDay];
  aptEndHour    = [aptEnd   hourOfDay];
  if (isStartOnSameDay && isEndOnSameDay)
    return (([self hour] >= aptStartHour) &&
            ([self hour] <= aptEndHour));
  if (!isStartOnSameDay)
    return [self hour] <= aptEndHour;
  return [self hour] >= aptStartHour;
}

/* item is active, if apt's dateRange intersects the range
of the current column (currentDay is set to be this date) */
- (BOOL)isItemActive {
  NSCalendarDate *dateStart, *dateEnd, *aptStart, *aptEnd;
  NGCalendarDateRange *dateRange, *aptRange;
  
  dateStart = [self currentDate];
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

/* hours */

- (NSArray *)hours {
  if(!self->hours) {
    NSMutableArray *result;
    NSArray *apts;
    unsigned i, count;
    unsigned min, max;
    
    min = [self dayStartHour];
    max = [self dayEndHour];
    
    apts = [self appointments];
    count = [apts count];
    for(i = 0; i < count; i++) {
      id apt;
      NSCalendarDate *aptStart, *aptEnd;
      apt = [apts objectAtIndex:i];
      aptStart = [apt valueForKey:@"startDate"];
      if(aptStart) {
        min = MIN(min, [aptStart hourOfDay]);
      }
      aptEnd = [apt valueForKey:@"endDate"];
      if(aptEnd) {
        max = MAX(max, [aptEnd hourOfDay]);
      }
    }
    result = [[NSMutableArray alloc] initWithCapacity:max - min];
    for(i = min; i <= max; i++) {
      [result addObject:[NSNumber numberWithInt:i]];
    }
    self->hours = result;
  }
  return self->hours;
}

/* descriptions */

- (void)configureFormatters {
  [super configureFormatters];
  [self->aptFormatter setTitleOnly];
  [self->privateAptFormatter setPrivateTitleOnly];
}


/* style sheet */

- (NSString *)titleStyle {
  if([self->currentDay isToday])
    return @"weekoverview_title_hilite";
  return @"weekoverview_title";
}

@end /* UIxCalWeekChartview */

