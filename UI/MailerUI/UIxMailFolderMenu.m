/* UIxMailFolderMenu.m - this file is part of SOGo
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
#import <Foundation/NSString.h>

#import "UIxMailTreeBlock.h"
#import "UIxMailFolderMenu.h"

@implementation UIxMailFolderMenu

- (void) setMenuId: (NSString *) newMenuId
{
  menuId = newMenuId;
}

- (NSString *) menuId
{
  return menuId;
}

- (void) setParentMenu: (NSString *) newParentMenu
{
  parentMenu = newParentMenu;
}

- (NSString *) parentMenu
{
  return parentMenu;
}

- (NSArray *) levelledNodes
{
  NSEnumerator *nodes;
  NSMutableArray *levelledNodes;
  UIxMailTreeBlock *block;

  levelledNodes = [NSMutableArray new];
  [levelledNodes autorelease];

  nodes = [[self flattenedNodes] objectEnumerator];
  block = [nodes nextObject];

  while (block)
    {
      if ([block parent] == [parentMenu intValue])
        [levelledNodes addObject: block];
      block = [nodes nextObject];
    }

  return levelledNodes;
}

@end
