/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#ifndef __UIxMailTreeBlock_H__
#define __UIxMailTreeBlock_H__

#import <Foundation/NSObject.h>

@class NSString, NSArray;

/*
  UIxMailTreeBlock

  A helper object for UIxMailTree.
*/

extern id UIxMailTreeHasChildrenMarker;

@interface UIxMailTreeBlock : NSObject
{
  NSString *name;
  NSString *title;
  NSString *link;
  NSArray  *blocks;
  NSString *iconName;
  struct {
    int isPath:1;
    int isActive:1;
    int reserved:30;
  } flags;
}

+ (id)blockWithName:(NSString *)_n title:(NSString *)_t iconName:(NSString *)_i
  link:(NSString *)_link isPathNode:(BOOL)_isPath isActiveNode:(BOOL)_isActive
  childBlocks:(NSArray *)_blocks;

- (id)initWithName:(NSString *)_n title:(NSString *)_t iconName:(NSString *)_i
  link:(NSString *)_link isPathNode:(BOOL)_isPath isActiveNode:(BOOL)_isActive
  childBlocks:(NSArray *)_blocks;

/* accessors */

- (BOOL)hasChildren;
- (BOOL)areChildrenLoaded;
- (NSArray *)children;

@end

#endif /* __UIxMailTreeBlock_H__ */
