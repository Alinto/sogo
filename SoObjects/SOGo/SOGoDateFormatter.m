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
//       locale = [_locale retain];
      
//       if ([[locale objectForKey:@"NSLocaleCode"] isEqualToString: @"fr"])
// 	shortDateFormat = SOGoDateDMYFormat;
//       else
// 	shortDateFormat = SOGoDateISOFormat;
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

// - (void) setFullWeekdayNameAndDetails
// {
//   auxFormatAction = formatAction;
//   formatAction = @selector(fullWeekdayNameAndDetailsForDate:);
// }

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

// /* Helpers */

// - (NSString *)shortDayOfWeek:(int)_day {
//   return [[locale objectForKey:@"NSShortWeekDayNameArray"]
// 	   objectAtIndex:_day];
// }

// - (NSString *)fullDayOfWeek:(int)_day {
//   return [[locale objectForKey:@"NSWeekDayNameArray"]
// 	   objectAtIndex:_day];
// }

// - (NSString *)shortMonthOfYear:(int)_month {
//   return [[locale objectForKey:@"NSShortMonthNameArray"]
// 	   objectAtIndex:_month - 1];
// }

// - (NSString *)fullMonthOfYear:(int)_month {
//   return [[locale objectForKey:@"NSMonthNameArray"]
// 	   objectAtIndex:_month - 1];
// }


/* Private API */

// - (NSString *) fullWeekdayNameAndDetailsForDate: (NSCalendarDate *) _date
// {
//   NSMutableString *desc;

//   if (_date)
//     {  
//       desc = [NSMutableString stringWithCapacity:24];
//       [desc appendString:[self fullDayOfWeek:[_date dayOfWeek]]];
//       [desc appendString:@", "];
//       [desc appendString:[self performSelector:auxFormatAction
//                            withObject:_date]];
//       [desc appendString:@" "];
//       [desc appendFormat:@"%02d:%02d ", [_date hourOfDay], [_date minuteOfHour]];
//       [desc appendString:[[_date timeZone] abbreviation]];
//     }
//   else
//     desc = nil;

//   return desc;
// }

// - (NSString *) _separatorForFormat: (unsigned int) format
// {
//   NSString *separator;

//   switch (format & (3))
//     {
//     case SOGoDateDotFormat:
//       separator = @".";
//       break;
//     case SOGoDateDashFormat:
//       separator = @".";
//       break;
//     default:
//       separator = @"/";
//     }

//   return separator;
// }

// - (NSString *) _dateFormatForDate: (NSCalendarDate *) date
// 		       withFormat: (unsigned int) format
// 		     andSeparator: (NSString *) separator
// {
//   NSString *day, *month, *year;
//   NSString *formattedDate;

//   day = [NSString stringWithFormat: @"%.2d", [date dayOfMonth]];
//   month = [NSString stringWithFormat: @"%.2d", [date monthOfYear]];
//   if (format & SOGoDateTwoDigitsYearFormat)
//     year = [NSString stringWithFormat: @"%.2d", [date yearOfCommonEra] % 100];
//   else
//     year = [NSString stringWithFormat: @"%.4d", [date yearOfCommonEra]];

//   if (format & SOGoDateDMYFormat)
//     formattedDate = [NSString stringWithFormat: @"%@%@%@%@%@",
// 			      day, separator, month, separator, year];
//   else if (format & SOGoDateMDYFormat)
//     formattedDate = [NSString stringWithFormat: @"%@%@%@%@%@",
// 			      month, separator, day, separator, year];
//   else
//     formattedDate = [NSString stringWithFormat: @"%@%@%@%@%@",
// 			      year, separator, month, separator, day];

//   return formattedDate;
// }

// - (NSString *) date: (NSCalendarDate *) date
// 	 withFormat: (unsigned int) format
// {
//   NSString *separator;

//   separator = [self _separatorForFormat: format];
  
//   return [self _dateFormatForDate: date
// 	       withFormat: format
// 	       andSeparator: separator];
// }

// - (NSString *) date: (NSCalendarDate *) date
//        withNSFormat: (NSNumber *) format
// {
//   return [self date: date withFormat: [format unsignedIntValue]];
// }

@end /* SOGoDateFormatter */
