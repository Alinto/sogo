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

#include "SOGoDateFormatter.h"
#include "common.h"

@implementation SOGoDateFormatter

- (id)initWithLocale:(NSDictionary *)_locale {
  if ((self = [super init])) {
    self->locale = [_locale retain];
    
    if ([[self->locale objectForKey:@"NSLocaleCode"] isEqualToString:@"fr"])
      [self setFrenchDateFormat];
    else
      [self setISODateFormat];
  }
  return self;
}

- (void)dealloc {
  [self->locale release];
  [super dealloc];
}

/* accessors */

- (void)setISODateFormat {
  self->formatAction = @selector(isoDateFormatForDate:);
}

- (void)setFrenchDateFormat {
  self->formatAction = @selector(frenchDateFormatForDate:);
}

- (void)setFullWeekdayNameAndDetails {
  self->auxFormatAction = self->formatAction;
  self->formatAction    = @selector(fullWeekdayNameAndDetailsForDate:);
}

/* operation */

- (NSString *)stringForObjectValue:(id)_obj {
  return [self performSelector:self->formatAction
	       withObject:_obj];
}

/* Helpers */

- (NSString *)shortDayOfWeek:(int)_day {
  return [[self->locale objectForKey:@"NSShortWeekDayNameArray"]
	   objectAtIndex:_day];
}

- (NSString *)fullDayOfWeek:(int)_day {
  return [[self->locale objectForKey:@"NSWeekDayNameArray"]
	   objectAtIndex:_day];
}

- (NSString *)shortMonthOfYear:(int)_month {
  return [[self->locale objectForKey:@"NSShortMonthNameArray"]
	   objectAtIndex:_month - 1];
}

- (NSString *)fullMonthOfYear:(int)_month {
  return [[self->locale objectForKey:@"NSMonthNameArray"]
	   objectAtIndex:_month - 1];
}


/* Private API */

- (NSString *)isoDateFormatForDate:(NSCalendarDate *)_date {
  char buf[16];
  
  if (_date == nil) return nil;
  snprintf(buf, sizeof(buf), 
	   "%04d-%02d-%02d",
	   [_date yearOfCommonEra], [_date monthOfYear], [_date dayOfMonth]);
  return [NSString stringWithCString:buf];
}

- (NSString *)frenchDateFormatForDate:(NSCalendarDate *)_date {
  char buf[16];
  
  if (_date == nil) return nil;
  snprintf(buf, sizeof(buf), 
	   "%02d/%02d/%04d",
	   [_date dayOfMonth], [_date monthOfYear], [_date yearOfCommonEra]);
  return [NSString stringWithCString:buf];
}

- (NSString *)fullWeekdayNameAndDetailsForDate:(NSCalendarDate *)_date {
  NSMutableString *desc;
  
  if (_date == nil) return nil;
  
  desc = [NSMutableString stringWithCapacity:24];
  [desc appendString:[self fullDayOfWeek:[_date dayOfWeek]]];
  [desc appendString:@", "];
  [desc appendString:[self performSelector:self->auxFormatAction
                           withObject:_date]];
  [desc appendString:@" "];
  [desc appendFormat:@"%02d:%02d ", [_date hourOfDay], [_date minuteOfHour]];
  [desc appendString:[[_date timeZone] abbreviation]];
  return desc;
}

@end /* SOGoDateFormatter */
