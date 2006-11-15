/* UIxCalDayTable.h - this file is part of $PROJECT_NAME_HERE$
 *
 * Copyright (C) 2006 Inverse groupe conseil
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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

#ifndef UIXCALDAYTABLE_H
#define UIXCALDAYTABLE_H

#import "UIxCalView.h"

@class NSArray;
@class NSCalendarDay;
@class NSDictionary;
@class NSString;
@class SOGoDateFormatter;

@interface UIxCalDayTable : UIxCalView
{
  SOGoDateFormatter *dateFormatter;
  int numberOfDays;
  NSCalendarDate *startDate;
  NSCalendarDate *currentTableDay;
  NSString *currentTableHour;
  NSMutableArray *daysToDisplay;
  NSMutableArray *hoursToDisplay;
  NSArray *allAppointments;

  NSDictionary *currentAppointment;

  NSString *cssClass;
  NSString *cssId;
}

- (void) setCSSClass: (NSString *) aCssClass;
- (NSString *) cssClass;

- (void) setCSSId: (NSString *) aCssId;
- (NSString *) cssId;

- (void) setNumberOfDays: (NSString *) aNumber;
- (NSString *) numberOfDays;

- (void) setStartDate: (NSCalendarDate *) aStartDate;
- (NSCalendarDate *) startDate;
- (NSCalendarDate *) endDate;

- (NSArray *) daysToDisplay;
- (void) setCurrentTableDay: (NSCalendarDate *) aTableDay;
- (NSCalendarDate *) currentTableDay;

- (void) setCurrentAppointment: (NSDictionary *) newCurrentAppointment;
- (NSDictionary *) currentAppointment;

@end

#endif /* UIXCALDAYTABLE_H */
