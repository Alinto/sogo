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

#import <NGCards/iCalPerson.h>
#import <NGObjWeb/WORequest.h>

#import <SoObjects/SOGo/AgenorUserManager.h>

#import "UIxComponent+Agenor.h"
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
    }

  return self;
}

- (void) dealloc
{
  [dayStartHour release];
  [dayEndHour release];
  if (contacts)
    [contacts release];
  if (selectorId)
    [selectorId release];
  [super dealloc];
}

- (void) setStartDate: (NSCalendarDate *) newStartDate
{
  startDate = newStartDate;
}

- (NSCalendarDate *) startDate
{
  return startDate;
}

- (void) setEndDate: (NSCalendarDate *) newEndDate
{
  endDate = newEndDate;
}

- (NSCalendarDate *) endDate
{
  return endDate;
}

- (void) setDayStartHour: (NSNumber *) newDayStartHour
{
  ASSIGN (dayStartHour, newDayStartHour);
}

- (NSNumber *) dayStartHour
{
  return dayStartHour;
}

- (void) setDayEndHour: (NSNumber *) newDayEndHour
{
  ASSIGN (dayEndHour, newDayEndHour);
}

- (NSNumber *) dayEndHour
{
  return dayEndHour;
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

- (NSString *) freeBusyViewId
{
  return [NSString stringWithFormat: @"parentOf%@", [selectorId capitalizedString]];
}
 
@end
