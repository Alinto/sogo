/* SOGoCalendarComponent.h - this file is part of SOGo
 * 
 * Copyright (C) 2006 Inverse inc.
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

#ifndef SOGOCALENDARCOMPONENT_H
#define SOGOCALENDARCOMPONENT_H

#import <SOGo/SOGoContentObject.h>

#import "SOGoComponentOccurence.h"

@class NSArray;
@class NSString;

@class iCalCalendar;
@class iCalPerson;
@class iCalRepeatableEntityObject;

@class SOGoUser;
@class SOGoComponentOccurence;

@interface SOGoCalendarComponent : SOGoContentObject <SOGoComponentOccurence>
{
  iCalCalendar *fullCalendar;
  iCalCalendar *safeCalendar;
  iCalCalendar *originalCalendar;
}

- (NSString *) componentTag;

- (iCalCalendar *) calendar: (BOOL) create
  		     secure: (BOOL) secure;
- (id) component: (BOOL) create secure: (BOOL) secure;

// - (NSException *) primarySaveContentString: (NSString *) _iCalString;
// - (NSException *) primaryDelete;

// - (NSException *) delete;

- (void) saveComponent: (iCalRepeatableEntityObject *) newObject;

/* mail notifications */
- (BOOL) sendEMailNotifications;
- (void) sendEMailUsingTemplateNamed: (NSString *) _pageName
                        forOldObject: (iCalRepeatableEntityObject *) _oldObject
                        andNewObject: (iCalRepeatableEntityObject *) _newObject
                         toAttendees: (NSArray *) _attendees;
- (void) sendIMIPReplyForEvent: (iCalRepeatableEntityObject *) event
			    to: (iCalPerson *) recipient;
- (void) sendResponseToOrganizer: (iCalRepeatableEntityObject *) newComponent;

// - (BOOL) isOrganizerOrOwner: (SOGoUser *) user;

- (iCalPerson *) findParticipantWithUID: (NSString *) uid;

- (iCalPerson *) iCalPersonWithUID: (NSString *) uid;
- (NSArray *) getUIDsForICalPersons: (NSArray *) iCalPersons;

/* recurrences */
- (SOGoComponentOccurence *)
 occurence: (iCalRepeatableEntityObject *) component;
- (iCalRepeatableEntityObject *) newOccurenceWithID: (NSString *) recID;

@end

#endif /* SOGOCALENDARCOMPONENT_H */
