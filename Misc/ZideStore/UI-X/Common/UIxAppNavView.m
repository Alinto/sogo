/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OGo

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
// $Id: UIxAppNavView.m 59 2004-06-22 13:40:19Z znek $


#import <NGObjWeb/NGObjWeb.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <Foundation/Foundation.h>


@interface UIxAppNavView : WOComponent
{
    id element;
    id lastElement;
}

@end


@implementation UIxAppNavView

- (void)dealloc {
    [self->element release];
    [self->lastElement release];
    [super dealloc];
}

- (void)setElement:(id)_element {
    ASSIGN(self->element, _element);
}

- (id)element {
    return self->element;
}

- (void)setLastElement:(id)_element {
    ASSIGN(self->lastElement, _element);
}

- (id)lastElement {
    return self->lastElement;
}

- (NSArray *)navPathElements {
    NSArray *traversalObjects;
    NSMutableArray *navPathComponents;
    NSMutableString *navURL;
    unsigned int i, count;

    traversalObjects = [[self context] objectTraversalStack];
    count = ([traversalObjects count] - 1); /* remove SoPageInvocation */
    navPathComponents = [[NSMutableArray alloc] initWithCapacity:count];
    navURL = [[NSMutableString alloc] initWithString:@"/"];

    for(i = 0; i < count; i++) {
        NSString *name, *url;
        id obj;
        
        obj = [traversalObjects objectAtIndex:i];

        name = [obj davDisplayName];
        if(!name)
            name = NSStringFromClass([obj class]);

        [navURL appendString:name];
        [navURL appendString:@"/"];
        
        if(! [name hasPrefix:@"ZideStore"]) {
            NSMutableDictionary *c;

            c = [[NSMutableDictionary alloc] initWithCapacity:2];
            [c setObject:name forKey:@"name"];
            url = [navURL copy];
            [c setObject:url forKey:@"url"];
            [url release];
            [navPathComponents addObject:c];
            [c release];
        }
    }

    [self setLastElement:[navPathComponents lastObject]];
    return [navPathComponents autorelease];
}

@end
