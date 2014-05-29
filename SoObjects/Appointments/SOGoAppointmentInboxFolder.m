/* SOGoAppointmentInboxFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2014 Inverse inc.
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
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <SaxObjC/XMLNamespaces.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <SOGo/NSObject+DAV.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoWebDAVValue.h>

#import "SOGoAppointmentFolders.h"

#import "SOGoAppointmentInboxFolder.h"

@implementation SOGoAppointmentInboxFolder

- (NSString *) davCollectionTag
{
  return @"-1";
}

- (NSArray *) davResourceType
{
  return [NSArray arrayWithObjects: @"collection",
                  [NSArray arrayWithObjects: @"schedule-inbox", XMLNS_CALDAV, nil],
                  nil];
}

- (SOGoWebDAVValue *) davCalendarFreeBusySet
{
  NSEnumerator *subFolders;
  SOGoAppointmentFolder *currentFolder;
  NSMutableArray *response;
  SOGoWebDAVValue *responseValue;

  response = [NSMutableArray array];
  subFolders = [[container subFolders] objectEnumerator];
  while ((currentFolder = [subFolders nextObject]))
    if ([owner isEqualToString: [currentFolder ownerInContext: context]])
      [response
        addObject: davElementWithContent (@"href", XMLNS_WEBDAV,
                                          [currentFolder davURLAsString])];
  responseValue = [davElementWithContent (@"calendar-free-busy-set", XMLNS_CALDAV, response)
					 asWebDAVValue];

  return responseValue;
}

/* This method is ignored but we must return a success value. */
- (NSException *) setDavCalendarFreeBusySet: (NSString *) newFreeBusySet
{
  return nil;
}

- (SOGoWebDAVValue *) davScheduleDefaultCalendarURL
{
  NSString *personalURL;
  NSDictionary *href;

  personalURL = [NSString stringWithFormat: @"%@personal/",
                          [container davURLAsString]];
  href = davElementWithContent (@"href", XMLNS_WEBDAV, personalURL);

  return [davElementWithContent (@"schedule-default-calendar-URL", XMLNS_CALDAV, href)
                                asWebDAVValue];
}

- (NSArray *) aclsForUser: (NSString *) userID
{
  NSString *login;
  NSArray *acls;

  acls = nil;

  login = [[context activeUser] login];
  if (![login isEqualToString: owner])
    {
      if ([container hasProxyCalendarsWithWriteAccess: YES
                                     forUserWithLogin: login]
          || [container hasProxyCalendarsWithWriteAccess: NO
                                        forUserWithLogin: login])
        acls = [NSArray arrayWithObject: SOGoRole_AuthorizedSubscriber];
    }

  return acls;
}

- (NSString *) displayName
{
  return nameInContainer;
}

@end
