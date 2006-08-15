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
// $Id: UIxCalWeekOverview.m 663 2005-07-05 18:13:24Z znek $

#include "UIxCalWeekOverview.h"
#include "common.h"
#include <SOGoUI/SOGoAptFormatter.h>

@implementation UIxCalWeekOverview

- (id) correctURLAction
{
  return [self redirectToLocation: @"weekoverview"];
}

- (void)configureFormatters {
  [super configureFormatters];
  
  [self->aptFormatter setOmitsEndDate];
}

- (void)setDayIndex:(char)_idx {
    NSCalendarDate *d;
    
    if ((self->dayIndex == _idx) && (self->currentDay != nil))
        return;
    
    self->dayIndex = _idx;
    
    if (_idx > 0) {
        d = [[self startDate]
               dateByAddingYears:0 months:0 days:_idx
                           hours:0 minutes:0 seconds:0];
    }
    else
        d = [self startDate];
    
    [self setCurrentDay:d];
}

- (int)dayIndex {
    return self->dayIndex;
}

/* style sheet */

- (NSString *)titleStyle {
    if([self->currentDay isToday])
        return @"weekoverview_title_hilite";
    return @"weekoverview_title";
}

- (NSString *)contentStyle {
    if([self->currentDay isToday])
        return @"weekoverview_content_hilite";
    return @"weekoverview_content";
}

@end /* UIxCalWeekOverview */
