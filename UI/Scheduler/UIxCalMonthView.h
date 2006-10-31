// $Id: UIxCalMonthView.h 163 2004-08-02 12:59:28Z znek $

#ifndef __SOGo_UIxCalMonthView_H__
#define __SOGo_UIxCalMonthView_H__

#include "UIxCalView.h"

/*
  UIxCalMonthView
  
  Abstract superclass for views which display months.
*/

@interface UIxCalMonthView : UIxCalView
{
    int dayIndex;
    int dayOfWeek;
    int weekOfYear;
    NSCalendarDate *currentWeekStart;
}

- (NSCalendarDate *)startOfMonth;

- (NSDictionary *)prevMonthQueryParameters;
- (NSDictionary *)nextMonthQueryParameters;

- (void)setDayIndex:(int)_idx;
- (int)dayIndex;
- (void)setDayOfWeek:(int)_day;
- (int)dayOfWeek;

- (void)setCurrentWeekStartDate:(NSCalendarDate *)_date;
- (NSCalendarDate *)currentWeekStartDate;
- (void)setWeekOfYear:(int)_week;
- (int)weekOfYear;
- (int)year;
- (int)month;
- (NSString *)localizedDayOfWeekName;
- (NSDictionary *)currentWeekQueryParameters;


/* style sheet */


- (NSString *)weekStyle;

- (NSString *)contentStyle;


/* appointments */


- (NSArray *)appointments;

@end

#endif /* __SOGo_UIxCalMonthView_H__ */
