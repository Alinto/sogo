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
}

- (void) setStartDate: (NSCalendarDate *) aStartDate
{
  startDate = aStartDate;
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
      hoursToDisplay
        = [NSMutableArray arrayWithCapacity: (lastHour - currentHour)];

      while (currentHour < lastHour)
        {
          [hoursToDisplay
            addObject: [NSString stringWithFormat: @"%d", currentHour]];
          currentHour++;
        }
    }

  return hoursToDisplay;
}

- (NSArray *) daysToDisplay
{
  NSMutableArray *days;
  NSCalendarDate *currentDate;
  int count;

  days = [NSMutableArray arrayWithCapacity: numberOfDays];
  currentDate = [[self startDate] hour: [currentTableHour intValue]
                                  minute: 0];
  [days addObject: currentDate];
  for (count = 1; count < numberOfDays; count++)
    {
      currentDate = [currentDate dateByAddingYears: 0
                                 months: 0
                                 days: 1];
      [days addObject: currentDate];
    }

  return days;
}

- (void) setCurrentTableDay: (NSCalendarDate *) aTableDay
{
  currentTableDay = aTableDay;
}

- (NSCalendarDate *) currentTableDay
{
  return currentTableDay;
}

- (NSString *) dayCellClasses
{
  NSMutableString *classes;
  int dayOfWeek;

  classes = [NSMutableString new];
  [classes autorelease];
  [classes appendString: @"contentOfDay"];
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
  return [NSString stringWithFormat: @"%@ %@",
                   [dateFormatter shortDayOfWeek: [currentTableDay dayOfWeek]],
                   [dateFormatter stringForObjectValue: currentTableDay]];
}

- (NSArray *) aptsForCurrentDate
{
  NSArray        *apts;
  NSMutableArray *filtered;
  unsigned       i, count;
  NSCalendarDate *start, *end;
  SOGoAppointment *apt;
  NSCalendarDate *aptStartDate;

  start = currentTableDay;
  end = [start dateByAddingYears: 0 months: 0 days: 0
               hours: 0 minutes: 59 seconds: 59];

  apts = [self fetchCoreAppointmentsInfos];
  filtered = [NSMutableArray new];
  [filtered autorelease];

  count    = [apts count];
  for (i = 0; i < count; i++)
    {
      apt = [apts objectAtIndex:i];
      aptStartDate = [apt valueForKey:@"startDate"];
      if ([aptStartDate isGreaterThanOrEqualTo: start]
          && [aptStartDate isLessThan: end])
        [filtered addObject:apt];
    }

  return filtered;
}

@end
