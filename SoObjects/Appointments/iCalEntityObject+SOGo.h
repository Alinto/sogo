/* iCalEntityObject+SOGo.h - this file is part of SOGo
 *
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

#ifndef ICALENTITYOBJECT_SOGO_H
#define ICALENTITYOBJECT_SOGO_H

#import <NGCards/iCalEntityObject.h>

@class iCalAlarm;
@class NSMutableDictionary;
@class SOGoUser;
@class WOContext;

extern NSCalendarDate *iCalDistantFuture;
extern NSNumber *iCalDistantFutureNumber;

@interface iCalEntityObject (SOGoExtensions)

+ (void) initializeSOGoExtensions;

- (NSDictionary *) attributesInContext: (WOContext *) context;
- (void) setAttributes: (NSDictionary *) data
             inContext: (WOContext *) context;

- (BOOL) userIsAttendee: (SOGoUser *) user;
- (BOOL) userIsOrganizer: (SOGoUser *) user;

- (iCalPerson *) userAsAttendee: (SOGoUser *) user;

- (iCalPerson *) participantForUser:  (SOGoUser *) theUser
                           attendee: (iCalPerson *) theAttendee;
/* - (NSArray *) attendeeUIDs; */
- (BOOL) isStillRelevant;

- (id) itipEntryWithMethod: (NSString *) method;

- (NSArray *) attendeesWithoutUser: (SOGoUser *) user;

- (int) priorityNumber;
- (NSDictionary *) createdBy;

- (void) adjustDate: (NSCalendarDate **) date
     withTimeString: (NSString *) timeString
          inContext: (WOContext *) context;

- (NSNumber *) quickRecordDateAsNumber: (NSCalendarDate *) _date
			    withOffset: (int) offset
			     forAllDay: (BOOL) allDay;

- (NSMutableDictionary *) quickRecordFromContent: (NSString *) theContent
                                       container: (id) theContainer
				 nameInContainer: (NSString *) nameInContainer;

- (iCalAlarm *) firstSupportedAlarm;
- (iCalAlarm *) firstDisplayOrAudioAlarm;

- (void) updateNextAlarmDateInRow: (NSMutableDictionary *) row
                     forContainer: (id) theContainer
		  nameInContainer: (NSString *) nameInContainer;

@end

#endif /* ICALENTITYOBJECT_SOGO_H */
