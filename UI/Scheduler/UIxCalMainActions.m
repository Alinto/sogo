/* UIxCalMainActions.m - this file is part of SOGo
 *
 * Copyright (C) 2009 Inverse inc.
 *
 * Author: Cyril Robert <crobert@inverse.ca>
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

#import <Foundation/Foundation.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <Appointments/SOGoWebAppointmentFolder.h>
#import <Appointments/SOGoAppointmentFolders.h>

#import "UIxCalMainActions.h"

@implementation UIxCalMainActions

- (NSString *) displayNameForUrl: (NSString *) calendarURL
{
  NSString *rc, *tmp;

  tmp = [calendarURL lastPathComponent];
  if (tmp)
    {
      if ([[tmp pathExtension] caseInsensitiveCompare: @"ics"] == NSOrderedSame)
	rc = [tmp substringToIndex: [tmp length] - 4];
      else
	rc = tmp;
    }
  else
    rc = [self labelForKey: @"Web Calendar"];

  return rc;
}

- (WOResponse *) addWebCalendarAction
{
  WORequest *r;
  WOResponse *response;
  SOGoWebAppointmentFolder *folder;
  NSURL *url;
  NSString *urlString, *displayName;
  NSMutableDictionary *rc;
  SOGoAppointmentFolders *folders;
  int imported = 0;

  r = [context request];
  rc = [NSMutableDictionary dictionary];

  // Just a check
  urlString = [r formValueForKey: @"url"];
  url = [NSURL URLWithString: urlString];
  if (url)
    {
      folders = [self clientObject];
      displayName = [self displayNameForUrl: [r formValueForKey: @"url"]];
      folder = [folders newWebCalendarWithName: displayName
                                         atURL: urlString];
      if (folder)
        {
          imported = [folder loadWebCalendar];
          if (imported >= 0)
            {
              [rc setObject: displayName forKey: @"displayname"];
              [rc setObject: [folder nameInContainer] forKey: @"name"];
            }
          else
            {
              [folder delete];
            }
          [rc setObject: [NSNumber numberWithInt: imported] 
                 forKey: @"imported"];
        }
    }
  
  response = [self responseWithStatus: 200];
  [response appendContentString: [rc jsonRepresentation]];
  return response;
}

- (WOResponse *) reloadWebCalendarsAction
{
  [[self clientObject] reloadWebCalendars: YES];

  return [self responseWith204];
}

//
// The method below is different than the -reloadWebCalendarsAction as it
// won't force the reload of all calendars and automatically redirect the
// user to the /SOGo/so page upon completion.
//
// This is particularly useful for WebAuth users and they won't have a
// precise "entry point" in SOGo - so calendars reload upon login
// isn't possible for them.
//
- (WOResponse *) reloadWebCalendarsAndRedirectAction
{
  [[self clientObject] reloadWebCalendars: NO];

  return [self redirectToLocation: @"/SOGo/so"];
}


@end
