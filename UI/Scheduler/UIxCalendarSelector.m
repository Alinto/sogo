/* UIxCalendarSelector.m - this file is part of SOGo
 *
 * Copyright (C) 2007, 2008 Inverse groupe conseil
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
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOResponse.h>

#import <SOGo/NSDictionary+Utilities.h>

#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>

#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoAppointmentFolders.h>

#import "UIxCalendarSelector.h"

@implementation UIxCalendarSelector

- (id) init
{
  if ((self = [super init]))
    {
      calendars = nil;
      currentCalendar = nil;
    }

  return self;
}

- (void) dealloc
{
  [calendars release];
  [currentCalendar release];
  [super dealloc];
}

- (NSArray *) calendars
{
  NSArray *folders, *roles;
  SOGoAppointmentFolders *co;
  SOGoAppointmentFolder *folder;
  NSMutableDictionary *calendar;
  unsigned int count, max;
  NSString *folderName, *fDisplayName;
  NSNumber *isActive;
  SOGoUser *user;

  if (!calendars)
    {
      co = [self clientObject];
      user = [[self context] activeUser];
      folders = [co subFolders];
      max = [folders count];
      calendars = [[NSMutableArray alloc] initWithCapacity: max];
      for (count = 0; count < max; count++)
	{
	  folder = [folders objectAtIndex: count];
	  roles = [user rolesForObject: folder inContext: [self context]];
	  calendar = [NSMutableDictionary dictionary];
	  folderName = [folder nameInContainer];
	  fDisplayName = [folder displayName];
	  if ([fDisplayName isEqualToString: [co defaultFolderName]])
	    fDisplayName = [self labelForKey: fDisplayName];
	  [calendar setObject: [NSString stringWithFormat: @"/%@", folderName]
		    forKey: @"id"];
	  [calendar setObject: fDisplayName forKey: @"displayName"];
	  [calendar setObject: folderName forKey: @"folder"];
	  [calendar setObject: [folder calendarColor]
		    forKey: @"color"];
	  isActive = [NSNumber numberWithBool: [folder isActive]];
	  [calendar setObject: isActive forKey: @"active"];
	  [calendar setObject: [folder ownerInContext: context]
		    forKey: @"owner"];
	  [calendar setObject: [roles componentsJoinedByString: @","]
		    forKey: @"roles"];
	  [calendars addObject: calendar];
	}
    }

  return calendars;
}

- (void) setCurrentCalendar: (NSDictionary *) newCalendar
{
  ASSIGN (currentCalendar, newCalendar);
}

- (NSDictionary *) currentCalendar
{
  return currentCalendar;
}

- (NSString *) currentCalendarClass
{
  return [currentCalendar
	   keysWithFormat: @"colorBox calendarFolder%{folder}"];
}

- (NSString *) currentCalendarStyle
{
  return [currentCalendar
	   keysWithFormat: @"color: %{color}; background-color: %{color};"];
}

- (WOResponse *) calendarsListAction
{
  WOResponse *response;

  response = [self responseWithStatus: 200];
  [response setHeader: @"text/plain; charset=utf-8"
	    forKey: @"content-type"];
  [response appendContentString: [[self calendars] jsonRepresentation]];

  return response;
}

@end /* UIxCalendarSelector */
