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

- (id <DOMNodeList>) childElementsWithTag: (NSString *) tagName
                              inNamespace: (NSString *) namespace
{
  id <DOMNodeList> nodes;
  NSMutableArray <DOMNodeList> *childElementsWithTag;
  id <DOMElement> currentElement;
  unsigned int count, max;

  childElementsWithTag = [NSMutableArray array];

  nodes = [self childNodes];
  max = [nodes length];
  for (count = 0; count < max; count++)
    {
      currentElement = [nodes objectAtIndex: count];
      if ([currentElement nodeType] == DOM_ELEMENT_NODE
          && [[currentElement tagName] isEqualToString: tagName]
          && (!namespace
              || [[currentElement namespaceURI] isEqualToString: namespace]))
        [childElementsWithTag addObject: currentElement];
    }

  return childElementsWithTag;
}

- (id <DOMNodeList>) childElementsWithTag: (NSString *) tagName
{
  return [self childElementsWithTag: tagName inNamespace: nil];
}

- (id <DOMElement>) firstElementWithTag: (NSString *) tagName
                            inNamespace: (NSString *) namespace
{
  id <DOMNodeList> nodes;
  id <DOMElement> node, currentElement;
  unsigned int count, max;

  node = nil;

  nodes = [self childNodes];
  max = [nodes length];
  for (count = 0; !node && count < max; count++)
    {
      currentElement = [nodes objectAtIndex: count];
      if ([currentElement nodeType] == DOM_ELEMENT_NODE
          && [[currentElement tagName] isEqualToString: tagName]
          && (!namespace
              || [[currentElement namespaceURI] isEqualToString: namespace]))
        node = currentElement;
    }

  return node;
}

- (id <DOMElement>) firstElementWithTag: (NSString *) tagName
{
  return [self firstElementWithTag: tagName inNamespace: nil];
}

@end
