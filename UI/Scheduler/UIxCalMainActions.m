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

#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/NSDictionary+Utilities.h>
#import <SoObjects/Appointments/SOGoWebAppointmentFolder.h>
#import <SoObjects/Appointments/SOGoAppointmentFolders.h>

#import "UIxCalMainActions.h"

@implementation UIxCalMainActions

- (WOResponse *) addWebCalendarAction
{
  WORequest *r;
  WOResponse *response;
  SOGoWebAppointmentFolder *folder;
  NSURL *url;
  NSString *name;
  NSMutableDictionary *rc;
  int imported = 0;

  r = [context request];
  rc = [NSMutableDictionary dictionary];

  // Just a check
  url = [NSURL URLWithString: [r formValueForKey: @"url"]];
  if (url)
    {
      [[self clientObject] newFolderWithName: @"Web Calendar"
                             nameInContainer: &name];
      [self saveUrl: url forCalendar: name];
      folder = [[self clientObject] lookupName: name
                                     inContext: context
                                       acquire: NO];
      if (folder)
        {
          imported = [folder loadWebCalendar: [r formValueForKey: @"url"]];
          
          if (imported >= 0)
            {
              [rc setObject: @"Web Calendar" forKey: @"displayname"];
              [rc setObject: name forKey: @"name"];
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

- (void) saveUrl: (NSURL *) calendarURL
     forCalendar: (NSString *) calendarName
{
  NSUserDefaults *settings;
  NSMutableDictionary *calSettings, *webCalendars;

  settings = [[context activeUser] userSettings];
  calSettings = [settings objectForKey: @"Calendar"];
  webCalendars = [calSettings objectForKey: @"WebCalendars"];
  if (!webCalendars)
    {
      webCalendars = [NSMutableDictionary dictionary];
      [calSettings setObject: webCalendars forKey: @"WebCalendars"];
    }
  [webCalendars setObject: calendarURL forKey: calendarName];
  [settings synchronize];
}

- (WOResponse *) reloadWebCalendarsAction
{
  NSUserDefaults *settings;
  NSMutableDictionary *calSettings, *webCalendars;
  NSArray *calendarIds;
  SOGoWebAppointmentFolder *folder;
  NSString *name, *url;
  int i, count, imported;

  settings = [[context activeUser] userSettings];
  calSettings = [settings objectForKey: @"Calendar"];
  webCalendars = [calSettings objectForKey: @"WebCalendars"];

  if (webCalendars)
    {
      calendarIds = [webCalendars allKeys];
      count = [calendarIds count];
      for (i = 0; i < count; i++)
        {
          name = [calendarIds objectAtIndex: i];
          url = [webCalendars objectForKey: name];
          folder = [[self clientObject] lookupName: name
                                         inContext: context
                                           acquire: NO];
          if (folder)
            imported = [folder loadWebCalendar: url];
        }
    }

  return [self responseWith204];
}



@end
