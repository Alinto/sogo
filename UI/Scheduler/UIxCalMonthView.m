// $Id: UIxCalMonthView.m 191 2004-08-12 16:28:32Z helge $

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSString.h>

#import <EOControl/EOQualifier.h>
#import <NGExtensions/NSCalendarDate+misc.h>

#import <SOGo/NSCalendarDate+SOGo.h>

#import <SOGoUI/SOGoAptFormatter.h>

#import "UIxCalMonthView.h"

@implementation UIxCalMonthView

- (void)dealloc {
  [self->currentWeekStart release];
  [super dealloc];
}

- (NSCalendarDate *)startOfMonth {
  return [[[self selectedDate] firstDayOfMonth] beginOfDay];
}

- (NSCalendarDate *)startDate {
  return [[self startOfMonth] mondayOfWeek];
}

- (NSCalendarDate *)endDate {
  NSCalendarDate *date;
  
  date = [self startOfMonth];
  date = [date dateByAddingYears:0 months:0 days:[date numberOfDaysInMonth]
               hours:0 minutes:0 seconds:0];
  date = [[date sundayOfWeek] endOfDay];
  return date;
}

/* URLs */

- (NSDictionary *) _monthQueryParametersWithOffset: (int) monthsOffset
{
  NSCalendarDate *date;
  
  date = [[self startOfMonth] dateByAddingYears: 0 months: monthsOffset days: 0
                              hours:0 minutes:0 seconds:0];
  return [self queryParametersBySettingSelectedDate:date];
}

- (NSDictionary *) monthBeforePrevMonthQueryParameters
{
  return [self _monthQueryParametersWithOffset: -14];
}

- (NSDictionary *) prevMonthQueryParameters
{
  return [self _monthQueryParametersWithOffset: -7];
}

- (NSDictionary *) nextMonthQueryParameters
{
  return [self _monthQueryParametersWithOffset: 7];
}

- (NSDictionary *) monthAfterNextMonthQueryParameters
{
  return [self _monthQueryParametersWithOffset: 14];
}

- (NSString *) _monthNameWithOffsetFromThisMonth: (int) offset
{
  NSCalendarDate *date;

  date = [[self startOfMonth] dateByAddingYears: 0 months: offset days: 0
                              hours:0 minutes:0 seconds:0];

  return [self localizedNameForMonthOfYear: [date monthOfYear]];
}

- (NSString *) monthBeforeLastMonthName
{
  return [self _monthNameWithOffsetFromThisMonth: -2];
}

- (NSString *) lastMonthName
{
  return [self _monthNameWithOffsetFromThisMonth: -1];
}

- (NSString *) currentMonthName
{
  return [self _monthNameWithOffsetFromThisMonth: 0];
}

- (NSString *) nextMonthName
{
  return [self _monthNameWithOffsetFromThisMonth: 1];
}

- (NSString *) monthAfterNextMonthName
{
  return [self _monthNameWithOffsetFromThisMonth: 2];
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

@end /* UIxCalMonthView */

