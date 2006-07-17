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

#include "UIxMailFormatter.h"
#include "common.h"

static Class StrClass     = Nil;
static Class CalDateClass = Nil;

@implementation UIxMailFormatter

static BOOL debugOn = YES;

+ (void)initialize {
  StrClass     = [NSString       class];
  CalDateClass = [NSCalendarDate class];
}

/* labels */

- (NSString *)labelForKey:(NSString *)_key {
  // TODO: fetch labels from context
  return _key;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* UIxMailFormatter */

@implementation UIxMailDateFormatter

- (id)init {
  if ((self = [super init])) {
    static NSTimeZone *met = nil;
    if (met == nil) met = [[NSTimeZone timeZoneWithName:@"MET"] retain];
    
    self->timeZone = [met retain];
    self->dfFlags.showOnlyTimeForToday  = 1;
    self->dfFlags.showLabelsForNearDays = 1;
  }
  return self;
}

- (void)dealloc {
  [self->timeZone release];
  [self->now      release];
  [super dealloc];
}

/* configuration */

- (NSTimeZone *)timeZone
{
  return self->timeZone;
}

- (void) setTimeZone: (NSTimeZone *) newTimeZone
{
  if (timeZone)
    [timeZone release];

  timeZone = newTimeZone;

  if (timeZone)
    [timeZone retain];
}

- (BOOL)showOnlyTimeForToday {
  return self->dfFlags.showOnlyTimeForToday ? YES : NO;
}
- (BOOL)showLabelsForNearDays {
  return self->dfFlags.showLabelsForNearDays ? YES : NO;
}

/* formatting dates */

- (NSString *)stringForTime:(NSCalendarDate *)_d prefix:(char *)_p {
  /* Note: prefix is not allowed to be long! */
  char buf[32];
  
  if (_p == NULL) _p = "";
  sprintf(buf, "%s%02i:%02i", _p, [_d hourOfDay], [_d minuteOfHour]);
  return [StrClass stringWithCString:buf];
}

- (NSString *)stringForCalendarDate:(NSCalendarDate *)_date {
  char buf[32];
  
  if (self->now == nil) {
    self->now = [[NSCalendarDate alloc] init];
    [self->now setTimeZone:[self timeZone]];
  }
  [_date setTimeZone:[self timeZone]];

  if ([self showOnlyTimeForToday] && [_date isDateOnSameDay:self->now])
    return [self stringForTime:_date prefix:NULL];
  
  if ([self showLabelsForNearDays]) {
    NSString *label;
    
    if ([_date isDateOnSameDay:self->now])
      label = [self labelForKey:@"today"];
    else if ([_date isDateOnSameDay:[self->now yesterday]])
      label = [self labelForKey:@"yesterday"];
    else
      label = nil;
    
    if (label != nil) {
      return [label stringByAppendingString:
		      [self stringForTime:_date prefix:", "]];
    }
  }
  
  /* 26.08.2004 13:24 */
  sprintf(buf, "%02d.%02d.%04d %02d:%02d",
	  [_date dayOfMonth], [_date monthOfYear], [_date yearOfCommonEra],
	  [_date hourOfDay], [_date minuteOfHour]);
  return [StrClass stringWithCString:buf];
}

/* formatter entry function */

- (NSString *)stringForObjectValue:(id)_date {
  if (![_date isNotNull])
    return nil;
  
  if ([_date isKindOfClass:StrClass]) /* already formatted */
    return _date;
  
  if ([_date isKindOfClass:CalDateClass])
    return [self stringForCalendarDate:_date];
  
  [self debugWithFormat:
	  @"NOTE: unexpected object for date formatter: %@<%@>",
	  _date, NSStringFromClass([_date class])];
  return [_date description];
}

@end /* UIxMailDateFormatter */
