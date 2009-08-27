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

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoUser.h>

#import "SOGoAppointmentFolder.h"
#import "SOGoCalendarProxy.h"

@implementation SOGoCalendarProxy

#define XMLNS_CALENDARSERVER @"http://calendarserver.org/ns/"

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
                             XMLNS_CALENDARSERVER, nil]];

  return rType;
}

- (NSArray *) davGroupMemberSet
{
  NSMutableArray *members;
  NSEnumerator *subscribers;
  NSArray *member;
  SOGoUser *ownerUser;
  SOGoAppointmentFolder *folder;
  NSString *subscriber;

  members = [NSMutableArray array];

  ownerUser = [SOGoUser userWithLogin: [self ownerInContext: context]
                                roles: nil];
  folder = [ownerUser personalCalendarFolderInContext: context];
  subscribers = [[folder proxySubscribersWithWriteAccess: hasWriteAccess]
                  objectEnumerator];
  while ((subscriber = [subscribers nextObject]))
    {
      member = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
                        [NSString stringWithFormat: @"/SOGo/dav/%@/",
                                  subscriber],
                        nil];
      [members addObject: member];
    }

  return members;
}

- (NSString *) davGroupMembership
{
  return nil;
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
  SOGoAppointmentFolder *folder;

  ownerUser = [SOGoUser userWithLogin: [self ownerInContext: context]
                                roles: nil];
  folder = [ownerUser personalCalendarFolderInContext: context];

  return [folder setProxySubscribers: [self _parseSubscribers: memberSet]
                     withWriteAccess: hasWriteAccess];
}

@end
