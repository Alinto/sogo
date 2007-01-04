// $Id: UIxCalView.h 1007 2007-01-04 14:42:10Z wolfgang $

#ifndef __SOGo_UIxCalView_H__
#define __SOGo_UIxCalView_H__

#include <SOGoUI/UIxComponent.h>

/*
  UIxCalView
  
  Superclass for most components which render a set of appointments coming from
  a SOPE clientObject (which usually is an SOGoAppointmentFolder).
*/

@class NSString, NSArray, NSDictionary, NSMutableDictionary, NSCalendarDate, SOGoAptFormatter;
@class SOGoAppointmentFolder;

@interface UIxCalView : UIxComponent
{
  NSArray          *appointments;
  NSMutableDictionary *componentsData;
  NSArray          *tasks;
  NSArray          *allDayApts;
  id               appointment;
  NSCalendarDate   *currentDay;
  SOGoAptFormatter *aptFormatter;
  SOGoAptFormatter *aptTooltipFormatter;
  SOGoAptFormatter *privateAptFormatter;
  SOGoAptFormatter *privateAptTooltipFormatter;

  struct {
    unsigned isMyApt      : 1;
    unsigned canAccessApt : 1;
    unsigned RESERVED     : 30;
  } aptFlags;
}


/* config */

- (void)configureFormatters;

/* accessors */

- (NSArray *) appointments;
- (void) setAppointments: (NSArray *) _apts;

- (void) setTasks: (NSArray *) _tasks;
- (NSArray *) tasks;

- (NSArray *)allDayApts;
- (id)appointment;
- (BOOL)isMyApt;
- (BOOL)canAccessApt; /* protection */

- (BOOL)hasDayInfo;
- (BOOL)hasHoldidayInfo;
- (BOOL)hasAllDayApts;

- (NSDictionary *)aptTypeDict;
- (NSString *)aptTypeLabel;
- (NSString *)aptTypeIcon;
- (SOGoAptFormatter *)aptFormatter;

- (NSString *)shortTextForApt;
- (NSString *)shortTitleForApt;
- (NSString *)tooltipForApt;
- (NSString *)appointmentViewURL;

- (id)holidayInfo;

/* related to current day */
- (void)setCurrentDay:(NSCalendarDate *)_day;
- (NSCalendarDate *)currentDay;
- (NSString *)currentDayName; /* localized */

/* defaults */
- (BOOL)showFullNames;
- (BOOL)showAMPMDates;
- (unsigned)dayStartHour;
- (unsigned)dayEndHour;
- (BOOL)shouldDisplayWeekend;
- (BOOL)shouldDisplayRejectedAppointments;

- (NSCalendarDate *)referenceDateForFormatter;
 
- (NSCalendarDate *)thisMonth;
- (NSCalendarDate *)nextMonth;

/* fetching */

- (NSCalendarDate *)startDate;
- (NSCalendarDate *)endDate;
- (NSArray *) fetchCoreAppointmentsInfos;
- (NSArray *) fetchCoreTasksInfos;

/* date selection */

- (NSDictionary *)todayQueryParameters;
- (NSDictionary *)currentDayQueryParameters;

/* calendarUIDs */

- (NSString *)formattedCalendarUIDs;

/* CSS related */

- (NSString *)aptStyle;

/* protected methods */
- (NSDictionary *) _dateQueryParametersWithOffset: (int) daysOffset;

@end

#endif /* __SOGo_UIxCalView_H__ */
