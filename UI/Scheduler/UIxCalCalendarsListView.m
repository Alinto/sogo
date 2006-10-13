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
    }

  return self;
}

- (void) _setupContacts
{
  AgenorUserManager *um;
  SOGoUser *user;
  NSString *list, *currentId;
  NSEnumerator *rawContacts;
  iCalPerson *currentContact;

  contacts = [NSMutableArray array];
  checkedContacts = [NSMutableArray array];

  um = [AgenorUserManager sharedUserManager];
  user = [context activeUser];
  list = [[user userDefaults] stringForKey: @"calendaruids"];
  if ([list length] == 0)
    list = [self shortUserNameForDisplay];

  rawContacts
    = [[list componentsSeparatedByString: @","] objectEnumerator];
  currentId = [rawContacts nextObject];
  while (currentId)
    {
      if ([currentId hasPrefix: @"-"])
        currentContact
          = [um iCalPersonWithUid: [currentId substringFromIndex: 1]];
      else
        {
          currentContact = [um iCalPersonWithUid: currentId];
          [checkedContacts addObject: currentContact];
        }
      [contacts addObject: currentContact];
      currentId = [rawContacts nextObject];
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

@end
