/* UIxCalendarProperties.m - this file is part of SOGo
 *
 * Copyright (C) 2008 Inverse inc.
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>

#import <NGObjWeb/WORequest.h>

#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/Appointments/SOGoAppointmentFolder.h>

#import "UIxCalendarProperties.h"

@implementation UIxCalendarProperties

- (id) init
{
  if ((self = [super init]))
    {
      calendar = [self clientObject];
      reloadTasks = NO;
    }

  return self;
}

- (NSString *) calendarID
{
  return [calendar folderReference];
}

- (NSString *) calendarName
{
  return [calendar displayName];
}

- (void) setCalendarName: (NSString *) newName
{
  NSString *login;

  login = [[context activeUser] login];

  if ([login isEqualToString: [calendar ownerInContext: context]])
    [calendar renameTo: newName];
}

- (NSString *) calendarNameIsDisabled
{
  NSString *login;

  login = [[context activeUser] login];

  return ([login isEqualToString: [calendar ownerInContext: context]]
	  ? @"false" : @"true");
}

- (NSString *) calendarColor
{
  return [calendar calendarColor];
}

- (void) setCalendarColor: (NSString *) newColor
{
  [calendar setCalendarColor: newColor];
}

- (BOOL) synchronizeCalendar
{
  return [self mustSynchronize] || [calendar synchronizeCalendar];
}

- (void) setSynchronizeCalendar: (BOOL) new
{
  [calendar setSynchronizeCalendar: new];
}

- (NSString *) originalCalendarSyncTag
{
  return [calendar syncTag];
}

- (NSString *) allCalendarSyncTags
{
  NSUserDefaults *settings;
  NSMutableDictionary *calendarSettings;
  NSMutableDictionary *syncTags;
  NSEnumerator *keysList;
  NSMutableArray *tags;
  NSString *key, *result;

  settings = [[context activeUser] userSettings];
  calendarSettings = [settings objectForKey: @"Calendar"];
  tags = nil;

  if (calendarSettings)
    {
      syncTags = [calendarSettings objectForKey: @"FolderSyncTags"];
      if (syncTags)
	{
	  tags = [NSMutableArray arrayWithCapacity: [syncTags count]];
	  keysList = [syncTags keyEnumerator];
	  while ((key = (NSString*)[keysList nextObject])) {
	    if (![key isEqualToString: [calendar folderReference]])
	      [tags addObject: [syncTags objectForKey: key]];
	  }
	}
    }
  
  if (!tags)
    result = @"";
  else
    result = [tags componentsJoinedByString: @","];

  return result;
}

- (BOOL) mustSynchronize
{
  return [[calendar nameInContainer] isEqualToString: @"personal"];
}

- (NSString *) calendarSyncTag
{
  return [calendar syncTag];
}

- (void) setCalendarSyncTag: (NSString *) newTag
{
  [calendar setSyncTag: newTag];
}

- (BOOL) showCalendarAlarms
{
  return [calendar showCalendarAlarms];
}

- (void) setShowCalendarAlarms: (BOOL) new
{
  if (new != [calendar showCalendarAlarms])
    reloadTasks = YES;
  [calendar setShowCalendarAlarms: new];
}

- (BOOL) showCalendarTasks
{
  return [calendar showCalendarTasks];
}

- (void) setShowCalendarTasks: (BOOL) new
{
  if (new != [calendar showCalendarTasks])
    reloadTasks = YES;
  [calendar setShowCalendarTasks: new];
}

- (NSString *) webCalendarURL
{
  NSUserDefaults *settings;
  NSMutableDictionary *calendarSettings;
  NSMutableDictionary *webCalendars;
  NSString *rc;

  settings = [[context activeUser] userSettings];
  calendarSettings = [settings objectForKey: @"Calendar"];

  if (calendarSettings)
    {
      webCalendars = [calendarSettings objectForKey: @"WebCalendars"];
      if (webCalendars)
        rc = [webCalendars objectForKey: [calendar nameInContainer]];
    }

  return rc;
}

- (BOOL) isWebCalendar
{
  return ([self webCalendarURL] != nil);
}

- (BOOL) shouldTakeValuesFromRequest: (WORequest *) request
                           inContext: (WOContext*) context
{
  NSString *method;

  method = [[request uri] lastPathComponent];

  return [method isEqualToString: @"saveProperties"];
}

- (id <WOActionResults>) savePropertiesAction
{
  NSString *action = nil;

  if (reloadTasks)
    action = @"refreshTasks()";
  return [self jsCloseWithRefreshMethod: action];
}

@end
