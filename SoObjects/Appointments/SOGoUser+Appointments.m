/* SOGoUser+Appointments.m - this file is part of SOGo
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

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoUserSettings.h>

#import "SOGoUser+Appointments.h"

@implementation SOGoUser (SOGoCalDAVSupport)

- (void) adjustProxySubscriptionToUser: (NSString *) ownerUser
                                remove: (BOOL) remove
                        forWriteAccess: (BOOL) write
{
  SOGoUserSettings *us;
  NSMutableArray *subscriptions;

  us = [self userSettings];

  /* first, we want to ensure the subscription does not appear in the
     opposite list... */
  if (!remove)
    {
      subscriptions
        = [[us calendarProxySubscriptionUsersWithWriteAccess: !write]
            mutableCopy];
      [subscriptions autorelease];
      if ([subscriptions containsObject: ownerUser])
        {
          [subscriptions removeObject: ownerUser];
          [us setCalendarProxySubscriptionUsers: subscriptions
                                withWriteAccess: !write];
          
        }
    }

  subscriptions
    = [[us calendarProxySubscriptionUsersWithWriteAccess: write]
        mutableCopy];
  [subscriptions autorelease];
  if (remove)
    [subscriptions removeObject: ownerUser];
  else
    {
      if (!subscriptions)
        subscriptions = [NSMutableArray array];
      [subscriptions addObjectUniquely: ownerUser];
    }
  
  [us setCalendarProxySubscriptionUsers: subscriptions
                        withWriteAccess: write];
  [us synchronize];
}

@end
