/* DOMNode+SOGo.m - this file is part of $PROJECT_NAME_HERE$
 *
 * Copyright (C) 2009 Inverse inc.
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
#import <Foundation/NSString.h>

#import <DOM/DOMProtocols.h>

#import "DOMNode+SOGo.h"

@implementation NGDOMNodeWithChildren (SOGo)

- (id <DOMNodeList>) childNodesWithTag: (NSString *) tagName
                           inNamespace: (NSString *) namespace
{
  id <DOMNodeList> nodes;
  NSMutableArray <DOMNodeList> *childNodesWithTag;
  id <NSObject, DOMNode> currentNode;
  unsigned int count, max;

  childNodesWithTag = [NSMutableArray array];

  nodes = [self childNodes];
  max = [nodes length];
  for (count = 0; count < max; count++)
    {
      currentNode = [nodes objectAtIndex: count];
      if ([[currentNode nodeName] isEqualToString: tagName]
          && (!namespace
              || [[currentNode nodeName] isEqualToString: namespace]))
        [childNodesWithTag addObject: currentNode];
    }

  return childNodesWithTag;
}

- (id <DOMNodeList>) childNodesWithTag: (NSString *) tagName
{
  return [self childNodesWithTag: tagName inNamespace: nil];
}

- (id <NSObject, DOMNode>) firstNodeWithTag: (NSString *) tagName
                                inNamespace: (NSString *) namespace
{
  id <DOMNodeList> nodes;
  id <NSObject, DOMNode> node, currentNode;
  unsigned int count, max;

  node = nil;

  nodes = [self childNodes];
  max = [nodes length];
  for (count = 0; !node && count < max; count++)
    {
      currentNode = [nodes objectAtIndex: count];
      if ([[currentNode nodeName] isEqualToString: tagName]
          && (!namespace
              || [[currentNode nodeName] isEqualToString: namespace]))
        node = currentNode;
    }

  return node;
}

- (id<NSObject,DOMNode>) firstNodeWithTag: (NSString *) tagName
{
  return [self firstNodeWithTag: tagName inNamespace: nil];
}


@end
