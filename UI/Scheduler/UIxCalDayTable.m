/* UIxCalDayTable.m - this file is part of SOGo
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSUserDefaults.h> /* for locale string constants */
#import <Foundation/NSValue.h>

#import <NGExtensions/NSCalendarDate+misc.h>

#import <SOPE/NGCards/iCalRecurrenceRule.h>

#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/SOGoDateFormatter.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/WOResourceManager+SOGo.h>

#import <SoObjects/Appointments/SOGoAppointmentFolder.h>
#import <SoObjects/Appointments/SOGoAppointmentFolders.h>

#import "UIxCalDayTable.h"

@class SOGoAppointment;

@implementation UIxCalDayTable

- (id) init
{
  SOGoUser *user;
  SOGoUserDefaults *ud;

  if ((self = [super init]))
    {
      user = [context activeUser];
      ud = [user userDefaults];
      ASSIGN (timeFormat, [ud timeFormat]);

      daysToDisplay = nil;
      calendarsToDisplay = nil;
      hoursToDisplay = nil;
      numberOfDays = 1;
      startDate = nil;
      currentView = nil;
      currentCalendar = nil;
      currentTableDay = nil;
      currentTableHour = nil;
      weekDays = [locale objectForKey: NSWeekDayNameArray];
      [weekDays retain];
      dateFormatter = [user dateFormatterInContext: context];
      [dateFormatter retain];
    }

  return self;
}

- (void) dealloc
{
//   if (allAppointments)
//     [allAppointments release];
  [weekDays release];
  [daysToDisplay release];
  [calendarsToDisplay release];
  [currentView release];
  [hoursToDisplay release];
  [dateFormatter release];
  [timeFormat release];
  free(daysNumbersToDisplay);
  [super dealloc];
}

- (void) setNumberOfDays: (NSNumber *) aNumber
{
  numberOfDays = [aNumber intValue];
  [daysToDisplay release];
  daysToDisplay = nil;
}

- (NSNumber *) numberOfDays
{
  return [NSNumber numberWithUnsignedInt: numberOfDays];
}

- (void) setStartDate: (NSCalendarDate *) aStartDate
{
  startDate = [aStartDate beginOfDay];
  [daysToDisplay release];
  daysToDisplay = nil;
}

- (NSCalendarDate *) startDate
{
  if (!startDate)
    startDate = [[super startDate] beginOfDay];

  return startDate;
}

- (NSCalendarDate *) endDate
{
  NSCalendarDate *endDate;

  endDate = [[self startDate] dateByAddingYears: 0
                              months: 0
                              days: numberOfDays - 1];

  return [endDate endOfDay];
}

- (void) setCurrentView: (NSString *) aView
{
  ASSIGN(currentView, aView);
}

- (NSString *) currentView
{
  return currentView;
}

- (NSArray *) hoursToDisplay
{
  unsigned int currentHour, lastHour;

  if (!hoursToDisplay)
    {
      hoursToDisplay = [NSMutableArray new];
      currentHour = [self dayStartHour];
      lastHour = [self dayEndHour];
      while (currentHour < lastHour)
        {
          [hoursToDisplay addObject: [NSNumber numberWithInt: currentHour]];
          currentHour++;
        }
      [hoursToDisplay addObject: [NSNumber numberWithInt: currentHour]];
    }

  return hoursToDisplay;
}

- (NSString *) currentHourId
{
  return [NSString stringWithFormat: @"hour%d", [currentTableHour intValue]];
}

/**
 * Return an array of NSCalendarDate instances matching the requested time period
 * and the week days enabled in the user's defaults.
 */
- (NSArray *) daysToDisplay
{
  NSCalendarDate *currentDate;
  NSString *weekDay;
  int count, enabledCount;

  if (!daysToDisplay)
  {
    daysToDisplay = [NSMutableArray new];
    daysNumbersToDisplay = malloc (numberOfDays * sizeof (unsigned int));
    currentDate = [[self startDate] hour: [self dayStartHour]
                                  minute: 0];

    for (count = 0, enabledCount = 0; count < numberOfDays; count++)
    {
      weekDay = iCalWeekDayString[[currentDate dayOfWeek]];
      if ([enabledWeekDays count] == 0 || [enabledWeekDays containsObject: weekDay])
        {
          [daysToDisplay addObject: currentDate];
          daysNumbersToDisplay[enabledCount] = count;
          enabledCount++;
        }
      currentDate = [currentDate tomorrow];
    }
  }

  return daysToDisplay;
}

