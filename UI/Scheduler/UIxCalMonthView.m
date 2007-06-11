/* UIxCalMonthView.m - this file is part of SOGo
 *
 * Copyright (C) 2006, 2007 Inverse groupe conseil
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

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSCalendarDate+misc.h>
#import <SoObjects/SOGo/NSCalendarDate+SOGo.h>

#import <SOGoUI/SOGoAptFormatter.h>
#import <SOGoUI/SOGoDateFormatter.h>

#import "UIxCalMonthView.h"

@implementation UIxCalMonthView

- (id) init
{
  if ((self = [super init]))
    {
      monthAptFormatter
        = [[SOGoAptFormatter alloc] initWithDisplayTimeZone: timeZone];
      [monthAptFormatter setShortMonthTitleOnly];
      dateFormatter = [[SOGoDateFormatter alloc]
                        initWithLocale: [self locale]];
      sortedAppointments = [NSMutableDictionary new];
      daysToDisplay = nil;
    }

  return self;
}

- (SOGoAptFormatter *) monthAptFormatter
{
  return monthAptFormatter;
}

- (void) dealloc
{
  [daysToDisplay release];
  [monthAptFormatter release];
  [dateFormatter release];
  [sortedAppointments release];
  [super dealloc];
}

- (NSArray *) headerDaysToDisplay
{
  NSMutableArray *headerDaysToDisplay;
  unsigned int counter;

  headerDaysToDisplay = [NSMutableArray arrayWithCapacity: 7];
  currentTableDay = [[self selectedDate] mondayOfWeek];
  for (counter = 0; counter < 7; counter++)
    {
      [headerDaysToDisplay addObject: currentTableDay];
      currentTableDay = [currentTableDay tomorrow];
    }

  return headerDaysToDisplay;
}

- (NSArray *) daysToDisplay
{
  NSMutableArray *days[7];
  unsigned int counter;
  NSCalendarDate *firstOfAllDays, *lastDayOfMonth;

  if (!daysToDisplay)
    {
      firstOfAllDays = [[[self selectedDate] firstDayOfMonth] mondayOfWeek];
      lastDayOfMonth  = [[self selectedDate] lastDayOfMonth];
      for (counter = 0; counter < 7; counter++)
        {
          days[counter] = [NSMutableArray new];
          [days[counter] autorelease];
        }
      currentTableDay = firstOfAllDays;
      while ([currentTableDay earlierDate: lastDayOfMonth] == currentTableDay)
        for (counter = 0; counter < 7; counter++)
          {
            [days[counter] addObject: currentTableDay];
            currentTableDay = [currentTableDay tomorrow];
          }
      daysToDisplay = [NSArray arrayWithObjects: days count: 7];
      [daysToDisplay retain];
    }

  return daysToDisplay;
}

- (NSString *) labelForCurrentDayToDisplay
{
  return [dateFormatter fullDayOfWeek: [currentTableDay dayOfWeek]];
}

- (NSDictionary *) _dateQueryParametersWithOffset: (int) monthsOffset
{
  NSCalendarDate *date;
  
  date = [[self selectedDate] dateByAddingYears: 0 months: monthsOffset
                              days: 0 hours: 0 minutes: 0 seconds: 0];

  return [self queryParametersBySettingSelectedDate: date];
}

- (NSDictionary *) monthBeforePrevMonthQueryParameters
{
  return [self _dateQueryParametersWithOffset: -2];
}

- (NSDictionary *) prevMonthQueryParameters
{
  return [self _dateQueryParametersWithOffset: -1];
}

- (NSDictionary *) nextMonthQueryParameters
{
  return [self _dateQueryParametersWithOffset: 1];
}

- (NSDictionary *) monthAfterNextMonthQueryParameters
{
  return [self _dateQueryParametersWithOffset: 2];
}

- (NSString *) _monthNameWithOffsetFromThisMonth: (int) offset
{
  NSCalendarDate *date;

  date = [[self selectedDate] dateByAddingYears: 0 months: offset days: 0];

  return [self localizedNameForMonthOfYear: [date monthOfYear]];
}

- (NSString *) monthNameOfTwoMonthAgo
{
  return [self _monthNameWithOffsetFromThisMonth: -2];
}

- (NSString *) monthNameOfOneMonthAgo
{
  return [self _monthNameWithOffsetFromThisMonth: -1];
}

- (NSString *) monthNameOfThisMonth
{
  return [self _monthNameWithOffsetFromThisMonth: 0];
}

- (NSString *) monthNameOfNextMonth
{
  return [self _monthNameWithOffsetFromThisMonth: 1];
}

- (NSString *) monthNameOfTheMonthAfterNextMonth
{
  return [self _monthNameWithOffsetFromThisMonth: 2];
}

/* template accessors */
- (void) setCurrentTableDay: (NSCalendarDate *) newCurrentTableDay
{
  currentTableDay = newCurrentTableDay;
}

