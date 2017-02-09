
/* SOGoSockDScanner.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2017 Inverse inc.
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


#import "SOGoSockDScanner.h"

@implementation SOGoSockDScanner

- (id) init
{
  if ((self = [super init]))
    {
      operation = nil;
    }

  return self;
}

- (void) _parseRequest
{
  NSString *method, *key, *value;
  NSMutableArray *multiValue;
  NSMutableDictionary *parameters;
  NSUInteger maxLocation;
  BOOL error;

  /* method */
  if ([self scanUpToString: @"\n" intoString: &method])
    {
      parameters = [NSMutableDictionary new];
      error = NO;
      maxLocation = [[self string] length] - 1;
      while (!error && [self scanLocation] < maxLocation)
        {
          if ([self scanUpToString: @":" intoString: &key]
              && [self scanUpToString: @"\n" intoString: &value])
            {
              if ([value hasPrefix: @": "])
                value = [value substringFromIndex: 2];
              multiValue = [parameters objectForKey: key];
              if (multiValue)
                {
                  if (![multiValue isKindOfClass: [NSArray class]])
                    {
                      multiValue = [NSMutableArray arrayWithObject: multiValue];
                      [parameters setObject: multiValue forKey: key];
                    }
                  [multiValue addObject: value];
                }
              else
                [parameters setObject: value forKey: key];
            }
          else
            error = YES;
        }
      if (!error)
        operation = [SOGoSockDOperation operationWithMethod: method
                                              andParameters: parameters];
      [parameters release];
    }
}

- (SOGoSockDOperation *) operation
{
  if (!operation)
    [self _parseRequest];

  return operation;
}

@end
