/*
  Copyright (C) 2004 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <SOGoUI/UIxComponent.h>

@interface UIxAppNavView : UIxComponent
{
  id element;
  id lastElement;
}

@end

@implementation UIxAppNavView

- (void)dealloc {
  [element     release];
  [lastElement release];
  [super dealloc];
}

/* accessors */

- (void)setElement:(id)_element {
  ASSIGN(element, _element);
}
- (id)element {
  return element;
}

- (void)setLastElement:(id)_element {
  ASSIGN(lastElement, _element);
}
- (id)lastElement {
  return lastElement;
}

/* navigation */

- (NSArray *)navPathElements {
  NSArray        *traversalObjects;
  NSMutableArray *navPathComponents;
  unsigned int   i, count;
  
  traversalObjects = [[self context] objectTraversalStack];
  count = ([traversalObjects count] - 1); /* remove SoPageInvocation */
  
  navPathComponents = [[NSMutableArray alloc] initWithCapacity:count];
  for (i = 0; i < count; i++) {
    NSString *name;
    id obj;
    
    obj = [traversalObjects objectAtIndex:i];
    
    name = [obj davDisplayName];
    if ([name length] == 0)
      name = NSStringFromClass([obj class]);
    name = [self labelForKey:name];

    if (![name hasPrefix:@"sogod"]) {
      NSMutableDictionary *c;
      NSString *url;
      
      url = [obj baseURLInContext:[self context]];
      if (![url hasSuffix:@"/"])
	url = [url stringByAppendingString:@"/"];
      
      c = [[NSMutableDictionary alloc] initWithCapacity:2];
      [c setObject:name forKey:@"name"];
      [c setObject:url forKey:@"url"];
      [navPathComponents addObject:c];
      [c release];
    }
  }

  [self setLastElement:[navPathComponents lastObject]];
  return [navPathComponents autorelease];
}

@end /* UIxAppNavView */