- (NSArray *) calendarsToDisplay
{
  if (!calendarsToDisplay)
  {
    NSArray *folders;
    SOGoAppointmentFolders *co;
    SOGoAppointmentFolder *folder;
    NSMutableDictionary *calendar;
    unsigned int count, foldersCount;
    NSString *folderName, *fDisplayName;
    BOOL isActive;

    co = [self clientObject];
    folders = [co subFolders];
    foldersCount = [folders count];
    calendarsToDisplay = [[NSMutableArray alloc] initWithCapacity: foldersCount];
    for (count = 0; count < foldersCount; count++)
    {
      folder = [folders objectAtIndex: count];
      isActive = [folder isActive];
      if (isActive != NO) {
        calendar = [NSMutableDictionary dictionary];
        folderName = [folder nameInContainer];
        fDisplayName = [folder displayName];
        if (fDisplayName == nil)
          fDisplayName = @"";
        if ([fDisplayName isEqualToString: [co defaultFolderName]])
          fDisplayName = [self labelForKey: fDisplayName];
        [calendar setObject: [NSString stringWithFormat: @"/%@", folderName]
                     forKey: @"id"];
        [calendar setObject: fDisplayName forKey: @"displayName"];
        [calendar setObject: folderName forKey: @"folder"];
        [calendar setObject: [folder calendarColor] forKey: @"color"];
        [calendar setObject: [NSNumber numberWithBool:isActive] forKey: @"active"];
        [calendar setObject: [folder ownerInContext: context]
                     forKey: @"owner"];
        [calendarsToDisplay addObject: calendar];
      }
    }
  }

  return calendarsToDisplay;
}

- (void) setCurrentTableDay: (NSCalendarDate *) aTableDay
{
  currentTableDay = aTableDay;
}

- (NSCalendarDate *) currentTableDay
{
  return currentTableDay;
}

- (void) setCurrentCalendar: (NSMutableDictionary *) aCalendar
{
  ASSIGN(currentCalendar, aCalendar);
}

- (NSMutableDictionary *) currentCalendar
{
  return currentCalendar;
}

- (void) setCurrentTableHour: (NSNumber *) aTableHour
{
  ASSIGN(currentTableHour, aTableHour);
}

- (NSNumber *) currentTableHour
{
  return currentTableHour;
}

- (NSString *) currentFormattedHour
{
  int hour;
  NSCalendarDate *tmp;
  NSString *formatted = [NSString stringWithFormat: @"%d", [currentTableHour intValue]], *parse;

  hour = [currentTableHour intValue];
  parse = [NSString stringWithFormat: @"2000-01-01 %02d:00", hour];

  tmp = [NSCalendarDate dateWithString: parse
                        calendarFormat: @"%Y-%m-%d %H:%M"];
  if (tmp)
    formatted = [tmp descriptionWithCalendarFormat: timeFormat
                                            locale: locale];

  return formatted;
}

- (NSString *) currentAllDayId
{
  return [NSString stringWithFormat: @"allDay%@", [currentTableDay shortDateString]];
}

- (NSString *) currentDayId
{
  return [NSString stringWithFormat: @"day%@", [currentTableDay shortDateString]];
}

- (int) currentDayNumber
{
  int i = [daysToDisplay indexOfObject: currentTableDay];

  return daysNumbersToDisplay[i];
}

- (NSNumber *) currentAppointmentHour
{
  return [NSNumber numberWithInt: [currentTableHour intValue]];
}

- (NSString *) currentYear
{
  if (([currentTableDay dayOfMonth] == 1 && [currentTableDay monthOfYear] == 1) ||
      [daysToDisplay indexOfObject: currentTableDay] == 0)
    return [NSString stringWithFormat: @"%i", [currentTableDay yearOfCommonEra]];

  return nil;
}

- (NSString *) labelForDay
{
  return [weekDays objectAtIndex: [currentTableDay dayOfWeek]];
}

- (NSString *) labelForMonth
{
  NSString *calendarFormat;
  BOOL isFirstDay;

  isFirstDay = NO;
  calendarFormat = @"%b";

  if ([currentView hasSuffix: @"dayview"])
    {
      isFirstDay = YES;
      calendarFormat = @"%B";
    }
  else if ([currentTableDay dayOfMonth] == 1 || [daysToDisplay indexOfObject: currentTableDay] == 0)
    {
      isFirstDay = YES;
    }

  return isFirstDay? [currentTableDay descriptionWithCalendarFormat: calendarFormat locale: locale] : nil;
}

- (NSString *) labelForDate
{
  return [dateFormatter shortFormattedDate: currentTableDay];
}

- (NSString *) labelForCalendar
{
  return [currentCalendar objectForKey: @"displayName"];
}

- (NSString *) colorForCalendar
{
  return [currentCalendar objectForKey:@"color"];
}

// - (NSDictionary *) _adjustedAppointment: (NSDictionary *) anAppointment
//                                forStart: (NSCalendarDate *) start
//                                  andEnd: (NSCalendarDate *) end
// {
//   NSMutableDictionary *newMutableAppointment;
//   NSDictionary *newAppointment;
//   BOOL startIsEarlier, endIsLater;

