/* CardGroup.m - this file is part of SOPE
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
#import <Foundation/NSString.h>
#import <SaxObjC/SaxXMLReader.h>
#import <SaxObjC/SaxXMLReaderFactory.h>

#import "NGCardsSaxHandler.h"
#import "NSArray+NGCards.h"

#import "CardGroup.h"

static id<NSObject,SaxXMLReader> parser = nil;
static NGCardsSaxHandler *sax = nil;

@implementation CardGroup

+ (id<NSObject,SaxXMLReader>) cardParser
{
  if (!sax)
    sax = [NGCardsSaxHandler new];
  
  if (!parser)
    {
#if 1
      parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
                 createXMLReaderWithName: @"VSCardSaxDriver"];
      [parser retain];
#else
      parser =
        [[[SaxXMLReaderFactory standardXMLReaderFactory] 
           createXMLReaderForMimeType:@"text/x-vcard"] retain];
#endif
      if (parser)
        {
          [parser setContentHandler:sax];
          [parser setErrorHandler:sax];
        }
      else
        NSLog(@"ERROR(%s): did not find a parser for text/x-vcard!",
              __PRETTY_FUNCTION__);
    }
  
  return parser;
}

+ (NSArray *) parseFromSource: (id) source
{
  static id <NSObject, SaxXMLReader> cardParser;
  NSArray *cardGroups;

  cardGroups = nil;

  if (source)
    {
      cardParser = [self cardParser];

      [sax setTopElementClass: self];

      [cardParser parseFromSource: source];

      cardGroups = [sax cards];
      [sax reset];
    }

  return cardGroups;
}

+ (id) parseSingleFromSource: (id) source
{
  NSArray *cards;
  CardGroup *card;

  cards = [self parseFromSource: source];
  if (cards && [cards count])
    card = [cards objectAtIndex: 0];
  else
    card = nil;

  return card;
}

+ (id) groupWithTag: (NSString *) aTag
{
  return [self elementWithTag: aTag];
}

+ (id) groupWithTag: (NSString *) aTag
           children: (NSArray *) someChildren
{
  id newGroup;

  newGroup = [self elementWithTag: aTag];
  [newGroup addChildren: someChildren];

  return newGroup;
}

- (id) init
{
  if ((self = [super init]))
    {
      children = [NSMutableArray new];
    }

  return self;
}

- (void) dealloc
{
  [children release];
  [super dealloc];
}

- (Class) classForTag: (NSString *) tagClass
{
//   NSLog (@"class '%@': '%@'", NSStringFromClass([self class]),
//          tagClass);

  return nil;
}

- (BOOL) isVoid
{
  BOOL isVoid = YES;
  NSUInteger count, max;

  max = [children count];
  for (count = 0; isVoid && count < max; count++)
    if (![[children objectAtIndex: count] isVoid])
      isVoid = NO;

  return isVoid;
}

- (void) addChild: (CardElement *) aChild
{
  Class mappedClass;
  NSString *childTag;
  CardElement *newChild;

  if (aChild)
    {
      childTag = [aChild tag];
      newChild = nil;
      mappedClass = [self classForTag: [childTag uppercaseString]];
      if (mappedClass)
	{
	  if (![aChild isKindOfClass: mappedClass])
	    {
	      NSLog (@"warning: new child to entity '%@': '%@' converted to '%@'",
		     tag, childTag, NSStringFromClass(mappedClass));
	      newChild = [aChild elementWithClass: mappedClass];
	    }
	}
      //   else
      //     NSLog (@"warning: no mapped class for tag '%@'",
      //            childTag);

      if (!newChild)
	newChild = aChild;
      [children addObject: newChild];
      [newChild setParent: self];
    }
}

- (CardElement *) uniqueChildWithTag: (NSString *) aTag
{
  NSArray *existing;
  Class elementClass;
  CardElement *uniqueChild;

  existing = [self childrenWithTag: aTag];
  if ([existing count] > 0)
    uniqueChild = [existing objectAtIndex: 0];
  else
    {
      elementClass = [self classForTag: [aTag uppercaseString]];
      if (!elementClass)
        elementClass = [CardElement class];

      uniqueChild = [elementClass new];
      [uniqueChild autorelease];
      [uniqueChild setTag: aTag];
      [self addChild: uniqueChild];
    }

  return uniqueChild;
}

- (void) setUniqueChild: (CardElement *) aChild
{
  CardElement *currentChild;
  NSString *childTag;
  NSEnumerator *existing;

  if (aChild)
    {
      childTag = [aChild tag];
      existing = [[self childrenWithTag: childTag] objectEnumerator];

      currentChild = [existing nextObject];
      while (currentChild)
	{
	  [children removeObject: currentChild];
	  currentChild = [existing nextObject];
	}

      [self addChild: aChild];
    }
}

- (CardElement *) firstChildWithTag: (NSString *) aTag;
{
  Class mappedClass;
  CardElement *child, *mappedChild;
  NSArray *existing;

  existing = [self childrenWithTag: aTag];
  if ([existing count])
    {
      child = [existing objectAtIndex: 0];
      mappedClass = [self classForTag: [aTag uppercaseString]];
      if (mappedClass)
	mappedChild = [child elementWithClass: mappedClass];
      else
        mappedChild = child;
    }
  else
    mappedChild = nil;

  return mappedChild;
}

- (void) addChildren: (NSArray *) someChildren
{
  CardElement *currentChild;
  NSEnumerator *newChildren;

  newChildren = [someChildren objectEnumerator];
  while ((currentChild = [newChildren nextObject]))
    [self addChild: currentChild];
}

- (void) removeChild: (CardElement *) aChild
{
  [aChild setParent: nil];
  [children removeObject: aChild];
}

- (void) removeChildren: (NSArray *) someChildren
{
  CardElement *currentChild;
  NSEnumerator *newChildren;

  newChildren = [someChildren objectEnumerator];
  while ((currentChild = [newChildren nextObject]))
    [self removeChild: currentChild];
}

- (NSMutableArray *) children
{
  return children;
}

- (NSArray *) childrenWithTag: (NSString *) aTag
{
  return [children cardElementsWithTag: aTag];
}

- (NSArray *) childrenWithAttribute: (NSString *) anAttribute
                        havingValue: (NSString *) aValue
{
  return [children cardElementsWithAttribute: anAttribute
                                 havingValue: aValue];
}

- (NSArray *) childrenWithTag: (NSString *) aTag
                 andAttribute: (NSString *) anAttribute
                  havingValue: (NSString *) aValue
{
  NSArray *elements;

  elements = [self childrenWithTag: aTag];

  return [elements cardElementsWithAttribute: anAttribute
                                 havingValue: aValue];
}

- (NSArray *) childrenGroupWithTag: (NSString *) aTag
                         withChild: (NSString *) aChild
                 havingSimpleValue: (NSString *) aValue
{
  NSEnumerator *allElements;
  NSMutableArray *elements;
  CardGroup *element;
  NSString *value;

  elements = [NSMutableArray array];

  allElements = [[self childrenWithTag: aTag] objectEnumerator];
  element = [allElements nextObject];
  while (element)
    {
      if ([element isKindOfClass: [CardGroup class]])
        {
          value = [[element uniqueChildWithTag: aChild]
                    flattenedValuesForKey: @""];
          if ([value isEqualToString: aValue])
            [elements addObject: element];
        }
      element = [allElements nextObject];
    }

  return elements;
}

- (id) elementWithClass: (Class) groupClass
{
  CardGroup *newGroup;

  if ([self isKindOfClass: groupClass])
    newGroup = self;
  else
    {
      newGroup = [super elementWithClass: groupClass];
      [newGroup setChildrenAsCopy: children];
    }

  return newGroup;
}

- (void) setChildrenAsCopy: (NSMutableArray *) someChildren
{
  NSUInteger count, max;

  ASSIGN (children, someChildren);

  max = [children count];
  for (count = 0; count < max; count++)
    [[children objectAtIndex: count] setParent: self];
}

- (void) addChildWithTag: (NSString *) aTag
                   types: (NSArray *) someTypes
             singleValue: (NSString *) aValue
{
  CardElement *newChild;
  NSEnumerator *types;
  NSString *type;

  newChild = [CardElement simpleElementWithTag: aTag value: aValue];
  types = [someTypes objectEnumerator];
  while ((type = [types nextObject]))
    [newChild addType: type];

  [self addChild: newChild];
}

- (void) cleanupEmptyChildren
{
  NSUInteger max;
  NSInteger count;
  CardElement *child;

  max = [children count];
  for (count = max - 1; count > -1; count--)
    {
      child = [children objectAtIndex: count];
      if ([child isKindOfClass: [CardGroup class]])
        [(CardGroup *) child cleanupEmptyChildren];
      if ([child isVoid])
        [children removeObjectAtIndex: count];
    }
}

- (NSString *) description
{
  NSMutableString *str;
  NSUInteger count, max;

  str = [NSMutableString stringWithCapacity:64];
  [str appendFormat:@"<%p[%@]:%@",
       self, NSStringFromClass([self class]), [self tag]];
  max = [children count];
  if (max > 0)
    {
      [str appendFormat: @"\n  %d children: {\n", [children count]];
      for (count = 0; count < max; count++)
        [str appendFormat: @"  %@\n",
             [[children objectAtIndex: count] description]];
      [str appendFormat: @"}"];
    }
  [str appendString:@">"];

  return str;
}

- (void) replaceThisElement: (CardElement *) oldElement
                withThisOne: (CardElement *) newElement
{
  NSUInteger index;

  index = [children indexOfObject: oldElement];
  if (index != NSNotFound)
    [children replaceObjectAtIndex: index withObject: newElement];
}

/* NSCopying */

- (id) copyWithZone: (NSZone *) aZone
{
  CardGroup *new;

  new = [super copyWithZone: aZone];
  [new setChildrenAsCopy: [self deepCopyOfArray: children
				withZone: aZone]];

  return new;
}

/* NSMutableCopying */

- (id) mutableCopyWithZone: (NSZone *) aZone
{
  CardGroup *new;

  new = [super mutableCopyWithZone: aZone];
  [new setChildrenAsCopy: [self deepCopyOfArray: children
				withZone: aZone]];

  return new;
}

@end
