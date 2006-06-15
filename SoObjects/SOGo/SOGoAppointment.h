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

#ifndef	__SOGoAppointment_H_
#define	__SOGoAppointment_H_

#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>

/*
  SOGoAppointment
  
  Wrapper around the iCalendar content of appointments stored in the 
  OGoContentStore.
*/

@class NSString, NSArray, NSCalendarDate, NGCalendarDateRange;
@class iCalPerson, iCalEvent, iCalRecurrenceRule;

@interface SOGoAppointment : NSObject <NSCopying>
{
  id        calendar;
  iCalEvent *event;
  id        participants;
}

- (id)initWithICalString:(NSString *)_iCal;

- (void)setUid:(NSString *)_value;
- (NSString *)uid;

- (void)setSummary:(NSString *)_value;
- (NSString *)summary;

- (void)setLocation:(NSString *)_value;
- (NSString *)location;
- (BOOL)hasLocation;

- (void)setComment:(NSString *)_value;
- (NSString *)comment;
- (BOOL)hasComment;

- (void)setUserComment:(NSString *)_userComment;
- (NSString *)userComment;

- (void)setPriority:(NSString *)_value;
- (NSString *)priority;
- (BOOL)hasPriority;

- (void)setCategories:(NSArray *)_value;
- (NSArray *)categories;
- (BOOL)hasCategories;

- (void)setStatus:(NSString *)_value;
- (NSString *)status;
    
- (void)setStartDate:(NSCalendarDate *)_date;
- (NSCalendarDate *)startDate;

- (void)setEndDate:(NSCalendarDate *)_date;
- (NSCalendarDate *)endDate;
- (BOOL)hasEndDate;

- (BOOL)hasDuration;
- (void)setDuration:(NSTimeInterval)_duration;
- (NSTimeInterval)duration;

- (void)setOrganizer:(iCalPerson *)_organizer;
- (iCalPerson *)organizer;

- (void)setAccessClass:(NSString *)_value;
- (NSString *)accessClass;
- (BOOL)isPublic;

- (void)setTransparency:(NSString *)_value;
- (NSString *)transparency;
- (BOOL)isTransparent;

- (void)setMethod:(NSString *)_method;
- (NSString *)method;

- (void)removeAllAttendees;
- (void)addToAttendees:(iCalPerson *)_person;
- (void)appendAttendees:(NSArray *)_persons;
- (void)setAttendees:(NSArray *)_persons;
- (NSArray *)attendees;

/* attendees -> role != NON-PART */
- (NSArray *)participants;
/* attendees -> role == NON-PART */
- (NSArray *)resources;

/* simplified recurrence API */
- (void)setRecurrenceRule:(iCalRecurrenceRule *)_rrule;
- (iCalRecurrenceRule *)recurrenceRule;
- (BOOL)hasRecurrenceRule;

- (NSArray *)recurrenceRangesWithinCalendarDateRange:(NGCalendarDateRange *)_r;

/* iCal generation */

- (NSString *)iCalString;
- (NSString *)vEventString;

/* raw entity objects */

- (id)calendar;
- (id)event;

/* checking */

- (BOOL)isOrganizer:(id)_email;
- (BOOL)isParticipant:(id)_email;

/* searching */

- (iCalPerson *)findParticipantWithEmail:(id)_email;

/* actions */

- (void)increaseSequence;
- (void)cancelWithoutIncreasingSequence;
- (void)cancelAndIncreaseSequence;
    
@end

#endif	/* __SOGoAppointment_H_ */
