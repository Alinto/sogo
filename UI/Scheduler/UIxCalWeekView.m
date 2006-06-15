// $Id: UIxCalWeekView.m 303 2004-09-10 15:23:10Z znek $

#include "UIxCalWeekView.h"
#include "common.h"

@implementation UIxCalWeekView

- (NSCalendarDate *)startDate {
    return [[[super startDate] mondayOfWeek] beginOfDay];
}

- (NSCalendarDate *)endDate {
    unsigned offset;
    
    if([self shouldDisplayWeekend])
        offset = 7;
    else
        offset = 5;
  return [[[self startDate] dateByAddingYears:0 months:0 days:offset
                            hours:0 minutes:0 seconds:0]
                            endOfDay];
}

- (NSArray *)appointments {
  return [self fetchCoreInfos];
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
