// $Id: UIxCalMonthOverview.m 885 2005-07-21 16:41:34Z znek $

#include "UIxCalMonthOverview.h"
#include "common.h"
#include <SOGoUI/SOGoAptFormatter.h>

@implementation UIxCalMonthOverview

- (void)dealloc {
  [self->currentWeekStart release];
  [super dealloc];
}

- (void)configureFormatters {
  [super configureFormatters];
  
  [self->aptFormatter        setShortTitleOnly];
  [self->privateAptFormatter setPrivateTitleOnly];
}

- (void)setDayIndex:(int)_idx {
    self->dayIndex = _idx;
}

- (int)dayIndex {
    return self->dayIndex;
}

- (void)setDayOfWeek:(int)_day {
    self->dayOfWeek = _day;
}

- (int)dayOfWeek {
    return self->dayOfWeek;
}

- (void)setCurrentWeekStartDate:(NSCalendarDate *)_date {
    ASSIGN(self->currentWeekStart, _date);
}

- (NSCalendarDate *)currentWeekStartDate {
    return self->currentWeekStart;
}

- (void)setWeekOfYear:(int)_week {
    NSCalendarDate *date;
    
    self->weekOfYear = _week;
    if(_week == 52 || _week == 53)
        date = [[self startOfMonth] mondayOfWeek];
    else
        date = [self startOfMonth];
    date = [date mondayOfWeek:_week];
    [self setCurrentWeekStartDate:date];
}

- (int)weekOfYear {
    return self->weekOfYear;
}

- (int)year {
    return [[self startOfMonth] yearOfCommonEra];
}

- (int)month {
    return [[self startOfMonth] monthOfYear];
}

- (NSString *)localizedDayOfWeekName {
    return [self localizedNameForDayOfWeek:self->dayOfWeek];
}

- (NSDictionary *)currentWeekQueryParameters {
    return [self queryParametersBySettingSelectedDate:self->currentWeekStart];
}


/* style sheet */


- (NSString *)weekStyle {
    if([self->currentWeekStart isDateInSameWeek:[NSCalendarDate date]])
        return @"monthoverview_week_hilite";
    return @"monthoverview_week";
}

- (NSString *)contentStyle {
    if([self->currentDay isToday])
        return @"monthoverview_content_hilite";
    else if([self->currentDay monthOfYear] != [[self startOfMonth] monthOfYear])
        return @"monthoverview_content_dimmed";
    return @"monthoverview_content";
}


/* appointments */


- (NSArray *)appointments {
  return [self fetchCoreAppointmentsInfos];
}

@end /* UIxCalMonthOverview */
