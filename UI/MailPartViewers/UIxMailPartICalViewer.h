/*
 * Copyright (C) 2007-2016 Inverse inc.
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

#ifndef UIXMAILPARTICALVIEWER_H
#define UIXMAILPARTICALVIEWER_H

#import "UIxMailPartViewer.h"

@class iCalEvent;
@class iCalCalendar;

@class SOGoAppointmentObject;
@class SOGoDateFormatter;

@interface UIxMailPartICalViewer : UIxMailPartViewer
{
  iCalCalendar *inCalendar;
  iCalEvent *inEvent;
  SOGoDateFormatter *dateFormatter;
  SOGoAppointmentObject *storedEventObject;
  BOOL storedEventFetched;
  iCalEvent *storedEvent;
}

- (iCalEvent *) authorativeEvent;
- (NSString *) endDate;
- (NSString *) endTime;
- (NSString *) startDate;
- (NSString *) startTime;
- (BOOL) isEndDateOnSameDay;
- (BOOL) hasLocation;
- (NSString *)location;

@end

#endif /* UIXMAILPARTICALVIEWER_H */
