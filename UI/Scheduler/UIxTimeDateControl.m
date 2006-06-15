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
// $Id: UIxTimeDateControl.m 601 2005-02-22 15:45:03Z znek $

#include <SOGoUI/UIxComponent.h>

@interface UIxTimeDateControl : UIxComponent
{
  NSString *controlID;
  NSString *label;
  NSCalendarDate *date;
  id       hour;
  id       minute;
  id       second;
  id       day;
  id       month;
  id       year;
  BOOL     displayTimeControl;
}

- (void)setControlID:(NSString *)_controlID;
- (NSString *)controlID;
- (void)setLabel:(NSString *)_label;
- (NSString *)label;
- (void)setDate:(NSCalendarDate *)_date;
- (NSCalendarDate *)date;

- (void)setHour:(id)_hour;
- (id)hour;
- (void)setMinute:(id)_minute;
- (id)minute;
- (void)setSecond:(id)_second;
- (id)second;
- (void)setDay:(id)_day;
- (id)day;
- (void)setMonth:(id)_month;
- (id)month;
- (void)setYear:(id)_year;
- (id)year;

- (NSString *)timeID;
- (NSString *)dateID;

- (void)_setDate:(NSCalendarDate *)_date;

@end

#include "common.h"

@implementation UIxTimeDateControl

- (id)init {
  self = [super init];
  if (self) {
    self->displayTimeControl = YES;
  }
  return self;
}

- (void)dealloc {
  [self->controlID release];
  [self->label     release];
  [self->date      release];
  [self->hour      release];
  [self->minute    release];
  [self->second    release];
  [self->day       release];
  [self->month     release];
  [self->year      release];
  [super dealloc];
}

/* accessors */

- (void)setControlID:(NSString *)_controlID {
  ASSIGNCOPY(self->controlID, _controlID);
}
- (NSString *)controlID {
  return self->controlID;
}
- (void)setLabel:(NSString *)_label {
  ASSIGNCOPY(self->label, _label);
}
- (NSString *)label {
  return self->label;
}
- (void)setDate:(NSCalendarDate *)_date {
  if (!_date)
    _date = [NSCalendarDate date];
  [self _setDate:_date];
  [self setHour:[NSNumber numberWithInt:[_date hourOfDay]]];
  [self setMinute:[NSNumber numberWithInt:[_date minuteOfHour]]];
  [self setYear:[NSNumber numberWithInt:[_date yearOfCommonEra]]];
  [self setMonth:[NSNumber numberWithInt:[_date monthOfYear]]];
  [self setDay:[NSNumber numberWithInt:[_date dayOfMonth]]];
}
- (void)_setDate:(NSCalendarDate *)_date {
  ASSIGN(self->date, _date);
}
- (NSCalendarDate *)date {
  return self->date;
}

- (void)setHour:(id)_hour {
  ASSIGN(self->hour, _hour);
}
- (id)hour {
  return self->hour;
}
- (void)setMinute:(id)_minute {
  ASSIGN(self->minute, _minute);
}
- (id)minute {
  return self->minute;
}
- (void)setSecond:(id)_second {
  ASSIGN(self->second, _second);
}
- (id)second {
  return self->second;
}

- (void)setDay:(id)_day {
  ASSIGN(self->day, _day);
}
- (id)day {
  return self->day;
}
- (void)setMonth:(id)_month {
  ASSIGN(self->month, _month);
}
- (id)month {
  return self->month;
}
- (void)setYear:(id)_year {
  ASSIGN(self->year, _year);
}
- (id)year {
  return self->year;
}

- (NSString *)timeID {
  return [[self controlID] stringByAppendingString:@"_time"];
}
- (NSString *)dateID {
  return [[self controlID] stringByAppendingString:@"_date"];
}

- (void)setDisplayTimeControl:(BOOL)_displayTimeControl {
  self->displayTimeControl = _displayTimeControl;
}
- (BOOL)displayTimeControl {
  return self->displayTimeControl;
}

#if 0
- (NSString *)timeControlStyle {
  if (self->displayTimeControl)
    return @"visibility : visible;";
  return @"visibility : hidden;";
}
#endif

/* processing request */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  NSCalendarDate *d;
  unsigned _year, _month, _day, _hour, _minute, _second;

  /* call super, so that the form values are applied on the popups */
  [super takeValuesFromRequest:_rq inContext:_ctx];

  _year  = [[self year] intValue];
  if(_year == 0)
      return;

  _month  = [[self month]  intValue];
  _day    = [[self day]    intValue];
  _hour   = [[self hour]   intValue];
  _minute = [[self minute] intValue];
  _second = [[self second] intValue];
  d       = [NSCalendarDate dateWithYear:_year
                            month:_month
                            day:_day
                            hour:_hour
                            minute:_minute
                            second:_second
                            timeZone:[self viewTimeZone]];
  [self _setDate:d];
}

@end /* UIxTimeDateControl */
