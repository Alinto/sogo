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

#include <NGCards/NGCards.h>
#include "common.h"

/* HACK ALERT
   This is a pretty ugly (unfortunately necessary) hack to map our limited
   set of recurrence rules back to the popup list
*/
@interface iCalRecurrenceRule (UsedPrivates)
- (NSString *)freq;
- (NSString *)byDayList;
@end /* iCalRecurrenceRule (UsedPrivates) */

@implementation iCalRecurrenceRule (SOGoExtensions)

- (NSString *)cycleRepresentationForSOGo {
  NSMutableString *s;
  
  s = [NSMutableString stringWithCapacity:20];
  [s appendString:@"FREQ="];
  [s appendString:[self freq]];
  if ([self repeatInterval] != 1) {
    [s appendFormat:@";INTERVAL=%d", [self repeatInterval]];
  }
  if (self->byDay.mask != 0) {
    [s appendString:@";BYDAY="];
    [s appendString:[self byDayList]];
  }
  return s;
}

@end /* iCalRecurrenceRule (SOGoExtensions) */
