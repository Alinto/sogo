/* UIxCalMulticolumnDayView.h - this file is part of SOGo
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

#ifndef	__UIxCalMulticolumnDayView_H_
#define	__UIxCalMulticolumnDayView_H_

#import "UIxCalDayView.h"

@interface UIxCalMulticolumnDayView : UIxCalDayView
{
  SOGoDateFormatter *dateFormatter;
  NSString *currentTableHour;
  NSMutableArray *subscriptionUsers;
  NSMutableArray *hoursToDisplay;
  NSArray *allAppointments;

  NSString *currentTableUser;
  NSDictionary *currentAppointment;

  NSString *cssClass;
  NSString *cssId;
}

- (void) setCSSClass: (NSString *) aCssClass;
- (NSString *) cssClass;

- (void) setCSSId: (NSString *) aCssId;
- (NSString *) cssId;

- (NSArray *) subscriptionUsers;
- (void) setCurrentTableUser: (NSString *) aTableDay;
- (NSString *) currentTableUser;

- (void) setCurrentAppointment: (NSDictionary *) newCurrentAppointment;
- (NSDictionary *) currentAppointment;

@end

#endif	/* __UIxCalMulticolumnDayView_H_ */
