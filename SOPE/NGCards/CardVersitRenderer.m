/* CardVersitRenderer.m - this file is part of SOPE
 *
 * Copyright (C) 2006-2020 Inverse inc.
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

#import <NGExtensions/NSObject+Logs.h>

#import "CardGroup.h"

#import "NSString+NGCards.h"
#import "NSDictionary+NGCards.h"

#import "CardVersitRenderer.h"

@interface CardVersitRenderer (PrivateAPI)

- (NSString *) renderElement: (CardElement *) anElement;
- (NSString *) renderGroup: (CardGroup *) aGroup;

@end

@implementation CardVersitRenderer

- (NSString *) render: (id) anElement
{
  return (([anElement isKindOfClass: [CardGroup class]])
          ? [self renderGroup: anElement]
          : [self renderElement: anElement]);
}

- (NSString *) renderElement: (CardElement *) anElement
{
  NSMutableString *rendering, *buffer;
  NSDictionary *attributes;
  NSMutableDictionary *values;
  NSString *finalRendering, *tag;

  if (![anElement isVoid])
    {
      rendering = [NSMutableString string];
      if ([anElement group])
        [rendering appendFormat: @"%@.", [anElement group]];
      tag = [anElement tag];
      if (!(tag && [tag length]))
        {
          tag = @"<no-tag>";
          [self warnWithFormat: @"card element of class '%@' has an empty tag",
                NSStringFromClass([anElement class])];
        }

      [rendering appendString: [tag uppercaseString]];

      /* parameters */
      attributes = [anElement attributes];
      if ([attributes count])
        {
          buffer = [NSMutableString string];
          [attributes versitRenderInString: buffer
                           withKeyOrdering: [anElement orderOfAttributeKeys]
                              asAttributes: YES];
          if ([buffer length])
            [rendering appendFormat: @";%@", buffer];
        }

      /* values */
      values = [anElement values];
      [rendering appendString: @":"];
      [values versitRenderInString: rendering
                   withKeyOrdering: [anElement orderOfValueKeys]
                      asAttributes: NO];

      if ([rendering length] > 0)
        [rendering appendString: @"\r\n"];

      finalRendering = [rendering foldedForVersitCards];
    }
  else
    finalRendering = @"";

  return finalRendering;
}

- (NSString *) renderGroup: (CardGroup *) aGroup
{
  NSEnumerator *children;
  CardElement *currentChild;
  NSMutableString *rendering;
  NSString *groupTag;
  NSArray *order;

  rendering = [NSMutableString string];

  groupTag = [aGroup tag];
  if (!(groupTag && [groupTag length]))
    {
      groupTag = @"<no-tag>";
      [self warnWithFormat: @"card group of class '%@' has an empty tag",
            NSStringFromClass([aGroup class])];
    }

  groupTag = [groupTag uppercaseString];
  [rendering appendFormat: @"BEGIN:%@\r\n", groupTag];

  // We reorder the group elemments, if necessary
  order = [aGroup orderOfElements];

  if (order)
    {
      NSMutableArray *orderedElements, *originalElements;
      NSArray *currentChildren;
      int i, c;

      originalElements = [NSMutableArray arrayWithArray: [aGroup children]];
      orderedElements = [NSMutableArray array];
      c = [order count];
      
      for (i = 0; i < c; i++)
        {
          currentChildren = [aGroup childrenWithTag: [order objectAtIndex: i]];
          [orderedElements addObjectsFromArray: currentChildren];
          [originalElements removeObjectsInArray: currentChildren];
        }
      
      // We add the remaining, unordered elements
      [orderedElements addObjectsFromArray: originalElements];
      children = [orderedElements objectEnumerator];
    }
  else
    {
      children = [[aGroup children] objectEnumerator];
    }

  while ((currentChild = [children nextObject]))
    [rendering appendString: [self render: currentChild]];
  [rendering appendFormat: @"END:%@\r\n", groupTag];

  return rendering;
}

@end
