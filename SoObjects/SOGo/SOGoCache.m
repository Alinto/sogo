/* SOGoCache.m - this file is part of SOGo
 *
 * Copyright (C) 2008 Inverse inc.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSDistributedNotificationCenter.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/SoObject.h>
#import <NGExtensions/NSObject+Logs.h>

#import "SOGoObject.h"
#import "SOGoUser.h"
#import "SOGoUserDefaults.h"

#import "SOGoCache.h"

// We define the default value for cleaning up cached
// users' preferences. This value should be relatively
// high to avoid useless database calls.
static NSTimeInterval cleanupInterval = 1800;

static NSMutableDictionary *cache = nil;
static NSMutableDictionary *users = nil;

static NSMutableDictionary *s_userDefaults = nil;
static NSMutableDictionary *s_userSettings = nil;

static SOGoCache *sharedCache = nil;

#if defined(THREADSAFE)
static NSLock *lock;
#endif

@implementation SOGoCache

+ (void) initialize
{
 #if defined(THREADSAFE)
  lock = [NSLock new];
#endif
  s_userDefaults = [[NSMutableDictionary alloc] init];
  s_userSettings = [[NSMutableDictionary alloc] init];
}

+ (NSTimeInterval) cleanupInterval
{
  return cleanupInterval;
}

+ (SOGoCache *) sharedCache
{
#if defined(THREADSAFE)
  [lock lock];
#endif
  if (!sharedCache)
    sharedCache = [self new];
#if defined(THREADSAFE)
  [lock unlock];
#endif

  return sharedCache;
}

+ (void) killCache
{
#if defined(THREADSAFE)
  [lock lock];
#endif
  [cache removeAllObjects];
  [users removeAllObjects];
#if defined(THREADSAFE)
  [lock unlock];
#endif
}

- (id) init
{
  if ((self = [super init]))
    {
      NSString *cleanupSetting;

      cache = [[NSMutableDictionary alloc] init];
      users = [[NSMutableDictionary alloc] init];
      
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
			 objectForKey: @"SOGoCacheCleanupInterval"];
      
      if (cleanupSetting && [cleanupSetting doubleValue] > 0.0)
	cleanupInterval = [cleanupSetting doubleValue];
      
      _cleanupTimer = [NSTimer scheduledTimerWithTimeInterval: cleanupInterval
			       target: self
			       selector: @selector(_cleanupSources)
			       userInfo: nil
			       repeats: YES];
      [self logWithFormat: @"cleanup interval set every %f seconds",
	    cleanupInterval];
    }

  return self;
}

- (void) dealloc
{
  [[NSDistributedNotificationCenter defaultCenter]
    removeObserver: self
    name: @"SOGoUserDefaultsHaveChanged"
    object: nil];
  
  [[NSDistributedNotificationCenter defaultCenter]
    removeObserver: self
    name: @"SOGoUserSettingsHaveChanged"
    object: nil];

  [cache release];
  [users release];
  [super dealloc];
}

- (NSString *) _pathFromObject: (SOGoObject *) container
withName: (NSString *) name
{
  NSString *fullPath, *nameInContainer;
  NSMutableArray *names;
  id currentObject;

  names = [NSMutableArray new];

  [names addObject: name];
  currentObject = container;
  while ((nameInContainer = [currentObject nameInContainer]))
    {
      [names addObject: nameInContainer];
      currentObject = [currentObject container];
    }

  fullPath = [names componentsJoinedByString: @"/"];
  [names release];

  return fullPath;
}

- (void) registerObject: (id) object
	       withName: (NSString *) name
	    inContainer: (SOGoObject *) container
{
  NSString *fullPath;

  if (object && name)
    {
      [self registerObject: container
	    withName: [container nameInContainer]
	    inContainer: [container container]];
      fullPath = [self _pathFromObject: container
		       withName: name];
#if defined(THREADSAFE)
      [lock lock];
#endif
      if (![cache objectForKey: fullPath])
	{
	  // 	  NSLog (@"registering '%@'", fullPath);
	  [cache setObject: object forKey: fullPath];
	}
#if defined(THREADSAFE)
      [lock unlock];
#endif
      //       else
      // 	NSLog (@"'%@' already registered", fullPath);
    }
}

- (id) objectNamed: (NSString *) name
       inContainer: (SOGoObject *) container
{
  NSString *fullPath;

  fullPath = [self _pathFromObject: container
		   withName: name];

  return [cache objectForKey: fullPath];
  //   if (object)
  //     NSLog (@"found cached object '%@'", fullPath);
}

- (void) registerUser: (SOGoUser *) user
{ 
#if defined(THREADSAFE)
  [lock lock];
#endif
  [users setObject: user
	 forKey: [user login]];
#if defined(THREADSAFE)
  [lock unlock];
#endif
}

- (id) userNamed: (NSString *) name
{
  return [users objectForKey: name];
}

+ (NSDictionary *) cachedUserDefaults
{
  return s_userDefaults;
}

/* defaults */
+ (void) setCachedUserDefaults: (SOGoUserDefaults *) theDefaults
			  user: (NSString *) login
{
  NSDate *cleanupDate;
  
#if defined(THREADSAFE)
  [lock lock];
#endif
  cleanupDate = [[NSDate date] addTimeInterval: [SOGoCache cleanupInterval]];
  [s_userDefaults setObject: [NSDictionary dictionaryWithObjectsAndKeys:
					     theDefaults, @"dictionary",
					   cleanupDate, @"cleanupDate", nil]
		  forKey: login];
#if defined(THREADSAFE)
  [lock unlock];
#endif
}

