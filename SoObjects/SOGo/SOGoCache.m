/* SOGoCache.m - this file is part of SOGo
 *
 * Copyright (C) 2008 Inverse groupe conseil
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/SoObject.h>

#import "SOGoObject.h"
#import "SOGoUser.h"

#import "SOGoCache.h"

static SOGoCache *sharedCache = nil;

@implementation SOGoCache

+ (SOGoCache *) sharedCache
{
  if (!sharedCache)
    sharedCache = [self new];

  return sharedCache;
}

+ (void) killCache
{
  [sharedCache release];
  sharedCache = nil;
}

- (id) init
{
  if ((self = [super init]))
    {
      cache = [NSMutableDictionary new];
      users = [NSMutableDictionary new];
    }

  return self;
}

- (void) dealloc
{
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
      if (![cache objectForKey: fullPath])
	{
// 	  NSLog (@"registering '%@'", fullPath);
	  [cache setObject: object forKey: fullPath];
	}
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
//   NSLog (@"registerUser: %@", user);

  [users setObject: user forKey: [user login]];
}

- (id) userNamed: (NSString *) name
{
//   NSLog (@"userNamed: %@", name);

  return [users objectForKey: name];
}

@end
