/* SOGoCalendarComponent.h - this file is part of SOGo
 * 
 * Copyright (C) 2006-2011 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Francis Lachapelle <flachapelle@inverse.ca>
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

#ifndef SOGOCALENDARCOMPONENT_H
#define SOGOCALENDARCOMPONENT_H

#import <SOGo/SOGoConstants.h>
#import <SOGo/SOGoContentObject.h>

#import "SOGoComponentOccurence.h"

@class NSArray;
@class NSString;

@class iCalCalendar;
@class iCalEvent;
@class iCalPerson;
@class iCalRepeatableEntityObject;

@class SOGoUser;
@class SOGoComponentOccurence;

@interface SOGoCalendarComponent : SOGoContentObject <SOGoComponentOccurence>
{
  iCalCalendar *fullCalendar;
  iCalCalendar *safeCalendar;
  iCalCalendar *originalCalendar;
  NSString *componentTag;
}

- (void) flush;
- (NSString *) componentTag;
- (void) setComponentTag: (NSString *) theTag;

- (iCalCalendar *) calendar: (BOOL) create
  		     secure: (BOOL) secure;
- (id) component: (BOOL) create secure: (BOOL) secure;

- (BOOL) expandGroupsInEvent: (iCalEvent *) theEvent;

- (NSException *) copyComponent: (iCalCalendar *) calendar
		       toFolder: (SOGoGCSFolder *) newFolder;

- (void) updateComponent: (iCalRepeatableEntityObject *) newObject;
- (NSException *) saveCalendar: (iCalCalendar *) newCalendar;
- (NSException *) saveComponent: (iCalRepeatableEntityObject *) newObject;

/* mail notifications */
- (void) sendEMailUsingTemplateNamed: (NSString *) pageName
			   forObject: (iCalRepeatableEntityObject *) object
		      previousObject: (iCalRepeatableEntityObject *) previousObject
                         toAttendees: (NSArray *) attendees
                            withType: (NSString *) msgType;
- (void) sendIMIPReplyForEvent: (iCalRepeatableEntityObject *) event
			  from: (SOGoUser *) from
			    to: (iCalPerson *) recipient;
- (void) sendResponseToOrganizer: (iCalRepeatableEntityObject *) newComponent
                            from: (SOGoUser *) owner;

- (void) sendReceiptEmailForObject: (iCalRepeatableEntityObject *) object
		    addedAttendees: (NSArray *) theAddedAttendees
		  deletedAttendees: (NSArray *) theDeletedAttendees
		  updatedAttendees: (NSArray *) theUpdatedAttendees
                         operation: (SOGoEventOperation) theOperation;

- (iCalPerson *) findParticipantWithUID: (NSString *) uid;

- (iCalPerson *) iCalPersonWithUID: (NSString *) uid;
- (NSArray *) getUIDsForICalPersons: (NSArray *) iCalPersons;

/* recurrences */
/* same as above, but refers to the existing calendar component */
- (iCalRepeatableEntityObject *) lookupOccurrence: (NSString *) recID;
- (SOGoComponentOccurence *) occurence: (iCalRepeatableEntityObject *) component;
- (iCalRepeatableEntityObject *) newOccurenceWithID: (NSString *) recID;

- (void) snoozeAlarm: (unsigned int) minutes;

@end

#endif /* SOGOCALENDARCOMPONENT_H */
