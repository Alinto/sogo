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
// $Id: UIxCalDayOverview.m 663 2005-07-05 18:13:24Z znek $


#include "UIxCalDayOverview.h"
#include "common.h"
#include <SOGoUI/SOGoAptFormatter.h>

@implementation UIxCalDayOverview

- (void)dealloc {
    [self->currentApts release];
    [super dealloc];
}

- (void)setCurrentApts:(NSArray *)_apts {
    ASSIGN(self->currentApts, _apts);
}
- (NSArray *)currentApts {
    return self->currentApts;
}

- (int)minRequiredRowSpan {
    unsigned count = [[self aptsForCurrentDate] count];
    return count == 0 ? 1 : count;
}

/* overriding */

- (void)configureFormatters {
  [super configureFormatters];

  [self->aptFormatter setSingleLineFullDetails];
  [self->aptTooltipFormatter setTooltip];
}

- (NSArray *)aptsForCurrentDate {
  NSArray        *apts;
  NSMutableArray *filtered;
  unsigned       i, count;
  NSCalendarDate *start, *end;
  
  start = self->currentDate;
  end   = [start dateByAddingYears:0
                            months:0
                              days:0
                             hours:0
                           minutes:59
                           seconds:59];
  
  apts     = [self appointments];
  filtered = [[NSMutableArray alloc] initWithCapacity:1];
  count    = [apts count];
  for (i = 0; i < count; i++) {
    id apt;
    NSCalendarDate *aptStartDate;
    
    apt = [apts objectAtIndex:i];
    aptStartDate = [apt valueForKey:@"startDate"];
    if([aptStartDate isGreaterThanOrEqualTo:start] &&
       [aptStartDate isLessThan:end])
    {
      [filtered addObject:apt];
    }
  }
  
  return [filtered autorelease];
}

- (NSArray *)allDayApts {
  NSCalendarDate *start;
  NSArray        *apts;
  NSMutableArray *filtered;
  unsigned       i, count;
  
  if (self->allDayApts)
    return self->allDayApts;

  start    = [self startDate];
  apts     = [self appointments];
  filtered = [[NSMutableArray alloc] initWithCapacity:1];
  count    = [apts count];
  for (i = 0; i < count; i++) {
    id       apt;
    NSNumber *bv;
    
    apt = [apts objectAtIndex:i];
    bv  = [apt valueForKey:@"isallday"];
    if ([bv boolValue]) {
      [filtered addObject:apt];
    }
    else {
      NSCalendarDate *aptStartDate;

      aptStartDate = [apt valueForKey:@"startDate"];
      if([aptStartDate isLessThan:start]) {
        [filtered addObject:apt];
      }
    }
  }
  
  ASSIGN(self->allDayApts, filtered);
  [filtered release];
  return self->allDayApts;
}

@end
