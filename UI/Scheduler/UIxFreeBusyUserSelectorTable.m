/* UIxFreeBusyUserSelectorTable.m - this file is part of SOGo
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
#import <Foundation/NSValue.h>
#import <Foundation/NSString.h>

#import <NGCards/iCalPerson.h>
#import <NGExtensions/NSCalendarDate+misc.h>

#import <SoObjects/Appointments/SOGoFreeBusyObject.h>
#import <SoObjects/SOGo/NSCalendarDate+SOGo.h>
#import <SOGoUI/SOGoDateFormatter.h>

#import "UIxComponent+Agenor.h"
#import "UIxFreeBusyUserSelectorTable.h"

@implementation UIxFreeBusyUserSelectorTable

- (id) init
{
  if ((self = [super init]))
    {
      standAlone = NO;
      startDate = nil;
      endDate = nil;
      contacts = nil;
      hoursToDisplay = nil;
      daysToDisplay = nil;
      dateFormatter
        = [[SOGoDateFormatter alloc] initWithLocale: [self locale]];
    }

  return self;
}

- (void) dealloc
{
  [dateFormatter release];
  if (hoursToDisplay)
    [hoursToDisplay release];
  if (daysToDisplay)
    [daysToDisplay release];
  if (standAlone)
    {
      if (startDate)
        [startDate release];
      if (endDate)
        [endDate release];
      if (contacts)
        [contacts release];
    }
  [super dealloc];
}

- (void) setContacts: (NSArray *) newContacts
{
  contacts = newContacts;
}

- (NSArray *) contacts
{
  return contacts;
}

- (void) setStartDate: (NSCalendarDate *) newStartDate
{
  startDate = newStartDate;
  if (daysToDisplay)
    {
      [daysToDisplay release];
      daysToDisplay = nil;
    }
}

- (NSCalendarDate *) startDate
{
  return startDate;
}

- (void) setEndDate: (NSCalendarDate *) newEndDate
{
  endDate = newEndDate;
  if (daysToDisplay)
    {
      [daysToDisplay release];
      daysToDisplay = nil;
    }
}

- (NSCalendarDate *) endDate
{
  return endDate;
}

- (void) setDayStartHour: (NSNumber *) newDayStartHour
{
  dayStartHour = newDayStartHour;
  if (hoursToDisplay)
    {
      [hoursToDisplay release];
      hoursToDisplay = nil;
    }
}

- (NSNumber *) dayStartHour
{
  return dayStartHour;
}

- (void) setDayEndHour: (NSNumber *) newDayEndHour
{
  dayEndHour = newDayEndHour;
  if (hoursToDisplay)
    {
      [hoursToDisplay release];
      hoursToDisplay = nil;
    }
}

- (NSNumber *) dayEndHour
{
  return dayEndHour;
}

/* template operations */
- (NSArray *) daysToDisplay
{
  NSCalendarDate *currentDay, *finalDay;

  if (!daysToDisplay)
    {
      daysToDisplay = [NSMutableArray new];
      finalDay = [endDate dateByAddingYears: 0 months: 0 days: 2];
      currentDay = startDate;
      [daysToDisplay addObject: currentDay];
      while (![currentDay isDateOnSameDay: finalDay])
        {
          currentDay = [currentDay dateByAddingYears: 0
                                   months: 0
                                   days: 1];
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

- (void) setCurrentContact: (iCalPerson *) newCurrentContact
{
  currentContact = newCurrentContact;
}

- (iCalPerson *) currentContact
{
  return currentContact;
}

- (BOOL) currentContactHasStatus
{
  return ([currentContact participationStatus] != 0);
}

- (NSString *) currentContactStatusImage
{
  NSString *basename;

  basename = [[currentContact partStatWithDefault] lowercaseString];
                       
  return [self urlForResourceFilename: [NSString stringWithFormat: @"%@.png", basename]];;
}

- (NSString *) currentContactId
{
  return [currentContact cn];
}

- (NSString *) currentContactName
{
  return [currentContact cn];
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

/* as stand-alone component... */

- (id <WOActionResults>) defaultAction
{
  SOGoFreeBusyObject *co;
  NSString *queryParam;
  NSTimeZone *uTZ;

  co = [self clientObject];
  uTZ = [co userTimeZone];

  queryParam = [self queryParameterForKey: @"sday"];
  if ([queryParam length] > 0)
    {
      [self setStartDate: [NSCalendarDate dateFromShortDateString: queryParam
                                          andShortTimeString: @"0000"
                                          inTimeZone: uTZ]];
      [startDate retain];
    }
  queryParam = [self queryParameterForKey: @"eday"];
  if ([queryParam length] > 0)
    {
      [self setEndDate: [NSCalendarDate dateFromShortDateString: queryParam
                                        andShortTimeString: @"0000"
                                        inTimeZone: uTZ]];
      [endDate retain];
    }
  queryParam = [self queryParameterForKey: @"attendees"];
  if ([queryParam length] > 0)
    {
      [self setContacts: [self getICalPersonsFromValue: queryParam]];
      [contacts retain];
    }
  dayStartHour = [NSNumber numberWithInt: 8];
  dayEndHour = [NSNumber numberWithInt: 18];

  standAlone = YES;

  return self;
}

@end
