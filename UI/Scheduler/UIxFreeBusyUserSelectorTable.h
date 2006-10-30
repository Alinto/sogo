/* UIxFreeBusyUserSelectorTable.h - this file is part of SOGo
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

#ifndef UIXFREEBUSYUSERSELECTORTABLE_H
#define UIXFREEBUSYUSERSELECTORTABLE_H

#import <SOGoUI/UIxComponent.h>

@class NSArray;
@class NSCalendarDate;
@class NSNumber;

@class iCalPerson;
@class SOGoDateFormatter;

@interface UIxFreeBusyUserSelectorTable : UIxComponent
{
  BOOL standAlone;
  NSMutableArray *daysToDisplay;
  NSMutableArray *hoursToDisplay;
  SOGoDateFormatter *dateFormatter;

  NSArray *contacts;
  NSNumber *dayStartHour;
  NSNumber *dayEndHour;
  NSCalendarDate *startDate;
  NSCalendarDate *endDate;

  iCalPerson *currentContact;
  NSNumber *currentHourToDisplay;
  NSCalendarDate *currentDayToDisplay;
}

- (void) setContacts: (NSArray *) newContacts;
- (NSArray *) contacts;

- (void) setStartDate: (NSCalendarDate *) newStartDate;
- (void) setEndDate: (NSCalendarDate *) newEndDate;

- (void) setDayStartHour: (NSNumber *) newDayStartHour;
- (NSNumber *) dayStartHour;
- (void) setDayEndHour: (NSNumber *) newDayEndHour;
- (NSNumber *) dayEndHour;

- (void) setCurrentContact: (iCalPerson *) newCurrentContact;
- (iCalPerson *) currentContact;
- (NSString *) currentContactId;
- (NSString *) currentContactName;

- (void) setCurrentDayToDisplay: (NSCalendarDate *) newCurrentDayToDisplay;
- (NSCalendarDate *) currentDayToDisplay;

- (void) setCurrentHourToDisplay: (NSNumber *) newCurrentHourToDisplay;
- (NSNumber *) currentHourToDisplay;

- (NSString *) currentFormattedDay;

- (NSArray *) daysToDisplay;
- (NSArray *) hoursToDisplay;

@end

#endif /* UIXFREEBUSYUSERSELECTORTABLE_H */
