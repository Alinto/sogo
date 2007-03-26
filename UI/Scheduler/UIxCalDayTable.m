/* UIxCalDayTable.m - this file is part of SOGo
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSString.h>

#import <EOControl/EOQualifier.h>

#import <NGExtensions/NSCalendarDate+misc.h>
#import <SOGoUI/SOGoDateFormatter.h>

#import "UIxCalDayTable.h"

@class SOGoAppointment;

@implementation UIxCalDayTable

- (id) init
{
  if ((self = [super init]))
    {
      allAppointments = nil;
      daysToDisplay = nil;
      hoursToDisplay = nil;
      numberOfDays = 1;
      startDate = nil;
      currentTableDay = nil;
      currentTableHour = nil;
      dateFormatter = [[SOGoDateFormatter alloc]
                        initWithLocale: [self locale]];
    }

  return self;
}

- (void) dealloc
{
  if (allAppointments)
    [allAppointments release];
  if (daysToDisplay)
    [daysToDisplay release];
  if (hoursToDisplay)
    [hoursToDisplay release];
  [dateFormatter release];
  [super dealloc];
}

- (void) setCSSClass: (NSString *) aCssClass
{
  cssClass = aCssClass;
}

- (NSString *) cssClass
{
  return cssClass;
}

- (void) setCSSId: (NSString *) aCssId
{
  cssId = aCssId;
}

- (NSString *) cssId
{
  return cssId;
}

- (void) setNumberOfDays: (NSString *) aNumber
{
  numberOfDays = [aNumber intValue];
  if (daysToDisplay)
    {
      [daysToDisplay release];
      daysToDisplay = nil;
    }
}

- (NSString *) numberOfDays
{
  return [NSString stringWithFormat: @"%d", numberOfDays];
}

- (void) setStartDate: (NSCalendarDate *) aStartDate
{
  startDate = aStartDate;
  if (daysToDisplay)
    {
      [daysToDisplay release];
      daysToDisplay = nil;
    }
}

- (NSCalendarDate *) startDate
{
  if (!startDate)
    startDate = [super startDate];

  return [startDate beginOfDay];
}

- (NSCalendarDate *) endDate
{
  NSCalendarDate *endDate;

  endDate = [[self startDate] dateByAddingYears: 0
                              months: 0
                              days: numberOfDays - 1];

  return [endDate endOfDay];
}

- (NSArray *) hoursToDisplay
{
  unsigned int currentHour, lastHour;

  if (!hoursToDisplay)
    {
      currentHour = [self dayStartHour];
      lastHour = [self dayEndHour];
      hoursToDisplay = [NSMutableArray new];

      while (currentHour < lastHour)
        {
          [hoursToDisplay
            addObject: [NSString stringWithFormat: @"%d", currentHour]];
          currentHour++;
        }
      [hoursToDisplay
        addObject: [NSString stringWithFormat: @"%d", currentHour]];
    }

  return hoursToDisplay;
}

- (NSArray *) daysToDisplay
{
  NSCalendarDate *currentDate;
  int count;

  if (!daysToDisplay)
    {
      daysToDisplay = [NSMutableArray new];
      currentDate = [[self startDate] hour: [self dayStartHour]
                                      minute: 0];
      [daysToDisplay addObject: currentDate];
      for (count = 1; count < numberOfDays; count++)
        [daysToDisplay addObject: [currentDate dateByAddingYears: 0
                                               months: 0
                                               days: count]];
    }

  return daysToDisplay;
}

- (void) setCurrentTableDay: (NSCalendarDate *) aTableDay
{
  currentTableDay = aTableDay;
}

- (NSCalendarDate *) currentTableDay
{
  return currentTableDay;
}

- (void) setCurrentTableHour: (NSString *) aTableHour
{
  currentTableHour = aTableHour;
}

- (NSString *) currentTableHour
{
  return currentTableHour;
}

- (NSString *) currentAppointmentHour
{
  return [NSString stringWithFormat: @"%.2d00", [currentTableHour intValue]];
}

- (NSString *) labelForDay
{
  return [NSString stringWithFormat: @"%@<br />%@",
                   [dateFormatter shortDayOfWeek: [currentTableDay dayOfWeek]],
                   [dateFormatter stringForObjectValue: currentTableDay]];
}

- (NSDictionary *) _adjustedAppointment: (NSDictionary *) anAppointment
                               forStart: (NSCalendarDate *) start
                                 andEnd: (NSCalendarDate *) end
{
  NSMutableDictionary *newMutableAppointment;
  NSDictionary *newAppointment;
  BOOL startIsEarlier, endIsLater;

  startIsEarlier
    = ([[anAppointment objectForKey: @"startDate"] laterDate: start] == start);
  endIsLater
    = ([[anAppointment objectForKey: @"endDate"] earlierDate: end] == end);

  if (startIsEarlier || endIsLater)
    {
      newMutableAppointment
        = [NSMutableDictionary dictionaryWithDictionary: anAppointment];
      
      if (startIsEarlier)
        [newMutableAppointment setObject: start
                               forKey: @"startDate"];
      if (endIsLater)
        [newMutableAppointment setObject: end
                               forKey: @"endDate"];

      newAppointment = newMutableAppointment;
    }
  else
    newAppointment = anAppointment;

  return newAppointment;
}

- (NSArray *) appointmentsForCurrentDay
{
  NSMutableArray *filteredAppointments;
  NSEnumerator *aptsEnumerator;
  NSDictionary *currentDayAppointment;
  NSCalendarDate *start, *end;
  int endHour;

  if (!allAppointments)
    {
      allAppointments = [self fetchCoreAppointmentsInfos];
      [allAppointments retain];
    }

  filteredAppointments = [NSMutableArray new];
  [filteredAppointments autorelease];

  start = [currentTableDay hour: [self dayStartHour] minute: 0];
  endHour = [self dayEndHour];
  if (endHour < 24)
    end = [currentTableDay hour: [self dayEndHour] minute: 59];
  else
    end = [[currentTableDay tomorrow] hour: 0 minute: 0];

  aptsEnumerator = [allAppointments objectEnumerator];
  currentDayAppointment = [aptsEnumerator nextObject];
  while (currentDayAppointment)
    {
      if (([end laterDate: [currentDayAppointment
                             valueForKey: @"startDate"]] == end)
          && ([start earlierDate: [currentDayAppointment
                                    valueForKey: @"endDate"]] == start))
        [filteredAppointments
          addObject: [self _adjustedAppointment: currentDayAppointment
                           forStart: start andEnd: end]];
      currentDayAppointment = [aptsEnumerator nextObject];
    }

  return filteredAppointments;
}

- (void) setCurrentAppointment: (NSDictionary *) newCurrentAppointment
{
  currentAppointment = newCurrentAppointment;
}

- (NSDictionary *) currentAppointment
{
  return currentAppointment;
}

- (NSString *) appointmentsClasses
{
  return [NSString stringWithFormat: @"appointments appointmentsFor%dDays",
                   numberOfDays];
}

- (NSString *) daysViewClasses
{
  return [NSString stringWithFormat: @"daysView daysViewFor%dDays", numberOfDays];
}

- (NSString *) dayClasses
{
  NSMutableString *classes;
  int dayOfWeek;

  classes = [NSMutableString new];
  [classes autorelease];
  [classes appendFormat: @"day day%d", [currentTableDay dayOfWeek]];
  if (numberOfDays > 1)
    {
      dayOfWeek = [currentTableDay dayOfWeek];
      if (dayOfWeek == 0 || dayOfWeek == 6)
        [classes appendString: @" weekEndDay"];
      if ([currentTableDay isToday])
        [classes appendString: @" dayOfToday"];
      if ([[self selectedDate] isDateOnSameDay: currentTableDay])
        [classes appendString: @" selectedDay"];
    }

  return classes;
}

- (NSString *) clickableHourCellClass
{
  return [NSString stringWithFormat: @"clickableHourCell clickableHourCell%@", currentTableHour];
}

@end
