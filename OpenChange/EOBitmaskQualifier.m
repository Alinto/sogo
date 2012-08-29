/* EOBitmaskQualifier.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2012 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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

#import <Foundation/NSString.h>

#import "EOBitmaskQualifier.h"

@implementation EOBitmaskQualifier

- (id) initWithKey: (NSString *) newKey
 	      mask: (uint32_t) newMask
	    isZero: (BOOL) newIsZero
{
  if ((self = [self init]))
    {
      ASSIGN (key, newKey);
      isZero = newIsZero;
      mask = newMask;
    }

  return self;
}

- (void) dealloc
{
  [key release];
  [super dealloc];
}

- (NSString *) key
{
  return key;
}

- (uint32_t ) mask
{
  return mask;
}

- (BOOL) isZero
{
  return isZero;
}

- (NSString *) description
{
  NSMutableString *desc;

  desc = [NSMutableString stringWithCapacity: [key length] + 24];

  if (isZero)
    [desc appendString: @"!"];
  [desc appendFormat: @"(%@ & 0x%.8x)", key, mask];

  return desc;
}

@end
