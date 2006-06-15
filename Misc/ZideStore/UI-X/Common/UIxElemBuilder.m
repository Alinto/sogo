/*
  Copyright (C) 2000-2004 SKYRIX Software AG

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
// $Id: UIxElemBuilder.m 30 2004-06-11 12:07:09Z znek $

#include <NGObjWeb/WOxElemBuilder.h>

/*
  This builder builds various elements from the UI-X product.

  All tags are mapped into the <uix:> namespace (XMLNS_OD_BIND).

    <var:tabview   .../>    maps to UIxTabView
    <var:tab       .../>    maps to UIxTabItem
*/

@interface UIxElemBuilder : WOxTagClassElemBuilder
{
}

@end

#include <SaxObjC/XMLNamespaces.h>
#include "common.h"

#define XMLNS_UIX @"OGo:uix"


@implementation UIxElemBuilder

- (Class)classForElement:(id<DOMElement>)_element {
  NSString *tagName;
  unsigned tl;
  unichar c1;
  
  if (![[_element namespaceURI] isEqualToString:XMLNS_UIX])
    return Nil;

  tagName = [_element tagName];
  if ((tl = [tagName length]) < 2)
    return Nil;

  c1 = [tagName characterAtIndex:0];

  switch (c1) {
    case 't': { /* starting with 't' */
      unichar c2;
      
      c2 = [tagName characterAtIndex:1];
      
      if (tl == 3 && c2 == 'a') {
        if ([tagName characterAtIndex:2] == 'b')
          return NSClassFromString(@"UIxTabItem");
      }

      if (tl > 5) {
        if (c2 == 'a') {
          if ([tagName isEqualToString:@"tabview"])
            return NSClassFromString(@"UIxTabView");
        }
      }
      break;
    }
  }
  
  return Nil;
}

@end /* UIxElemBuilder */
