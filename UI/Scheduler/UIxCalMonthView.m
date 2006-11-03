/* UIxCalMonthView.m - this file is part of SOGo
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
  NSTimeZone *tz;

  if ((self = [super init]))
    {
      tz = [[self clientObject] userTimeZone];
 
      monthAptFormatter
        = [[SOGoAptFormatter alloc] initWithDisplayTimeZone: tz];
      [monthAptFormatter setShortMonthTitleOnly];
      dateFormatter = [[SOGoDateFormatter alloc]
                        initWithLocale: [self locale]];
      sortedAppointments = [NSMutableDictionary new];
    }

  return self;
}

- (SOGoAptFormatter *) monthAptFormatter
{
  return monthAptFormatter;
}

- (void) dealloc
{
  [monthAptFormatter release];
  [dateFormatter release];
  [sortedAppointments release];
  [super dealloc];
}

- (void) _addEventToSortedEvents: (NSDictionary *) newEvent
{
  NSMutableArray *eventArray;
  NSString *dayId;

  dayId = [[newEvent objectForKey: @"startDate"] shortDateString];
  eventArray = [sortedAppointments objectForKey: dayId];
  if (!eventArray)
    {
      eventArray = [NSMutableArray new];
      [eventArray autorelease];
      [sortedAppointments setObject: eventArray forKey: dayId];
    }
  [eventArray addObject: newEvent];
}

- (id <WOActionResults>) defaultAction
{
  NSEnumerator *events;
  NSDictionary *currentEvent;

  events = [[self fetchCoreAppointmentsInfos] objectEnumerator];
  currentEvent = [events nextObject];
  while (currentEvent)
    {
      [self _addEventToSortedEvents: currentEvent];
      currentEvent = [events nextObject];
//       NSLog (@"event:\n'%@'", currentEvent);
    }

  return self;
}

- (NSArray *) daysToDisplay
{
  NSMutableArray *daysToDisplay;
  NSCalendarDate *currentDayToDisplay;
  unsigned int day;

  daysToDisplay = [NSMutableArray arrayWithCapacity: 7];
  currentDayToDisplay = [[NSCalendarDate calendarDate] mondayOfWeek];
  for (day = 0; day < 7; day++)
    {
      [daysToDisplay addObject: currentDayToDisplay];
      currentDayToDisplay
        = [currentDayToDisplay dateByAddingYears: 0 months: 0 days: 1];
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

- (void) setCurrentRangeOf7Days: (NSArray *) newCurrentRangeOf7Days
{
  currentRangeOf7Days = newCurrentRangeOf7Days;
}

- (NSArray *) currentRangeOf7Days
{
  return currentRangeOf7Days;
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

- (NSString *) dayCellClasses
{
  NSMutableString *classes;
  NSCalendarDate *selectedDate;
  int dayOfWeek;

  classes = [NSMutableString new];
  [classes autorelease];
  [classes appendString: @"contentOfDay"];
  dayOfWeek = [currentTableDay dayOfWeek];
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

- (NSArray *) rangesOf7Days
{
  NSCalendarDate *currentDate, *firstDayOfMonth, *lastDayOfMonth;
  NSMutableArray *rangesOf7Days;
  NSArray *currentRange;
  int monthOfYear;

  rangesOf7Days = [NSMutableArray new];
  [rangesOf7Days autorelease];

  firstDayOfMonth = [[self selectedDate] firstDayOfMonth];
  lastDayOfMonth = [firstDayOfMonth lastDayOfMonth];
  currentDate = [firstDayOfMonth mondayOfWeek];
  currentRange = [self _rangeOf7DaysForWeekStartingOn: currentDate];
  [rangesOf7Days addObject: currentRange];

  currentDate = [[currentRange objectAtIndex: 6] dateByAddingYears: 0
                                                 months: 0 days: 1];
  monthOfYear = [currentDate monthOfYear];
  while ([currentDate monthOfYear] == monthOfYear)
    {
      currentRange = [self _rangeOf7DaysForWeekStartingOn: currentDate];
      [rangesOf7Days addObject: currentRange];
      currentDate = [[currentRange objectAtIndex: 6] dateByAddingYears: 0
                                                     months: 0 days: 1];
    }

  return rangesOf7Days;
}

- (NSArray *) aptsForCurrentDate
{
  return [sortedAppointments objectForKey: [currentTableDay shortDateString]];
}

@end