+ (NSDictionary *) cachedUserSettings
{
  return s_userSettings;
}

+ (void) setCachedUserSettings: (SOGoUserDefaults *) theSettings
			  user: (NSString *) login
{
  NSDate *cleanupDate;
  
#if defined(THREADSAFE)
  [lock lock];
#endif
  cleanupDate = [[NSDate date] addTimeInterval: [SOGoCache cleanupInterval]];
  [s_userSettings setObject: [NSDictionary dictionaryWithObjectsAndKeys:
					     theSettings, @"dictionary",
					   cleanupDate, @"cleanupDate", nil]
		  forKey: login];
#if defined(THREADSAFE)
  [lock unlock];
#endif
}

- (void) _userDefaultsHaveChanged: (NSNotification *) theNotification
{
  SOGoUser *user;
  NSString *uid;
  SOGoUserDefaults *defaults;
  
  uid = [[theNotification userInfo] objectForKey: @"uid"];

#if defined(THREADSAFE)
  [lock lock];
#endif
  if ((user = [users objectForKey: uid]))
    {
      defaults = (SOGoUserDefaults *) [user userDefaults];
      [defaults setValues: [[theNotification userInfo] objectForKey: @"values"]];
      [SOGoCache setCachedUserDefaults: defaults user: uid];
    }
  else
    {
      [s_userDefaults removeObjectForKey: uid];
    }
#if defined(THREADSAFE)
  [lock unlock];
#endif
}

- (void) _userSettingsHaveChanged: (NSNotification *) theNotification
{
  SOGoUser *user;
  NSString *uid;
  SOGoUserDefaults *settings; 
 
  uid = [[theNotification userInfo] objectForKey: @"uid"];

  if ((user = [users objectForKey: uid]))
    {
      settings = (SOGoUserDefaults *) [user userSettings];
      [settings setValues: [[theNotification userInfo] objectForKey: @"values"]];
      [SOGoCache setCachedUserSettings: settings user: uid];
    }
  else
    {
      [s_userSettings removeObjectForKey: uid];
    }
}

- (void) _cleanupSources
{
  NSDictionary *currentEntry;
  NSEnumerator *userIDs;
  NSString *currentID;
  NSDate *now;
  
  unsigned int count;

#if defined(THREADSAFE)
  [lock lock];
#endif

  now = [NSDate date];
  
  // We cleanup the user defaults
  userIDs = [[s_userDefaults allKeys] objectEnumerator];
  count = 0;
  while ((currentID = [userIDs nextObject]))
    {
      currentEntry = [s_userDefaults objectForKey: currentID];
      
      if ([now earlierDate: [currentEntry objectForKey: @"cleanupDate"]] == now)
	{
	  [s_userDefaults removeObjectForKey: currentID];
	  count++;
	}
    }
  
  if (count)
    [self logWithFormat: @"cleaned %d users records from user defaults cache", count];

  // We cleanup the user settings
  userIDs = [[s_userSettings allKeys] objectEnumerator];
  count = 0;
  while ((currentID = [userIDs nextObject]))
    {
      currentEntry = [s_userSettings objectForKey: currentID];
      
      if ([now earlierDate: [currentEntry objectForKey: @"cleanupDate"]] == now)
	{
	  [s_userSettings removeObjectForKey: currentID];
	  count++;
	}
    }
  
  if (count)
    [self logWithFormat: @"cleaned %d users records from user settings cache",
	  count];

#if defined(THREADSAFE)
  [lock unlock];
#endif
}

@end
