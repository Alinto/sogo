/* UIxFreeBusyUserSelector.m - this file is part of SOGo
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
#import <Foundation/NSValue.h>

#import <NGExtensions/NSCalendarDate+misc.h>

#import <SOGoUI/SOGoDateFormatter.h>

#import "UIxFreeBusyUserSelector.h"

@implementation UIxFreeBusyUserSelector

- (id) init
{
  if ((self = [super init]))
    {
      startDate = [NSCalendarDate calendarDate];
      [startDate retain];
      endDate = [NSCalendarDate calendarDate];
      [endDate retain];
      dayStartHour = [NSNumber numberWithInt: 8];
      [dayStartHour retain];
      dayEndHour = [NSNumber numberWithInt: 18];
      [dayEndHour retain];
      daysToDisplay = nil;
      hoursToDisplay = nil;
      dateFormatter = [[SOGoDateFormatter alloc]
                        initWithLocale: [self locale]];
    }

  return self;
}

- (void) dealloc
{
  [startDate release];
  [endDate release];
  [dayStartHour release];
  [dayEndHour release];
  if (daysToDisplay)
    [daysToDisplay release];
  if (hoursToDisplay)
    [hoursToDisplay release];
  [dateFormatter release];
  [super dealloc];
}

- (void) setStartDate: (NSCalendarDate *) newStartDate
{
  ASSIGN (startDate, newStartDate);
#warning The following code is hackish and should not be shown to children < 18.
  if (daysToDisplay)
    {
      [daysToDisplay release];
      daysToDisplay = nil;
    }
}

- (void) setEndDate: (NSCalendarDate *) newEndDate
{
  ASSIGN (endDate, newEndDate);
  if (daysToDisplay)
    {
      [daysToDisplay release];
      daysToDisplay = nil;
    }
}

- (void) setDayStartHour: (NSNumber *) newDayStartHour
{
  ASSIGN (dayStartHour, newDayStartHour);
}

- (void) setDayEndHour: (NSNumber *) newDayEndHour
{
  ASSIGN (dayEndHour, newDayEndHour);
}

/* in-template operations */
- (NSArray *) daysToDisplay
{
  NSCalendarDate *currentDay, *finalDay;

  if (!daysToDisplay)
    {
      daysToDisplay = [NSMutableArray new];
      finalDay = [endDate  dateByAddingYears: 0 months: 0 days: 2];
      currentDay = startDate;
      [daysToDisplay addObject: currentDay];
      while (![currentDay isDateOnSameDay: finalDay])
        {
          currentDay = [currentDay dateByAddingYears: 0 months: 0 days: 1];
          [daysToDisplay addObject: currentDay];
        }
    }

  return daysToDisplay;
}

- (NSArray *) hoursToDisplay
{
  NSNumber *currentHour;

  if (!hoursToDisplay)
    {
      hoursToDisplay = [NSMutableArray new];
      currentHour = dayStartHour;
      [hoursToDisplay addObject: currentHour];
      while (![currentHour isEqual: dayEndHour])
        {
          currentHour = [NSNumber numberWithInt: [currentHour intValue] + 1];
          [hoursToDisplay addObject: currentHour];
        }
    }

  return hoursToDisplay;
}

- (void) setCurrentDayToDisplay: (NSCalendarDate *) newCurrentDayToDisplay
{
  currentDayToDisplay = newCurrentDayToDisplay;
}

- (void) setCurrentHourToDisplay: (NSNumber *) newCurrentHourToDisplay
{
  currentHourToDisplay = newCurrentHourToDisplay;
}

- (NSCalendarDate *) currentDayToDisplay
{
  return currentDayToDisplay;
}

- (NSNumber *) currentHourToDisplay
{
  return currentHourToDisplay;
}

- (NSString *) currentFormattedDay
{
  return [NSString stringWithFormat: @"%@, %.4d-%.2d-%.2d",
                   [dateFormatter shortDayOfWeek: [currentDayToDisplay dayOfWeek]],
                   [currentDayToDisplay yearOfCommonEra],
                   [currentDayToDisplay monthOfYear],
                   [currentDayToDisplay dayOfMonth]];
}

@end
