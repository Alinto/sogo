/* UIxCalCalendarsListView.m - this file is part of SOGo
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <SOGo/AgenorUserManager.h>
#import <SOGo/SOGoUser.h>

#import "UIxCalCalendarsListView.h"

@implementation UIxCalCalendarsListView

- (id) init
{
  if ((self = [super init]))
    {
      contacts = nil;
      checkedContacts = nil;
      currentContactPerson = nil;
      colors = nil;
    }

  return self;
}

- (void) dealloc
{
  if (currentContactPerson)
    [currentContactPerson release];
  if (contacts)
    [contacts release];
  if (checkedContacts)
    [checkedContacts release];
  if (colors)
    [colors release];
  [super dealloc];
}

- (NSString *) _colorForNumber: (unsigned int) number
{
  unsigned int index, currentValue;
  unsigned char colorTable[] = { 1, 1, 1 };
  NSString *color;

  if (number == 0)
    color = @"#ccf";
  else if (number == NSNotFound)
    color = @"#f00";
  else
    {
      currentValue = number;
      index = 0;
      while (currentValue)
        {
          if (currentValue & 1)
            colorTable[index]++;
          if (index == 3)
            index = 0;
          currentValue >>= 1;
          index++;
        }
      color = [NSString stringWithFormat: @"#%2x%2x%2x",
                        (255 / colorTable[2]) - 1,
                        (255 / colorTable[1]) - 1,
                        (255 / colorTable[0]) - 1];
    }

  NSLog(@"color = '%@'", color);

  return color;
}

- (void) _addContactId: (NSString *) contactId
                withUm: (AgenorUserManager *) um
             andNumber: (unsigned int) count
{
  NSString *contactRealId;
  iCalPerson *currentContact;

  if ([contactId hasPrefix: @"-"])
    contactRealId = [contactId substringFromIndex: 1];
  else
    contactRealId = contactId;

  currentContact = [um iCalPersonWithUid: contactRealId];
  [contacts addObject: currentContact];
  if (contactId == contactRealId)
    [checkedContacts addObject: currentContact];
  [colors setObject: [self _colorForNumber: count]
          forKey: contactRealId];
}

- (void) _setupContacts
{
  SOGoUser *user;
  NSString *list, *currentId;
  NSEnumerator *rawContacts;
  AgenorUserManager *um;
  unsigned int count;

  contacts = [NSMutableArray new];
  checkedContacts = [NSMutableArray new];
  colors = [NSMutableDictionary new];

  um = [AgenorUserManager sharedUserManager];
  user = [context activeUser];
  list = [[user userDefaults] stringForKey: @"calendaruids"];
  if ([list length] == 0)
    list = [self shortUserNameForDisplay];

  rawContacts
    = [[list componentsSeparatedByString: @","] objectEnumerator];
  currentId = [rawContacts nextObject];
  count = 0;
  while (currentId)
    {
      [self _addContactId: currentId withUm: um andNumber: count];
      currentId = [rawContacts nextObject];
      count++;
    }
}

- (NSArray *) contacts
{
  if (!contacts)
    [self _setupContacts];

  return contacts;
}

- (NSArray *) checkedContacts
{
  if (!checkedContacts)
    [self _setupContacts];

  return checkedContacts;
}

- (void) setCurrentContactPerson: (iCalPerson *) contact
{
  if (currentContactPerson)
    [currentContactPerson release];
  currentContactPerson = contact;
  if (currentContactPerson)
    [currentContactPerson retain];
}

- (NSString *) currentContactLogin
{
  return [currentContactPerson cn];
}

- (NSString *) currentContactSpanBG
{
  return [colors objectForKey: [currentContactPerson cn]];
}

- (NSDictionary *) colors
{
  return colors;
}

@end
