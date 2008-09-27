/* CardElement.m - this file is part of SOPE
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSRange.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NGQuotedPrintableCoding.h>

#import "NSArray+NGCards.h"
#import "NSDictionary+NGCards.h"
#import "CardVersitRenderer.h"

#import "CardElement.h"
#import "CardGroup.h"

@implementation CardElement

+ (id) elementWithTag: (NSString *) aTag
{
  id newElement;

  newElement = [self new];
  [newElement autorelease];
  [newElement setTag: aTag];

  return newElement;
}

+ (id) simpleElementWithTag: (NSString *) aTag
                      value: (NSString *) aValue
{
  id newElement;

  newElement = [self elementWithTag: aTag];
  [newElement addValue: aValue];

  return newElement;
}

+ (id) simpleElementWithTag: (NSString *) aTag
                 singleType: (NSString *) aType
                      value: (NSString *) aValue
{
  id newElement;

  newElement = [self simpleElementWithTag: aTag
                     value: aValue];
  [newElement addType: aType];

  return newElement;
}

+ (id) elementWithTag: (NSString *) aTag
           attributes: (NSDictionary *) someAttributes
               values: (NSArray *) someValues
{
  id newElement;

  newElement = [self new];
  [newElement autorelease];
  [newElement setTag: aTag];
  [newElement addAttributes: someAttributes];
  [newElement addValues: someValues];

  return newElement;
}

- (id) init
{
  if ((self = [super init]))
    {
      parent = nil;
      tag = nil;
      group = nil;
      values = [NSMutableArray new];
      attributes = [NSMutableDictionary new];
    }

  return self;
}

- (void) dealloc
{
  if (tag)
    [tag release];
  [values release];
  [attributes release];
  [super dealloc];
}

- (void) setParent: (CardGroup *) aParent
{
  parent = aParent;
}

- (id) parent
{
  return parent;
}

- (void) setTag: (NSString *) aTag
{
  ASSIGN (tag, aTag);
}

- (void) setGroup: (NSString *) aGroup
{
  ASSIGN (group, aGroup);
}

- (NSString *) group
{
  return group;
}

- (void) addValue: (NSString *) aValue
{
  if (!aValue)
    aValue = @"";
  [values addObject: aValue];
}

- (void) addValues: (NSArray *) someValues
{
  [values addObjectsFromArray: someValues];
}

- (void) addAttribute: (NSString *) anAttribute
                value: (NSString *) aValue
{
  NSMutableArray *attrValues;

  if (!aValue)
    aValue = @"";

  attrValues = [attributes objectForCaseInsensitiveKey: anAttribute];
  if (!attrValues)
    {
      attrValues = [NSMutableArray new];
      [attrValues autorelease];
      [attributes setObject: attrValues forKey: anAttribute];
    }

  [attrValues addObject: aValue];
}

- (void) removeValue: (NSString *) aValue
       fromAttribute: (NSString *) anAttribute
{
  NSMutableArray *attrValues;
  NSString *currentValue;

  if (!aValue)
    aValue = @"";

  attrValues = [attributes objectForCaseInsensitiveKey: anAttribute];
  if (attrValues)
    {
      currentValue = [attrValues valueForCaseInsensitiveString: aValue];
      while (currentValue)
        {
          [attrValues removeObject: currentValue];
          currentValue = [attrValues valueForCaseInsensitiveString: aValue];
        }
    }
}

- (void) addAttributes: (NSDictionary *) someAttributes
{
  NSEnumerator *keys;
  NSString *currentKey;
  NSMutableArray *oldValues;
  NSArray *newValues;

  keys = [[someAttributes allKeys] objectEnumerator];
  currentKey = [keys nextObject];
  while (currentKey)
    {
      oldValues = [attributes objectForCaseInsensitiveKey: currentKey];
      newValues = [someAttributes objectForKey: currentKey];
      if (oldValues)
        [oldValues addObjectsFromArray: newValues];
      else
        [attributes setObject: newValues forKey: currentKey];
      currentKey = [keys nextObject];
    }
}

- (void) addType: (NSString *) aType
{
  [self addAttribute: @"type" value: aType];
}

- (NSString *) tag
{
  return tag;
}

- (NSArray *) values
{
  return values;
}

- (NSDictionary *) attributes
{
  return attributes;
}

- (BOOL) hasAttribute: (NSString *) anAttribute
          havingValue: (NSString *) aValue
{
  NSArray *attribute;

  attribute = [attributes objectForCaseInsensitiveKey: anAttribute];

  return (attribute && [attribute hasCaseInsensitiveString: aValue]);
}

- (void) setValue: (unsigned int) anInt
               to: (NSString *) aValue
{
  unsigned int count, max;

  if (!aValue)
    aValue = @"";
  max = [values count];
  for (count = max; count <= anInt; count++)
    [self addValue: @""];

  [values replaceObjectAtIndex: anInt withObject: aValue];
}

- (NSString *) value: (unsigned int) anInt
{
  NSString *realValue, *value, *encoding;

  if ([values count] <= anInt)
    value = @"";
  else
    {
      realValue = [values objectAtIndex: anInt];
      encoding = [[self value: 0 ofAttribute: @"encoding"] lowercaseString];
      if ([encoding length])
	{
	  if ([encoding isEqualToString: @"quoted-printable"])
	    value = [realValue stringByDecodingQuotedPrintable];
	  else if ([encoding isEqualToString: @"base64"])
	    value = [realValue stringByDecodingBase64];
	  else
	    {
	      value = realValue;
	      if (![encoding isEqualToString: @"8bit"])
		[self logWithFormat: @"unknown encoding '%@'", encoding];
	    }
	}
      else
	value = realValue;
    }

  return value;
}

- (unsigned int) _namedValue: (NSString *) aValueName
{
  NSString *prefix, *value;
  unsigned int count, max, result;

  result = NSNotFound;

  prefix = [NSString stringWithFormat: @"%@=", [aValueName uppercaseString]];
  max = [values count];
  count = 0;

  while (result == NSNotFound && count < max)
    {
      value = [[values objectAtIndex: count] uppercaseString];
      if ([value hasPrefix: prefix])
        result = count;
      else
        count++;
    }

  return result;
}

- (void) setNamedValue: (NSString *) aValueName
                    to: (NSString *) aValue
{
  NSString *newValue;
  unsigned int index;

  if (!aValue)
    aValue = @"";
  newValue = [NSString stringWithFormat: @"%@=%@",
                       [aValueName uppercaseString],
                       aValue];
  index = [self _namedValue: aValueName];
  if (index == NSNotFound)
    [self addValue: newValue];
  else
    {
      if ([aValue length])
        [self setValue: index to: newValue];
      else
        [values removeObjectAtIndex: index];
    }
}

- (NSString *) namedValue: (NSString *) aValueName
{
  unsigned int index;
  NSRange equalSign;
  NSString *value;

  index = [self _namedValue: aValueName];
  if (index == NSNotFound)
    value = @"";
  else
    {
      value = [values objectAtIndex: index];
      equalSign = [value rangeOfString: @"="];
      if (equalSign.location != NSNotFound)
        value = [value substringFromIndex: equalSign.location + 1];
    }

  return value;
}

- (void) setValue: (unsigned int) anInt
      ofAttribute: (NSString *) anAttribute
               to: (NSString *) aValue
{
  NSMutableArray *attrValues;

  if (!aValue)
    aValue = @"";

  attrValues = [attributes objectForCaseInsensitiveKey: anAttribute];
  if (!attrValues)
    {
      attrValues = [NSMutableArray new];
      [attrValues autorelease];
      [attributes setObject: attrValues forKey: anAttribute];
    }

  while ([attrValues count] <= anInt)
    [attrValues addObject: @""];
  [attrValues replaceObjectAtIndex: anInt
              withObject: aValue];
}

- (NSString *) value: (unsigned int) anInt
         ofAttribute: (NSString *) anAttribute
{
  NSArray *attrValues;
  NSString *value;

  attrValues = [attributes objectForCaseInsensitiveKey: anAttribute];
  if (attrValues && [attrValues count] > anInt)
    value = [attrValues objectAtIndex: anInt];
  else
    value = @"";

  return value;
}

- (NSString *) description
{
  NSArray *attrs;
  NSMutableString *str;
  unsigned int count, max;
  NSString *attr;

  str = [NSMutableString stringWithCapacity:64];
  [str appendFormat:@"<%p[%@]:", self, NSStringFromClass([self class])];
  if (group)
    [str appendFormat: @"%@ (group: %@)\n", tag, group];
  else
    [str appendFormat: @"%@\n", tag, group];

  attrs = [attributes allKeys];
  max = [attrs count];
  if (max > 0)
    {
      [str appendFormat: @"\n  %d attributes: {\n", [attrs count]];
      for (count = 0; count < max; count++)
        {
          attr = [attrs objectAtIndex: count];
          [str appendFormat: @"  %@: %@\n",
               attr, [attributes objectForKey: attr]];
        }
      [str appendFormat: @"}"];
    }

  max = [values count];
  if (max > 0)
    {
      [str appendFormat: @"\n  %d values: {\n", [values count]];
      for (count = 0; count < max; count++)
        [str appendFormat: @"  %@\n", [values objectAtIndex: count]];
      [str appendFormat: @"}"];
    }

  [str appendString:@">"];

  return str;
}

- (BOOL) isVoid
{
  BOOL result;
  NSString *value;
  NSEnumerator *enu;

  result = YES;

  enu = [values objectEnumerator];
  value = [enu nextObject];
  while (value && result)
    {
      result = ([value length] == 0);
      value = [enu nextObject];
    }

  return result;
}

- (NSString *) versitString
{
  NSString *string;
  CardVersitRenderer *renderer;

  renderer = [CardVersitRenderer new];
  string = [renderer render: self];
  [renderer release];

  if ([string hasSuffix: @"\r\n"])
    string = [string substringToIndex: [string length] - 2];

  return string;
}

- (id) elementWithClass: (Class) elementClass
{
  CardElement *newElement;

  if ([self isKindOfClass: elementClass])
    newElement = self;
  else
    {
      newElement = [elementClass new];
      [newElement autorelease];
      [newElement setTag: tag];
      [newElement setValuesAsCopy: values];
      [newElement setAttributesAsCopy: attributes];
      if (group)
        [newElement setGroup: group];
      if (parent)
        {
          [newElement setParent: parent];
          [parent replaceThisElement: self
                  withThisOne: newElement];
        }
    }

  return newElement;
}

- (void) setValuesAsCopy: (NSMutableArray *) someValues
{
  [values release];
  values = someValues;
  [values retain];
}

- (void) setAttributesAsCopy: (NSMutableDictionary *) someAttributes
{
  [attributes release];
  attributes = someAttributes;
  [attributes retain];
}

- (CardGroup *) searchParentOfClass: (Class) parentClass
{
  CardGroup *current;
  CardGroup *found;

  found = nil;
  current = parent;
  while (current && !found)
    if ([current isKindOfClass: parentClass])
      found = current;
    else
      current = [current parent];

  return found;
}

/* NSCopying */

