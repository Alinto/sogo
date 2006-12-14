/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
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

/*
  SOGoAppointmentObject
  
  Represents a single appointment. This SOPE controller object manages all the
  attendee storages (that is, it might store into multiple folders for meeting
  appointments!).

  Note: SOGoAppointmentObject do not need to exist yet. They can also be "new"
        appointments with an externally generated unique key.
*/

@class NSArray;
@class NSException;
@class NSString;

@class iCalEvent;
@class iCalCalendar;

#import "SOGoCalendarComponent.h"

@interface SOGoAppointmentObject : SOGoCalendarComponent

/* accessors */

- (iCalEvent *) event;
- (iCalEvent *) firstEventFromCalendar: (iCalCalendar *) calendar;

/* folder management */

- (id)lookupHomeFolderForUID:(NSString *)_uid inContext:(id)_ctx;
- (NSArray *)lookupCalendarFoldersForUIDs:(NSArray *)_uids inContext:(id)_ctx;

/* raw saving */

- (NSException *)primarySaveContentString:(NSString *)_iCalString;
- (NSException *)primaryDelete;

/* "iCal multifolder saves" */

- (NSException *)saveContentString:(NSString *)_iCal baseSequence:(int)_v;
- (NSException *)deleteWithBaseSequence:(int)_v;

- (NSException *)saveContentString:(NSString *)_iCalString;
- (NSException *)delete;

- (NSException *)changeParticipationStatus:(NSString *)_status
  inContext:(id)_ctx;


@end

#endif /* __Appointments_SOGoAppointmentObject_H__ */
