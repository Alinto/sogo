/* SOGoCache.m - this file is part of SOGo
 *
 * Copyright (C) 2008-2009 Inverse inc.
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

/*
 * [ Structure ]
 * users: key = user ID         value = NSMutableDictionary instance
 * value: key = @"user"         value = SOGOUser instance
 *        key = @"cleanupDate"  value = NSDate instance
 *        key = @"defaults"     value = SOGoUserDefaults instance
 *        key = @"settings"     value = SOGoUserDefaults instance
 *        key = @"attributes"   value = NSDictionary instance (attributes from LDAP)
 *
 * [ Workflows - processes A and B ]
 *
 * A cache user defaults and posts the notification
 * B ....
 *
 * B crashes
 * B receives a notificaion update
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
static NSTimeInterval cleanupInterval = 300;

static NSMutableDictionary *cache = nil;
static NSMutableDictionary *users = nil;

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
	selector: @selector(_userAttributesHaveLoaded:)
	name: @"SOGoUserAttributesHaveLoaded"
	object: nil];

      [[NSDistributedNotificationCenter defaultCenter]
	addObserver: self
	selector: @selector(_userDefaultsHaveLoaded:)
	name: @"SOGoUserDefaultsHaveLoaded"
	object: nil];

      [[NSDistributedNotificationCenter defaultCenter]
	addObserver: self
	selector: @selector(_userDefaultsHaveChanged:)
	name: @"SOGoUserDefaultsHaveChanged"
	object: nil];
      
      [[NSDistributedNotificationCenter defaultCenter]
	addObserver: self
	selector: @selector(_userSettingsHaveLoaded:)
	name: @"SOGoUserSettingsHaveLoaded"
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
      [self logWithFormat: @"Cache cleanup interval set every %f seconds",
	    cleanupInterval];
    }

  return self;
}

- (void) dealloc
{
  [[NSDistributedNotificationCenter defaultCenter]
    removeObserver: self
    name: @"SOGoUserAttributesHaveLoaded"
    object: nil];

  [[NSDistributedNotificationCenter defaultCenter]
    removeObserver: self
    name: @"SOGoUserDefaultsHaveLoaded"
    object: nil];

  [[NSDistributedNotificationCenter defaultCenter]
    removeObserver: self
    name: @"SOGoUserDefaultsHaveChanged"
    object: nil];

  [[NSDistributedNotificationCenter defaultCenter]
    removeObserver: self
    name: @"SOGoUserSettingsHaveLoaded"
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
	  [cache setObject: object forKey: fullPath];
	}
#if defined(THREADSAFE)
      [lock unlock];
#endif
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
  NSData *cleanupDate;

#if defined(THREADSAFE)
  [lock lock];
#endif

  cleanupDate = [[NSDate date] addTimeInterval: [SOGoCache cleanupInterval]];
  
  if (![users objectForKey: [user login]])
    [users setObject: [NSMutableDictionary dictionary]  forKey: [user login]];

  [[users objectForKey: [user login]] setObject: user  forKey: @"user"];
  [[users objectForKey: [user login]] setObject: [[NSDate date] addTimeInterval: [SOGoCache cleanupInterval]]
				      forKey: @"cleanupDate"];

#if defined(THREADSAFE)
  [lock unlock];
#endif
}

- (id) userNamed: (NSString *) name
{
  return [[users objectForKey: name] objectForKey: @"user"];
}

- (void) cacheAttributes: (NSDictionary *) theAttributes
		forLogin: (NSString *) theLogin
{
  if (![users objectForKey: theLogin])
    [users setObject: [NSMutableDictionary dictionary]  forKey: theLogin];

  [[users objectForKey: theLogin] setObject: theAttributes  forKey: @"attributes"];
  [[users objectForKey: theLogin] setObject: [[NSDate date] addTimeInterval: [SOGoCache cleanupInterval]]
				  forKey: @"cleanupDate"];
}

- (NSMutableDictionary *) userAttributesForLogin: (NSString *) theLogin
{
  return [[users objectForKey: theLogin] objectForKey: @"attributes"];
}

- (SOGoUserDefaults *) userDefaultsForLogin: (NSString *) theLogin
{
  return [[users objectForKey: theLogin] objectForKey: @"defaults"];
}

- (SOGoUserDefaults *) userSettingsForLogin: (NSString *) theLogin
{
  return [[users objectForKey: theLogin] objectForKey: @"settings"];
}

//
//
//
- (void) setDefaults: (SOGoUserDefaults *) theDefaults
	    forLogin: (NSString *) theLogin
		 key: (NSString *) theKey
{
  if (![users objectForKey: theLogin])
    [users setObject: [NSMutableDictionary dictionary]  forKey: theLogin];
  
  [[users objectForKey: theLogin] setObject: theDefaults  forKey: theKey];
  [[users objectForKey: theLogin] setObject: [[NSDate date] addTimeInterval: [SOGoCache cleanupInterval]]
				  forKey: @"cleanupDate"];

  //NSLog(@"Set %@ to %@", theKey, [users objectForKey: theLogin]);
}

//
// Notification callbacks.
//
- (void) _cacheValues: (NSDictionary *) theValues
                login: (NSString *) theLogin
	          url: (NSString *) theURL
		  key: (NSString *) theKey
{
  SOGoUserDefaults *defaults;
  NSURL *url;
  
#if defined(THREADSAFE)
  [lock lock];
#endif
  url = [[[NSURL alloc] initWithString: theURL] autorelease];
  
  defaults = [[[SOGoUserDefaults alloc] initWithTableURL: url
					uid: theLogin
					fieldName: [NSString stringWithFormat: @"c_%@", theKey]]
	       autorelease];
  [defaults setValues: theValues];
  [self setDefaults: defaults  forLogin: theLogin  key: theKey];

#if defined(THREADSAFE)
  [lock unlock];
#endif
}

//
//
//
- (void) _userAttributesHaveLoaded: (NSNotification *) theNotification
{
  NSString *uid;

  uid = [[theNotification userInfo] objectForKey: @"uid"];
  //NSLog(@"Caching user attributes for UID: %@", uid);
  if (![self userAttributesForLogin: uid])
    {
      NSEnumerator *emails;
      NSDictionary *values;
      NSString *key;
      
      if (![users objectForKey: uid])
	[users setObject: [NSMutableDictionary dictionary]  forKey: uid];

      values = [[theNotification userInfo] objectForKey: @"values"];
      [self cacheAttributes: values  forLogin: uid];

      emails = [[values objectForKey: @"emails"] objectEnumerator];
      while ((key = [emails nextObject]))
	{
	  [self cacheAttributes: values  forLogin: key];
	}

      [[users objectForKey: uid] setObject: [[NSDate date] addTimeInterval: [SOGoCache cleanupInterval]]
				 forKey: @"cleanupDate"];
    }
}

//
//
//
- (void) _userDefaultsHaveLoaded: (NSNotification *) theNotification
{
  NSString *uid;

  uid = [[theNotification userInfo] objectForKey: @"uid"];
  //NSLog(@"Loading user defaults for UID: %@", uid);
  if (![self userDefaultsForLogin: uid])
    {
      [self _cacheValues: [[theNotification userInfo] objectForKey: @"values"]
	    login: uid
	    url: [[theNotification userInfo] objectForKey: @"url"]
	    key: @"defaults"];
    }
}

//
//
//
- (void) _userDefaultsHaveChanged: (NSNotification *) theNotification
{
  SOGoUserDefaults *defaults;
  NSString *uid;

  uid = [[theNotification userInfo] objectForKey: @"uid"];
  //NSLog(@"Updating user defaults for UID: %@", uid);
  defaults = (SOGoUserDefaults *)[self userDefaultsForLogin: uid];
  if (defaults)
    {
#if defined(THREADSAFE)
      [lock lock];
#endif
      [defaults setValues: [[theNotification userInfo] objectForKey: @"values"]];
      [[users objectForKey: uid] setObject: [[NSDate date] addTimeInterval: [SOGoCache cleanupInterval]]
				 forKey: @"cleanupDate"];
#if defined(THREADSAFE)
      [lock unlock];
#endif
    }
  else
    {
      [self _cacheValues: [[theNotification userInfo] objectForKey: @"values"]
	    login: uid
	    url: [[theNotification userInfo] objectForKey: @"url"]
	    key: @"defaults"];
    }
}

//
//
//
- (void) _userSettingsHaveLoaded: (NSNotification *) theNotification
{
  NSString *uid;

  uid = [[theNotification userInfo] objectForKey: @"uid"];
  //NSLog(@"Loading user settings for UID: %@", uid);
  if (![self userSettingsForLogin: uid])
    {
      [self _cacheValues: [[theNotification userInfo] objectForKey: @"values"]
	    login: uid
	    url: [[theNotification userInfo] objectForKey: @"url"]
	    key: @"settings"];
    }
}

//
//
//
- (void) _userSettingsHaveChanged: (NSNotification *) theNotification
{
  SOGoUserDefaults *settings;
  NSString *uid;
  
  uid = [[theNotification userInfo] objectForKey: @"uid"];
  //NSLog(@"Updating user settings for UID: %@", uid);
  settings = (SOGoUserDefaults *)[self userSettingsForLogin: uid];
  if (settings)
    {
#if defined(THREADSAFE)
      [lock lock];
#endif
      [settings setValues: [[theNotification userInfo] objectForKey: @"values"]];
      [[users objectForKey: uid] setObject: [[NSDate date] addTimeInterval: [SOGoCache cleanupInterval]]
				 forKey: @"cleanupDate"];
#if defined(THREADSAFE)
      [lock unlock];
#endif
    }
  else
    {
      [self _cacheValues: [[theNotification userInfo] objectForKey: @"values"]
	    login: uid
	    url: [[theNotification userInfo] objectForKey: @"url"]
	    key: @"settings"];
    }
}

//
//
//
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

  // We cleanup the user cache
  userIDs = [[users allKeys] objectEnumerator];
  count = 0;
  while ((currentID = [userIDs nextObject]))
    {
      currentEntry = [users objectForKey: currentID];
      
      if ([now earlierDate: [currentEntry objectForKey: @"cleanupDate"]] == now)
	{
	  [users removeObjectForKey: currentID];
	  count++;
	}
    }
  
  if (count)
    [self logWithFormat: @"cleaned %d users records from users cache",
	  count];

#if defined(THREADSAFE)
  [lock unlock];
#endif
}

@end
