/* NSArray+NGCards.m - this file is part of SOPE
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

#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>

#import "CardElement.h"
#import "NSString+NGCards.h"

#import "NSArray+NGCards.h"

@implementation NSArray (NGCardsExtensions)

- (NSString *) valueForCaseInsensitiveString: (NSString *) aString
{
  NSString *currentString, *resultString, *cmpString;
  unsigned int count, max;

  resultString = nil;

  max = [self count];
  count = 0;
  cmpString = [aString uppercaseString];

  while (!resultString && count < max)
    {
      currentString = [self objectAtIndex: count];
      if ([[currentString uppercaseString] isEqualToString: cmpString])
        resultString = currentString;
      else
        count++;
    }

  return resultString;
}

- (BOOL) hasCaseInsensitiveString: (NSString *) aString
{
  return ([self valueForCaseInsensitiveString: aString] != nil);
}

- (NSArray *) cardElementsWithTag: (NSString *) aTag
{
  NSMutableArray *matchingElements;
  NSEnumerator *allElements;
  CardElement *currentElement;
  NSString *cmpTag, *currentTag;

  cmpTag = [aTag uppercaseString];

  matchingElements = [NSMutableArray new];
  [matchingElements autorelease];

  allElements = [self objectEnumerator];
  currentElement = [allElements nextObject];
  while (currentElement)
    {
      currentTag = [[currentElement tag] uppercaseString];
      if ([currentTag isEqualToString: cmpTag])
        [matchingElements addObject: currentElement];
      currentElement = [allElements nextObject];
    }

  return matchingElements;
}

- (NSArray *) cardElementsWithAttribute: (NSString *) anAttribute
                            havingValue: (NSString *) aValue
{
  NSMutableArray *matchingElements;
  NSEnumerator *allElements;
  CardElement *currentElement;

  allElements = [self objectEnumerator];

  matchingElements = [NSMutableArray new];
  [matchingElements autorelease];
  currentElement = [allElements nextObject];
  while (currentElement)
    {
      if ([currentElement hasAttribute: anAttribute
                          havingValue: aValue])
        [matchingElements addObject: currentElement];
      currentElement = [allElements nextObject];
    }

  return matchingElements;
}

- (NSArray *) renderedForCards
{
  NSMutableArray *purified;
  NSString *string;
  int count, max, lastInsert;

  max = [self count];
  purified = [NSMutableArray arrayWithCapacity: max];

  lastInsert = -1;
  for (count = 0; count < max; count++)
    {
      string = [self objectAtIndex: count];
      if ([string length] > 0)
        {
          while (lastInsert < (count - 1))
            {
              [purified addObject: @""];
              lastInsert++;
            }
          [purified addObject: [string escapedForCards]];
          lastInsert = count;
        }
    }

  return purified;
}

@end
