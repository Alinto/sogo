/* SOGoUserManager.m - this file is part of SOGo
 *
 * Copyright (C) 2008 Inverse inc.
 *
 * Author: Ludovic Marcotte <lmarcotte@inverse.ca>
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

#include "SOGoUserManager.h"

#include <Foundation/NSDictionary.h>
#include <Foundation/NSDistributedNotificationCenter.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSString.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSUserDefaults.h>

#import <NGExtensions/NSObject+Logs.h>

#include "SOGoUser.h"

// We define the default value for cleaning up cached
// users' preferences. This value should be relatively high
// to avoid useless database calls.
static NSTimeInterval cleanupInterval = 1800;

@implementation SOGoUserManager

- (id) init
{
  NSString *cleanupSetting;

  if ((self = [super init]))
    {
      _cache = [[NSMutableDictionary alloc] init];
    }

  // We register ourself for notifications
  [[NSDistributedNotificationCenter defaultCenter]
    addObserver: self
    selector: @selector(_userDefaultsHaveChanged:)
    name: @"SOGoUserDefaultsHaveChanged"
    object: nil];

  [[NSDistributedNotificationCenter defaultCenter]
    addObserver: self
    selector: @selector(_userSettingsHaveChanged:)
    name: @"SOGoUserSettingsHaveChanged"
    object: nil];

  // We fire our timer that will cleanup cache entries
  cleanupSetting = [[NSUserDefaults standardUserDefaults] 
		     objectForKey: @"SOGoUserManagerCleanupInterval"];
  
  if (cleanupSetting && [cleanupSetting doubleValue] > 0.0)
    cleanupInterval = [cleanupSetting doubleValue];

  _cleanupTimer = [NSTimer scheduledTimerWithTimeInterval: cleanupInterval
			   target: self
			   selector: @selector(_cleanupSources)
			   userInfo: nil
			   repeats: YES];
  [self logWithFormat: @"cleanup interval set every %f seconds",
	cleanupInterval];
  
  return self;
}

- (void) dealloc
{
  [_cache release];
  [super dealloc];
}

+ (id) sharedManager
{
  static id sharedManager = nil;

  if (!sharedManager)
    sharedManager = [self new];

  return sharedManager;
}

- (SOGoUser *) userWithLogin: (NSString *) theLogin
		       roles: (NSArray *) theRoles
{
  NSDate *cleanupDate;
  SOGoUser *user;
  id entry;
  
  cleanupDate = [[NSDate date] addTimeInterval: cleanupInterval];
  entry = [_cache objectForKey: theLogin];

  if (!entry)
    {
      user = [SOGoUser userWithLogin: theLogin  roles: theRoles];

      entry = [NSMutableDictionary dictionaryWithObjectsAndKeys: user, @"user", cleanupDate, @"cleanupDate", nil];
      [_cache setObject: entry  forKey: theLogin];
    }
  else
    {
      [entry setObject: cleanupDate  forKey: @"cleanupDate"];
      user = [entry objectForKey: @"user"];
    }

  [user setPrimaryRoles: theRoles];

  return user;
}

//
// Private stuff
//
- (void) _userDefaultsHaveChanged: (NSNotification *) theNotification
{
  NSMutableDictionary *d;
  SOGoUser *user;

  d = [[NSMutableDictionary alloc] init];
  [d addEntriesFromDictionary: [theNotification userInfo]];

  user = [self userWithLogin: [d objectForKey: @"uid"]
	       roles: nil];
  
  [d removeObjectForKey: @"uid"];
  [user setUserDefaultsFromDictionary: d];
  [d release];
}

- (void) _userSettingsHaveChanged: (NSNotification *) theNotification
{
  NSMutableDictionary *d;
  SOGoUser *user;
 
  d = [[NSMutableDictionary alloc] init];
  [d addEntriesFromDictionary: [theNotification userInfo]];

  user = [self userWithLogin: [d objectForKey: @"uid"]
	       roles: nil];
  
  [d removeObjectForKey: @"uid"];
  [user setUserSettingsFromDictionary: d];
  [d release];
}

- (void) _cleanupSources
{
  NSEnumerator *userIDs;
  NSString *currentID;
  NSDictionary *currentUser;
  NSDate *now;
  unsigned int count;

  now = [NSDate date];
  count = 0;
  userIDs = [[_cache allKeys] objectEnumerator];

  while ((currentID = [userIDs nextObject]))
    {
      currentUser = [_cache objectForKey: currentID];
      if ([now earlierDate:
		 [currentUser objectForKey: @"cleanupDate"]] == now)
	{
	  [_cache removeObjectForKey: currentID];
	  count++;
	}
    }

  if (count)
    [self logWithFormat: @"cleaned %d users records from cache", count];
}

@end
