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

#import <Foundation/NSCalendarDate.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalEventChanges.h>
#import <NGCards/iCalPerson.h>

#import <SoObjects/SOGo/iCalEntityObject+Utilities.h>
#import <SoObjects/SOGo/LDAPUserManager.h>
#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/SOGoObject.h>
#import <SoObjects/SOGo/SOGoPermissions.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/WORequest+SOGo.h>

#import "NSArray+Appointments.h"
#import "SOGoAppointmentFolder.h"
#import "iCalEventChanges+SOGo.h"
#import "iCalEntityObject+SOGo.h"
#import "iCalPerson+SOGo.h"

#import "SOGoAppointmentObject.h"

@implementation SOGoAppointmentObject

- (NSString *) componentTag
{
  return @"vevent";
}

- (SOGoAppointmentObject *) _lookupEvent: (NSString *) eventUID
				  forUID: (NSString *) uid
{
  SOGoAppointmentFolder *folder;
  SOGoAppointmentObject *object;
  NSString *possibleName;

  folder = [container lookupCalendarFolderForUID: uid];
  object = [folder lookupName: nameInContainer
		   inContext: context acquire: NO];
  if ([object isKindOfClass: [NSException class]])
    {
      possibleName = [folder resourceNameForEventUID: eventUID];
      if (possibleName)
	{
	  object = [folder lookupName: nameInContainer
			   inContext: context acquire: NO];
	  if ([object isKindOfClass: [NSException class]])
	    object = nil;
	}
    }

  if (!object)
    object = [SOGoAppointmentObject objectWithName: nameInContainer
				    inContainer: folder];

  return object;
}

- (void) _addOrUpdateEvent: (iCalEvent *) event
		    forUID: (NSString *) uid
{
  SOGoAppointmentObject *object;
  NSString *iCalString, *userLogin;

  userLogin = [[context activeUser] login];
  if (![uid isEqualToString: userLogin])
    {
      object = [self _lookupEvent: [event uid] forUID: uid];
      iCalString = [[event parent] versitString];
      [object saveContentString: iCalString];
    }
}

- (void) _removeEventFromUID: (NSString *) uid
{
  SOGoAppointmentFolder *folder;
  SOGoAppointmentObject *object;
  NSString *userLogin;

  userLogin = [[context activeUser] login];
  if (![uid isEqualToString: userLogin])
    {
      folder = [container lookupCalendarFolderForUID: uid];
      object = [folder lookupName: nameInContainer
		       inContext: context acquire: NO];
      if (![object isKindOfClass: [NSException class]])
	[object delete];
    }
}

- (void) _handleRemovedUsers: (NSArray *) attendees
{
  NSEnumerator *enumerator;
  iCalPerson *currentAttendee;
  NSString *currentUID;

  enumerator = [attendees objectEnumerator];
  while ((currentAttendee = [enumerator nextObject]))
    {
      currentUID = [currentAttendee uid];
      if (currentUID)
	[self _removeEventFromUID: currentUID];
    }
}

- (void) _requireResponseFromAttendees: (NSArray *) attendees
{
  NSEnumerator *enumerator;
  iCalPerson *currentAttendee;

  enumerator = [attendees objectEnumerator];
  while ((currentAttendee = [enumerator nextObject]))
    {
      [currentAttendee setRsvp: @"TRUE"];
      [currentAttendee setParticipationStatus: iCalPersonPartStatNeedsAction];
    }
}

- (void) _handleSequenceUpdateInEvent: (iCalEvent *) newEvent
		    ignoringAttendees: (NSArray *) attendees
		         fromOldEvent: (iCalEvent *) oldEvent
{
  NSMutableArray *updateAttendees, *updateUIDs;
  NSEnumerator *enumerator;
  iCalPerson *currentAttendee;
  NSString *currentUID;

  updateAttendees = [NSMutableArray arrayWithArray: [newEvent attendees]];
  [updateAttendees removeObjectsInArray: attendees];

  updateUIDs = [NSMutableArray arrayWithCapacity: [updateAttendees count]];
  enumerator = [updateAttendees objectEnumerator];
  while ((currentAttendee = [enumerator nextObject]))
    {
      currentUID = [currentAttendee uid];
      if (currentUID)
	[self _addOrUpdateEvent: newEvent
	      forUID: currentUID];
    }

  [self sendEMailUsingTemplateNamed: @"Update"
	forOldObject: oldEvent
	andNewObject: [newEvent itipEntryWithMethod: @"request"]
	toAttendees: updateAttendees];
}

- (void) _handleAddedUsers: (NSArray *) attendees
		 fromEvent: (iCalEvent *) newEvent
{
  NSEnumerator *enumerator;
  iCalPerson *currentAttendee;
  NSString *currentUID;

  enumerator = [attendees objectEnumerator];
  while ((currentAttendee = [enumerator nextObject]))
    {
      currentUID = [currentAttendee uid];
      if (currentUID)
	[self _addOrUpdateEvent: newEvent
	      forUID: currentUID];
    }
}

