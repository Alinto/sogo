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
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimer.h>

#import <NGObjWeb/SoObject.h>
#import <NGExtensions/NSObject+Logs.h>

#import "SOGoObject.h"
#import "SOGoSystemDefaults.h"
#import "SOGoUser.h"
#import "SOGoUserProfile.h"

#import "SOGoCache.h"

@implementation SOGoCache

+ (SOGoCache *) sharedCache
{
  static SOGoCache *sharedCache = nil;

  if (!sharedCache)
    sharedCache = [self new];

  return sharedCache;
}

- (void) killCache
{
  [cache removeAllObjects];

  // This is essential for refetching the cached values in case something has changed
  // accross various sogod processes
  [users removeAllObjects];
  [localCache removeAllObjects];
}

- (id) init
{
  SOGoSystemDefaults *sd;

  if ((self = [super init]))
    {
      memcached_return error;
      
      cache = [NSMutableDictionary new];
      users = [NSMutableDictionary new];

      // localCache is used to avoid going all the time to the memcached
      // server during each request. We'll cache the value we got from
      // memcached for the duration of the current request - which is good
      // enough for pretty much all cases. We surely don't want to get new
      // defaults/settings during the _same_ requests, it could produce
      // relatively strange behaviors
      localCache = [NSMutableDictionary new];

      handle = memcached_create(NULL);
      if (handle)
	{
#warning We could also make the port number configurable and even make use \
  of NGNetUtilities for that.

          sd = [SOGoSystemDefaults sharedSystemDefaults];
          // We define the default value for cleaning up cached users'
          // preferences. This value should be relatively high to avoid
          // useless database calls.

          cleanupInterval = [sd cacheCleanupInterval];
          ASSIGN (memcachedServerName, [sd memcachedHost]);

          [self logWithFormat: @"Cache cleanup interval set every %f seconds",
                cleanupInterval];
          [self logWithFormat: @"Using host '%@' as server",
                memcachedServerName];
	  servers
            = memcached_server_list_append(NULL,
                                           [memcachedServerName UTF8String],
                                           11211, &error);
	  error = memcached_server_push(handle, servers);
	}
    }

  return self;
}

- (void) dealloc
{
  memcached_server_free(servers);
  memcached_free(handle);
  [memcachedServerName release];
  [cache release];
  [users release];
  [localCache release];
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
      if (![cache objectForKey: fullPath])
	{
	  [cache setObject: object forKey: fullPath];
	}
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
             withName: (NSString *) userName
{ 
  [users setObject: user forKey: userName];
}

- (id) userNamed: (NSString *) name
{
  return [users objectForKey: name];
}

//
// For non-blocking cache method, see memcached_behavior_set and MEMCACHED_BEHAVIOR_NO_BLOCK
// memcached is thread-safe so no need to lock here.
//
- (void) _cacheValues: (NSString *) theAttributes
	       ofType: (NSString *) theType
	     forLogin: (NSString *) theLogin
{
  memcached_return error;
  NSString *keyName;
  NSData *key, *value;

  keyName = [NSString stringWithFormat: @"%@+%@", theLogin, theType];
  if (handle)
    {
      key = [keyName dataUsingEncoding: NSUTF8StringEncoding];
      value = [theAttributes dataUsingEncoding: NSUTF8StringEncoding];
      error = memcached_set(handle,
                            [key bytes], [key length],
                            [value bytes], [value length],
                            cleanupInterval, 0);
      [localCache setObject: theAttributes forKey: keyName];

      if (error != MEMCACHED_SUCCESS)
        [self logWithFormat: @"memcached error: unable to cache values with subtype '%@' for user '%@'", theType, theLogin];
      //else
      //[self logWithFormat: @"memcached: cached values (%s) with subtype %@
      //for user %@", value, theType, theLogin];
    }
   else
    [self errorWithFormat: @"attempting to cache value for key '%@' while"
          " no handle exists", keyName];
}

- (NSString *) _valuesOfType: (NSString *) theType
                    forLogin: (NSString *) theLogin
{
  NSString *valueString, *keyName;
  NSData *key;
  char *value;
  size_t vlen;
  memcached_return rc;
  unsigned int flags;

  valueString = nil;

  keyName = [NSString stringWithFormat: @"%@+%@", theLogin, theType];
  if (handle)
    {
      valueString = [localCache objectForKey: keyName];
      if (!valueString)
        {
          key = [keyName dataUsingEncoding: NSUTF8StringEncoding];
          value = memcached_get (handle, [key bytes], [key length],
                                 &vlen, &flags, &rc);
          if (rc == MEMCACHED_SUCCESS && value)
            {
              valueString
                = [[NSString alloc] initWithBytesNoCopy: value
                                                 length: vlen
                                               encoding: NSUTF8StringEncoding
                                           freeWhenDone: YES];
              [valueString autorelease];
              // Cache the value in our localCache
              [localCache setObject: valueString forKey: keyName];
            }
        }
    }
   else
     [self errorWithFormat: @"attempting to retrieved cached value for key"
           @" '%@' while no handle exists", keyName];

  return valueString;
}

- (void) setUserAttributes: (NSString *) theAttributes
                  forLogin: (NSString *) login
{
  [self _cacheValues: theAttributes ofType: @"attributes"
            forLogin: login];
}

- (NSString *) userAttributesForLogin: (NSString *) theLogin
{
  return [self _valuesOfType: @"attributes" forLogin: theLogin];
}

- (void) setUserDefaults: (NSString *) theAttributes
                forLogin: (NSString *) login
{
  [self _cacheValues: theAttributes ofType: @"defaults"
            forLogin: login];
}

- (NSString *) userDefaultsForLogin: (NSString *) theLogin
{
  return [self _valuesOfType: @"defaults" forLogin: theLogin];
}

- (void) setUserSettings: (NSString *) theAttributes
                forLogin: (NSString *) login
{
  [self _cacheValues: theAttributes ofType: @"settings"
            forLogin: login];
}

- (NSString *) userSettingsForLogin: (NSString *) theLogin
{
  return [self _valuesOfType: @"settings" forLogin: theLogin];
}

@end
