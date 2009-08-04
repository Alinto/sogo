/* SOGoCache.h - this file is part of SOGo
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

#ifndef SOGOCACHE_H
#define SOGOCACHE_H

#import <Foundation/NSObject.h>

#include <libmemcached/memcached.h>

@class NSMutableDictionary;
@class NSString;
@class NSTimer;
@class NSUserDefaults;

@class SOGoObject;
@class SOGoUser;
@class SOGoUserDefaults;

@interface SOGoCache : NSObject
{
  @private
    NSTimer *_cleanupTimer;
    memcached_server_st *servers;
    memcached_st *handle;
}

+ (NSTimeInterval) cleanupInterval;
+ (SOGoCache *) sharedCache;
+ (void) killCache;

- (void) registerObject: (id) object
	       withName: (NSString *) name
	    inContainer: (SOGoObject *) container;
- (id) objectNamed: (NSString *) name
       inContainer: (SOGoObject *) container;

- (void) registerUser: (SOGoUser *) user;
- (id) userNamed: (NSString *) name;

- (NSMutableDictionary *) userAttributesForLogin: (NSString *) theLogin;
- (NSDictionary *) userDefaultsForLogin: (NSString *) theLogin;
- (NSDictionary *) userSettingsForLogin: (NSString *) theLogin;

- (void) cacheValues: (NSDictionary *) theAttributes
	      ofType: (NSString *) theType
	    forLogin: (NSString *) theLogin;

@end

#endif /* SOGOCACHE_H */
