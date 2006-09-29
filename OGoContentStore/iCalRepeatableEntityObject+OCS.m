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
// $Id: iCalRepeatableEntityObject+OCS.m 617 2005-03-01 17:08:11Z znek $

#include "iCalRepeatableEntityObject+OCS.h"
#include "common.h"

@implementation iCalRepeatableEntityObject (OCS)

- (NSString *)cycleInfo {
  NSMutableDictionary *cycleInfo;
  NSMutableArray      *ma;
  NSArray             *a;
  unsigned            count;

  if (![self isRecurrent])
    return nil;

  cycleInfo = [NSMutableDictionary dictionaryWithCapacity:3];

  /* rules */
  a     = [self recurrenceRules];
  count = [a count];
  if (count > 0) {
    unsigned i;

    ma = [NSMutableArray arrayWithCapacity:count];
    for (i = 0; i < count; i++) {
      iCalRecurrenceRule *rule;
      
      rule = [a objectAtIndex:i];
      [ma addObject: [rule versitString]];
    }
    [cycleInfo setObject:ma forKey:@"rules"];
  }

  /* exception rules */
  a     = [self exceptionRules];
  count = [a count];
  if (count > 0) {
    unsigned i;
    
    ma = [NSMutableArray arrayWithCapacity:count];
    for (i = 0; i < count; i++) {
      iCalRecurrenceRule *rule;
      
      rule = [a objectAtIndex:i];
      [ma addObject: [rule versitString]];
    }
    [cycleInfo setObject:ma forKey:@"exRules"];
  }
  
  /* exception dates */
  a     = [self exceptionDates];
  count = [a count];
  if (count > 0) {
    unsigned i;
    
    ma = [NSMutableArray arrayWithCapacity:count];
    for (i = 0; i < count; i++) {
      NSCalendarDate *date;
      
      date = [a objectAtIndex:i];
      [ma addObject:[date icalString]];
    }
    [cycleInfo setObject:ma forKey:@"exDates"];
  }

  return [cycleInfo description];
}
@end