//   startIsEarlier
//     = ([[anAppointment objectForKey: @"startDate"] laterDate: start] == start);
//   endIsLater
//     = ([[anAppointment objectForKey: @"endDate"] earlierDate: end] == end);

//   if (startIsEarlier || endIsLater)
//     {
//       newMutableAppointment
//         = [NSMutableDictionary dictionaryWithDictionary: anAppointment];

//       if (startIsEarlier)
//         [newMutableAppointment setObject: start
//                                forKey: @"startDate"];
//       if (endIsLater)
//         [newMutableAppointment setObject: end
//                                forKey: @"endDate"];

//       newAppointment = newMutableAppointment;
//     }
//   else
//     newAppointment = anAppointment;

//   return newAppointment;
// }

// - (NSArray *) appointmentsForCurrentDay
// {
//   NSMutableArray *filteredAppointments;
//   NSEnumerator *aptsEnumerator;
//   NSDictionary *currentDayAppointment;
//   NSCalendarDate *start, *end;
//   int endHour;

//   if (!allAppointments)
//     {
//       allAppointments = [self fetchCoreAppointmentsInfos];
//       [allAppointments retain];
//     }

//   filteredAppointments = [NSMutableArray new];
//   [filteredAppointments autorelease];

//   start = [currentTableDay hour: [self dayStartHour] minute: 0];
//   endHour = [self dayEndHour];
//   if (endHour < 24)
//     end = [currentTableDay hour: [self dayEndHour] minute: 59];
//   else
//     end = [[currentTableDay tomorrow] hour: 0 minute: 0];

//   aptsEnumerator = [allAppointments objectEnumerator];
//   currentDayAppointment = [aptsEnumerator nextObject];
//   while (currentDayAppointment)
//     {
//       if (([end laterDate: [currentDayAppointment
//                              valueForKey: @"startDate"]] == end)
//           && ([start earlierDate: [currentDayAppointment
//                                     valueForKey: @"endDate"]] == start))
//         [filteredAppointments
//           addObject: [self _adjustedAppointment: currentDayAppointment
//                            forStart: start andEnd: end]];
//       currentDayAppointment = [aptsEnumerator nextObject];
//     }

//   return filteredAppointments;
// }

// - (void) setCurrentAppointment: (NSDictionary *) newCurrentAppointment
// {
//   currentAppointment = newCurrentAppointment;
// }

// - (NSDictionary *) currentAppointment
// {
//   return currentAppointment;
// }

- (NSString *) appointmentsClasses
{
  return [NSString stringWithFormat: @"appointments appointmentsFor%dDays",
                   numberOfDays];
}

// - (NSString *) daysViewClasses
// {
//   NSString *daysView;

//   if ([currentView isEqualToString:@"multicolumndayview"])
//     daysView = @"daysView daysViewForMultipleDays";

//   else
//     daysView = [NSString stringWithFormat: @"daysView daysViewFor%dDays", numberOfDays];

//   return daysView;
//}

// - (NSString *) daysViewHeaderClasses
// {
//   return [NSString stringWithFormat: @"%@ daysHeader", [self daysViewClasses]];
// }

- (NSString *) dayClasses
{
  NSMutableString *classes;
  unsigned int realDayOfWeek;

  classes = [NSMutableString stringWithString: @"day"];
  realDayOfWeek = [currentTableDay dayOfWeek];

  if (numberOfDays > 1)
    {
      if (realDayOfWeek == 0 || realDayOfWeek == 6)
        [classes appendString: @" weekEndDay"];
      if ([currentTableDay isToday])
        [classes appendString: @" dayOfToday"];
    }

  return classes;
}

- (NSString *) clickableHourCellClass
{
  NSMutableString *cellClass;
  int hour;
  SOGoUserDefaults *ud;

  cellClass = [NSMutableString string];
  hour = [currentTableHour intValue];
  ud = [[context activeUser] userDefaults];
  [cellClass appendFormat: @"clickableHourCell clickableHourCell%d", hour];
  if (hour < [ud dayStartHour] || hour > [ud dayEndHour] - 1)
    [cellClass appendString: @" outOfDay"];

  return cellClass;
}

- (BOOL) isMultiColumnView
{
  if ([currentView isEqualToString:@"multicolumndayview"])
    return YES;

  return NO;
}

- (BOOL) isNotMultiColumnView
{
  if ([currentView isEqualToString:@"dayview"] || [currentView isEqualToString:@"weekview"])
    return YES;

  return NO;
}

- (BOOL) isWeekView
{
  return [currentView isEqualToString:@"weekview"];
}

@end
