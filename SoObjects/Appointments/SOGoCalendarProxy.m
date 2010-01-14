/* SOGoCalendarProxy.m - this file is part of SOGo
 *
 * Copyright (C) 2009 Inverse inc.
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
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <SaxObjC/XMLNamespaces.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>

#import "SOGoAppointmentFolders.h"

#import "SOGoCalendarProxy.h"

@implementation SOGoCalendarProxy

- (id) init
{
  if ((self = [super init]))
    {
      hasWriteAccess = NO;
    }

  return self;
}

- (void) setWriteAccess: (BOOL) newHasWriteAccess
{
  hasWriteAccess = newHasWriteAccess;
}

- (NSArray *) davResourceType
{
  NSString *proxyType;
  NSMutableArray *rType;

  rType = [NSMutableArray arrayWithArray: [super davResourceType]];
  [rType addObject: @"principal"];
  if (hasWriteAccess)
    proxyType = @"calendar-proxy-write";
  else
    proxyType = @"calendar-proxy-read";
  [rType addObject: [NSArray arrayWithObjects: proxyType,
                             XMLNS_CalendarServerOrg, nil]];

  return rType;
}

- (NSArray *) davGroupMemberSet
{
  NSMutableArray *members;
  NSArray *proxyUsers, *member;
  SOGoUser *ownerUser;
  NSString *appName, *proxyUser;
  int count, max;

  appName = [[context request] applicationName];

  ownerUser = [SOGoUser userWithLogin: [self ownerInContext: context]];
  proxyUsers = [[ownerUser userSettings]
                 calendarProxyUsersWithWriteAccess: hasWriteAccess];
  max = [proxyUsers count];
  members = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      proxyUser = [proxyUsers objectAtIndex: count];
      member = [NSArray arrayWithObjects: @"href", XMLNS_WEBDAV, @"D",
                        [NSString stringWithFormat: @"/%@/dav/%@/",
                                  appName, proxyUser],
                        nil];
      [members addObject: member];
    }

  return members;
}

- (NSString *) _parseSubscriber: (NSString *) memberSet
                          until: (int) length
{
  int begin, end;
  NSRange beginRange;

  end = length;
  if ([memberSet characterAtIndex: end - 1] == '/')
    end--;
  beginRange = [memberSet rangeOfString: @"/"
                                options: NSBackwardsSearch
                                  range: NSMakeRange (0, end)];
  begin = NSMaxRange (beginRange);

  return [memberSet substringWithRange: NSMakeRange (begin, end - begin)];
}

- (NSArray *) _parseSubscribers: (NSString *) memberSet
{
  NSRange endRange;
  NSMutableArray *subscribers;
  NSMutableString *mMemberSet;
  NSString *subscriber;

  subscribers = [NSMutableArray array];
  mMemberSet = [NSMutableString stringWithString: memberSet];

  endRange = [mMemberSet rangeOfString: @"</"];
  while (endRange.location != NSNotFound)
    {
      subscriber = [self _parseSubscriber: mMemberSet
                                    until: endRange.location];
      [subscribers addObjectUniquely: subscriber];
      [mMemberSet
        deleteCharactersInRange: NSMakeRange (0, endRange.location + 1)];
      endRange = [mMemberSet rangeOfString: @"</"];
    }

  return subscribers;
}

- (NSException *) setDavGroupMemberSet: (NSString *) memberSet
{
  SOGoUser *ownerUser;
  SOGoUserSettings *us;
  NSMutableArray *addedUsers, *removedUsers;
  NSArray *oldProxyUsers, *newProxyUsers;
  NSString *login;
  SOGoAppointmentFolders *folders;

  login = [self ownerInContext: context];
  ownerUser = [SOGoUser userWithLogin: login roles: nil];
  us = [ownerUser userSettings];
  oldProxyUsers = [us calendarProxyUsersWithWriteAccess: hasWriteAccess];
  if (!oldProxyUsers)
    oldProxyUsers = [NSMutableArray array];
  newProxyUsers = [self _parseSubscribers: memberSet];
  if (!newProxyUsers)
    newProxyUsers = [NSMutableArray array];
  [us setCalendarProxyUsers: newProxyUsers
            withWriteAccess: hasWriteAccess];

  folders = [container lookupName: @"Calendar" inContext: context
                          acquire: NO];
  addedUsers = [newProxyUsers mutableCopy];
  [addedUsers removeObjectsInArray: oldProxyUsers];
  [folders adjustProxyRolesForUsers: addedUsers
                             remove: NO
                     forWriteAccess: hasWriteAccess];
  [folders adjustProxySubscriptionsForUsers: addedUsers
                                     remove: NO
                             forWriteAccess: hasWriteAccess];
  [addedUsers autorelease];

  removedUsers = [oldProxyUsers mutableCopy];
  [removedUsers removeObjectsInArray: newProxyUsers];
  [folders adjustProxyRolesForUsers: removedUsers
                             remove: YES
                     forWriteAccess: hasWriteAccess];
  [folders adjustProxySubscriptionsForUsers: removedUsers
                                     remove: YES
                             forWriteAccess: hasWriteAccess];
  [removedUsers autorelease];

  [us synchronize];

  return nil;
}

@end
