/* NSArray+Utilities.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2011 Inverse inc.
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import "NSArray+Utilities.h"

@implementation NSArray (SOGoArrayUtilities)

+ (id) arrayWithObject: (id) member
           repeatCount: (int) repeatCount
{
  NSMutableArray *newArray;
  int count;

  newArray = [NSMutableArray arrayWithCapacity: repeatCount];
  for (count = 0; count < repeatCount; count++)
    [newArray addObject: member];

  return newArray;
}

- (id *) asPointersOfObjects
{
  id *pointers;
  unsigned int max;

  max = [self count];
  pointers = NSZoneMalloc (NULL, sizeof (id) * (max + 1));
  [self getObjects: pointers];
  *(pointers + max) = nil;

  return pointers;
}

- (NSArray *) stringsWithFormat: (NSString *) format
{
  NSMutableArray *formattedStrings;
  NSEnumerator *objects;
  id currentObject;

  formattedStrings = [NSMutableArray arrayWithCapacity: [self count]];

  objects = [self objectEnumerator];
  currentObject = [objects nextObject];
  while (currentObject)
    {
      if ([currentObject isKindOfClass: [NSNull class]])
	[formattedStrings addObject: @""];
      else
	[formattedStrings
	  addObject: [NSString stringWithFormat: format, currentObject]];
      currentObject = [objects nextObject];
    }

  return formattedStrings;
}

- (NSArray *) keysWithFormat: (NSString *) format
{
  NSMutableArray *formattedStrings;
  NSEnumerator *objects;
  id currentObject;

  formattedStrings = [NSMutableArray arrayWithCapacity: [self count]];

  objects = [self objectEnumerator];
  currentObject = [objects nextObject];
  while (currentObject)
    {
      [formattedStrings addObject: [currentObject keysWithFormat: format]];
      currentObject = [objects nextObject];
    }

  return formattedStrings;
}

- (NSArray *) objectsForKey: (NSString *) key
	     notFoundMarker: (id) marker
{
  NSMutableArray *objectsForKey;
  unsigned int count, max;
  id value;

  max = [self count];
  objectsForKey = [NSMutableArray arrayWithCapacity: max];

  for (count = 0; count < max; count++)
    {
      value = [[self objectAtIndex: count] objectForKey: key];
      if (value)
	[objectsForKey addObject: value];
      else if (marker)
	[objectsForKey addObject: marker];
    }

  return objectsForKey;
}

- (NSArray *) flattenedArray
{
  NSMutableArray *flattenedArray;
  NSEnumerator *objects;
  id currentObject;

  flattenedArray = [NSMutableArray array];
  objects = [self objectEnumerator];
  while ((currentObject = [objects nextObject]))
    if ([currentObject isKindOfClass: [NSArray class]])
      [flattenedArray addObjectsFromArray: [(NSArray *)currentObject flattenedArray]];
    else
      [flattenedArray addObject: currentObject];

  return flattenedArray;
}

- (NSDictionary *) flattenedDictionaries
{
  NSMutableDictionary *newDict;
  NSDictionary *currentDictionary;
  int count, max;

  newDict = [NSMutableDictionary dictionary];

  max = [self count];
  for (count = 0; count < max; count++)
    {
      currentDictionary = [self objectAtIndex: count];
      [newDict addEntriesFromDictionary: currentDictionary];
    }

  return newDict;
}

- (NSArray *) uniqueObjects
{
  NSMutableArray *newArray;
  NSEnumerator *objects;
  id currentObject;

  newArray = [NSMutableArray array];

  objects = [self objectEnumerator];
  while ((currentObject = [objects nextObject]))
    [newArray addObjectUniquely: currentObject];

  return newArray;
}

- (NSArray *) trimmedComponents
{
  return [self resultsOfSelector: @selector (stringByTrimmingSpaces)];
}

#ifdef GNUSTEP_BASE_LIBRARY
- (void) makeObjectsPerform: (SEL) selector
                 withObject: (id) object1
                 withObject: (id) object2
{
  int count, max;

  max = [self count];
  for (count = 0; count < max; count++)
    [[self objectAtIndex: count] performSelector: selector
                                 withObject: object1
                                 withObject: object2];
}
#endif

- (NSArray *) resultsOfSelector: (SEL) operation
{
  NSMutableArray *results;
  int count, max;
  id result;

  max = [self count];
  results = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      result = [[self objectAtIndex: count] performSelector: operation];
      [results addObject: result];
    }

  return results;
}

- (NSArray *) mergedArrayWithArray: (NSArray *) otherArray
{
  NSMutableArray *mergedArray;
  NSUInteger count, max;
  id object;

  max = [otherArray count];
  mergedArray = [NSMutableArray arrayWithCapacity: (max + [self count])];
  [mergedArray setArray: self];
  for (count = 0; count < max; count++)
    {
      object = [otherArray objectAtIndex: count];
      if (![mergedArray containsObject: object])
        [mergedArray addObject: object];
    }

  return mergedArray;
}

- (NSString *) jsonRepresentation
{
  id currentElement;
  NSMutableArray *jsonElements;
  NSEnumerator *elements;
  NSString *representation;

  jsonElements = [NSMutableArray array];
  elements = [self objectEnumerator];
  while ((currentElement = [elements nextObject]))
    [jsonElements addObject: [currentElement jsonRepresentation]];
  representation = [NSString stringWithFormat: @"[%@]",
			     [jsonElements componentsJoinedByString: @", "]];

  return representation;
}

- (BOOL) containsCaseInsensitiveString: (NSString *) match
{
  BOOL response;
  NSString *currentString, *cmpObject;
  NSEnumerator *objects;

  response = NO;

  cmpObject = [match lowercaseString];
  objects = [self objectEnumerator];
  currentString = [objects nextObject];
  while (currentString && !response)
    if ([[currentString lowercaseString] isEqualToString: cmpObject])
      response = YES;
    else
      currentString = [objects nextObject];

  return response;
}

@end

@implementation NSMutableArray (SOGoArrayUtilities)

- (void) addNonNSObject: (void *) objectPtr
               withSize: (size_t) objectSize
                   copy: (BOOL) doCopy
{
  void *newObjectPtr;

  if (doCopy)
    {
      newObjectPtr = NSZoneMalloc (NULL, objectSize);
      memcpy (newObjectPtr, objectPtr, objectSize);
    }
  else
    newObjectPtr = objectPtr;

  [self addObject: [NSValue valueWithPointer: newObjectPtr]];
}

- (void) freeNonNSObjects
{
  unsigned int count, max;
  void *objectPtr;

  max = [self count];
  for (count = 0; count < max; count++)
    {
      objectPtr = [[self objectAtIndex: count] pointerValue];
      NSZoneFree (NULL, objectPtr);
    }
}

- (void) addObjectUniquely: (id) object
{
  if (![self containsObject: object])
    [self addObject: object];
}

- (BOOL) hasRangeIntersection: (NSRange) testRange
{
  NSEnumerator *ranges;
  NSValue *currentRangePtr;
  NSRange *currentRange;
  BOOL response;

  response = NO;

  ranges = [self objectEnumerator];
  while (!response && (currentRangePtr = [ranges nextObject]))
    {
      currentRange = [currentRangePtr pointerValue];
      if (NSLocationInRange (testRange.location, *currentRange)
	  || NSLocationInRange (currentRange->location, testRange))
	response = YES;
    }

  return response;
}

- (void) removeDoubles
{
  NSMutableDictionary *valueDicts;
  NSNull *dummy;
  NSUInteger count, max;

  dummy = [NSNull null];

  max = [self count];
  valueDicts = [NSMutableDictionary dictionaryWithCapacity: max];

  for (count = 0; count < max; count++)
    [valueDicts setObject: dummy forKey: [self objectAtIndex: count]];
  [self setArray: [valueDicts allKeys]];
}

@end
