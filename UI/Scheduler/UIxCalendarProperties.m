/* UIxCalendarProperties.m - this file is part of SOGo
 *
 * Copyright (C) 2008-2012 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Ludovic Marcotte <lmarcotte@inverse.ca>
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
#import <Foundation/NSURL.h>

#import <NGObjWeb/WORequest.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoWebAppointmentFolder.h>

#import "UIxCalendarProperties.h"

@implementation UIxCalendarProperties

- (id) init
{
  if ((self = [super init]))
    {
      calendar = [self clientObject];
      baseCalDAVURL = nil;
      basePublicCalDAVURL = nil;
      reloadTasks = NO;
    }

  return self;
}

- (void) dealloc
{
  [baseCalDAVURL release];
  [basePublicCalDAVURL release];
  [super dealloc];
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
  [calendar renameTo: newName];
}

- (NSString *) calendarColor
{
  return [calendar calendarColor];
}

- (void) setCalendarColor: (NSString *) newColor
{
  [calendar setCalendarColor: newColor];
}

- (BOOL) includeInFreeBusy
{
  return [calendar includeInFreeBusy];
}

- (void) setIncludeInFreeBusy: (BOOL) newInclude
{
  [calendar setIncludeInFreeBusy: newInclude];
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
  SOGoUserSettings *settings;
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

- (BOOL) userIsOwner
{
  NSString *userLogin;

  userLogin = [[context activeUser] login];

  return ([userLogin isEqualToString: [calendar ownerInContext: context]]);
}

- (BOOL) isPublicAccessEnabled
{
  // NOTE: This method is the same found in Common/UIxAclEditor.m
  return [[SOGoSystemDefaults sharedSystemDefaults]
           enablePublicAccess];
}

- (BOOL) isWebCalendar
{
  return ([calendar isKindOfClass: [SOGoWebAppointmentFolder class]]);
}

- (NSString *) webCalendarURL
{
  return [calendar folderPropertyValueInCategory: @"WebCalendars"];
}

- (void) setReloadOnLogin: (BOOL) newReloadOnLogin
{
  if ([calendar respondsToSelector: @selector (setReloadOnLogin:)])
    [(SOGoWebAppointmentFolder *) calendar
      setReloadOnLogin: newReloadOnLogin];
}

- (BOOL) reloadOnLogin
{
  BOOL rc;

  if ([calendar respondsToSelector: @selector (reloadOnLogin)])
    rc = [(SOGoWebAppointmentFolder *) calendar reloadOnLogin];
  else
    rc = NO;

  return rc;
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
  NSString *action;

  if (reloadTasks)
    action = @"refreshTasks()";
  else
    action = nil;
  return [self jsCloseWithRefreshMethod: action];
}

- (NSString *) _baseCalDAVURL
{
  NSString *davURL;

  if (!baseCalDAVURL)
    {
      davURL = [[calendar realDavURL] absoluteString];
      if ([davURL hasSuffix: @"/"])
        baseCalDAVURL = [davURL substringToIndex: [davURL length] - 1];
      else
        baseCalDAVURL = davURL;
      [baseCalDAVURL retain];
    }

  return baseCalDAVURL;
}

- (NSString *) _basePublicCalDAVURL
{
  NSString *davURL;

  if (!basePublicCalDAVURL)
    {
      davURL = [[calendar publicDavURL] absoluteString];
      if ([davURL hasSuffix: @"/"])
	basePublicCalDAVURL = [davURL substringToIndex: [davURL length] - 1];
      else
        basePublicCalDAVURL = davURL;
      [basePublicCalDAVURL retain];
    }

  return basePublicCalDAVURL;
}

- (NSString *) calDavURL
{
  return [NSString stringWithFormat: @"%@/", [self _baseCalDAVURL]];
}

- (NSString *) webDavICSURL
{
  return [NSString stringWithFormat: @"%@.ics", [self _baseCalDAVURL]];
}

- (NSString *) webDavXMLURL
{
  return [NSString stringWithFormat: @"%@.xml", [self _baseCalDAVURL]];
}

- (NSString *) publicCalDavURL
{
  return [NSString stringWithFormat: @"%@/", [self _basePublicCalDAVURL]];
}

- (NSString *) publicWebDavICSURL
{
  return [NSString stringWithFormat: @"%@.ics", [self _basePublicCalDAVURL]];
}

- (NSString *) publicWebDavXMLURL
{
  return [NSString stringWithFormat: @"%@.xml", [self _basePublicCalDAVURL]];
}

- (BOOL) notifyOnPersonalModifications
{
  return [calendar notifyOnPersonalModifications];
}

- (void) setNotifyOnPersonalModifications: (BOOL) b
{
  [calendar setNotifyOnPersonalModifications: b];
}

- (BOOL) notifyOnExternalModifications
{
  return [calendar notifyOnExternalModifications];
}

- (void) setNotifyOnExternalModifications: (BOOL) b
{
  [calendar setNotifyOnExternalModifications: b];
}

- (BOOL) notifyUserOnPersonalModifications
{
  return [calendar notifyUserOnPersonalModifications];
}

- (void) setNotifyUserOnPersonalModifications: (BOOL) b
{
  [calendar setNotifyUserOnPersonalModifications: b];
}

- (NSString *) notifiedUserOnPersonalModifications
{
  return [calendar notifiedUserOnPersonalModifications];
}

- (void) setNotifiedUserOnPersonalModifications: (NSString *) theUser
{
  [calendar setNotifiedUserOnPersonalModifications: theUser];
}

@end
