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
// $Id: UIxCalSelectTab.m 477 2004-12-16 19:52:40Z znek $


#include <SOGoUI/UIxComponent.h>
#include <NGObjWeb/NGObjWeb.h>
#include <NGExtensions/NGExtensions.h>


@interface UIxCalSelectTab : UIxComponent
{
    NSString *selection;
    NSCalendarDate *currentDate;
}

@end


@implementation UIxCalSelectTab

- (void)dealloc {
    [self->selection release];
    [self->currentDate release];
    [super dealloc];
}

- (void)setSelection:(NSString *)_selection {
    ASSIGN(self->selection, _selection);
}

- (NSString *)selection {
    return self->selection;
}

- (void)setCurrentDate:(NSCalendarDate *)_date {
    [_date setTimeZone:[self viewTimeZone]];
    ASSIGN(self->currentDate, _date);
}

- (NSCalendarDate *)currentDate {
    return self->currentDate;
}


/* labels */


- (NSString *)dayLabel {
    return [NSString stringWithFormat:@"%d",
        [self->currentDate dayOfMonth]];
}

- (NSString *)weekLabel {
    NSString *wlbl;
    
    wlbl = [self labelForKey:@"Week"];
    return [NSString stringWithFormat:@"%@ %d",
        wlbl,
        [self->currentDate weekOfYear]];
}

- (NSString *)monthLabel {
    return [NSString stringWithFormat:@"%@",
        [self localizedNameForMonthOfYear:[self->currentDate monthOfYear]]];
}

- (NSString *)yearLabel {
    return [NSString stringWithFormat:@"%d",
        [self->currentDate yearOfCommonEra]];
}


/* hrefs */

- (NSString *)scheduletabLink {
  return [self completeHrefForMethod:@"schedule"];
}

- (NSString *)daytabLink {
    return [self completeHrefForMethod:@"dayoverview"];
}

- (NSString *)weektabLink {
    return [self completeHrefForMethod:@"weekoverview"];
}

- (NSString *)monthtabLink {
    return [self completeHrefForMethod:@"monthoverview"];
}

- (NSString *)yeartabLink {
    return [self completeHrefForMethod:@"yearoverview"];
}


@end
