/* NSArray+Utilities.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse groupe conseil
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

#import <Foundation/NSString.h>

#import "NSArray+Utilities.h"

@implementation NSArray (SOGoArrayUtilities)

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
      [formattedStrings
        addObject: [NSString stringWithFormat: format, currentObject]];
      currentObject = [objects nextObject];
    }

  return formattedStrings;
}

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

- (NSString *) jsonRepresentation
{
  id currentElement;
  NSMutableArray *jsonElements;
  NSEnumerator *elements;
  NSString *representation;

  jsonElements = [NSMutableArray new];

  elements = [self objectEnumerator];
  currentElement = [elements nextObject];
  while (currentElement)
    {
      [jsonElements addObject: [currentElement jsonRepresentation]];
      currentElement = [elements nextObject];
    }
  representation = [NSString stringWithFormat: @"[%@]",
			     [jsonElements componentsJoinedByString: @", "]];
  [jsonElements release];

  return representation;
}

@end

@implementation NSMutableArray (SOGoArrayUtilities)

- (void) addObjectUniquely: (id) object
{
  if (![self containsObject: object])
    [self addObject: object];
}

- (void) addRange: (NSRange) newRange
{
  [self addObject: NSStringFromRange (newRange)];
}

- (BOOL) hasRangeIntersection: (NSRange) testRange
{
  NSEnumerator *ranges;
  NSString *currentRangeString;
  NSRange currentRange;
  BOOL response;

  response = NO;

  ranges = [self objectEnumerator];
  currentRangeString = [ranges nextObject];
  while (!response && currentRangeString)
    {
      currentRange = NSRangeFromString (currentRangeString);
      if (NSLocationInRange (testRange.location, currentRange)
	  || NSLocationInRange (NSMaxRange (testRange), currentRange))
	response = YES;
      else
	currentRangeString = [ranges nextObject];
    }

  return response;
}

@end

