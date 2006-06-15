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
// $Id: UIxTimeSelector.m 247 2004-08-16 09:32:04Z znek $

#include <NGObjWeb/WOComponent.h>

@class NSString, NSCalendarDate, NSArray;

@interface UIxTimeSelector : WOComponent
{
  NSString *timeID;
  id       hour;
  id       minute;
  NSString *minuteInterval;
}

- (void)setTimeID:(NSString *)_timeID;
- (NSString *)timeID;
- (void)setHour:(id)_hour;
- (id)hour;
- (void)setMinute:(id)_minute;
- (id)minute;
- (void)setMinuteInterval:(NSString *)_minuteInterval;
- (NSString *)minuteInterval;

@end

#include "common.h"

@implementation UIxTimeSelector

- (void)dealloc {
  [self->timeID         release];
  [self->hour           release];
  [self->minute         release];
  [self->minuteInterval release];
  [super dealloc];
}

/* accessors */

- (void)setTimeID:(NSString *)_timeID {
  ASSIGNCOPY(self->timeID, _timeID);
}
- (NSString *)timeID {
  return self->timeID;
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

- (void)setMinuteInterval:(NSString *)_minuteInterval {
  ASSIGNCOPY(self->minuteInterval, _minuteInterval);
}
- (NSString *)minuteInterval {
  if(self->minuteInterval == nil)
    return @"1";
  return self->minuteInterval;
}

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx { 
    /* call super, so that the form values are applied on the popups */
    [super takeValuesFromRequest:_rq inContext:_ctx];
}

@end /* UIxTimeSelector */
