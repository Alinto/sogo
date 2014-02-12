/*

  Copyright (C) 2006-2013 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of SOGo.

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

#ifndef __Appointments_SOGoTaskObject_H__
#define __Appointments_SOGoTaskObject_H__

#import "SOGoCalendarComponent.h"

/*
  SOGoTaskObject
  
  Represents a single task. This SOPE controller object manages all the
  attendee storages (that is, it might store into multiple folders for meeting
  tasks!).

  Note: SOGoTaskObject do not need to exist yet. They can also be "new"
        tasks with an externally generated unique key.
*/

@class NSArray;
@class NSException;
@class NSString;

@class iCalToDo;
@class iCalCalendar;

@interface SOGoTaskObject : SOGoCalendarComponent

@end

#endif /* __Appointmentss_SOGoTaskObject_H__ */
