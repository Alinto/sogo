/* UIxDatePicker.h - this file is part of SOGo
 *
 * Copyright (C) 2009-2014 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <Foundation/NSValue.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSTimeZone.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGExtensions/NSObject+Logs.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import "UIxDatePicker.h"

@implementation UIxDatePicker

- (id) init
{
  if ((self = [super init]))
    {
      dateID = nil;
      day = nil;
      year = nil;
      label = nil;
      isDisabled = NO;
    }

  return self;
}

- (void) dealloc
{
  [self->dateID release];
  [self->day    release];
  [self->month  release];
  [self->year   release];
  [self->label  release];
  [super dealloc];
}

/* Accessors */

- (void) setDateID: (NSString *) _dateID
{
  ASSIGNCOPY(self->dateID, _dateID);
}
- (NSString *) dateID
{
  return self->dateID;
}

- (void) setDay: (id) _day
{
  ASSIGN(self->day, _day);
}
- (id) day
{
  return self->day;
}

- (void) setMonth: (id) _month
{
  ASSIGN(self->month, _month);
}
- (id) month
{
  return self->month;
}

- (void) setYear: (id) _year
{
  ASSIGN(self->year, _year);
}
- (id) year
{
  return self->year;
}

- (void) setLabel: (NSString *) _label
{
  ASSIGNCOPY(self->label, _label);
}
- (NSString *) label
{
  return self->label;
}


/* formats */

- (BOOL) useISOFormats
{
  NSNumber *useISOFormats;
  WOContext *ctx;
  
  ctx = [self context];
  useISOFormats = [ctx valueForKey:@"useISOFormats"];
  if (!useISOFormats)
    {
      NSArray *languages;

      languages = [ctx resourceLookupLanguages];
      if (languages && [languages count] > 0)
        {
          if ([[languages objectAtIndex:0] isEqualToString:@"French"])
            {
              useISOFormats = [NSNumber numberWithBool:NO];
            }
        }
      if (!useISOFormats)
        useISOFormats = [NSNumber numberWithBool: YES];

      [ctx takeValue: useISOFormats  forKey:@"useISOFormats"];
    }

  return [useISOFormats boolValue];
}

- (NSString *) formattedDateString
{
  char buf[22];

  if ([self useISOFormats])
    {
      sprintf(buf, "%04d-%02d-%02d",
              [[self year]  intValue],
              [[self month] intValue],
              [[self day]  intValue]);
    }
  else
    {
      sprintf(buf, "%02d/%02d/%04d",
              [[self day] intValue],
              [[self month] intValue],
              [[self year] intValue]);
  }
  return [NSString stringWithCString:buf];
}

- (NSString *) dateFormat
{
  return [self useISOFormats] ? @"%Y-%m-%d" : @"%d/%m/%Y";
}

- (NSString *) jsDateFormat
{
  return [self useISOFormats] ? @"yyyy-mm-dd" : @"dd/mm/yyyy";
}

- (void) takeValuesFromRequest: (WORequest *) _rq
                     inContext: (WOContext *) _ctx
{
  NSInteger dateTZOffset, userTZOffset;
  NSTimeZone *systemTZ, *userTZ;
  SOGoUserDefaults *ud;
  NSString *dateString;
  NSCalendarDate *d;

  dateString = [_rq formValueForKey:[self dateID]];
  
  if (dateString == nil)
    {
      [self debugWithFormat:@"got no date string!"];
      return;
    }

  d = [NSCalendarDate dateWithString: dateString
                      calendarFormat: [self dateFormat]];
  if (!d)
    {
      [self warnWithFormat: @"Could not parse dateString: '%@'", 
            dateString];
    }

  /* we must adjust the date timezone because "dateWithString:..." uses the
     system timezone, which can be different from the user's. */
  ud = [[_ctx activeUser] userDefaults];
  systemTZ = [d timeZone];
  dateTZOffset = [systemTZ secondsFromGMTForDate: d];
  userTZ = [ud timeZone];
  userTZOffset = [userTZ secondsFromGMTForDate: d];
  if (dateTZOffset != userTZOffset)
    d = [d dateByAddingYears: 0 months: 0 days: 0
                       hours: 0 minutes: 0
                     seconds: (dateTZOffset - userTZOffset)];
  [d setTimeZone: userTZ];

  [self setDay: [NSNumber numberWithInt:[d dayOfMonth]]];
  [self setMonth: [NSNumber numberWithInt:[d monthOfYear]]];
  [self setYear: [NSNumber numberWithInt:[d yearOfCommonEra]]];
  
  [super takeValuesFromRequest: _rq  inContext: _ctx];
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
