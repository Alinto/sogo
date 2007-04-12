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
// $Id: UIxTimeDateControl.m 1045 2007-04-11 20:13:07Z wolfgang $

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/SoObjects.h>

#import <SOGo/NSCalendarDate+SOGo.h>

#import "UIxTimeDateControl.h"

@implementation UIxTimeDateControl

- (id)init {
  self = [super init];
  if (self) {
    displayTimeControl = YES;
    isDisabled = NO;
  }
  return self;
}

- (void)dealloc {
  [controlID release];
  [label     release];
  [date      release];
  [hour      release];
  [minute    release];
  [second    release];
  [day       release];
  [month     release];
  [year      release];
  [super dealloc];
}

/* accessors */

- (void)setControlID:(NSString *)_controlID {
  ASSIGNCOPY(controlID, _controlID);
}
- (NSString *)controlID {
  return controlID;
}
- (void)setLabel:(NSString *)_label {
  ASSIGNCOPY(label, _label);
}
- (NSString *)label {
  return label;
}

- (void) setDate: (NSCalendarDate *) _date
{
  NSTimeZone *timeZone;
  int minuteValue;

  timeZone = [[context activeUser] timeZone];
  if (!_date)
    _date = [NSCalendarDate date];
  [_date setTimeZone: timeZone];
  [self _setDate: _date];

  minuteValue = [_date minuteOfHour];
  if (minuteValue % 15)
    minuteValue += 15 - (minuteValue % 15);
  [self setHour: [NSNumber numberWithInt: [_date hourOfDay]]];
  [self setMinute: [NSNumber numberWithInt: minuteValue]];
  [self setYear: [NSNumber numberWithInt: [_date yearOfCommonEra]]];
  [self setMonth: [NSNumber numberWithInt: [_date monthOfYear]]];
  [self setDay: [NSNumber numberWithInt: [_date dayOfMonth]]];
}

- (void)_setDate:(NSCalendarDate *)_date {
  ASSIGN(date, _date);
}

- (NSCalendarDate *)date {
  return date;
}

- (void)setHour:(id)_hour {
  NSLog (@"---------------- setHour:");
  ASSIGN(hour, _hour);
}

- (id)hour {
  return hour;
}
- (void)setMinute:(id)_minute {
  ASSIGN(minute, _minute);
}
- (id)minute {
  return minute;
}
- (void)setSecond:(id)_second {
  ASSIGN(second, _second);
}
- (id)second {
  return second;
}

- (void)setDay:(id)_day {
  ASSIGN(day, _day);
}
- (id)day {
  return day;
}
- (void)setMonth:(id)_month {
  ASSIGN(month, _month);
}
- (id)month {
  return month;
}
- (void)setYear:(id)_year {
  ASSIGN(year, _year);
}
- (id)year {
  return year;
}

- (void) setDayStartHour: (unsigned int) aStartHour
{
  NSLog (@"******************** setDayStartHour...");
  startHour = aStartHour;
}

- (void) setDayEndHour: (unsigned int) anEndHour
{
  endHour = anEndHour;
}

- (void) setHourOption: (NSNumber *) option
{
  currentHour = option;
}

- (BOOL) isCurrentHour
{
  return [currentHour isEqual: hour];
}

- (BOOL) isCurrentMinute
{
  return [currentMinute isEqual: minute];
}

- (int) hourValue
{
  return [currentHour intValue];
}

- (NSString *) hourLabel
{
  return [NSString stringWithFormat: @"%.2d", [currentHour intValue]];
}

- (NSArray *) selectableHours
{
  NSMutableArray *hours;
  unsigned int h;

  hours = [NSMutableArray new];
  [hours autorelease];

  for (h = startHour; h < (endHour + 1); h++)
    [hours addObject: [NSNumber numberWithInt: h]];

  return hours;
}

- (NSString *) hourSelectId
{
  return [[self controlID] stringByAppendingString:@"_time_hour"];
}

- (void) setMinuteOption: (NSNumber *) option
{
  currentMinute = option;
}

- (int) minuteValue
{
  return [currentMinute intValue];
}

- (NSString *) minuteLabel
{
  return [NSString stringWithFormat: @"%.2d", [currentMinute intValue]];
}

- (NSArray *) selectableMinutes
{
  NSMutableArray *minutes;
  unsigned int m;

  minutes = [NSMutableArray new];
  [minutes autorelease];

  for (m = 0; m < 60; m += 15)
    [minutes addObject: [NSNumber numberWithInt: m]];

  return minutes;
}

- (NSString *) minuteSelectId
{
  return [[self controlID] stringByAppendingString:@"_time_minute"];
}

- (NSString *) timeID
{
  return [[self controlID] stringByAppendingString:@"_time"];
}

- (NSString *) dateID
{
  return [[self controlID] stringByAppendingString:@"_date"];
}

- (void) setDisplayTimeControl: (BOOL) _displayTimeControl
{
  displayTimeControl = _displayTimeControl;
}

- (BOOL) displayTimeControl
{
  return displayTimeControl;
}

/* processing request */

- (void) takeValuesFromRequest: (WORequest *) _rq
                     inContext: (WOContext *) _ctx
{
  NSCalendarDate *d;
  unsigned _year, _month, _day, _hour, _minute, _second;
  NSTimeZone *timeZone;

  timeZone = [[context activeUser] timeZone];
  /* call super, so that the form values are applied on the popups */
  [super takeValuesFromRequest:_rq inContext:_ctx];

  _year  = [[self year] intValue];
  if (_year > 0)
    {
      [self setHour: [_rq formValueForKey: [self hourSelectId]]];
      [self setMinute: [_rq formValueForKey: [self minuteSelectId]]];

      _month  = [[self month] intValue];
      _day    = [[self day] intValue];
      _hour   = [[self hour] intValue];
      _minute = [[self minute] intValue];
      _second = [[self second] intValue];
      
      d = [NSCalendarDate dateWithYear: _year month:_month day:_day
                          hour:_hour minute:_minute second:_second
                          timeZone: timeZone];
      [self _setDate: d];
    }
}

- (void) setDisabled: (BOOL) disabled
{
  isDisabled = disabled;
}

- (BOOL) disabled
{
  return isDisabled;
}

@end /* UIxTimeDateControl */
