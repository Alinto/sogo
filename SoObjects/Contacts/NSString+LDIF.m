/* NSString+LDIF.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
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

#import <Foundation/NSCharacterSet.h>

#import "NSString+LDIF.h"

@implementation NSString (SOGoLDIF)

static NSMutableCharacterSet *safeLDIFChars = nil;
static NSMutableCharacterSet *safeLDIFStartChars = nil;

- (void) _initSafeLDIFChars
{
  safeLDIFChars = [NSMutableCharacterSet new];
  [safeLDIFChars addCharactersInRange: NSMakeRange (0x01, 9)];
  [safeLDIFChars addCharactersInRange: NSMakeRange (0x0b, 2)];
  [safeLDIFChars addCharactersInRange: NSMakeRange (0x0e, 114)];

  safeLDIFStartChars = [safeLDIFChars mutableCopy];
  [safeLDIFStartChars removeCharactersInString: @" :<"];
}

- (BOOL) mustEncodeLDIFValue
{
  int count, max;
  BOOL rc;

  if (!safeLDIFChars)
    [self _initSafeLDIFChars];

  rc = NO;

  max = [self length];
  if (max > 0)
    {
      if ([safeLDIFStartChars characterIsMember: [self characterAtIndex: 0]])
        for (count = 1; !rc && count < max; count++)
          rc = ![safeLDIFChars
                  characterIsMember: [self characterAtIndex: count]];
      else
        rc = YES;
    }
  
  return rc;
}

@end
