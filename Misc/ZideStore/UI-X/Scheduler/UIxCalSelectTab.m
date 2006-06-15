/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OGo

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
// $Id: UIxCalSelectTab.m 59 2004-06-22 13:40:19Z znek $


#include <Common/UIxComponent.h>
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
    ASSIGN(self->currentDate, _date);
}

- (NSCalendarDate *)currentDate {
    return self->currentDate;
}


/* labels */


- (NSString *)dayLabel {
    return [self->currentDate descriptionWithCalendarFormat:@"%d"];
}

- (NSString *)weekLabel {
    return [NSString stringWithFormat:@"Week %d", [self->currentDate weekOfYear]];
}

- (NSString *)monthLabel {
    return [self->currentDate descriptionWithCalendarFormat:@"%B"];
}

- (NSString *)yearLabel {
    return [self->currentDate descriptionWithCalendarFormat:@"%Y"];
}


/* hrefs */


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
