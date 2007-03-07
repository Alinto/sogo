/* CardVersitRenderer.m - this file is part of SOPE
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSObject+Logs.h>

#import "CardElement.h"
#import "CardGroup.h"

#import "NSString+NGCards.h"
#import "NSArray+NGCards.h"

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
  NSMutableString *rendering;
  NSDictionary *attributes;
  NSEnumerator *keys;
  NSArray *values, *renderedAttrs;
  NSString *key, *finalRendering, *tag;

  if (![anElement isVoid])
    {
      rendering = [NSMutableString new];
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
      attributes = [anElement attributes];
      keys = [[attributes allKeys] objectEnumerator];
      key = [keys nextObject];
      while (key)
        {
          renderedAttrs = [[attributes objectForKey: key] renderedForCards];
          [rendering appendFormat: @";%@=%@",
                     [key uppercaseString],
                     [renderedAttrs componentsJoinedByString: @","]];
          key = [keys nextObject];
        }

      values = [anElement values];
      if ([values count] > 0)
        [rendering appendFormat: @":%@",
                   [[values renderedForCards] componentsJoinedByString: @";"]];

      if ([rendering length] > 0)
        [rendering appendString: @"\r\n"];

      finalRendering = [rendering foldedForVersitCards];
      [rendering release];
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

  rendering = [NSMutableString new];
  [rendering autorelease];

  groupTag = [aGroup tag];
  if (!(groupTag && [groupTag length]))
    {
      groupTag = @"<no-tag>";
      [self warnWithFormat: @"card group of class '%@' has an empty tag",
            NSStringFromClass([aGroup class])];
    }

  groupTag = [groupTag uppercaseString];
  [rendering appendFormat: @"BEGIN:%@\r\n", groupTag];
  children = [[aGroup children] objectEnumerator];
  currentChild = [children nextObject];
  while (currentChild)
    {
      [rendering appendString: [self render: currentChild]];
      currentChild = [children nextObject];
    }
  [rendering appendFormat: @"END:%@\r\n", groupTag];

  return rendering;
}

@end
