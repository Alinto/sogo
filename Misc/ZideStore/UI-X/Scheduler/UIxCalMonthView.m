// $Id: UIxCalMonthView.m 62 2004-06-24 11:03:44Z znek $

#include "UIxCalMonthView.h"
#include "common.h"

@implementation UIxCalMonthView

- (NSCalendarDate *)startDate {
  return [[super startDate] firstDayOfMonth];
}

- (NSCalendarDate *)endDate {
  NSCalendarDate *startDate = [self startDate];
  return [startDate dateByAddingYears:0
                    months:0
                    days:[startDate numberOfDaysInMonth]
                    hours:0
                    minutes:0
                    seconds:0];
}

/* URLs */


- (NSDictionary *)prevMonthQueryParameters {
    NSCalendarDate *date;

    date = [[self startDate] dateByAddingYears:0
                             months:-1
                             days:0
                             hours:0
                             minutes:0
                             seconds:0];
    return [self queryParametersBySettingSelectedDate:date];
}

- (NSDictionary *)nextMonthQueryParameters {
    NSCalendarDate *date;
    
    date = [[self startDate] dateByAddingYears:0
                             months:1
                             days:0
                             hours:0
                             minutes:0
                             seconds:0];
    return [self queryParametersBySettingSelectedDate:date];
}

@end /* UIxCalMonthView */
