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
// $Id: UIxCalBackForthNavView.m 59 2004-06-22 13:40:19Z znek $


#include <NGObjWeb/NGObjWeb.h>

/*
    Associations:

    methodName              -> maps to href
    prevQueryParameters     -> queryDictionary
    currentQueryParameters  -> queryDictionary
    nextQueryParameters     -> queryDictionary
    label                   -> user presentable name to display for "this"
 */

@interface UIxCalBackForthNavView : WOComponent
{
}

@end


@implementation UIxCalBackForthNavView

- (BOOL)synchronizesVariablesWithBindings {
    return NO;
}

@end
