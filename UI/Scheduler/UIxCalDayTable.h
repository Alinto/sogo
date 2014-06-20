/* UIxCalDayTable.h - this file is part of $PROJECT_NAME_HERE$
 *
 * Copyright (C) 2006 Inverse inc.
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
@class NSNumber;
@class NSString;

@class SOGoDateFormatter;

@interface UIxCalDayTable : UIxCalView
{
  SOGoDateFormatter *dateFormatter;
  NSArray *weekDays;
  NSString *currentView, *timeFormat, *currentTableHour;
  NSCalendarDate *startDate, *currentTableDay;
  NSMutableArray *daysToDisplay, *calendarsToDisplay,  *currentCalendar, *hoursToDisplay;
  unsigned int numberOfDays;
}

- (void) setNumberOfDays: (NSNumber *) aNumber;
- (NSNumber *) numberOfDays;
- (NSString *) currentView;

- (void) setStartDate: (NSCalendarDate *) aStartDate;
- (NSCalendarDate *) startDate;
- (NSCalendarDate *) endDate;

- (NSArray *) daysToDisplay;
- (NSArray *) calendarsToDisplay;
- (void) setCurrentTableDay: (NSCalendarDate *) aTableDay;
- (NSCalendarDate *) currentTableDay;
- (NSMutableArray *) currentCalendar;

@end

#endif /* UIXCALDAYTABLE_H */
