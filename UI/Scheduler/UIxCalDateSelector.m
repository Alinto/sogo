/* UIxCalDateSelector.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse groupe conseil
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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

#import <NGExtensions/NSCalendarDate+misc.h>

#import <SOGo/NSCalendarDate+SOGo.h>

#import "UIxCalDateSelector.h"

@implementation UIxCalDateSelector

/* binding accessors */

- (void) setSelectedDate: (NSCalendarDate *) _date
{
  ASSIGN (selectedDate, _date);
  [selectedDate setTimeZone: timeZone];
}

- (NSCalendarDate *) selectedDate
{
  if (!selectedDate)
    selectedDate = [super selectedDate];

  return selectedDate;
}

- (NSString *) style
{
  return style;
}

- (NSString *) headerStyle
{
  return headerStyle;
}

- (NSString *) weekStyle
{
  return weekStyle;
}

- (void) setTodayWeekStyle: (NSString *) _style
{
  ASSIGN (todayWeekStyle, _style);
}

- (NSString *) todayWeekStyle
{
  return ((todayWeekStyle)
          ? todayWeekStyle
          : [self weekStyle]);
}

- (NSString *) dayHeaderStyle
{
  return dayHeaderStyle;
}

- (void) setSelectedDayExtraStyle: (NSString *) _style
{
  ASSIGN(selectedDayExtraStyle, _style);
}

- (NSString *) selectedDayExtraStyle
{
  return selectedDayExtraStyle;
}

/* date ranges */

- (NSCalendarDate *) startDate
{
  return [[self selectedDate] firstDayOfMonth];
}

/* labels */

- (NSString *) headerMonthValue
{
  NSCalendarDate *date;

  date = [self startDate];

  return [NSString stringWithFormat: @"%.2d", [date monthOfYear]];
}

- (NSString *) headerMonthString
{
  NSCalendarDate *date;

  date = [self startDate];

  return [NSString stringWithFormat:@"%@",
                   [self localizedNameForMonthOfYear: [date monthOfYear]]];
}

- (NSString *) headerYearString
{
  NSCalendarDate *date;

  date = [self startDate];

  return [NSString stringWithFormat: @"%d", [date yearOfCommonEra]];
}

- (NSString *) localizedDayOfWeekName
{
  return [self localizedAbbreviatedNameForDayOfWeek: [self dayOfWeek]];
}


/* stylesheets */

- (NSString *) currentWeekStyle
{
  return (([currentWeekStart isDateInSameWeek:[NSCalendarDate date]] &&
           [currentWeekStart isDateInSameMonth:[self selectedDate]])
          ? [self todayWeekStyle]
          : [self weekStyle]);
}

- (NSString *) contentStyle
{
  return (([currentDay isToday]
           && [currentDay isDateInSameMonth:[self selectedDate]])
          ? @"dayOfToday"
          : (([currentDay monthOfYear] != [[self startDate] monthOfYear])
             ? @"inactiveDay"
             :  @"activeDay"));
}

- (NSString *) extraStyle
{
  return (([[self selectedDate] isDateOnSameDay: currentDay])
          ? [self selectedDayExtraStyle]
          : nil);
}

/* URLs */

- (NSDictionary *) currentMonthQueryParameters
{
  return [self queryParametersBySettingSelectedDate: [self startDate]];
}

/* overriding */

- (NSArray *) fetchCoreInfos
{
  return nil;
}

@end
