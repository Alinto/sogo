/* UIxCalMulticolumnDayView.h - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse inc.
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSCalendarDate+misc.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoDateFormatter.h>

#import "UIxCalMulticolumnDayView.h"

@implementation UIxCalMulticolumnDayView : UIxCalDayView

- (id) init
{
  if ((self = [super init]))
  {
    //       allAppointments = nil;
    subscriptionUsers = nil;
    hoursToDisplay = nil;
    currentTableUser = nil;
    currentTableHour = nil;
    //       dateFormatter = [[SOGoDateFormatter alloc]
    //                         initWithLocale: [self locale]];
  }
  
  return self;
}

- (void) dealloc
{
  //   [allAppointments release];
  [subscriptionUsers release];
  [hoursToDisplay release];
  //   [dateFormatter release];
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

- (NSArray *) subscriptionUsers
{
  SOGoUser *activeUser;
  NSString *userList, *currentUserLogin;
  NSEnumerator *users;

  if (!subscriptionUsers)
    {
      subscriptionUsers = [NSMutableArray new];
      activeUser = [context activeUser];
      userList = [[activeUser userDefaults] objectForKey: @"calendaruids"];
      users = [[userList componentsSeparatedByString: @","] objectEnumerator];
      currentUserLogin = [users nextObject];
      while (currentUserLogin)
        {
          if (![currentUserLogin hasPrefix: @"-"])
            [subscriptionUsers addObject: currentUserLogin];
          currentUserLogin = [users nextObject];
        }
    }

  return subscriptionUsers;
}

- (void) setCurrentTableUser: (NSString *) aTableUser;
{
  currentTableUser = aTableUser;
}

- (NSString *) currentTableUser;
{
  return currentTableUser;
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

/* fetching */

// - (NSArray *) appointmentsForCurrentUser
// {
//   NSMutableArray *filteredAppointments;
//   NSEnumerator *aptsEnumerator;
//   NSDictionary *userAppointment;
//   NSCalendarDate *start, *end;
//   int endHour;

//   if (!allAppointments)
//     {
//       allAppointments = [self fetchCoreAppointmentsInfos];
//       [allAppointments retain];
//     }

//   start = [[self selectedDate] hour: [self dayStartHour] minute: 0];
//   endHour = [self dayEndHour];
//   if (endHour < 24)
//     end = [[self selectedDate] hour: [self dayEndHour] minute: 59];
//   else
//     end = [[[self selectedDate] tomorrow] hour: 0 minute: 0];

//   filteredAppointments = [NSMutableArray new];
//   [filteredAppointments autorelease];

//   aptsEnumerator = [allAppointments objectEnumerator];
//   userAppointment = [aptsEnumerator nextObject];
//   while (userAppointment)
//     {
//       if ([[userAppointment objectForKey: @"owner"]
//             isEqualToString: currentTableUser])
//         [filteredAppointments
//           addObject: [self _adjustedAppointment: userAppointment
//                            forStart: start andEnd: end]];
//       userAppointment = [aptsEnumerator nextObject];
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

// - (NSString *) appointmentsClasses
// {
//   return @"appointments appointmentsFor1Days";
// }

- (NSString *) currentUserClasses
{
  NSArray *users;
  NSString *lastDayUser;

  users = [self subscriptionUsers];

  if (currentTableUser == [users lastObject])
    lastDayUser = @" lastDayUser";
  else
    lastDayUser = @"";
    
  return [NSString stringWithFormat: @"day appointmentsOf%@%@",
                   currentTableUser, lastDayUser];
}

- (NSString *) clickableHourCellClass
{
  return [NSString stringWithFormat: @"clickableHourCell clickableHourCell%@", currentTableHour];
}

- (NSNumber *) dayWidthPercentage
{
  NSArray *users;

  users = [self subscriptionUsers];

  return [NSNumber numberWithFloat: (100.0 / [users count])];
}

- (NSNumber *) currentTableUserDayLeftPercentage
{
  NSArray *users;

  users = [self subscriptionUsers];

  return [NSNumber numberWithFloat: ([users indexOfObject: currentTableUser]
                                     * (100.0 / [users count]))];
}

- (id <WOActionResults>) defaultAction
{
  [super setCurrentView: @"multicolumndayview"];
  
  return self;
}

@end
