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
  [newElement setSingleValue: aValue forKey: @""];

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

- (id) init
{
  if ((self = [super init]))
    {
      parent = nil;
      tag = nil;
      group = nil;
      values = [NSMutableDictionary new];
      attributes = [NSMutableDictionary new];
    }

  return self;
}

- (void) dealloc
{
  [tag release];
  [group release];
  [attributes release];
  [values release];
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

- (NSString *) tag
{
  return tag;
}

- (void) setGroup: (NSString *) aGroup
{
  ASSIGN (group, aGroup);
}

- (NSString *) group
{
  return group;
}

/* values */
- (void) setValues: (NSMutableDictionary *) newValues
{
  ASSIGN (values, newValues);
}

- (NSMutableDictionary *) values
{
  return values;
}

- (void) setValues: (NSMutableArray *) newValues
           atIndex: (NSUInteger) idx
            forKey: (NSString *) key
{
  NSMutableArray *oldValues, *subValues;

  oldValues = [self valuesForKey: key];
  if (!oldValues)
    {
      oldValues = [NSMutableArray new];
      [values setObject: oldValues forKey: key];
      [oldValues release];
    }

  while ([oldValues count] < (idx + 1))
    {
      subValues = [NSMutableArray new];
      [oldValues addObject: subValues];
      [subValues release];
    }

  if (!newValues)
    newValues = [NSMutableArray array];
  [oldValues replaceObjectAtIndex: idx withObject: newValues];
}

- (void) setSingleValue: (NSString *) newValue
                atIndex: (NSUInteger) idx
                 forKey: (NSString *) key
{
  NSMutableArray *subValues;

  if (newValue)
    {
      subValues = [NSMutableArray new];
      [subValues addObject: newValue];
    }
  else
    subValues = nil;
  [self setValues: subValues atIndex: idx forKey: key];
  [subValues release];
}

- (void) setSingleValue: (NSString *) newValue
                 forKey: (NSString *) key
{
  [self setSingleValue: newValue
               atIndex: 0 forKey: key];
}

- (NSMutableArray *) valuesForKey: (NSString *) key
{
  return [values objectForKey: [key lowercaseString]];
}

- (NSMutableArray *) valuesAtIndex: (NSUInteger) idx
                            forKey: (NSString *) key
{
  return [[self valuesForKey: key] objectAtIndex: idx];
}

- (NSString *) flattenedValueAtIndex: (NSUInteger) idx
                              forKey: (NSString *) key
{
  NSMutableArray *orderedValues, *sValues;
  NSUInteger count, max;
  NSMutableString *flattenedValues;
  NSString *encoding, *realValue, *value;

  flattenedValues = [NSMutableString string];

  orderedValues = [self valuesForKey: key];
  max = [orderedValues count];
  if (max > idx)
    {
      encoding = [[self value: 0 ofAttribute: @"encoding"]
                   lowercaseString];
      sValues = [orderedValues objectAtIndex: idx];
      max = [sValues count];
      for (count = 0; count < max; count++)
        {
          if (count > 0)
            [flattenedValues appendString: @","];
          realValue = [sValues objectAtIndex: count];
          if ([encoding isEqualToString: @"quoted-printable"])
            value = [realValue stringByDecodingQuotedPrintable];
          else if ([encoding isEqualToString: @"base64"])
            value = [realValue stringByDecodingBase64];
          else
            {
              value = realValue;
              if ([encoding length] && ![encoding isEqualToString: @"8bit"])
                [self logWithFormat: @"unknown encoding '%@'", encoding];
            }

          [flattenedValues appendString: value];
        }
    }

  return flattenedValues;
}

- (NSString *) flattenedValuesForKey: (NSString *) key
{
  NSMutableArray *orderedValues, *sValues;
  NSUInteger count, max, sCount, sMax;
  NSMutableString *flattenedValues;
  NSString *encoding, *realValue, *value;

  encoding = [[self value: 0 ofAttribute: @"encoding"]
               lowercaseString];

  flattenedValues = [NSMutableString string];

  orderedValues = [self valuesForKey: key];
  max = [orderedValues count];
  for (count = 0; count < max; count++)
    {
      if (count > 0)
        [flattenedValues appendString: @";"];
      sValues = [orderedValues objectAtIndex: count];
      sMax = [sValues count];
      for (sCount = 0; sCount < sMax; sCount++)
        {
          if (sCount > 0)
            [flattenedValues appendString: @","];
          realValue = [sValues objectAtIndex: sCount];
          if ([encoding isEqualToString: @"quoted-printable"])
            value = [realValue stringByDecodingQuotedPrintable];
          else if ([encoding isEqualToString: @"base64"])
            value = [realValue stringByDecodingBase64];
          else
            {
              value = realValue;
              if ([encoding length] && ![encoding isEqualToString: @"8bit"])
                [self logWithFormat: @"unknown encoding '%@'", encoding];
            }

          [flattenedValues appendString: value];
        }
    }

  return flattenedValues;
}

/* attributes */

- (NSMutableDictionary *) attributes
{
  return attributes;
}

- (void) setAttributesAsCopy: (NSMutableDictionary *) someAttributes
{
  ASSIGN (attributes, someAttributes);
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
      attrValues = [NSMutableArray array];
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

- (BOOL) hasAttribute: (NSString *) anAttribute
          havingValue: (NSString *) aValue
{
  NSArray *attribute;

  attribute = [attributes objectForCaseInsensitiveKey: anAttribute];

  return (attribute && [attribute hasCaseInsensitiveString: aValue]);
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
      attrValues = [NSMutableArray array];
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
  NSMutableString *str;

  str = [NSMutableString stringWithCapacity:64];
  [str appendFormat:@"<%p[%@]:", self, NSStringFromClass([self class])];
  if (group)
    [str appendFormat: @"%@ (group: %@)\n", tag, group];
  else
    [str appendFormat: @"%@\n", tag, group];

  [str appendString: [self versitString]];

  return str;
}

static inline BOOL
_subValuesAreVoid (NSArray *subValues)
{
  BOOL result = YES;
  NSUInteger count, max;

  result = YES;

  max = [subValues count];
  for (count = 0; result && count < max; count++)
    result = ([[subValues objectAtIndex: count] length] == 0);

  return result;
}

static inline BOOL
_orderedValuesAreVoid (NSArray *orderedValues)
{
  BOOL result = YES;
  NSUInteger count, max;

  result = YES;

  max = [orderedValues count];
  for (count = 0; result && count < max; count++)
    result = _subValuesAreVoid ([orderedValues objectAtIndex: count]);

  return result;
}

- (BOOL) isVoid
{
  BOOL result = YES;
  NSArray *keys;
  NSMutableArray *orderedValues;
  NSUInteger count, max;

  keys = [values allKeys];
  max = [keys count];
  for (count = 0; result && count < max; count++)
    {
      orderedValues = [values objectForKey: [keys objectAtIndex: count]];
      result = _orderedValuesAreVoid (orderedValues);
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
      [newElement setValues: values];
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
      [newChild release];
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
  NSString *newTag, *newGroup;

  new = [[self class] new];
  newTag = [tag copyWithZone: aZone];
  [new setTag: newTag];
  [newTag release];
  newGroup = [group copyWithZone: aZone];
  [new setGroup: newGroup];
  [newGroup release];
  [new setValues: [self deepCopyOfDictionary: values withZone: aZone]];
  [new setAttributesAsCopy: [self deepCopyOfDictionary: attributes
				  withZone: aZone]];

  return new;
}

/* NSMutableCopying */
- (id) mutableCopyWithZone: (NSZone *) aZone
{
  return [self copyWithZone: aZone];
}

@end
