/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __NGCards_iCalEvent_H__
#define __NGCards_iCalEvent_H__

#import "iCalRepeatableEntityObject.h"

/*
  iCalEvent
  
  This class keeps the attributes of an iCalendar event record, that is,
  an appointment.
*/

@class NSCalendarDate;
@class NSDate;
@class NSString;
@class NSMutableArray;

@class NGCalendarDateRange;
@class iCalEventChanges;

@interface iCalEvent : iCalRepeatableEntityObject

/* accessors */

- (void) setAllDayWithStartDate: (NSCalendarDate *) newStartDate
		       duration: (unsigned int) days;

- (void) setEndDate: (NSCalendarDate *) _date;
- (NSCalendarDate *) endDate;
- (BOOL) hasEndDate;

- (NSString *) duration;
- (void) setDuration: (NSString *) _value;
- (BOOL) hasDuration;
- (NSTimeInterval) durationAsTimeInterval;

- (void) setTransparency: (NSString *) _transparency;
- (NSString *) transparency;

/* convenience */

- (BOOL) isOpaque;
- (BOOL) isAllDay;

- (BOOL) isWithinCalendarDateRange: (NGCalendarDateRange *) _range;
- (NSArray *) recurrenceRangesWithinCalendarDateRange: (NGCalendarDateRange *)_r;

/* calculating changes */

- (iCalEventChanges *) getChangesRelativeToEvent: (iCalEvent *) _event;

- (id) propertyValue: (NSString *) property;

- (NSCalendarDate *) firstRecurrenceStartDate;

@end 

#endif /* __NGCards_iCalEvent_H__ */
