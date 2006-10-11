/*
  Copyright (C) 2004 SKYRIX Software AG

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
// $Id: NSObject+AptComparison.m 620 2005-03-02 19:57:10Z znek $

#include "NSObject+AptComparison.h"
#include <NGExtensions/NGCalendarDateRange.h>
#include "common.h"

@implementation NSObject (SOGoAptComparison)

- (NSComparisonResult) compareAptsAscending: (id) _other
{
  NSCalendarDate      *sd, *ed;
  NGCalendarDateRange *r1, *r2;
  NSComparisonResult  result;
  NSTimeInterval      t1, t2;

  sd = [self valueForKey: @"startDate"];
  ed = [self valueForKey: @"endDate"];
  if (sd && ed)
    r1 = [NGCalendarDateRange calendarDateRangeWithStartDate: sd
                              endDate: ed];
  else
    r1 = nil;

  sd = [_other valueForKey: @"startDate"];
  ed = [_other valueForKey: @"endDate"];
  if (sd && ed)
    r2 = [NGCalendarDateRange calendarDateRangeWithStartDate: sd
                              endDate: ed];
  else
    r2 = nil;

  if (r1)
    if (r2)
      {
        result = [r1 compare: r2];
        if (result != NSOrderedSame)
          return result;
        
        t1 = [r1 duration];
        t2 = [r2 duration];
        if (t1 == t2)
          return NSOrderedSame;
        if (t1 > t2)
          return NSOrderedDescending;
      }
    else
      return NSOrderedDescending;
  else
    if (!r2)
      return NSOrderedSame;

  return NSOrderedAscending;
}

@end
