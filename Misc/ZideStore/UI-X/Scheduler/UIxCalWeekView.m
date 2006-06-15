// $Id: UIxCalWeekView.m 59 2004-06-22 13:40:19Z znek $

#include "UIxCalWeekView.h"
#include "common.h"

@implementation UIxCalWeekView

- (NSCalendarDate *)startDate {
  return [[super startDate] mondayOfWeek];
}

- (NSCalendarDate *)endDate {
  return [[self startDate] dateByAddingYears:0 months:0 days:7
			   hours:0 minutes:0 seconds:0];
}

/* URLs */

- (NSDictionary *)prevWeekQueryParameters {
    NSCalendarDate *date;

    date = [[self startDate] dateByAddingYears:0 months:0 days:-7 
                             hours:0 minutes:0 seconds:0];
    return [self queryParametersBySettingSelectedDate:date];
}

- (NSDictionary *)nextWeekQueryParameters {
    NSCalendarDate *date;
    
    date = [[self startDate] dateByAddingYears:0 months:0 days:7 
                             hours:0 minutes:0 seconds:0];
    return [self queryParametersBySettingSelectedDate:date];
}

@end /* UIxCalWeekView */
