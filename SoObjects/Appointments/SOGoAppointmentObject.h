/*
  Copyright (C) 2007-2011 Inverse inc.

  This file is part of SOGo

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __Appointments_SOGoAppointmentObject_H__
#define __Appointments_SOGoAppointmentObject_H__

#import <SOGo/SOGoContentObject.h>

@class NSArray;
@class NSException;
@class NSString;

@class WORequest;

@class iCalEvent;
@class iCalCalendar;

#import "SOGoCalendarComponent.h"

@interface SOGoAppointmentObject : SOGoCalendarComponent

- (NSException *) changeParticipationStatus: (NSString *) status
                               withDelegate: (iCalPerson *) delegate;
- (NSException *) changeParticipationStatus: (NSString *) status
                               withDelegate: (iCalPerson *) delegate
			    forRecurrenceId: (NSCalendarDate *) _recurrenceId;

//
// Old CalDAV scheduling (draft 4 and below) methods. We keep them since we still
// advertise for its support but we do everything within the calendar-auto-scheduling code
//
- (NSArray *) postCalDAVEventRequestTo: (NSArray *) recipients  from: (NSString *) originator;
- (NSArray *) postCalDAVEventReplyTo: (NSArray *) recipients  from: (NSString *) originator;
- (NSArray *) postCalDAVEventCancelTo: (NSArray *) recipients  from: (NSString *) originator;

- (NSException *) updateContentWithCalendar: (iCalCalendar *) calendar
                                fromRequest: (WORequest *) rq;

@end

#endif /* __Appointments_SOGoAppointmentObject_H__ */
