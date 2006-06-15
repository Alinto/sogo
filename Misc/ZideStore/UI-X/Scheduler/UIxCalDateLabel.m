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
// $Id: UIxCalDateLabel.m 59 2004-06-22 13:40:19Z znek $


#include <NGObjWeb/NGObjWeb.h>


@interface UIxCalDateLabel : WOComponent
{
    NSString *selection;
    NSCalendarDate *startDate;
    NSCalendarDate *endDate;
}

- (NSString *)dayLabel;
- (NSString *)weekLabel;
- (NSString *)monthLabel;
- (NSString *)yearLabel;

@end


@implementation UIxCalDateLabel

- (void)dealloc {
    [self->selection release];
    [self->startDate release];
    [self->endDate release];
    [super dealloc];
}

- (void)setSelection:(NSString *)_selection {
    ASSIGN(self->selection, _selection);
}

- (NSString *)selection {
    return self->selection;
}

- (void)setStartDate:(NSCalendarDate *)_date {
    ASSIGN(self->startDate, _date);
}

- (NSCalendarDate *)startDate {
    return self->startDate;
}

- (void)setEndDate:(NSCalendarDate *)_date {
    ASSIGN(self->endDate, _date);
}

- (NSCalendarDate *)endDate {
    return self->endDate;
}

- (NSString *)label {
    NSString *key = [self selection];
    if([key isEqualToString:@"day"])
        return [self dayLabel];
    else if([key isEqualToString:@"week"])
        return [self weekLabel];
    else if([key isEqualToString:@"month"])
        return [self monthLabel];
    return [self yearLabel];
}

- (NSString *)dayLabel {
    return [self->startDate descriptionWithCalendarFormat:@"%Y-%m-%d"];
}

- (NSString *)weekLabel {
    NSString *label;
    
    label = [self->startDate descriptionWithCalendarFormat:@"%B %Y"];
    if([self->startDate monthOfYear] != [self->endDate monthOfYear]) {
        NSString *ext;
        
        ext = [self->endDate descriptionWithCalendarFormat:@"%B %Y"];
        label = [NSString stringWithFormat:@"<nobr>%@ / %@</nobr>",
                                            label,
                                            ext];
    }
    return label;
}

- (NSString *)monthLabel {
    return [self->startDate descriptionWithCalendarFormat:@"%B %Y"];
}

- (NSString *)yearLabel {
    return [self->startDate descriptionWithCalendarFormat:@"%Y"];
}

@end
