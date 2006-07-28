/* UIxMailTreeBlockJS.m - this file is part of $PROJECT_NAME_HERE$
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

#import "UIxMailTreeBlockJS.h"

#import "Common/UIxPageFrame.h"

@implementation UIxMailTreeBlockJS

- (id) init
{
  if ((self = [super init]))
    {
      item = nil;
    }

  return self;
}

- (void) setItem: (UIxMailTreeBlock *) newItem
{
  item = newItem;
}

- (UIxMailTreeBlock *) item
{
  return item;
}

- (WOResourceManager *) resourceManager
{
  WOResourceManager *resourceManager;
  id c;

  resourceManager = nil;

  c = self;
  while (!resourceManager
	 && c)
    if ([c respondsToSelector: @selector(pageResourceManager)])
      resourceManager = [c pageResourceManager];
    else
      c = [c parent];

  return resourceManager;
}

- (NSString *) iconName
{
  WOResourceManager *resourceManager;
  NSString *iconName, *rsrcIconName;

  iconName = [item iconName];
  if ([iconName length] > 0)
    {
      resourceManager = [self resourceManager];
      rsrcIconName = [resourceManager urlForResourceNamed: iconName
				      inFramework: nil
				      languages: nil
				      request: [[self context] request]];
    }
  else
    rsrcIconName = nil;

  return rsrcIconName;
}

- (void) setTreeObjectName: (NSString *) newName
{
  treeObjectName = newName;
}

- (NSString *) treeObjectName
{
  return treeObjectName;
}

- (BOOL) isAccount
{
  return ([item parent] == 0);
}

- (BOOL) isInbox
{
  return ([[item name] isEqualToString: @"INBOX"]);
}

- (BOOL) isTrash
{
  return NO;
}


@end