- (void) _handleUpdatedEvent: (iCalEvent *) newEvent
		fromOldEvent: (iCalEvent *) oldEvent
{
  NSArray *attendees;
  iCalEventChanges *changes;

  changes = [newEvent getChangesRelativeToEvent: oldEvent];
  attendees = [changes deletedAttendees];
  if ([attendees count])
    {
      [self _handleRemovedUsers: attendees];
      [self sendEMailUsingTemplateNamed: @"Deletion"
	    forOldObject: oldEvent
	    andNewObject: [newEvent itipEntryWithMethod: @"cancel"]
	    toAttendees: attendees];
    }

  attendees = [changes insertedAttendees];
  if ([changes sequenceShouldBeIncreased])
    {
      [newEvent increaseSequence];
      [self _requireResponseFromAttendees: [newEvent attendees]];
      [self _handleSequenceUpdateInEvent: newEvent
	    ignoringAttendees: attendees
	    fromOldEvent: oldEvent];
    }
  else
    [self _requireResponseFromAttendees: attendees];

  if ([attendees count])
    {
      [self _handleAddedUsers: attendees fromEvent: newEvent];
      [self sendEMailUsingTemplateNamed: @"Invitation"
	    forOldObject: oldEvent
	    andNewObject: [newEvent itipEntryWithMethod: @"request"]
	    toAttendees: attendees];
    }
}

- (void) saveComponent: (iCalEvent *) newEvent
{
  iCalEvent *oldEvent;
  NSArray *attendees;
  SOGoUser *currentUser;

  [[newEvent parent] setMethod: @""];
  currentUser = [context activeUser];
  if ([newEvent userIsOrganizer: currentUser])
    {
      oldEvent = [self component: NO secure: NO];
      if (oldEvent)
	[self _handleUpdatedEvent: newEvent fromOldEvent: oldEvent];
      else
	{
	  attendees = [newEvent attendeesWithoutUser: [context activeUser]];
	  if ([attendees count])
	    {
	      [self _handleAddedUsers: attendees fromEvent: newEvent];
	      [self sendEMailUsingTemplateNamed: @"Invitation"
		    forOldObject: nil
		    andNewObject: [newEvent itipEntryWithMethod: @"request"]
		    toAttendees: attendees];
	    }

	  if (![[newEvent attendees] count]
	      && [[self ownerInContext: context]
		   isEqualToString: [currentUser login]])
	    [[newEvent uniqueChildWithTag: @"organizer"] setValue: 0
							 to: @""];
	}
    }

  [super saveComponent: newEvent];
}

- (NSException *) _updateAttendee: (iCalPerson *) attendee
		      forEventUID: (NSString *) eventUID
		     withSequence: (NSNumber *) sequence
			   forUID: (NSString *) uid
{
  SOGoAppointmentObject *eventObject;
  iCalEvent *event;
  iCalPerson *otherAttendee;
  NSString *iCalString;
  NSException *error;

  error = nil;

  eventObject = [self _lookupEvent: eventUID forUID: uid];
  if (![eventObject isNew])
    {
      event = [eventObject component: NO secure: NO];
      if ([[event sequence] compare: sequence]
	  == NSOrderedSame)
	{
	  otherAttendee = [event findParticipant: [context activeUser]];
	  [otherAttendee setPartStat: [attendee partStat]];
	  iCalString = [[event parent] versitString];
	  error = [eventObject saveContentString: iCalString];
	}
    }

  return error;
}

- (NSException *) _handleAttendee: (iCalPerson *) attendee
		     statusChange: (NSString *) newStatus
			  inEvent: (iCalEvent *) event
{
  NSString *newContent, *currentStatus, *organizerUID;
  NSException *ex;

  ex = nil;

  currentStatus = [attendee partStat];
  if ([currentStatus caseInsensitiveCompare: newStatus]
      != NSOrderedSame)
    {
      [attendee setPartStat: newStatus];
      newContent = [[event parent] versitString];
      ex = [self saveContentString: newContent];
      if (!(ex || [event userIsOrganizer: [context activeUser]]))
	{
	  if ([[attendee rsvp] isEqualToString: @"true"])
	    [self sendResponseToOrganizer];
	  organizerUID = [[event organizer] uid];
	  if (organizerUID)
	    ex = [self _updateAttendee: attendee
		       forEventUID: [event uid]
		       withSequence: [event sequence]
		       forUID: organizerUID];
	}
    }

  return ex;
}

- (NSException *) changeParticipationStatus: (NSString *) _status
{
  iCalEvent *event;
  iCalPerson *attendee;
  NSException *ex;
  
  ex = nil;

  event = [self component: NO secure: NO];
  if (event)
    {
      attendee = [event findParticipant: [context activeUser]];
      if (attendee)
	ex = [self _handleAttendee: attendee statusChange: _status
		   inEvent: event];
      else
        ex = [NSException exceptionWithHTTPStatus: 404 /* Not Found */
                          reason: @"user does not participate in this "
                          @"calendar event"];
    }
  else
    ex = [NSException exceptionWithHTTPStatus: 500 /* Server Error */
                      reason: @"unable to parse event record"];

  return ex;
}

- (void) prepareDelete
{
  iCalEvent *event;
  SOGoUser *currentUser;
  NSArray *attendees;

  if ([[context request] handledByDefaultHandler])
    {
      currentUser = [context activeUser];
      event = [self component: NO secure: NO];
      if ([event userIsOrganizer: currentUser])
	{
	  attendees = [event attendeesWithoutUser: currentUser];
	  if ([attendees count])
	    {
	      [self _handleRemovedUsers: attendees];
	      [self sendEMailUsingTemplateNamed: @"Deletion"
		    forOldObject: nil
		    andNewObject: [event itipEntryWithMethod: @"cancel"]
		    toAttendees: attendees];
	    }
	}
      else if ([event userIsParticipant: currentUser])
	[self changeParticipationStatus: @"DECLINED"];
    }
}

/* message type */

- (NSString *) outlookMessageClass
{
  return @"IPM.Appointment";
}

@end /* SOGoAppointmentObject */