- (NSMutableArray *) deepCopyOfArray: (NSArray *) oldArray
			    withZone: (NSZone *) aZone
{
  NSMutableArray *newArray;
  unsigned int count, max;
  id newChild;

  newArray = [NSMutableArray array];

  max = [oldArray count];
  for (count = 0; count < max; count++)
    {
      newChild = [[oldArray objectAtIndex: count] mutableCopyWithZone: aZone];
      [newArray addObject: newChild];
    }

  return newArray;
}

- (NSMutableDictionary *) deepCopyOfDictionary: (NSDictionary *) oldDictionary
				      withZone: (NSZone *) aZone
{
  NSMutableDictionary *newDict;
  NSArray *newKeys, *newValues;

  newKeys = [self deepCopyOfArray: [oldDictionary allKeys]
		  withZone: aZone];
  newValues = [self deepCopyOfArray: [oldDictionary allValues]
		    withZone: aZone];
  newDict = [NSMutableDictionary dictionaryWithObjects: newValues
				 forKeys: newKeys];

  return newDict;
}

- (id) copyWithZone: (NSZone *) aZone
{
  CardElement *new;

  new = [[self class] new];
  [new setTag: [tag copyWithZone: aZone]];
  [new setGroup: [group copyWithZone: aZone]];
  [new setParent: nil];
  [new setValuesAsCopy: [self deepCopyOfArray: values withZone: aZone]];
  [new setAttributesAsCopy: [self deepCopyOfDictionary: attributes
				  withZone: aZone]];

  return new;
}

/* NSMutableCopying */
- (id) mutableCopyWithZone: (NSZone *) aZone
{
  CardElement *new;

  new = [[self class] new];
  [new setTag: [tag mutableCopyWithZone: aZone]];
  [new setGroup: [group mutableCopyWithZone: aZone]];
  [new setParent: nil];
  [new setValuesAsCopy: [self deepCopyOfArray: values withZone: aZone]];
  [new setAttributesAsCopy: [self deepCopyOfDictionary: attributes
				  withZone: aZone]];

  return new;
}

@end
