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
// $Id: UIxCalInlineMonthOverview.m 181 2004-08-11 15:13:25Z helge $


#import <NGExtensions/NSCalendarDate+misc.h>

#import "NSCalendarDate+Scheduler.h"

#import "UIxCalInlineMonthOverview.h"

@implementation UIxCalInlineMonthOverview

/* init & dealloc */

- (void)dealloc {
    [self->selectedDate release];
    [self->style release];
    [self->headerStyle release];
    [self->weekStyle release];
    [self->todayWeekStyle release];
    [self->dayHeaderStyle release];
    [self->dayBodyStyle release];
    [self->todayBodyStyle release];
    [self->inactiveDayBodyStyle release];
    [self->selectedDayExtraStyle release];
    [self->daySelectionHref release];
    [self->weekSelectionHref release];
    [self->monthSelectionHref release];
    [super dealloc];
}


/* binding accessors */

- (void)setSelectedDate:(NSCalendarDate *)_date {
    [_date setTimeZone:[[self clientObject] userTimeZone]];
    ASSIGN(self->selectedDate, _date);
}
- (NSCalendarDate *)selectedDate {
    return self->selectedDate;
}
- (void)setStyle:(NSString *)_style {
    ASSIGN(self->style, _style);
}
- (NSString *)style {
    return self->style;
}
- (void)setHeaderStyle:(NSString *)_style {
    ASSIGN(self->headerStyle, _style);
}
- (NSString *)headerStyle {
    return self->headerStyle;
}
- (void)setWeekStyle:(NSString *)_style {
    ASSIGN(self->weekStyle, _style);
}
- (NSString *)weekStyle {
    return self->weekStyle;
}
- (void)setTodayWeekStyle:(NSString *)_style {
    ASSIGN(self->todayWeekStyle, _style);
}
- (NSString *)todayWeekStyle {
    if(self->todayWeekStyle)
        return self->todayWeekStyle;
    return [self weekStyle];
}
- (void)setDayHeaderStyle:(NSString *)_style {
    ASSIGN(self->dayHeaderStyle, _style);
}
- (NSString *)dayHeaderStyle {
    return self->dayHeaderStyle;
}
- (void)setDayBodyStyle:(NSString *)_style {
    ASSIGN(self->dayBodyStyle, _style);
}
- (NSString *)dayBodyStyle {
    return self->dayBodyStyle;
}
- (void)setTodayBodyStyle:(NSString *)_style {
    ASSIGN(self->todayBodyStyle, _style);
}
- (NSString *)todayBodyStyle {
    return self->todayBodyStyle;
}
- (void)setInactiveDayBodyStyle:(NSString *)_style {
    ASSIGN(self->inactiveDayBodyStyle, _style);
}
- (NSString *)inactiveDayBodyStyle {
    return self->inactiveDayBodyStyle;
}
- (void)setSelectedDayExtraStyle:(NSString *)_style {
    ASSIGN(self->selectedDayExtraStyle, _style);
}
- (NSString *)selectedDayExtraStyle {
    return self->selectedDayExtraStyle;
}
- (void)setDaySelectionHref:(NSString *)_href {
    ASSIGN(self->daySelectionHref, _href);
}
- (NSString *)daySelectionHref {
    return self->daySelectionHref;
}
- (BOOL)hasDaySelectionHref {
    return self->daySelectionHref != nil;
}
- (void)setWeekSelectionHref:(NSString *)_href {
    ASSIGN(self->weekSelectionHref, _href);
}
- (NSString *)weekSelectionHref {
    return self->weekSelectionHref;
}
- (BOOL)hasWeekSelectionHref {
    return self->weekSelectionHref != nil;
}
- (void)setMonthSelectionHref:(NSString *)_href {
    ASSIGN(self->monthSelectionHref, _href);
}
- (NSString *)monthSelectionHref {
    return self->monthSelectionHref;
}
- (BOOL)hasMonthSelectionHref {
    return self->monthSelectionHref != nil;
}
- (void)setShowWeekColumn:(BOOL)_yn {
    self->showWeekColumn = _yn;
}
- (BOOL)showWeekColumn {
    return self->showWeekColumn;
}
- (void)setShowYear:(BOOL)_yn {
    self->showYear = _yn;
}
- (BOOL)showYear {
    return self->showYear;
}


/* date ranges */


- (NSCalendarDate *)startDate {
    return [[self selectedDate] firstDayOfMonth];
}


/* labels */

- (NSString *)headerString {
    NSString *label;
    
    label = [self localizedNameForMonthOfYear:[[self startDate] monthOfYear]];
    if([self showYear]) {
        label = [NSString stringWithFormat:@"%@ %d",
            label,
            [[self startDate] yearOfCommonEra]];
    }
    return label;
}

- (NSString *)localizedDayOfWeekName {
    return [self localizedAbbreviatedNameForDayOfWeek:[self dayOfWeek]];
}


/* stylesheets */

- (NSString *)currentWeekStyle {
    if([self->currentWeekStart isDateInSameWeek:[NSCalendarDate date]] &&
       [self->currentWeekStart isDateInSameMonth:[self selectedDate]])
        return [self todayWeekStyle];
    return [self weekStyle];
}

- (NSString *)currentDayStyle {
    return [self dayBodyStyle];
}

- (NSString *)contentStyle {
    if([self->currentDay isToday] &&
       [self->currentDay isDateInSameMonth:[self selectedDate]])
        return [self todayBodyStyle];
    else if([self->currentDay monthOfYear] != [[self startDate] monthOfYear])
        return [self inactiveDayBodyStyle];
    return [self dayBodyStyle];
}

- (NSString *)extraStyle {
    if([[self selectedDate] isDateOnSameDay:self->currentDay]) {
        return [self selectedDayExtraStyle];
    }
    return nil;
}


/* URLs */

- (NSDictionary *)currentMonthQueryParameters {
    return [self queryParametersBySettingSelectedDate:[self startDate]];
}

/* overriding */

- (NSArray *)fetchCoreInfos {
    return nil;
}

@end
