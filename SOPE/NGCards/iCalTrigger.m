/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSString.h>

#import "iCalTrigger.h"

@implementation iCalTrigger

/* accessors */

- (void) setValue: (NSString *) theValue
{
  [self setValue: 0 to: theValue];
}

- (NSString *) value
{
  return [self value: 0];
}

- (void) setValueType: (NSString *) theValue
{
  [self setValue: 0 ofAttribute: @"value" to: theValue];
}

- (NSString *) valueType
{
  return [self value: 0 ofAttribute: @"value"];
}

- (void) setRelationType: (NSString *) theRelationType
{
  [self setValue: 0 ofAttribute: @"related" to: theRelationType];
}

- (NSString *) relationType
{
  return [self value: 0 ofAttribute: @"related"];
}

@end /* iCalTrigger */
