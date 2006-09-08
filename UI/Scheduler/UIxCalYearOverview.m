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
// $Id: UIxCalYearOverview.m 191 2004-08-12 16:28:32Z helge $

#include <SOGoUI/UIxComponent.h>

@interface UIxCalYearOverview : UIxComponent
{
  NSArray        *row;
  NSCalendarDate *month;
}

- (NSCalendarDate *)startDate;

- (NSDictionary *)queryParametersBySettingSelectedDate:(NSCalendarDate *)_date;

- (void)setSelectedDateQueryParameter:(NSCalendarDate *)_newDate
  inDictionary:(NSMutableDictionary *)_qp;

@end

#include "common.h"

@implementation UIxCalYearOverview

- (void)dealloc {
    [self->row release];
    [self->month release];
    [super dealloc];
}

/* accessors */

- (void)setRow:(NSArray *)_row {
  ASSIGN(self->row, _row);
}
- (NSArray *)row {
  return self->row;
}

- (void)setMonth:(NSCalendarDate *)_date {
  ASSIGN(self->month, _date);
}
- (NSCalendarDate *)month {
  return self->month;
}

- (int)year {
  return [[self selectedDate] yearOfCommonEra];
}

- (NSArray *)arrayOfDateArrays {
  NSCalendarDate *startDate;
  NSMutableArray *result, *tmp;
  unsigned       rowIdx, columnIdx;
  int            monthOffset = 0;
  
  startDate = [self startDate];
  result    = [NSMutableArray arrayWithCapacity:3];
  
  for (rowIdx = 0; rowIdx < 3; rowIdx++) {
    tmp = [[NSMutableArray alloc] initWithCapacity:4];
    
    for (columnIdx = 0; columnIdx < 4; columnIdx++) {
      NSCalendarDate *date;
      
      date = [startDate dateByAddingYears:0 months:monthOffset days:0];
      [tmp addObject:date];
      monthOffset++;
    }
    [result addObject:tmp];
    [tmp release];
  }
  return result;
}


/* date ranges */

- (NSCalendarDate *)startDate {
  return [[[NSCalendarDate alloc] initWithYear:[self year] month:1 day:1
                                  hour:0 minute:0 second:0
                                  timeZone:[[self clientObject] userTimeZone]] autorelease];
}
- (NSCalendarDate *)endDate {
  return nil;
}

/* URLs */

- (NSDictionary *)todayQueryParameters {
  NSCalendarDate *date;
    
  date = [NSCalendarDate date]; /* today */
  return [self queryParametersBySettingSelectedDate:date];
}

- (NSDictionary *)queryParametersBySettingSelectedDate:(NSCalendarDate *)_date{
  NSMutableDictionary *qp;
    
  qp = [[self queryParameters] mutableCopy];
  [self setSelectedDateQueryParameter:_date inDictionary:qp];
  return [qp autorelease];
}

- (void)setSelectedDateQueryParameter:(NSCalendarDate *)_newDate
  inDictionary:(NSMutableDictionary *)_qp;
{
  if (_newDate != nil)
    [_qp setObject:[self dateStringForDate:_newDate] forKey:@"day"];
  else
    [_qp removeObjectForKey:@"day"];
}

- (NSDictionary *)prevYearQueryParameters {
  NSCalendarDate *date;
    
  date = [[self startDate] dateByAddingYears:-1 months:0 days:0
			   hours:0 minutes:0 seconds:0];
  return [self queryParametersBySettingSelectedDate:date];
}

- (NSDictionary *)nextYearQueryParameters {
  NSCalendarDate *date;
   
  date = [[self startDate] dateByAddingYears:1 months:0 days:0
			   hours:0 minutes:0 seconds:0];
  return [self queryParametersBySettingSelectedDate:date];
}

@end /* UIxCalYearOverview */
