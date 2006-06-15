// $Id: UIxCalMonthOverview.m 62 2004-06-24 11:03:44Z znek $

#include "UIxCalMonthView.h"
#include <NGExtensions/NGExtensions.h>


@interface UIxCalMonthOverview : UIxCalMonthView
{
    int dayIndex;
    int dayOfWeek;
    int weekOfYear;
    NSCalendarDate *currentWeekStart;
}

@end

#include "common.h"

@implementation UIxCalMonthOverview

- (void)dealloc {
    [self->currentWeekStart release];
    [super dealloc];
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
        date = [[self startDate] mondayOfWeek];
    else
        date = [self startDate];
    date = [date mondayOfWeek:_week];
    [self setCurrentWeekStartDate:date];
}

- (int)weekOfYear {
    return self->weekOfYear;
}

- (int)year {
    return [[self startDate] yearOfCommonEra];
}

- (int)month {
    return [[self startDate] monthOfYear];
}

- (NSString *)localizedNameOfDayOfWeek {
    // TODO: move this to some locale method
    static char *dayNames[] = {
        "Sunday",
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday"
    };
    return [[[NSString alloc] initWithCString:
        dayNames[self->dayOfWeek]] autorelease];
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
    else if([self->currentDay monthOfYear] != [[self startDate] monthOfYear])
        return @"monthoverview_content_dimmed";
    return @"monthoverview_content";
}


/* appointments */


- (NSArray *)appointments {
  return [self fetchCoreInfos];
}

@end /* UIxCalMonthOverview */
