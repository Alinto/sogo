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

#ifndef UIXTIMEDATECONTROL_H
#define UIXTIMEDATECONTROL_H

#import <SOGoUI/UIxComponent.h>

@class NSString;
@class NSCalendarDate;
@class NSNumber;

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
  unsigned int startHour;
  unsigned int endHour;
  NSNumber *currentHour;
  NSNumber *currentMinute;
}

- (void) setDayStartHour: (unsigned int) hour;
- (void) setDayEndHour: (unsigned int) hour;

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

#endif /* UIXTIMEDATECONTROL_H */
