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

#import <SOGoUI/UIxComponent.h>

@class NSString;

@class SOGoAppointmentFolder;

@interface UIxCalendarProperties : UIxComponent
{
  SOGoAppointmentFolder *calendar;
  NSString *baseCalDAVURL, *basePublicCalDAVURL;
  BOOL reloadTasks;
}

- (NSString *) calendarName;
- (void) setCalendarName: (NSString *) newName;

- (NSString *) calendarColor;
- (void) setCalendarColor: (NSString *) newColor;

- (BOOL) showCalendarAlarms;
- (void) setShowCalendarAlarms: (BOOL) new;

- (BOOL) synchronizeCalendar;
- (void) setSynchronizeCalendar: (BOOL) new;

- (NSString *) originalCalendarSyncTag;
- (NSString *) allCalendarSyncTags;
- (BOOL) mustSynchronize;
- (NSString *) calendarSyncTag;
- (void) setCalendarSyncTag: (NSString *) newTag;

/* notifications */
- (BOOL) notifyOnPersonalModifications;
- (void) setNotifyOnPersonalModifications: (BOOL) b;
- (BOOL) notifyOnExternalModifications;
- (void) setNotifyOnExternalModifications: (BOOL) b;
- (BOOL) notifyUserOnPersonalModifications;
- (void) setNotifyUserOnPersonalModifications: (BOOL) b;
- (NSString *) notifiedUserOnPersonalModifications;
- (void) setNotifiedUserOnPersonalModifications: (NSString *) theUser;

@end
