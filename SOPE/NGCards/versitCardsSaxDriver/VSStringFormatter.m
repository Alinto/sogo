/*
  Copyright (C) 2004-2005 OpenGroupware.org
 
  This file is part of versitCardsSaxDriver, written for the OpenGroupware.org
  project (OGo).
 
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

#include "VSStringFormatter.h"
#include "common.h"

@implementation VSStringFormatter

static NSCharacterSet *escSet = nil;

+ (void)initialize {
  static BOOL didInit = NO;
  
  if(didInit)
    return;
  
  didInit = YES;
  escSet = [[NSCharacterSet characterSetWithCharactersInString:@"\\"] retain];
}

+ (id)sharedFormatter {
  static id sharedInstance = nil;
  if(!sharedInstance) {
    sharedInstance = [[self alloc] init];
  }
  return sharedInstance;
}

- (NSString *)stringByUnescapingRFC2445Text:(NSString *)_s {
  NSMutableString *safeString;
  unsigned        length;
  NSRange         prevRange, escRange;
  NSRange         todoRange;
  BOOL            needsEscaping;

  length    = [_s length];
  prevRange = NSMakeRange(0, length);
  escRange  = [_s rangeOfCharacterFromSet:escSet options:0 range:prevRange];

  needsEscaping = escRange.length > 0 ? YES : NO;
  if (!needsEscaping)
    return _s; /* cheap */
  
  safeString = [NSMutableString stringWithCapacity:length];
  
  do {
    prevRange.length = escRange.location - prevRange.location;
    if (prevRange.length > 0)
      [safeString appendString:[_s substringWithRange:prevRange]];

    /* test edge case */
    if(NSMaxRange(escRange) < length) {
      unichar c = [_s characterAtIndex:escRange.location + 1];
      if(c == 'n' || c == 'N') {
        [safeString appendString:@"\n"];
        escRange.length += 1; /* skip the 'n' */
      }
    }
    
    prevRange.location = NSMaxRange(escRange);
    todoRange.location = prevRange.location;
    todoRange.length   = length - prevRange.location;
    escRange           = [_s rangeOfCharacterFromSet:escSet
                             options:0
                             range:todoRange];
  }
  while(escRange.length > 0);
  
  if (todoRange.length > 0)
    [safeString appendString:[_s substringWithRange:todoRange]];
  
  return safeString;
}

@end /* VSStringFormatter */