- (NSCalendarDate *) currentTableDay
{
  return currentTableDay;
}

- (void) setCurrentTableColumn: (NSArray *) newCurrentTableColumn
{
  currentTableColumn = newCurrentTableColumn;
}

- (NSArray *) currentTableColumn
{
  return currentTableColumn;
}

- (NSString *) labelForCurrentDayCell
{
  NSCalendarDate *lastDayOfMonth;
  NSString *label, *monthOfYear;
  int dayOfMonth;

  dayOfMonth = [currentTableDay dayOfMonth];
  lastDayOfMonth = [currentTableDay lastDayOfMonth];
  if (dayOfMonth == 1
      || [currentTableDay isDateOnSameDay: lastDayOfMonth])
    {
      monthOfYear
        = [dateFormatter shortMonthOfYear: [currentTableDay monthOfYear]];
      label = [NSString stringWithFormat: @"%d %@", dayOfMonth, monthOfYear];
    }
  else
    label = [NSString stringWithFormat: @"%d", dayOfMonth];

  return label;
}

- (NSString *) headerDayCellClasses
{
  return [NSString stringWithFormat: @"headerDay day%d",
                   [currentTableDay dayOfWeek]];
}

- (NSString *) dayHeaderNumber
{
  NSString *nameOfMonth, *dayHeaderNumber;
  unsigned int dayOfMonth;

  dayOfMonth = [currentTableDay dayOfMonth];
  if (dayOfMonth == 1
      || [currentTableDay isDateOnSameDay: [currentTableDay lastDayOfMonth]])
    {
      nameOfMonth
        = [self localizedNameForMonthOfYear: [currentTableDay monthOfYear]];
      dayHeaderNumber = [NSString stringWithFormat: @"%d %@", dayOfMonth,
                                  nameOfMonth];
    }
  else
    dayHeaderNumber = [NSString stringWithFormat: @"%d", dayOfMonth];

  return dayHeaderNumber;
}

- (NSString *) dayCellClasses
{
  NSMutableString *classes;
  NSCalendarDate *selectedDate;
  int dayOfWeek, numberOfWeeks;

  classes = [NSMutableString new];
  [classes autorelease];

  dayOfWeek = [currentTableDay dayOfWeek];
  numberOfWeeks = [currentTableColumn count];

  [classes appendFormat: @"day weekOf%d week%dof%d day%d",
           numberOfWeeks,
           [currentTableColumn indexOfObject: currentTableDay],
           numberOfWeeks, dayOfWeek];
  if (dayOfWeek == 0 || dayOfWeek == 6)
    [classes appendString: @" weekEndDay"];
  selectedDate = [self selectedDate];
  if (![[currentTableDay firstDayOfMonth]
         isDateOnSameDay: [selectedDate firstDayOfMonth]])
    [classes appendString: @" dayOfAnotherMonth"];
  if ([currentTableDay isToday])
    [classes appendString: @" dayOfToday"];
  if ([selectedDate isDateOnSameDay: currentTableDay])
    [classes appendString: @" selectedDay"];

  return classes;
}

- (NSArray *) _rangeOf7DaysForWeekStartingOn: (NSCalendarDate *) weekStart
{
  unsigned int count;
  NSMutableArray *range;
  NSCalendarDate *currentDate;

  range = [NSMutableArray arrayWithCapacity: 7];
  currentDate = weekStart;
  for (count = 0; count < 7; count++)
    {
      [range addObject: currentDate];
      currentDate = [currentDate dateByAddingYears: 0 months: 0 days: 1];
    }

  return range;
}

- (NSCalendarDate *) startDate
{
  NSCalendarDate *firstDayOfMonth;

  firstDayOfMonth = [[self selectedDate] firstDayOfMonth];

  return [firstDayOfMonth mondayOfWeek];
}

- (NSCalendarDate *) endDate
{
  NSCalendarDate *lastDayOfMonth;

  lastDayOfMonth = [[self selectedDate] lastDayOfMonth];

  return [[lastDayOfMonth mondayOfWeek] dateByAddingYears: 0 months: 0 days: 6];
}

- (NSArray *) aptsForCurrentDate
{
  return [sortedAppointments objectForKey: [currentTableDay shortDateString]];
}

@end
