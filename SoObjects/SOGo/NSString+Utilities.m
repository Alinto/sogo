/* NSString+Utilities.m - this file is part of SOGo
 *
 * Copyright (C) 2006  Inverse group conseil
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

#import "NSString+Utilities.h"
#import "NSDictionary+URL.h"

@implementation NSString (SOGoURLExtension)

- (NSString *) composeURLWithAction: (NSString *) action
			 parameters: (NSDictionary *) urlParameters
			    andHash: (BOOL) useHash
{
  NSMutableString *completeURL;

  completeURL = [NSMutableString new];
  [completeURL autorelease];

  [completeURL appendString: [self urlWithoutParameters]];
  if (![completeURL hasSuffix: @"/"])
    [completeURL appendString: @"/"];
  [completeURL appendString: action];
  [completeURL appendString: [urlParameters asURLParameters]];
  if (useHash)
    [completeURL appendString: @"#"];

  return completeURL;
}

- (NSString *) hostlessURL
{
  NSString *newURL;
  NSRange hostR, locationR;

  if ([self hasPrefix: @"/"])
    {
      newURL = [self copy];
      [newURL autorelease];
    }
  else
    {
      hostR = [self rangeOfString: @"://"];
      locationR = [[self substringFromIndex: (hostR.location + hostR.length)]
                    rangeOfString: @"/"];
      newURL = [self substringFromIndex: (hostR.location + hostR.length + locationR.location)];
    }

  return newURL;
}

- (NSString *) urlWithoutParameters;
{
  NSRange r;
  NSString *newUrl;
  
  r = [self rangeOfString:@"?" options: NSBackwardsSearch];
  if (r.length > 0)
    newUrl = [self substringToIndex: NSMaxRange(r) - 1];
  else
    newUrl = self;

  return newUrl;
}

- (NSString *) davMethodToObjC
{
  NSMutableString *newName;
  NSEnumerator *components;
  NSString *component;

  newName = [NSMutableString stringWithString: @"dav"];
  components = [[self componentsSeparatedByString: @"-"] objectEnumerator];
  component = [components nextObject];
  while (component)
    {
      [newName appendString: [component capitalizedString]];
      component = [components nextObject];
    }

  return newName;
}

#ifndef GNUSTEP_BASE_LIBRARY
- (BOOL) boolValue
{
  return !([self isEqualToString: @"0"]
	   || [self isEqualToString: @"NO"]);
}

#ifdef LIB_FOUNDATION_LIBRARY
- (NSString *) stringByAppendingPathComponent: (NSString *) component
{
  NSMutableArray *components;
  NSString *newString;

  components = [NSMutableArray new];
  [components addObjectsFromArray: [self componentsSeparatedByString: @"/"]];
  [components addObject: component];
  newString = [components componentsJoinedByString: @"/"];
  [components release];

  return newString;
}
#endif

#endif

@end
