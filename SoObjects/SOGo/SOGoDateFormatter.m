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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSUserDefaults.h>

#import "SOGoDateFormatter.h"

@implementation SOGoDateFormatter

- (id) init
{
  if ((self = [super init]))
    {
      locale = nil;
      shortDateFormat = nil;
      longDateFormat = nil;
      timeFormat = nil;
    }

  return self;
}

- (void) dealloc
{
  [longDateFormat release];
  [shortDateFormat release];
  [timeFormat release];
  [locale release];
  [super dealloc];
}

/* accessors */

- (void) setLocale: (NSDictionary *) newLocale
{
  ASSIGN (locale, newLocale);
  ASSIGN (shortDateFormat, [locale objectForKey: NSShortDateFormatString]);
  ASSIGN (longDateFormat, [locale objectForKey: NSDateFormatString]);
  ASSIGN (timeFormat, [locale objectForKey: NSTimeFormatString]);
}

- (void) setShortDateFormat: (NSString *) newFormat
{
  ASSIGN (shortDateFormat, newFormat);
}

- (void) setLongDateFormat: (NSString *) newFormat
{
  ASSIGN (longDateFormat, newFormat);
}

- (void) setTimeFormat: (NSString *) newFormat
{
  ASSIGN (timeFormat, newFormat);
}

/* operation */

- (NSString *) _date: (NSCalendarDate *) date
	  withFormat: (NSString *) format
{
  NSString *formattedDate;

  if (format && locale)
    formattedDate
      = [date descriptionWithCalendarFormat: format locale: locale];
  else
    formattedDate = nil;

  return formattedDate;
}

- (NSString *) shortFormattedDate: (NSCalendarDate *) date
{
  return [self _date: date withFormat: shortDateFormat];
}

- (NSString *) formattedDate: (NSCalendarDate *) date
{
  return [self _date: date withFormat: longDateFormat];
}

- (NSString *) formattedTime: (NSCalendarDate *) date
{
  return [self _date: date withFormat: timeFormat];
}

- (NSString *) formattedDateAndTime: (NSCalendarDate *) date
{
  NSString *format;

  format = [NSString stringWithFormat: @"%@ %@ %%Z",
		     longDateFormat, timeFormat];

  return [self _date: date withFormat: format];
}

- (NSString *) stringForObjectValue: (id) object
{
  NSString *formattedString;

  if ([object isKindOfClass: [NSCalendarDate class]])
    formattedString = [self formattedDateAndTime: object];
  else
    formattedString = nil;

  return formattedString;
}

@end /* SOGoDateFormatter */
