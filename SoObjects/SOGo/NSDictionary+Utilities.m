/* NSDictionary+Utilities.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
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
#import <Foundation/NSData.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSString.h>

#import "NSArray+Utilities.h"
#import "NSObject+Utilities.h"
#import "NSDictionary+Utilities.h"

@implementation NSDictionary (SOGoDictionaryUtilities)

+ (NSDictionary *) dictionaryFromStringsFile: (NSString *) file
{
  NSString *serialized;
  NSMutableData *content;
  NSDictionary *newDictionary;

  content = [NSMutableData new];
  [content appendBytes: "{" length: 1];
  [content appendData: [NSData dataWithContentsOfFile: file]];
  [content appendBytes: "}" length: 1];
  serialized = [[NSString alloc] initWithData: content
				 encoding: NSUTF8StringEncoding];
  [content release];
  newDictionary = [serialized propertyList];
  [serialized release];

  return newDictionary;
}

- (NSString *) jsonRepresentation
{
  NSMutableArray *values;
  NSString *representation, *currentKey, *currentValue, *currentPair;
  NSEnumerator *keys;

  values = [NSMutableArray new];
  keys = [[self allKeys] objectEnumerator];
  currentKey = [keys nextObject];
  while (currentKey)
    {
      currentValue = [[self objectForKey: currentKey] jsonRepresentation];
      currentPair = [NSString stringWithFormat: @"%@: %@",
			      [currentKey jsonRepresentation], currentValue];
      [values addObject: currentPair];
      currentKey = [keys nextObject];
    }
  representation = [NSString stringWithFormat: @"{%@}",
			     [values componentsJoinedByString: @", "]];
  [values release];

  return representation;
}

- (NSString *) keysWithFormat: (NSString *) keyFormat
{
  NSArray *keys, *allKeys;
  unsigned int count, max;
  NSMutableString *keysWithFormat;
  id value;

  keysWithFormat = [NSMutableString stringWithString: keyFormat];

  allKeys = [self allKeys];
  keys = [allKeys stringsWithFormat: @"%{%@}"];

  max = [allKeys count];
  for (count = 0; count < max; count++)
    {
      value = [self objectForKey: [allKeys objectAtIndex: count]];
      if ([value isKindOfClass: [NSNull class]])
	[keysWithFormat replaceString: [keys objectAtIndex: count]
			withString: @""];
      else
	[keysWithFormat replaceString: [keys objectAtIndex: count]
			withString: [value description]];
    }

  return keysWithFormat;
}

@end
