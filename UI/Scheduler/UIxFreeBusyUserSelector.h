/* UIxFreeBusyUserSelector.h - this file is part of SOGo
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

#ifndef UIXFREEBUSYUSERSELECTOR_H
#define UIXFREEBUSYUSERSELECTOR_H

#import <SOGoUI/UIxComponent.h>

@class NSArray;
@class NSMutableArray;
@class NSCalendarDate;
@class NSNumber;
@class SOGoDateFormatter;
@class iCalPerson;

@interface UIxFreeBusyUserSelector : UIxComponent
{
  SOGoDateFormatter *dateFormatter;
  NSCalendarDate *startDate;
  NSCalendarDate *endDate;
  NSNumber *dayStartHour;
  NSNumber *dayEndHour;
  NSMutableArray *daysToDisplay;
  NSMutableArray *hoursToDisplay;
  NSCalendarDate *currentDayToDisplay;
  NSNumber *currentHourToDisplay;

  NSArray *contacts;
  iCalPerson *currentContact;

  NSString *selectorId;
}

- (void) setStartDate: (NSCalendarDate *) newStartDate;
- (void) setEndDate: (NSCalendarDate *) newEndDate;

- (void) setDayStartHour: (NSNumber *) newDayStartHour;
- (void) setDayEndHour: (NSNumber *) newDayEndHour;

- (void) setContacts: (NSArray *) contacts;
- (NSArray *) contacts;

- (void) setSelectorId: (NSString *) newSelectorId;
- (NSString *) selectorId;

- (NSArray *) daysToDisplay;
- (NSArray *) hoursToDisplay;
- (void) setCurrentDayToDisplay: (NSCalendarDate *) newCurrentDayToDisplay;
- (void) setCurrentHourToDisplay: (NSNumber *) newCurrentHourToDisplay;
- (NSCalendarDate *) currentDayToDisplay;
- (NSNumber *) currentHourToDisplay;

@end

#endif /* UIXFREEBUSYUSERSELECTOR_H */
