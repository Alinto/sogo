/* SOGoAppointmentInboxFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
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
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <SaxObjC/XMLNamespaces.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <SOGo/NSObject+DAV.h>
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
  NSMutableArray *colType;
  NSString *login;

  colType = [NSMutableArray arrayWithCapacity: 10];
  [colType addObject: @"collection"];
  login = [[context activeUser] login];
  if ([login isEqualToString: [self ownerInContext: self]])
    [colType addObject: [NSArray arrayWithObjects: @"schedule-inbox",
                                 XMLNS_CALDAV, nil]];

  return colType;
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

@end
