/* NSDictionary+Utilities.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2011 Inverse inc.
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
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSException.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSString.h>

#import "NSArray+Utilities.h"
#import "NSString+Utilities.h"

#import "NSDictionary+Utilities.h"

@implementation NSDictionary (SOGoDictionaryUtilities)

+ (NSDictionary *) dictionaryFromStringsFile: (NSString *) file
{
  NSString *serialized;
  NSMutableData *content;
  NSDictionary *newDictionary;

  content = [NSMutableData data];
  [content appendBytes: "{" length: 1];
  [content appendData: [NSData dataWithContentsOfFile: file]];
  [content appendBytes: "}" length: 1];
  serialized = [[NSString alloc] initWithData: content
				 encoding: NSUTF8StringEncoding];
  [serialized autorelease];
  newDictionary = [serialized propertyList];

  return newDictionary;
}

- (NSString *) jsonRepresentation
{
  NSMutableArray *values;
  NSString *representation, *currentKey, *currentValue, *currentPair;
  NSEnumerator *keys;

  values = [NSMutableArray array];
  keys = [[self allKeys] objectEnumerator];
  while ((currentKey = [keys nextObject]))
    {
      currentValue = [[self objectForKey: currentKey] jsonRepresentation];
      currentPair = [NSString stringWithFormat: @"%@: %@",
			      [currentKey jsonRepresentation], currentValue];
      [values addObject: currentPair];
    }
  representation = [NSString stringWithFormat: @"{%@}",
			     [values componentsJoinedByString: @", "]];

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

- (NSComparisonResult) caseInsensitiveDisplayNameCompare: (NSDictionary *) theDictionary
{
  return [[self objectForKey: @"cn"] caseInsensitiveCompare: [theDictionary objectForKey: @"cn"]];
}

@end

@implementation NSMutableDictionary (SOGoDictionaryUtilities)

- (void) setObject: (id) object
           forKeys: (NSArray *) keys
{
  unsigned int count, max;

  max = [keys count];
  for (count = 0; count < max; count++)
    [self setObject: object
             forKey: [keys objectAtIndex: count]];
}

- (void) setObjects: (NSArray *) objects
	    forKeys: (NSArray *) keys
{
  unsigned int count, max;

  max = [objects count];
  if ([keys count] == max)
    for (count = 0; count < max; count++)
      [self setObject: [objects objectAtIndex: count]
	    forKey: [keys objectAtIndex: count]];
  else
    [NSException raise: NSInvalidArgumentException
		 format: @"Number of objects does not match"
		 @" the number of keys."];
}

@end
