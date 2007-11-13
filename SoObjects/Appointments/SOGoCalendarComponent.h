/* SOGoCalendarComponent.h - this file is part of SOGo
 * 
 * Copyright (C) 2006 Inverse groupe conseil
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

@class NSArray;
@class NSString;

@class iCalCalendar;
@class iCalPerson;
@class iCalRepeatableEntityObject;

@class SOGoUser;

@interface SOGoCalendarComponent : SOGoContentObject
{
  iCalCalendar *calendar;
  NSString *calContent;
}

- (NSString *) componentTag;
- (iCalCalendar *) calendar: (BOOL) create;
- (iCalRepeatableEntityObject *) component: (BOOL) create;

- (NSException *) primarySaveContentString: (NSString *) _iCalString;
- (NSException *) primaryDelete;

- (NSException *) delete;

- (NSException *) changeParticipationStatus: (NSString *) _status;

/* mail notifications */
- (BOOL) sendEMailNotifications;
- (void) sendEMailUsingTemplateNamed: (NSString *) _pageName
                        forOldObject: (iCalRepeatableEntityObject *) _oldObject
                        andNewObject: (iCalRepeatableEntityObject *) _newObject
                         toAttendees: (NSArray *) _attendees;
- (void) sendResponseToOrganizer;

// - (BOOL) isOrganizerOrOwner: (SOGoUser *) user;

- (iCalPerson *) findParticipantWithUID: (NSString *) uid;

- (iCalPerson *) iCalPersonWithUID: (NSString *) uid;
- (NSString *) getUIDForICalPerson: (iCalPerson *) person;
- (NSArray *) getUIDsForICalPersons: (NSArray *) iCalPersons;

@end

#endif /* SOGOCALENDARCOMPONENT_H */
