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

#ifndef	__SOGoDateFormatter_H_
#define	__SOGoDateFormatter_H_

#import <Foundation/NSFormatter.h>

@class NSCalendarDate;
@class NSDictionary;
@class NSString;

@interface SOGoDateFormatter : NSFormatter
{
  NSDictionary *locale;
  NSString *shortDateFormat;
  NSString *longDateFormat;
  NSString *timeFormat;
}

- (void) setLocale: (NSDictionary *) newLocale;
- (void) setShortDateFormat: (NSString *) newDateFormat;
- (void) setLongDateFormat: (NSString *) newDateFormat;
- (void) setTimeFormat: (NSString *) newDateFormat;

- (NSString *) shortFormattedDate: (NSCalendarDate *) date;
- (NSString *) formattedDate: (NSCalendarDate *) date;
- (NSString *) formattedTime: (NSCalendarDate *) date;
- (NSString *) formattedDateAndTime: (NSCalendarDate *) date;

- (NSString *) stringForObjectValue: (id) date;

// - (void) setFullWeekdayNameAndDetails;

// - (NSString *) date: (NSCalendarDate *) date
// 	 withFormat: (unsigned int) format;
// - (NSString *) date: (NSCalendarDate *) date
//        withNSFormat: (NSNumber *) format;


// - (NSString *) shortDayOfWeek: (int)_day;
// - (NSString *) fullDayOfWeek: (int)_day;
// - (NSString *) shortMonthOfYear: (int)_month;
// - (NSString *) fullMonthOfYear: (int)_month;

// - (NSString *) fullWeekdayNameAndDetailsForDate: (NSCalendarDate *)_date;

@end

#endif	/* __SOGoDateFormatter_H_ */
