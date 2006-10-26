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
#import <NGCards/iCalPerson.h>
#import <NGObjWeb/WORequest.h>

#import <SOGoUI/SOGoDateFormatter.h>
#import <SoObjects/SOGo/AgenorUserManager.h>

#import "UIxFreeBusyUserSelector.h"

@implementation UIxFreeBusyUserSelector

- (id) init
{
  if ((self = [super init]))
    {
      startDate = nil;
      endDate = nil;
      dayStartHour = [NSNumber numberWithInt: 8];
      [dayStartHour retain];
      dayEndHour = [NSNumber numberWithInt: 18];
      [dayEndHour retain];
      contacts = nil;
      selectorId = nil;
      daysToDisplay = nil;
      hoursToDisplay = nil;
      dateFormatter = [[SOGoDateFormatter alloc]
                        initWithLocale: [self locale]];
    }

  return self;
}

- (void) dealloc
{
  [dayStartHour release];
  [dayEndHour release];
  if (daysToDisplay)
    [daysToDisplay release];
  if (hoursToDisplay)
    [hoursToDisplay release];
  if (contacts)
    [contacts release];
  if (selectorId)
    [selectorId release];
  [dateFormatter release];
  [super dealloc];
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
  ASSIGN (dayStartHour, newDayStartHour);
}

- (void) setDayEndHour: (NSNumber *) newDayEndHour
{
  ASSIGN (dayEndHour, newDayEndHour);
}

- (void) setSelectorId: (NSString *) newSelectorId
{
  ASSIGN (selectorId, newSelectorId);
}

- (NSString *) selectorId
{
  return selectorId;
}

- (void) setContacts: (NSArray *) newContacts
{
  ASSIGN (contacts, newContacts);
}

- (NSArray *) contacts
{
  return contacts;
}

/* callbacks */
- (NSArray *) getICalPersonsFromValue: (NSString *) selectorValue
{
  NSMutableArray *persons;
  NSEnumerator *uids;
  NSString *uid;
  AgenorUserManager *um;

  um = [AgenorUserManager sharedUserManager];

  persons = [NSMutableArray new];
  [persons autorelease];

  if ([selectorValue length] > 0)
    {
      uids = [[selectorValue componentsSeparatedByString: @","]
               objectEnumerator];
      uid = [uids nextObject];
      while (uid)
        {
          [persons addObject: [um iCalPersonWithUid: uid]];
          uid = [uids nextObject];
        }
    }

  return persons;
}

- (void) takeValuesFromRequest: (WORequest *) request
                     inContext: (WOContext *) context
{
  NSArray *newContacts;

  newContacts
    = [self getICalPersonsFromValue: [request formValueForKey: selectorId]];
  ASSIGN (contacts, newContacts);
  if ([contacts count] > 0)
    NSLog (@"got %i attendees: %@", [contacts count], contacts);
  else
    NSLog (@"got no attendees!");
}

/* in-template operations */
- (NSString *) initialContactsAsString
{
  NSEnumerator *persons;
  iCalPerson *person;
  NSMutableArray *participants;

  participants = [NSMutableArray arrayWithCapacity: [contacts count]];
  persons = [contacts objectEnumerator];
  person = [persons nextObject];
  while (person)
    {
      [participants addObject: [person cn]];
      person = [persons nextObject];
    }

  return [participants componentsJoinedByString: @","];
}

- (void) setCurrentContact: (iCalPerson *) newCurrentContact
{
  currentContact = newCurrentContact;
}

- (iCalPerson *) currentContact
{
  return currentContact;
}

- (NSString *) currentContactId
{
  return [currentContact cn];
}

- (NSString *) currentContactName
{
  return [currentContact cn];
}

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
