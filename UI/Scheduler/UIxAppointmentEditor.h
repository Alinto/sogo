/* UIxAppointmentEditor.h - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
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

#ifndef UIXAPPOINTMENTEDITOR_H
#define UIXAPPOINTMENTEDITOR_H

#import <SOGoUI/UIxComponent.h>

@class iCalEvent;
@class NSString;

@interface UIxAppointmentEditor : UIxComponent
{
  iCalEvent *event;
  SOGoAppointmentFolder *componentCalendar;
  BOOL isAllDay;
  NSCalendarDate *aptStartDate;
  NSCalendarDate *aptEndDate;
  NSString *item;
}

/* template values */
- (NSString *) saveURL;
- (iCalEvent *) event;

/* icalendar values */
- (BOOL) isAllDay;
- (void) setIsAllDay: (BOOL) newIsAllDay;

- (void) setAptStartDate: (NSCalendarDate *) _date;
- (NSCalendarDate *) aptStartDate;

- (void) setAptEndDate: (NSCalendarDate *) _date;
- (NSCalendarDate *) aptEndDate;

@end

#endif /* UIXAPPOINTMENTEDITOR_H */
