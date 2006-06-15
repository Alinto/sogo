/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#include <NGObjWeb/WOComponent.h>

@class NSString;

@interface UIxDatePicker : WOComponent
{
  NSString *dateID;
  id       day;
  id       month;
  id       year;
  NSString *label;
}

- (NSString *)dateID;
- (NSString *)dateFormat;
- (NSString *)jsDateFormat;
- (BOOL)useISOFormats;
@end

#include "common.h"

@implementation UIxDatePicker

- (void)dealloc {
  [self->dateID release];
  [self->day    release];
  [self->month  release];
  [self->year   release];
  [self->label  release];
  [super dealloc];
}

/* Accessors */

- (void)setDateID:(NSString *)_dateID {
  ASSIGNCOPY(self->dateID, _dateID);
}
- (NSString *)dateID {
  return self->dateID;
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


- (void)setLabel:(NSString *)_label {
  ASSIGNCOPY(self->label, _label);
}
- (NSString *)label {
  return self->label;
}


/* formats */

- (BOOL)useISOFormats {
  WOContext *ctx;
  NSNumber  *useISOFormats;
  
  ctx           = [self context];
  useISOFormats = [ctx valueForKey:@"useISOFormats"];
  if (!useISOFormats) {
      NSArray *languages = [ctx resourceLookupLanguages];
      if (languages && [languages count] > 0) {
        if ([[languages objectAtIndex:0] isEqualToString:@"French"]) {
          useISOFormats = [NSNumber numberWithBool:NO];
        }
      }
      if (!useISOFormats)
        useISOFormats = [NSNumber numberWithBool:YES];
      [ctx takeValue:useISOFormats forKey:@"useISOFormats"];
 }
  return [useISOFormats boolValue];
}
- (NSString *)formattedDateString {
  char buf[22];

  if ([self useISOFormats]) {
    sprintf(buf, "%04d-%02d-%02d",
	    [[self year]  intValue],
	    [[self month] intValue],
	    [[self day]  intValue]);
  }
  else {
    sprintf(buf, "%02d/%02d/%04d",
	    [[self day] intValue],
	    [[self month] intValue],
	    [[self year] intValue]);
  }
  return [NSString stringWithCString:buf];
}

- (NSString *)dateFormat {
  return [self useISOFormats] ? @"%Y-%m-%d" : @"%d/%m/%Y";
}

- (NSString *)jsDateFormat {
  return [self useISOFormats] ? @"yyyy-mm-dd" : @"dd/mm/yyyy";
}


/* URLs */

- (NSString *)calendarPageURL {
  WOResourceManager *rm;
  WOContext *ctx;
  NSArray   *languages;

  if ((rm = [self resourceManager]) == nil)
    rm = [[WOApplication application] resourceManager];
  if (rm == nil)
    [self warnWithFormat:@"missing resource manager!"];

  ctx       = [self context];
#if 0
  languages = [ctx resourceLookupLanguages];
#else
#warning !! FIX SoProduct to enable localizable resource, then disable this!
  languages = nil;
#endif
    
  return [rm urlForResourceNamed:@"skycalendar.html" inFramework:nil
             languages:languages request:[ctx request]];
}

/* JavaScript */

- (NSString *)jsPopup {
  return [NSString stringWithFormat:@"javascript:calendar_%@.popup()",
        [self dateID]];
}

- (NSString *)jsCode {
  static NSString *code = \
    @"var calendar_%@ = new skycalendar(document.getElementById('%@'));\n"
    @"calendar_%@.setCalendarPage('%@');\n"
    @"calendar_%@.setDateFormat('%@');\n";
  
  return [NSString stringWithFormat:code,
		   self->dateID,
		   self->dateID,
		   self->dateID,
		   [self calendarPageURL],
		   self->dateID,
		   [self jsDateFormat]];
}

/* action */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  NSString       *dateString;
  NSCalendarDate *d;

  dateString = [_rq formValueForKey:[self dateID]];
  if (dateString == nil) {
    [self debugWithFormat:@"got no date string!"];
    return;
  }

  d = [NSCalendarDate dateWithString:dateString
                      calendarFormat:[self dateFormat]];
  if (d == nil) {
    [self warnWithFormat:@"Could not parse dateString: '%@'", 
            dateString];
  }
  [self setDay:  [NSNumber numberWithInt:[d dayOfMonth]]];
  [self setMonth:[NSNumber numberWithInt:[d monthOfYear]]];
  [self setYear: [NSNumber numberWithInt:[d yearOfCommonEra]]];
  
  [super takeValuesFromRequest:_rq inContext:_ctx];
}

@end /* UIxDatePicker */
