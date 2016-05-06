/* UIxCalView.h - this file is part of SOGo
 *
 * Copyright (C) 2006-2016 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#ifndef __SOGo_UIxCalView_H__
#define __SOGo_UIxCalView_H__

#include <SOGoUI/UIxComponent.h>

/*
  UIxCalView
  
  Superclass for most components which render a set of appointments coming from
  a SOPE clientObject (which usually is an SOGoAppointmentFolder).
*/

@class NSArray;
@class NSCalendarDate;
@class NSDictionary;
@class NSMutableDictionary;
@class NSString;
@class NSTimeZone;

@class SOGoAptFormatter;
@class SOGoAppointmentFolder;

@interface UIxCalView : UIxComponent
{
  NSArray *appointments;
  NSMutableDictionary *componentsData;
  NSArray *tasks;
  NSArray *allDayApts;
  NSArray *enabledWeekDays;
  id appointment;
  NSCalendarDate *currentDay;
  NSTimeZone *timeZone;
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

- (void) configureFormatters;

/* accessors */

- (NSArray *) appointments;
- (void) setAppointments: (NSArray *) _apts;

- (void) setTasks: (NSArray *) _tasks;
- (NSArray *) tasks;

- (NSArray *) allDayApts;
- (id) appointment;
- (BOOL) isMyApt;
- (BOOL) canAccessApt; /* protection */

- (BOOL) hasDayInfo;
- (BOOL) hasHoldidayInfo;
- (BOOL) hasAllDayApts;

- (NSDictionary *) aptTypeDict;
- (NSString *) aptTypeLabel;
- (NSString *) aptTypeIcon;
- (SOGoAptFormatter *) aptFormatter;

- (NSString *) shortTextForApt;
- (NSString *) shortTitleForApt;
- (NSString *) tooltipForApt;
- (NSString *) appointmentViewURL;

- (id) holidayInfo;

/* related to current day */
- (void) setCurrentDay: (NSCalendarDate *) _day;
- (NSCalendarDate *) currentDay;
- (NSString *) currentDayName; /* localized */

/* defaults */
- (BOOL) showFullNames;
- (BOOL) showAMPMDates;
- (unsigned) dayStartHour;
- (unsigned) dayEndHour;
- (BOOL) shouldDisplayRejectedAppointments;

- (NSCalendarDate *) referenceDateForFormatter;
 
- (NSCalendarDate *) thisMonth;
- (NSCalendarDate *) nextMonth;

- (void) setCurrentView: (NSString *) theView;

/* fetching */

- (NSCalendarDate *) startDate;
- (NSCalendarDate *) endDate;

/* date selection */

- (NSDictionary *) todayQueryParameters;
- (NSDictionary *) currentDayQueryParameters;

/* CSS related */

- (NSString *) aptStyle;

/* protected methods */
- (NSCalendarDate *) _nextValidDate: (NSCalendarDate *) date;
- (int) _nextValidOffset: (int) daysOffset;
- (NSDictionary *) _dateQueryParametersWithOffset: (int) daysOffset;

@end

#endif /* __SOGo_UIxCalView_H__ */
