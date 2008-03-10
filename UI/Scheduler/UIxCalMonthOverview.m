
#import <Foundation/NSCalendarDate.h>
#import <NGExtensions/NSCalendarDate+misc.h>

#import <SOGoUI/SOGoAptFormatter.h>

#import "UIxCalMonthOverview.h"

@implementation UIxCalMonthOverview

- (void)dealloc {
  [currentWeekStart release];
  [super dealloc];
}

- (void)configureFormatters {
  [super configureFormatters];
  
  [aptFormatter        setShortTitleOnly];
  [privateAptFormatter setPrivateTitleOnly];
}

- (void)setDayIndex:(int)_idx {
  dayIndex = _idx;
}

- (int)dayIndex {
  return dayIndex;
}

- (void)setDayOfWeek:(int)_day {
  dayOfWeek = _day;
}

- (int)dayOfWeek {
  return dayOfWeek;
}

- (void)setCurrentWeekStartDate:(NSCalendarDate *)_date {
  ASSIGN(currentWeekStart, _date);
}

- (NSCalendarDate *)currentWeekStartDate {
  return currentWeekStart;
}

- (void)setWeekOfYear:(int)_week {
  NSCalendarDate *date;
    
  weekOfYear = _week;
  if(_week == 52 || _week == 53)
    date = [[self startOfMonth] mondayOfWeek];
  else
    date = [self startOfMonth];
  date = [date mondayOfWeek:_week];
  [self setCurrentWeekStartDate:date];
}

- (int)weekOfYear {
  return weekOfYear;
}

- (int)year {
  return [[self startOfMonth] yearOfCommonEra];
}

- (int)month {
  return [[self startOfMonth] monthOfYear];
}

- (NSString *)localizedDayOfWeekName {
  return [self localizedNameForDayOfWeek:dayOfWeek];
}

- (NSDictionary *)currentWeekQueryParameters {
  return [self queryParametersBySettingSelectedDate:currentWeekStart];
}


/* style sheet */


- (NSString *)weekStyle {
  if([currentWeekStart isDateInSameWeek:[NSCalendarDate date]])
    return @"monthoverview_week_hilite";
  return @"monthoverview_week";
}

- (NSString *)contentStyle {
  if([currentDay isToday])
    return @"monthoverview_content_hilite";
  else if([currentDay monthOfYear] != [[self startOfMonth] monthOfYear])
    return @"monthoverview_content_dimmed";
  return @"monthoverview_content";
}


/* appointments */


// - (NSArray *)appointments {
//   return [self fetchCoreAppointmentsInfos];
// }

@end /* UIxCalMonthOverview */
