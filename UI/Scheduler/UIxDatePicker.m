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

#import <Foundation/NSValue.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>
#import <NGExtensions/NSObject+Logs.h>

#import "UIxDatePicker.h"

@implementation UIxDatePicker

- (id) init
{
  if ((self = [super init]))
    {
      isDisabled = NO;
      format = nil;
      jsFormat = nil;
    }

  return self;
}

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

- (NSString *) formattedDateString
{
  NSMutableString *buf;
  NSString *_day, *_month, *_year, *_syear;

  if (!format)
    [self setupFormat];

  _day = [NSString stringWithFormat: @"%02d", [[self day] intValue]];
  _month = [NSString stringWithFormat: @"%02d", [[self month] intValue]];
  _year = [NSString stringWithFormat: @"%04d", [[self year] intValue]];
  _syear = [NSString stringWithFormat: @"%02d", [[self year] intValue] % 100];

  buf = [NSMutableString stringWithString: jsFormat];
  [buf replaceString: @"dd" withString: _day];
  [buf replaceString: @"mm" withString: _month];
  [buf replaceString: @"yyyy" withString: _year];
  [buf replaceString: @"yy" withString: _syear];

  return buf;
}

- (NSString *) dateFormat
{
  if (!format)
    [self setupFormat];
  return format;
}

- (NSString *) jsDateFormat
{
  if (!format)
    [self setupFormat];
  return jsFormat;
}

- (void) setupFormat
{
  NSUserDefaults *ud;
  NSMutableString *tmp;
  
  ud = [[[self context] activeUser] userDefaults];
  tmp = [NSMutableString stringWithString: 
         [ud stringForKey: @"ShortDateFormat"]];
  if (!tmp)
    {
      if ([self useISOFormats])
        tmp = [NSMutableString stringWithString: @"%Y-%m-%d"];
      else
        tmp = [NSMutableString stringWithString: @"%d/%m/%Y"];
    }

  format = [NSString stringWithString: tmp];

  [tmp replaceString: @"%d" withString: @"dd"];
  [tmp replaceString: @"%m" withString: @"mm"];
  [tmp replaceString: @"%Y" withString: @"yyyy"];
  [tmp replaceString: @"%y" withString: @"yy"];
  jsFormat = [NSString stringWithString: tmp];
}

/* action */

- (void) takeValuesFromRequest: (WORequest *) _rq
                     inContext: (WOContext *)_ctx
{
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

- (void) setDisabled: (BOOL) disabled
{
  isDisabled = disabled;
}

- (BOOL) disabled
{
  return isDisabled;
}

@end /* UIxDatePicker */
