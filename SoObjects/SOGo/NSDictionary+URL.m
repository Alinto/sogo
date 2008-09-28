/* NSDictionary+URL.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse inc.
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

#import "NSDictionary+URL.h"

@implementation NSDictionary (SOGoURLExtension)

- (NSString *) asURLParameters
{
  NSMutableString *urlParameters;
  NSArray *keys;
  NSEnumerator *keysEnum;
  NSString *currentKey, *separator;
  id currentValue;
  BOOL isFirst;

  urlParameters = [NSMutableString new];
  [urlParameters autorelease];

  keys = [self allKeys];
  if ([keys count] > 0)
    {
      isFirst = YES;
      keysEnum = [keys objectEnumerator];
      currentKey = [keysEnum nextObject];
      while (currentKey)
	{
          currentValue = [self objectForKey: currentKey];
          if ([currentValue isKindOfClass: [NSArray class]])
            {
              separator = [NSString stringWithFormat: @"&%@=", currentKey];
              currentValue
                = [currentValue componentsJoinedByString: separator];
            }
          [urlParameters appendFormat: @"%@%@=%@",
                         ((isFirst) ? @"?" : @"&"),
                         currentKey, currentValue];
	  isFirst = NO;
	  currentKey = [keysEnum nextObject];
	}
    }

  return urlParameters;
}

@end
