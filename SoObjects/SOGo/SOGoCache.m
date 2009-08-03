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
 * [ Cache Structure ]
 *
 * users               value = instances of SOGoUser > flushed after the completion of every SOGo requests
 * <uid>+defaults      value = NSDictionary instance > user's defaults
 * <uid>+settings      value = NSDictionary instance > user's settings
 * <uid>+attributes    value = NSMutableDictionary instance > user's LDAP attributes
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
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

#import "NSDictionary+BSJSONAdditions.h"

// We define the default value for cleaning up cached
// users' preferences. This value should be relatively
// high to avoid useless database calls.
static NSTimeInterval cleanupInterval = 300;

static NSMutableDictionary *cache = nil;
static NSMutableDictionary *users = nil;

static NSString *memcachedServerName = @"localhost";

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
    sharedCache = [[self alloc] init];
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

  // This is essential for refetching the cached values in case something has changed
  // accross various sogod processes
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
      memcached_return error;
      
      cache = [[NSMutableDictionary alloc] init];
      users = [[NSMutableDictionary alloc] init];
      
      // We fire our timer that will cleanup cache entries
      cleanupSetting = [[NSUserDefaults standardUserDefaults] 
			 objectForKey: @"SOGoCacheCleanupInterval"];
      
      if (cleanupSetting && [cleanupSetting doubleValue] > 0.0)
	cleanupInterval = [cleanupSetting doubleValue];
      
      [self logWithFormat: @"Cache cleanup interval set every %f seconds for memcached",
	    cleanupInterval];

      handle = memcached_create(NULL);

      if (handle)
	{
	  servers = memcached_server_list_append(NULL, [memcachedServerName UTF8String], 11211, &error);
	  error = memcached_server_push(handle, servers);
	}
    }

  return self;
}

- (void) dealloc
{
  memcached_server_free(servers);
  memcached_free(handle);
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

  if ([name length])
    {
      names = [NSMutableArray array];

      [names addObject: name];
      currentObject = container;
      while ((nameInContainer = [currentObject nameInContainer]))
        {
          [names addObject: nameInContainer];
          currentObject = [currentObject container];
        }

      fullPath = [names componentsJoinedByString: @"/"];
    }
  else
    fullPath = nil;

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
#if defined(THREADSAFE)
  [lock lock];
#endif
  [users setObject: user  forKey: [user login]];
#if defined(THREADSAFE)
  [lock unlock];
#endif
}

- (id) userNamed: (NSString *) name
{
  return [users objectForKey: name];
}

//
// For non-blocking cache method, see memcached_behavior_set and MEMCACHED_BEHAVIOR_NO_BLOCK
// memcached is thread-safe so no need to lock here.
//
- (void) cacheValues: (NSDictionary *) theAttributes
	      ofType: (NSString *) theType
	    forLogin: (NSString *) theLogin
{
  memcached_return error;
  const char *key, *value;
  unsigned int len, vlen;

  if (!handle)
    return;

  key = [[NSString stringWithFormat: @"%@+%@", theLogin, theType] UTF8String];
  len = strlen(key);

  value = [[theAttributes jsonStringValue] UTF8String];
  vlen = strlen(value);

  error = memcached_set(handle, key, len, value, vlen, cleanupInterval, 0);

  if (error != MEMCACHED_SUCCESS)
    [self logWithFormat: @"memcached error: unable to cache values with subtype %@ for user %@", theType, theLogin];
  //else
  //[self logWithFormat: @"memcached: cached values (%s) with subtype %@ for user %@", value, theType, theLogin];
}

- (NSDictionary *) _valuesOfType: (NSString *) theType
                        forLogin: (NSString *) theLogin
{
  NSDictionary *d;

  memcached_return rc;
  const char *key;
  char *s;
  unsigned int len, vlen, flags;

  if (!handle)
    return nil;

  key = [[NSString stringWithFormat: @"%@+%@", theLogin, theType] UTF8String];
  len = strlen(key);
  d = nil;

  s = memcached_get(handle, key, len, &vlen, &flags, &rc);

  if (rc == MEMCACHED_SUCCESS && s)
    {
      NSString *v;

      v = [NSString stringWithUTF8String: s];
      d = [NSDictionary dictionaryWithJSONString: v];
      //[self logWithFormat: @"read values (%@) for subtype %@ for user %@", [d description], theType, theLogin];

      free(s);
    }

  return d;
}


- (NSMutableDictionary *) userAttributesForLogin: (NSString *) theLogin
{
  id o;

  o = [self _valuesOfType: @"attributes"  forLogin: theLogin];

  if (o)
    return [NSMutableDictionary dictionaryWithDictionary: o];

  return nil;
}

- (NSDictionary *) userDefaultsForLogin: (NSString *) theLogin
{
  return [self _valuesOfType: @"defaults"  forLogin: theLogin];
}

- (NSDictionary *) userSettingsForLogin: (NSString *) theLogin
{
  return [self _valuesOfType: @"settings"  forLogin: theLogin];
}

@end
