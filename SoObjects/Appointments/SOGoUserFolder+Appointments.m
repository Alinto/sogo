/* SOGoUserFolder+Appointments.m - this file is part of SOGo
 *
 * Copyright (C) 2008 Inverse groupe conseil
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
#import <NGObjWeb/WOContext+SoObjects.h>

#import <SOGo/SOGoUser.h>

#import "SOGoUserFolder+Appointments.h"

@implementation SOGoUserFolder (SOGoCalDAVSupport)

- (NSArray *) davCalendarUserAddressSet
{
  NSArray *tag, *allEmails;
  NSMutableArray *addresses;
  NSEnumerator *emails;
  NSString *currentEmail;

  addresses = [NSMutableArray array];

  allEmails = [[context activeUser] allEmails];
  emails = [allEmails objectEnumerator];
  while ((currentEmail = [emails nextObject]))
    {
      tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
		     [NSString stringWithFormat: @"MAILTO:%@", currentEmail],
		     nil];
      [addresses addObject: tag];
    }

  return addresses;
}

/* CalDAV support */
- (NSArray *) davCalendarHomeSet
{
  /*
    <C:calendar-home-set xmlns:D="DAV:"
        xmlns:C="urn:ietf:params:xml:ns:caldav">
      <D:href>http://cal.example.com/home/bernard/calendars/</D:href>
    </C:calendar-home-set>

    Note: this is the *container* for calendar collections, not the
          collections itself. So for use its the home folder, the
	  public folder and the groups folder.
  */
  NSArray *tag;
  SOGoAppointmentFolders *parent;

  parent = [self privateCalendars: @"Calendar" inContext: context];
  tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
                 [[parent davURL] path], nil];

  return [NSArray arrayWithObject: tag];
}

- (NSArray *) davCalendarScheduleInboxURL
{
  NSArray *tag;
  SOGoAppointmentFolders *parent;

  parent = [self privateCalendars: @"Calendar" inContext: context];
  tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
                 [NSString stringWithFormat: @"%@personal/", [[parent davURL] path]],
		 nil];

  return [NSArray arrayWithObject: tag];
}

- (NSString *) davCalendarScheduleOutboxURL
{
  NSArray *tag;
  SOGoAppointmentFolders *parent;

  parent = [self privateCalendars: @"Calendar" inContext: context];
  tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
                 [NSString stringWithFormat: @"%@personal/", [[parent davURL] path]],
		 nil];

  return [NSArray arrayWithObject: tag];
}

- (NSString *) davDropboxHomeURL
{
  NSArray *tag;
  SOGoAppointmentFolders *parent;

  parent = [self privateCalendars: @"Calendar" inContext: context];
  tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
                 [NSString stringWithFormat: @"%@personal/", [[parent davURL] path]],
		 nil];

  return [NSArray arrayWithObject: tag];
}

- (NSString *) davNotificationsURL
{
  NSArray *tag;
  SOGoAppointmentFolders *parent;

  parent = [self privateCalendars: @"Calendar" inContext: context];
  tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
                 [NSString stringWithFormat: @"%@personal/", [[parent davURL] path]],
		 nil];

  return [NSArray arrayWithObject: tag];
}

@end
