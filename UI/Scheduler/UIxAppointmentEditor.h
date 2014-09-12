/* UIxAppointmentEditor.h - this file is part of SOGo
 *
 * Copyright (C) 2007-2014 Inverse inc.
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

#ifndef UIXAPPOINTMENTEDITOR_H
#define UIXAPPOINTMENTEDITOR_H

#import <SOGoUI/UIxComponent.h>

@class iCalEvent;
@class NSString;

@interface UIxAppointmentEditor : UIxComponent
{
  iCalEvent *event;
  BOOL isAllDay, isTransparent, sendAppointmentNotifications;
  NSCalendarDate *aptStartDate;
  NSCalendarDate *aptEndDate;
  NSString *item;
  SOGoAppointmentFolder *componentCalendar;
  SOGoDateFormatter *dateFormatter;
}

/* template values */
- (NSString *) saveURL;
- (iCalEvent *) event;

/* icalendar values */
- (void) setIsAllDay: (BOOL) newIsAllDay;
- (BOOL) isAllDay;

- (void) setIsTransparent: (BOOL) newIsOpaque;
- (BOOL) isTransparent;

- (void) setSendAppointmentNotifications: (BOOL) theBOOL;
- (BOOL) sendAppointmentNotifications;

- (void) setAptStartDate: (NSCalendarDate *) newAptStartDate;
- (NSCalendarDate *) aptStartDate;

- (void) setAptEndDate: (NSCalendarDate *) newAptEndDate;
- (NSCalendarDate *) aptEndDate;

- (NSString *) aptStartDateText;
- (NSString *) aptStartDateTimeText;
- (NSString *) aptEndDateTimeText;

@end

#endif /* UIXAPPOINTMENTEDITOR_H */
