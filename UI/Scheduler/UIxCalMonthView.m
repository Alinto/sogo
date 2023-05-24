/* UIxCalMonthView.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2016 Inverse inc.
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
#import <SoObjects/SOGo/NSCalendarDate+SOGo.h>

#import <SOPE/NGCards/iCalRecurrenceRule.h>

#import <SOGoUI/SOGoAptFormatter.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/WOResourceManager+SOGo.h>

#import "UIxCalMonthView.h"

@implementation UIxCalMonthView

- (id) init
{
  if ((self = [super init]))
    {
//       monthAptFormatter
//         = [[SOGoAptFormatter alloc] initWithDisplayTimeZone: timeZone];
//       [monthAptFormatter setShortMonthTitleOnly];
//       dateFormatter = [[SOGoDateFormatter alloc]
//                         initWithLocale: [self locale]];
      dayNames = [locale objectForKey: NSWeekDayNameArray];
      [dayNames retain];
      monthNames = [locale objectForKey: NSMonthNameArray];
      [monthNames retain];
      weeksToDisplay = nil;
      currentTableDay = nil;
      currentWeek = nil;
    }

  return self;
}

- (void) dealloc
{
  [monthNames release];
  [dayNames release];
  [weeksToDisplay release];
  [currentTableDay release];
  [currentWeek release];
  [enabledWeekDays release];
  free(daysNumbersToDisplay);
  [super dealloc];
}

- (id <WOActionResults>) defaultAction
{
  [super setCurrentView: @"monthview"];

  return self;
}

- (NSArray *) headerDaysToDisplay
{
  NSCalendarDate *currentDate;
  NSMutableArray *headerDaysToDisplay;
  NSString *weekDay;
  unsigned int counter;

  headerDaysToDisplay = [NSMutableArray arrayWithCapacity: 7];
  currentDate = [[context activeUser] firstDayOfWeekForDate: [self selectedDate]];
  for (counter = 0; counter < 7; counter++)
    {
      // Skip days that match disabled weekdays in user's defaults
      weekDay = iCalWeekDayString[[currentDate dayOfWeek]];
      if ([enabledWeekDays count] == 0 || [enabledWeekDays containsObject: weekDay])
        [headerDaysToDisplay addObject: currentDate];
      currentDate = [currentDate tomorrow];
    }

  return headerDaysToDisplay;
}

- (NSArray *) weeksToDisplay
{
  NSCalendarDate *currentDate, *selectedDate, *lastDayOfMonth, *firstOfAllDays;
  NSMutableArray *week;
  NSString *weekDay;
  unsigned int counter, day, enabledCounter;
  unsigned int firstToLast, weeks;

  if (!weeksToDisplay)
    {
      selectedDate = [self selectedDate];
      firstOfAllDays = [[context activeUser] firstDayOfWeekForDate:
                                               [selectedDate firstDayOfMonth]];
      lastDayOfMonth = [selectedDate lastDayOfMonth];
      firstToLast = ([lastDayOfMonth timeIntervalSinceDate: firstOfAllDays] / 86400) + 1;
      weeks = firstToLast / 7;
      if ((firstToLast % 7))
	weeks++;
      weeksToDisplay = [NSMutableArray arrayWithCapacity: weeks];
      daysNumbersToDisplay = malloc (weeks * 7 * sizeof (unsigned int));
      currentDate = firstOfAllDays;
      for (counter = 0, enabledCounter = 0; counter < weeks; counter++)
	{
	  week = [NSMutableArray arrayWithCapacity: 7];
	  for (day = 0; day < 7; day++)
	    {
              weekDay = iCalWeekDayString[[currentDate dayOfWeek]];
              if ([enabledWeekDays count] == 0 || [enabledWeekDays containsObject: weekDay])
                {
                  [week addObject: currentDate];
                  daysNumbersToDisplay[enabledCounter] = (counter * 7) + day;
                  enabledCounter++;
                }
	      currentDate = [currentDate tomorrow];
	    }
	  [weeksToDisplay addObject: week];
	}
      [weeksToDisplay retain];
    }

  return weeksToDisplay;
}

- (NSString *) labelForCurrentDayToDisplay
{
  return [dayNames objectAtIndex: [currentTableDay dayOfWeek]];
}

- (NSDictionary *) _dateQueryParametersWithOffset: (int) monthsOffset
{
  NSCalendarDate *date, *firstDay;
  
  firstDay = [[self selectedDate] firstDayOfMonth];
  date = [firstDay dateByAddingYears: 0 months: monthsOffset
		   days: 0 hours: 0 minutes: 0 seconds: 0];

  return [self queryParametersBySettingSelectedDate: [self _nextValidDate: date]];
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

- (NSString *) _monthNameWithOffsetFromThisMonth: (int) monthsOffset
{
  NSCalendarDate *date, *firstDay;

  firstDay = [[self selectedDate] firstDayOfMonth];
  date = [firstDay dateByAddingYears: 0 months: monthsOffset
		   days: 0 hours: 0 minutes: 0 seconds: 0];

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
  ASSIGN (currentTableDay, newCurrentTableDay);
}

- (NSCalendarDate *) currentTableDay
{
  return currentTableDay;
}

- (NSString *) currentDayId
{
  return [NSString stringWithFormat: @"day%@", [currentTableDay shortDateString]];
}

- (int) currentDayNumber
{
  int i = [currentWeek indexOfObject: currentTableDay] +
    ([weeksToDisplay indexOfObject: currentWeek] * [currentWeek count]);

  return daysNumbersToDisplay[i];
}

- (BOOL) isFirstDayOfWeek {
  return 0 == [currentWeek indexOfObject: currentTableDay];
}

- (int) currentWeekNumber
{
  SOGoUser *user;

  user = [context activeUser];
  
  return [user weekNumberForDate: currentTableDay];
}

- (void) setCurrentWeek: (NSArray *) newCurrentWeek
{
  ASSIGN (currentWeek, newCurrentWeek);
}

- (NSArray *) currentWeek
{
  return currentWeek;
}

- (NSString *) headerDayCellClasses
{
  unsigned int dayOfWeek;

  dayOfWeek = [[context activeUser] dayOfWeekForDate: currentTableDay];

  return [NSString stringWithFormat: @"headerDay day%d", dayOfWeek];
}

- (NSString *) dayHeaderMonth
{
  NSString *nameOfMonth = nil;
  unsigned int dayOfMonth;

  dayOfMonth = [currentTableDay dayOfMonth];
  if (dayOfMonth == 1
      || [currentTableDay isDateOnSameDay: [currentTableDay lastDayOfMonth]])
    {
      nameOfMonth = [self localizedNameForMonthOfYear: [currentTableDay monthOfYear]];
    }

  return nameOfMonth;
}

- (NSString *) dayCellClasses
{
  NSMutableString *classes;
  NSCalendarDate *selectedDate;
  unsigned int realDayOfWeek, dayOfWeek, numberOfWeeks;

  classes = [NSMutableString string];

  dayOfWeek = [[context activeUser] dayOfWeekForDate: currentTableDay];
  realDayOfWeek = [currentTableDay dayOfWeek];
  numberOfWeeks = [weeksToDisplay count];

  [classes appendFormat: @"day weekOf%d week%dof%d day%d",
           numberOfWeeks,
           (int)[weeksToDisplay indexOfObject: currentWeek],
           numberOfWeeks, dayOfWeek];
  if (realDayOfWeek == 0 || realDayOfWeek == 6)
    [classes appendString: @" weekEndDay"];
  selectedDate = [self selectedDate];
  if (![[currentTableDay firstDayOfMonth]
         isDateOnSameDay: [selectedDate firstDayOfMonth]])
    [classes appendString: @" dayOfAnotherMonth"];
  if ([currentTableDay isToday])
    [classes appendString: @" dayOfToday"];

  return classes;
}

- (NSCalendarDate *) startDate
{
  NSCalendarDate *firstDayOfMonth;

  firstDayOfMonth = [[self selectedDate] firstDayOfMonth];
  firstDayOfMonth = [[context activeUser] firstDayOfWeekForDate: firstDayOfMonth];

  return [self _nextValidDate: firstDayOfMonth];
}

- (NSCalendarDate *) endDate
{
  NSCalendarDate *lastDayOfMonth, *firstDay;

  lastDayOfMonth = [[self selectedDate] lastDayOfMonth];
  firstDay = [[context activeUser] firstDayOfWeekForDate: lastDayOfMonth];

  return [firstDay dateByAddingYears: 0 months: 0 days: 6];
}

@end
