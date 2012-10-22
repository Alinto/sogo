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
#import <Foundation/NSTimeZone.h>

#import "iCalObject.h"

@implementation iCalObject

// what shall we take, if no timeZone is specified in dateValues
static NSTimeZone *defTZ = nil;
+ (void)setICalDefaultTimeZone:(NSTimeZone *)_timeZone {
  ASSIGNCOPY(defTZ,_timeZone);
}
+ (NSTimeZone *)iCalDefaultTimeZone {
  return defTZ;
}

- (void)dealloc {
  [super dealloc];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  iCalObject *new;
  
  new = [[[self class] allocWithZone:_zone] init];
  return new;
}

/* KVC */

- (void)takeValue:(id)_value forXKey:(id)_key {
  /* extended keys are ignored by default */
}

- (void)handleTakeValue:(id)_value forUnboundKey:(NSString *)_key {
  if ([_key hasPrefix:@"X-"]) {
    [self takeValue:_value forXKey:_key];
  }
  else {
    NSLog(@"0x%08x[%@]: ignoring attempt to set unbound key '%@'",
	  self, NSStringFromClass([self class]), _key);
  }
}

@end /* iCalObject */
