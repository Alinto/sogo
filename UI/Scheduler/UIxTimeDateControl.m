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

#import <Foundation/NSValue.h>

#import <NGObjWeb/SoObjects.h>
#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

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
  [time      release];
  [day       release];
  [month     release];
  [year      release];
  [super dealloc];
}

/* accessors */

- (void)setControlID:(NSString *)_controlID
{
  ASSIGNCOPY(controlID, _controlID);
}

- (NSString *)controlID
{
  return controlID;
}

- (void)setLabel:(NSString *)_label
{
  ASSIGNCOPY(label, _label);
}
- (NSString *)label
{
  return label;
}

- (void) setDate: (NSCalendarDate *) _date
{
  SOGoUserDefaults *ud;

  if (!_date)
    _date = [NSCalendarDate date];

  ud = [[context activeUser] userDefaults];
  [_date setTimeZone: [ud timeZone]];

  [self _setDate: _date];
  [self setTime: [_date descriptionWithCalendarFormat: @"%H:%M"]];

  [self setYear: [NSNumber numberWithInt: [_date yearOfCommonEra]]];
  [self setMonth: [NSNumber numberWithInt: [_date monthOfYear]]];
  [self setDay: [NSNumber numberWithInt: [_date dayOfMonth]]];
}

- (void)_setDate:(NSCalendarDate *)_date
{
  ASSIGN(date, _date);
}

- (NSCalendarDate *)date
{
  return date;
}

- (void) setTime: (NSString *)_time
{
  ASSIGN(time, _time);
}

- (NSString *) time
{
  return time;
}

- (void)setDay:(id)_day
{
  ASSIGN(day, _day);
}

- (id)day
{
  return day;
}

- (void)setMonth:(id)_month
{
  ASSIGN(month, _month);
}

- (id)month
{
  return month;
}

- (void)setYear:(id)_year
{
  ASSIGN(year, _year);
}

- (id)year
{
  return year;
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
  unsigned _year, _month, _day, _hour, _minute;//, _second;
  SOGoUserDefaults *ud;
  NSArray *_time;

  /* call super, so that the form values are applied on the popups */
  [super takeValuesFromRequest:_rq inContext:_ctx];

  _year  = [[self year] intValue];
  if (_year > 0)
    {
      [self setTime: [_rq formValueForKey: [self timeID]]];

      _month  = [[self month] intValue];
      _day    = [[self day] intValue];
      _time = [[self time] componentsSeparatedByString: @":"];
      _hour = [[_time objectAtIndex: 0] intValue];
      _minute = [[_time objectAtIndex: 1] intValue];
//      _second = [[self second] intValue];
      
      ud = [[context activeUser] userDefaults];
      d = [NSCalendarDate dateWithYear: _year month: _month day: _day
                                  hour: _hour minute: _minute second: 0
                              timeZone: [ud timeZone]];
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
