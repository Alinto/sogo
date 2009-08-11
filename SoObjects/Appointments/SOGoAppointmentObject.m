/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2007-2009 Inverse inc.

  This file is part of OpenGroupware.org.

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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalEventChanges.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/NSCalendarDate+NGCards.h>
#import <SaxObjC/XMLNamespaces.h>

#import <SoObjects/SOGo/iCalEntityObject+Utilities.h>
#import <SoObjects/SOGo/LDAPUserManager.h>
#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/NSObject+DAV.h>
#import <SoObjects/SOGo/SOGoObject.h>
#import <SoObjects/SOGo/SOGoPermissions.h>
#import <SoObjects/SOGo/SOGoGroup.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoWebDAVAclManager.h>
#import <SoObjects/SOGo/SOGoWebDAVValue.h>
#import <SoObjects/SOGo/WORequest+SOGo.h>

#import "iCalEventChanges+SOGo.h"
#import "iCalEntityObject+SOGo.h"
#import "iCalPerson+SOGo.h"
#import "NSArray+Appointments.h"
#import "SOGoAppointmentFolder.h"
#import "SOGoAppointmentOccurence.h"
#import "SOGoCalendarComponent.h"

#import "SOGoAppointmentObject.h"

@implementation SOGoAppointmentObject

+ (SOGoWebDAVAclManager *) webdavAclManager
{
  static SOGoWebDAVAclManager *aclManager = nil;
  NSString *nsD, *nsI;

  if (!aclManager)
    {
      nsD = @"DAV:";
      nsI = @"urn:inverse:params:xml:ns:inverse-dav";

      aclManager = [SOGoWebDAVAclManager new];
      [aclManager registerDAVPermission: davElement (@"read", nsD)
		  abstract: YES
		  withEquivalent: nil
		  asChildOf: davElement (@"all", nsD)];
      [aclManager registerDAVPermission: davElement (@"read-current-user-privilege-set", nsD)
		  abstract: YES
		  withEquivalent: SoPerm_WebDAVAccess
		  asChildOf: davElement (@"read", nsD)];
      [aclManager registerDAVPermission: davElement (@"view-whole-component", nsI)
		  abstract: NO
		  withEquivalent: SOGoCalendarPerm_ViewAllComponent
		  asChildOf: davElement (@"read", nsD)];
      [aclManager registerDAVPermission: davElement (@"view-date-and-time", nsI)
		  abstract: NO
		  withEquivalent: SOGoCalendarPerm_ViewDAndT
		  asChildOf: davElement (@"view-whole-component", nsI)];
      [aclManager registerDAVPermission: davElement (@"write", nsD)
		  abstract: YES
		  withEquivalent: SOGoCalendarPerm_ModifyComponent
		  asChildOf: davElement (@"all", nsD)];
      [aclManager
	registerDAVPermission: davElement (@"write-properties", nsD)
	abstract: YES
	withEquivalent: SoPerm_ChangePermissions /* hackish */
	asChildOf: davElement (@"write", nsD)];
      [aclManager
	registerDAVPermission: davElement (@"write-content", nsD)
	abstract: YES
	withEquivalent: nil
	asChildOf: davElement (@"write", nsD)];
      [aclManager
        registerDAVPermission: davElement (@"respond-to-component", nsI)
                     abstract: NO
               withEquivalent: SOGoCalendarPerm_RespondToComponent
                    asChildOf: davElement (@"write-content", nsD)];
      [aclManager registerDAVPermission: davElement (@"admin", nsI)
		  abstract: YES
		  withEquivalent: nil
		  asChildOf: davElement (@"all", nsD)];
      [aclManager
	registerDAVPermission: davElement (@"read-acl", nsD)
	abstract: YES
	withEquivalent: SOGoPerm_ReadAcls
	asChildOf: davElement (@"admin", nsI)];
      [aclManager
	registerDAVPermission: davElement (@"write-acl", nsD)
	abstract: YES
	withEquivalent: nil
	asChildOf: davElement (@"admin", nsI)];
    }

  return aclManager;
}

- (NSString *) componentTag
{
  return @"vevent";
}

- (SOGoComponentOccurence *) occurence: (iCalRepeatableEntityObject *) occ
{
  NSArray *allEvents;

  allEvents = [[occ parent] events];

  return [SOGoAppointmentOccurence
	   occurenceWithComponent: occ
	   withMasterComponent: [allEvents objectAtIndex: 0]
	   inContainer: self];
}

- (iCalRepeatableEntityObject *) newOccurenceWithID: (NSString *) recID
{
  iCalEvent *newOccurence;
  NSCalendarDate *date;
  unsigned int interval, nbrDays;

  newOccurence = (iCalEvent *) [super newOccurenceWithID: recID];
  date = [newOccurence recurrenceId];
  interval = [[newOccurence endDate]
	       timeIntervalSinceDate: [newOccurence startDate]];
  if ([newOccurence isAllDay])
    {
      nbrDays = ((float) abs (interval) / 86400) + 1;
      [newOccurence setAllDayWithStartDate: date
		    duration: nbrDays];
    }
  else
    [newOccurence setStartDate: date];

  [newOccurence setEndDate: [date addYear: 0
				  month: 0
				  day: 0
				  hour: 0
				  minute: 0
				  second: interval]];

  return newOccurence;
}

- (SOGoAppointmentObject *) _lookupEvent: (NSString *) eventUID
				  forUID: (NSString *) uid
{
  SOGoAppointmentFolder *folder;
  SOGoAppointmentObject *object;
  NSArray *folders;
  NSEnumerator *e;
  NSString *possibleName;

  object = nil;
  folders = [container lookupCalendarFoldersForUID: uid];
  e = [folders objectEnumerator];
  while ( object == nil && (folder = [e nextObject]) )
    {
      object = [folder lookupName: nameInContainer
		       inContext: context 
		       acquire: NO];
      if ([object isKindOfClass: [NSException class]])
	{
	  possibleName = [folder resourceNameForEventUID: eventUID];
	  if (possibleName)
	    {
	      object = [folder lookupName: possibleName
			       inContext: context acquire: NO];
	      if ([object isKindOfClass: [NSException class]])
		object = nil;
	    }
	  else
	    object = nil;
	}
    }

  if (!object)
    {
      // Create the event in the user's personal calendar.
      folder = [container lookupCalendarFolderForUID: uid];
      object = [SOGoAppointmentObject objectWithName: nameInContainer
				      inContainer: folder];
      [object setIsNew: YES];
    }

  return object;
}

- (void) _addOrUpdateEvent: (iCalEvent *) theEvent
		    forUID: (NSString *) theUID
		     owner: (NSString *) theOwner
{
  if (![theUID isEqualToString: theOwner])
    {
      SOGoAppointmentObject *attendeeObject;
      NSString *iCalString;

      attendeeObject = [self _lookupEvent: [theEvent uid] forUID: theUID];
      
      // We must add an occurence to a non-existing event. We have
      // to handle this with care, as in the postCalDAVEventRequestTo:from:
      if ([attendeeObject isNew] && [theEvent recurrenceId])
	{
	  SOGoAppointmentObject *ownerObject;
	  NSArray *attendees;
	  iCalEvent *ownerEvent;
	  iCalPerson *person;
	  SOGoUser *user;
	  BOOL found;
	  int i;

	  // We check if the attendee that was added to a single occurence is
	  // present in the master component. If not, we add it with a participation
	  // status set to "DECLINED".

	  user = [SOGoUser userWithLogin: theUID roles: nil];
	  person = [iCalPerson elementWithTag: @"attendee"];
	  [person setCn: [user cn]];
	  [person setEmail: [[user allEmails] objectAtIndex: 0]];
	  [person setParticipationStatus: iCalPersonPartStatDeclined];
	  [person setRsvp: @"TRUE"];
	  [person setRole: @"REQ-PARTICIPANT"];
	  
	  ownerObject = [self _lookupEvent: [theEvent uid] forUID: theOwner];
	  ownerEvent = [[[theEvent parent] events] objectAtIndex: 0];
	  attendees = [ownerEvent attendees];
	  found = NO;
	  
	  for (i = 0; i < [attendees count]; i++)
	    {
	      if ([[attendees objectAtIndex: i] hasSameEmailAddress: person])
		{
		  found = YES;
		  break;
		}
	    }
	  
	  if (!found)
	    {
	      // Update the master event in the owner's calendar with the
	      // status of the new attendee set as "DECLINED".
	      [ownerEvent addToAttendees: person];
	      iCalString = [[ownerEvent parent] versitString];
	      [ownerObject saveContentString: iCalString];
	    }
	} 
      else
	{
	  // TODO : if [theEvent recurrenceId], only update this occurrence
	  // in attendee's calendar

	  // TODO : when updating the master event, handle exception dates
	  // in attendee's calendar (add exception dates and remove matching
	  // occurrences) -- see _updateRecurrenceIDsWithEvent:
	  
	  iCalString = [[theEvent parent] versitString];
	}
      
      // Save the event in the attendee's calendar
      [attendeeObject saveContentString: iCalString];
    }
}

- (void) _removeEventFromUID: (NSString *) theUID
                       owner: (NSString *) theOwner
	    withRecurrenceId: (NSCalendarDate *) recurrenceId
{
  if (![theUID isEqualToString: theOwner])
    {
      SOGoAppointmentFolder *folder;
      SOGoAppointmentObject *object;
      iCalEntityObject *currentOccurence;
      iCalRepeatableEntityObject *event;
      iCalCalendar *calendar;
      NSCalendarDate *currentId;
      NSString *calendarContent;
      NSArray *occurences;
      int max, count;
      
      // Invitations are always written to the personal folder; it's not necessay
      // to look into all folders of the user
      folder = [container lookupCalendarFolderForUID: theUID];
      object = [folder lookupName: nameInContainer
		       inContext: context acquire: NO];
      if (![object isKindOfClass: [NSException class]])
	{
	  if (recurrenceId == nil)
	    [object delete];
	  else
	    {
	      calendar = [object calendar: NO secure: NO];
	      
	      // If recurrenceId is defined, remove the occurence from
	      // the repeating event.
	      occurences = [calendar events];
	      max = [occurences count];
	      count = 1;
	      while (count < max)
		{
		  currentOccurence = [occurences objectAtIndex: count];
		  currentId = [currentOccurence recurrenceId];
		  if ([currentId compare: recurrenceId] == NSOrderedSame)
		    {
		      [[calendar children] removeObject: currentOccurence];
		      break;
		    }
		  count++;
		}
	      
	      // Add an date exception.
	      event = (iCalRepeatableEntityObject*)[calendar firstChildWithTag: [object componentTag]];
	      [event addToExceptionDates: recurrenceId];
	      
	      [event increaseSequence];
	      
	      // We generate the updated iCalendar file and we save it
	      // in the database.
	      calendarContent = [calendar versitString];
	      [object saveContentString: calendarContent];
	    }
	}
    }
}

- (void) _handleRemovedUsers: (NSArray *) attendees
            withRecurrenceId: (NSCalendarDate *) recurrenceId
{
  NSEnumerator *enumerator;
  iCalPerson *currentAttendee;
  NSString *currentUID;

  enumerator = [attendees objectEnumerator];
  while ((currentAttendee = [enumerator nextObject]))
    {
      currentUID = [currentAttendee uid];
      if (currentUID)
	[self _removeEventFromUID: currentUID
	      owner: owner
	      withRecurrenceId: recurrenceId];
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
	      forUID: currentUID
	      owner: owner];
    }

  [self sendEMailUsingTemplateNamed: @"Update"
	forObject: [newEvent itipEntryWithMethod: @"request"]
	previousObject: oldEvent
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
	      forUID: currentUID
	      owner: owner];
    }
}

//
//
//
- (void) _handleUpdatedEvent: (iCalEvent *) newEvent
		fromOldEvent: (iCalEvent *) oldEvent
{
  NSArray *attendees;
  iCalEventChanges *changes;

  changes = [newEvent getChangesRelativeToEvent: oldEvent];
  attendees = [changes deletedAttendees];
  if ([attendees count])
    {
      [self _handleRemovedUsers: attendees
	    withRecurrenceId: [newEvent recurrenceId]];
      [self sendEMailUsingTemplateNamed: @"Deletion"
	    forObject: [newEvent itipEntryWithMethod: @"cancel"]
	    previousObject: oldEvent
	    toAttendees: attendees];
    }

  attendees = [changes insertedAttendees];
  if ([changes sequenceShouldBeIncreased])
    {
      [newEvent increaseSequence];
      // Set new attendees status to "needs action"
      [self _requireResponseFromAttendees: [newEvent attendees]];
      // Update attendees calendars and send them an update
      // notification by email
      [self _handleSequenceUpdateInEvent: newEvent
	    ignoringAttendees: attendees
	    fromOldEvent: oldEvent];
    }
  else
    {
      // If other attributes have changed, update the event
      // in each attendee's calendar
      if ([[changes updatedProperties] count])
	{
	  NSEnumerator *enumerator;
	  iCalPerson *currentAttendee;
	  NSString *currentUID;
	  
	  enumerator = [[newEvent attendees] objectEnumerator];
	  while ((currentAttendee = [enumerator nextObject]))
	    {
	      currentUID = [currentAttendee uid];
	      if (currentUID)
		[self _addOrUpdateEvent: newEvent
		      forUID: currentUID
		      owner: owner];
	    }
	}
    }

  if ([attendees count])
    {
      NSArray *originalAttendees;

      originalAttendees = [NSArray arrayWithArray: [newEvent attendees]];
      
      // Send an invitation to new attendees
      [self _handleAddedUsers: attendees fromEvent: newEvent];
      [self sendEMailUsingTemplateNamed: @"Invitation"
	    forObject: [newEvent itipEntryWithMethod: @"request"]
	    previousObject: oldEvent
	    toAttendees: attendees];
    }
}

- (void) saveComponent: (iCalEvent *) newEvent
{
  iCalEvent *oldEvent;
  NSArray *attendees;
  NSCalendarDate *recurrenceId;
  NSString *recurrenceTime;
  SOGoUser *ownerUser;

  [[newEvent parent] setMethod: @""];
  ownerUser = [SOGoUser userWithLogin: owner roles: nil];

  [self expandGroupsInEvent: newEvent];

  // We first save the event. It is important to this initially
  // as the event's UID might get modified in SOGoCalendarComponent: -saveComponent:
  [super saveComponent: newEvent];

  if ([self isNew])
    {
      // New event -- send invitation to all attendees
      attendees = [newEvent attendeesWithoutUser: ownerUser];
      if ([attendees count])
	{
	  [self _handleAddedUsers: attendees fromEvent: newEvent];
	  [self sendEMailUsingTemplateNamed: @"Invitation"
				  forObject: [newEvent itipEntryWithMethod: @"request"]
			     previousObject: nil
				toAttendees: attendees];
	}
    }
  else
    {
      // Event is modified -- sent update status to all attendees
      // and modify their calendars.
      recurrenceId = [newEvent recurrenceId];
      if (recurrenceId == nil)
	oldEvent = [self component: NO secure: NO];
      else
	{
	  // If recurrenceId is defined, find the specified occurence
	  // within the repeating vEvent.
	  recurrenceTime = [NSString stringWithFormat: @"%f", [recurrenceId timeIntervalSince1970]];
	  oldEvent = (iCalEvent*)[self lookupOccurence: recurrenceTime];
	  if (oldEvent == nil)
	    // If no occurence found, create one
	    oldEvent = (iCalEvent*)[self newOccurenceWithID: recurrenceTime];
	}
      
      if ([[[oldEvent parent] firstChildWithTag: @"vevent"] userIsOrganizer: ownerUser])
	{
	  // The owner is the organizer of the event; handle the modifications
	  
	  [self _handleUpdatedEvent: newEvent fromOldEvent: oldEvent];
	  
	  // The sequence has possibly been increased -- resave the event.
	  [super saveComponent: newEvent];
	}
    }
}

//
// This method is used to update the status of an attendee.
//
// - theOwnerUser is owner of the calendar where the attendee
//   participation state has changed.
// - uid is the actual UID of the user for whom we must
//   update the calendar event (with the participation change)
//
// This method is called multiple times, in order to update the
// status of the attendee in calendars for the particular event UID.
// 
- (NSException *) _updateAttendee: (iCalPerson *) attendee
                        ownerUser: (SOGoUser *) theOwnerUser
		      forEventUID: (NSString *) eventUID
		 withRecurrenceId: (NSCalendarDate *) recurrenceId
		     withSequence: (NSNumber *) sequence
			   forUID: (NSString *) uid
	          shouldAddSentBy: (BOOL) b
{
  SOGoAppointmentObject *eventObject;
  iCalCalendar *calendar;
  iCalEntityObject *event;
  iCalPerson *otherAttendee;
  NSString *iCalString, *recurrenceTime;
  NSException *error;

  error = nil;

  eventObject = [self _lookupEvent: eventUID forUID: uid];
  if (![eventObject isNew])
    {
      if (recurrenceId == nil)
	{
	  // We must update main event and all its occurences (if any).
	  calendar = [eventObject calendar: NO secure: NO];
	  event = (iCalEntityObject*)[calendar firstChildWithTag: [self componentTag]];
	}
      else
	{
	  // If recurrenceId is defined, find the specified occurence
	  // within the repeating vEvent.
	  recurrenceTime = [NSString stringWithFormat: @"%f", [recurrenceId timeIntervalSince1970]];
	  event = [eventObject lookupOccurence: recurrenceTime];
	  
	  if (event == nil)
	    // If no occurence found, create one
	    event = [eventObject newOccurenceWithID: recurrenceTime];
	}

      if ([[event sequence] compare: sequence]
	  == NSOrderedSame)
	{
	  SOGoUser *currentUser;

	  currentUser = [context activeUser];
	  otherAttendee = [event findParticipant: theOwnerUser];
	  [otherAttendee setPartStat: [attendee partStat]];
	  
	  // If one has accepted / declined an invitation on behalf of
	  // the attendee, we add the user to the SENT-BY attribute.
	  if (b && ![[currentUser login] isEqualToString: [theOwnerUser login]])
	    {
	      NSString *currentEmail, *quotedEmail;
	      currentEmail = [[currentUser allEmails] objectAtIndex: 0];
              quotedEmail = [NSString stringWithFormat: @"\"MAILTO:%@\"",
                                      currentEmail];
	      [otherAttendee setValue: 0 ofAttribute: @"SENT-BY"
                                   to: quotedEmail];
	    }
	  else
	    {
	      // We must REMOVE any SENT-BY here. This is important since if A accepted
	      // the event for B and then, B changes by himself his participation status,
	      // we don't want to keep the previous SENT-BY attribute there.
	      [(NSMutableDictionary *)[otherAttendee attributes] removeObjectForKey: @"SENT-BY"];
	    }
	}
      
      // We generate the updated iCalendar file and we save it
      // in the database.
      iCalString = [[event parent] versitString];
      error = [eventObject saveContentString: iCalString];
    }
  
  return error;
}


//
// This method is invoked only from the SOGo Web interface.
//
// - theOwnerUser is owner of the calendar where the attendee
//   participation state has changed.
//
- (NSException *) _handleAttendee: (iCalPerson *) attendee
                        ownerUser: (SOGoUser *) theOwnerUser
		     statusChange: (NSString *) newStatus
			  inEvent: (iCalEvent *) event
{
  NSString *newContent, *currentStatus, *organizerUID;
  SOGoUser *ownerUser, *currentUser;
  NSException *ex;

  ex = nil;

  currentStatus = [attendee partStat];
  if ([currentStatus caseInsensitiveCompare: newStatus]
      != NSOrderedSame)
    {
      [attendee setPartStat: newStatus];
      
      // If one has accepted / declined an invitation on behalf of
      // the attendee, we add the user to the SENT-BY attribute.
      currentUser = [context activeUser];
      if (![[currentUser login] isEqualToString: [theOwnerUser login]])
	{
          NSString *currentEmail, *quotedEmail;
          currentEmail = [[currentUser allEmails] objectAtIndex: 0];
          quotedEmail = [NSString stringWithFormat: @"\"MAILTO:%@\"",
                                  currentEmail];
          [attendee setValue: 0 ofAttribute: @"SENT-BY"
                          to: quotedEmail];
	}
      else
	{
	  // We must REMOVE any SENT-BY here. This is important since if A accepted
	  // the event for B and then, B changes by himself his participation status,
	  // we don't want to keep the previous SENT-BY attribute there.
	  [(NSMutableDictionary *)[attendee attributes] removeObjectForKey: @"SENT-BY"];
	}

      // We generate the updated iCalendar file and we save it
      // in the database.
      newContent = [[event parent] versitString];
      ex = [self saveContentString: newContent];

      // If the current user isn't the organizer of the event
      // that has just been updated, we update the event and
      // send a notification
      ownerUser = [SOGoUser userWithLogin: owner roles: nil];
      if (!(ex || [event userIsOrganizer: ownerUser]))
	{
	  if ([[attendee rsvp] isEqualToString: @"true"]
	      && [event isStillRelevant])
	    [self sendResponseToOrganizer: event
		  from: ownerUser];
	  
	  organizerUID = [[event organizer] uid];

	  if (!organizerUID)
	    // event is an recurrence; retrieve organizer from master event
	    organizerUID = [[(iCalEntityObject*)[[event parent] firstChildWithTag: [self componentTag]] organizer] uid];

	  if (organizerUID)
	    // Update the attendee in organizer's calendar.
	    ex = [self _updateAttendee: attendee
		       ownerUser: theOwnerUser
		       forEventUID: [event uid]
		       withRecurrenceId: [event recurrenceId]
		       withSequence: [event sequence]
		       forUID: organizerUID
		       shouldAddSentBy: YES];
	}

      // We update the calendar of all participants that are
      // local to the system. This is useful in case user A accepts
      // invitation from organizer B and users C, D, E who are also
      // attendees need to verify if A has accepted.
      NSArray *attendees;
      iCalPerson *att;
      NSString *uid;
      int i;

      attendees = [event attendees];

      for (i = 0; i < [attendees count]; i++)
	{
	  att = [attendees objectAtIndex: i];
	  
	  if (att == attendee) continue;
	  
	  uid = [[LDAPUserManager sharedUserManager]
		  getUIDForEmail: [att rfc822Email]];

	  if (uid)
	    {
	      [self _updateAttendee: attendee
		    ownerUser: theOwnerUser
		    forEventUID: [event uid]
		    withRecurrenceId: [event recurrenceId]
		    withSequence: [event sequence]
		    forUID: uid
		    shouldAddSentBy: YES];
	    }
	}
    }

  return ex;
}

- (NSDictionary *) _caldavSuccessCodeWithRecipient: (NSString *) recipient
{
  NSMutableArray *element;
  NSDictionary *code;

  element = [NSMutableArray new];
  [element addObject: davElementWithContent (@"recipient", XMLNS_CALDAV,
					     recipient)];
  [element addObject: davElementWithContent (@"request-status",
					     XMLNS_CALDAV,
					     @"2.0;Success")];
  code = davElementWithContent (@"response", XMLNS_CALDAV,
				element);
  [element release];

  return code;
}

//
// The originator here is the owner of the calendar where
// the event was created. Lightning sends us exactly this
// and handles the SENT-BY itself. We might have to review
// this if the originator ever becomes the user on whom
// the act is performed (ie. Alice creates an event in Bob's
// calendar and invites Thomas).
// 
- (NSArray *) postCalDAVEventRequestTo: (NSArray *) recipients
				  from: (NSString *) originator
{
  NSMutableArray *elements;
  NSEnumerator *recipientsEnum;
  NSString *recipient, *uid, *ownerUID;
  iCalEvent *newEvent, *oldEvent, *emailEvent;
  iCalPerson *person, *eventOwner;
  BOOL isUpdate, hasChanged;
  
  elements = [NSMutableArray array];
  ownerUID = [[LDAPUserManager sharedUserManager]
	       getUIDForEmail: originator];
  eventOwner = [self iCalPersonWithUID: ownerUID];
  emailEvent = [self component: NO secure: NO];
  newEvent = [self component: NO secure: NO];
  [newEvent removeAllAlarms];
  [[newEvent parent] setMethod: @""];
  
  recipientsEnum = [recipients objectEnumerator];
  while ((recipient = [recipientsEnum nextObject]))
    if ([[recipient lowercaseString] hasPrefix: @"mailto:"])
      {
 	person = [iCalPerson new];
	[person setValue: 0 to: recipient];
	uid = [person uid];
	oldEvent = nil;
	hasChanged = YES;
	isUpdate = NO;

	if (uid) 
	  {
	    // We check if we must send an invitation update
	    // rather than just a normal invitation.
	    NSCalendarDate *recurrenceId;
	    NSString *iCalString;
	    SOGoAppointmentObject *oldEventObject, *ownerEventObject;
	    iCalCalendar *calendar;

	    oldEventObject = [self _lookupEvent: [newEvent uid] forUID: uid];
	    calendar = [oldEventObject calendar: NO secure: NO];
	    ownerEventObject = nil;
	    
	    recurrenceId = [newEvent recurrenceId];
	    
	    if (![oldEventObject isNew])
	      {
		// We are updating an existing event.
		// If the event containts a recurrence-id, replace the proper
		// occurrence of the recurrent event.
		iCalEvent *currentOccurence;
		iCalEventChanges *changes;
		NSArray *occurences;
		NSCalendarDate *currentId;
		NSString *recurrenceTime;
		unsigned int i;
		
		if (recurrenceId == nil)
		  oldEvent = [oldEventObject component: NO  secure: NO];
		else
		  {
		    // If recurrenceId is defined, find the specified occurence
		    // within the repeating vEvent and remove it.
		    occurences = [calendar events];
		    for (i = 1; i < [occurences count]; i++)
		      {
			currentOccurence = [occurences objectAtIndex: i];
			currentId = [currentOccurence recurrenceId];
			if ([currentId compare: recurrenceId] == NSOrderedSame)
			  {
			    oldEvent = currentOccurence;
			    [[calendar children] removeObject: currentOccurence];
			    break;
			  }
		      }

		    if (oldEvent == nil)
		      {
			// If no occurence found, create one.
			recurrenceTime = [NSString stringWithFormat: @"%f", [recurrenceId timeIntervalSince1970]];
			oldEvent = (iCalEvent *)[oldEventObject newOccurenceWithID: recurrenceTime];
		      }
		    
		    // Add the event as a new occurrence, without the organizer.
		    [newEvent setOrganizer: nil];
		    [calendar addChild: newEvent];
		  }

		// Identify changes in order to send a notification to the attendee
		// if necessary and with the proper template.
		changes = [newEvent getChangesRelativeToEvent: oldEvent];
		if ([[oldEvent sequence] compare: [newEvent sequence]] != NSOrderedSame
		    && [changes sequenceShouldBeIncreased]) 
		  isUpdate = YES;
		else
		  hasChanged = NO;
	      }
	    else if (recurrenceId)
	      {
		NSArray *attendees;
		unsigned int i;
		BOOL found;
		
		// We must add an occurence to a non-existing event -- simply retrieve
		// the event from the organizer's calendar
		if (ownerEventObject == nil)
		  ownerEventObject = [self _lookupEvent: [newEvent uid] forUID: ownerUID];

		newEvent = [ownerEventObject component: NO  secure: NO];
		attendees = [newEvent attendees];
		found = NO;

		// We check if the attendee that was added to a single occurence is
		// present in the master component. If not, we add it with a participation
		// status set to "DECLINED"
		for (i = 0; i < [attendees count]; i++)
		  {
		    if ([[attendees objectAtIndex: i] hasSameEmailAddress: person])
		      {
			found = YES;
			break;
		      }
		  }
		
		if (!found)
		  {
		    [person setParticipationStatus: iCalPersonPartStatDeclined];
		    [person setRsvp: @"TRUE"];
		    [person setRole: @"REQ-PARTICIPANT"];
		    [newEvent addToAttendees: person];
		    if ([[newEvent organizer] isVoid])
		      [newEvent setOrganizer: eventOwner];
		    [ownerEventObject saveContentString: [[newEvent parent] versitString]];
		  }
	      }

	    // We generate the updated iCalendar file and we save it
	    // in the database.
	    iCalString = [[newEvent parent] versitString];
	    [oldEventObject saveContentString: iCalString];
	  }
#warning fix this when sendEmailUsing blabla has been cleaned up
	if (hasChanged)
	  {
	    [self sendEMailUsingTemplateNamed: (isUpdate ? @"Update" : @"Invitation")
		  forObject: emailEvent
		  previousObject: oldEvent
		  toAttendees: [NSArray arrayWithObject: person]];
	  }
	
	[person release];
	[elements
	  addObject: [self _caldavSuccessCodeWithRecipient: recipient]];
      }

  return elements;
}

//
// See our comment about the originator in the method above.
//
- (NSArray *) postCalDAVEventCancelTo: (NSArray *) recipients
				 from: (NSString *) originator
{
  NSMutableArray *elements;
  NSEnumerator *recipientsEnum;
  NSString *recipient, *ownerUID, *uid;
  iCalEvent *event;
  iCalPerson *person;

  elements = [NSMutableArray array];

  ownerUID = [[LDAPUserManager sharedUserManager]
		    getUIDForEmail: originator];
  event = [self component: NO secure: NO];
  recipientsEnum = [recipients objectEnumerator];
  while ((recipient = [recipientsEnum nextObject]))
    if ([[recipient lowercaseString] hasPrefix: @"mailto:"])
      {
	person = [iCalPerson new];
	[person setValue: 0 to: recipient];
	uid = [person uid];
	if (uid)
	  [self _removeEventFromUID: uid
		owner: ownerUID
		withRecurrenceId: [event recurrenceId]];
#warning fix this when sendEmailUsing blabla has been cleaned up
	[self sendEMailUsingTemplateNamed: @"Deletion"
	      forObject: event
	      previousObject: nil
	      toAttendees: [NSArray arrayWithObject: person]];
	[person release];
	[elements
	  addObject: [self _caldavSuccessCodeWithRecipient: recipient]];
      }

  return elements;
}


//
// This method is invoked by CalDAV clients such as
// Mozilla Lightning. We assume the SENT-BY has
// already been added, if required.
//
// It is used to update the status of an attendee.
// The originator is the actualy owner of the calendar
// where the update took place. The status must then
// be propagated to the organizer and the other attendees.
//
- (void) takeAttendeeStatus: (iCalPerson *) attendee
		       from: (SOGoUser *) ownerUser
	   withRecurrenceId: (NSCalendarDate*) recurrenceId
{
  iCalPerson *localAttendee;
  iCalEvent *event;
  NSString *recurrenceTime;

  if (recurrenceId == nil)
    // We must update the master event only.
    event = [self component: NO secure: NO];
  else
    {
      // If recurrenceId is defined, find the specified occurence
      // within the repeating vEvent.
      recurrenceTime = [NSString stringWithFormat: @"%f", [recurrenceId timeIntervalSince1970]];
      event = (iCalEvent*)[self lookupOccurence: recurrenceTime];
      
      if (event == nil)
	// If no occurence found, create one
	event = (iCalEvent*)[self newOccurenceWithID: recurrenceTime];      
    }
  
  // Find attendee within event
  localAttendee = [event findParticipantWithEmail: [attendee rfc822Email]];
  if (localAttendee)
    {
      // Update the attendee's status
      [localAttendee setPartStat: [attendee partStat]];
      [self saveComponent: event];
      
      NSArray *attendees;
      iCalPerson *att;
      NSString *uid;
      int i;
      
      // We update the copy of the organizer, only
      // if it's a local user.
#warning add a check for only local users
      uid = [[event organizer] uid];
      if (uid)
	[self _updateAttendee: attendee
	      ownerUser: ownerUser
	      forEventUID: [event uid]
	      withRecurrenceId: [event recurrenceId]
	      withSequence: [event sequence]
	      forUID: uid
	      shouldAddSentBy: NO];
      
      attendees = [event attendees];

      for (i = 0; i < [attendees count]; i++)
	{
	  att = [attendees objectAtIndex: i];
	  
	  if (att == attendee) continue;
	  
	  uid = [[LDAPUserManager sharedUserManager]
		  getUIDForEmail: [att rfc822Email]];
	  
	  if (uid)
	    {		
	      // We skip the update that correspond to the owner
	      // since the CalDAV client will already have updated
	      // the actual event.
	      if ([ownerUser hasEmail: [att rfc822Email]]) 
		continue;
	      
	      [self _updateAttendee: attendee
		    ownerUser: ownerUser
		    forEventUID: [event uid]
		    withRecurrenceId: [event recurrenceId]
		    withSequence: [event sequence]
		    forUID: uid
		    shouldAddSentBy: NO];
	    }
	}
    }
  else
    [self errorWithFormat: @"attendee not found: '%@'", attendee];
}

- (NSArray *) postCalDAVEventReplyTo: (NSArray *) recipients
				from: (NSString *) originator
{
  NSMutableArray *elements;
  NSEnumerator *recipientsEnum;
  NSString *recipient, *uid, *eventUID;
  iCalEvent *event;
  iCalPerson *attendee, *person;
  SOGoAppointmentObject *recipientEvent;
  SOGoUser *ownerUser;

  elements = [NSMutableArray array];
  event = [self component: NO secure: NO];
  [[event parent] setMethod: @""];
  ownerUser = [SOGoUser userWithLogin: [[LDAPUserManager sharedUserManager]
					 getUIDForEmail: originator]
			roles: nil];
  attendee = [event findParticipant: ownerUser];
  eventUID = [event uid];

  recipientsEnum = [recipients objectEnumerator];
  while ((recipient = [recipientsEnum nextObject]))
    if ([[recipient lowercaseString] hasPrefix: @"mailto:"])
      {
	person = [iCalPerson new];
	[person setValue: 0 to: recipient];
	uid = [person uid];
	if (uid)
	  {
	    recipientEvent = [self _lookupEvent: eventUID forUID: uid];
	    if ([recipientEvent isNew])
	      [recipientEvent saveComponent: event];
	    else
	      [recipientEvent takeAttendeeStatus: attendee
			      from: ownerUser
			      withRecurrenceId: [event recurrenceId]];
	  }

	// Send reply to recipient/organizer
	[self sendIMIPReplyForEvent: event
	      from: ownerUser
	      to: person];
	[person release];
	[elements
	  addObject: [self _caldavSuccessCodeWithRecipient: recipient]];
      }

  return elements;
}

//
// This method is invoked only from the SOGo Web interface.
//
- (NSException *) changeParticipationStatus: (NSString *) _status
{
  return [self changeParticipationStatus: _status forRecurrenceId: nil];
}

- (NSException *) changeParticipationStatus: (NSString *) _status
                            forRecurrenceId: (NSCalendarDate *) _recurrenceId
{
  iCalCalendar *calendar;
  iCalEvent *event;
  iCalPerson *attendee;
  NSException *ex;
  SOGoUser *ownerUser;
  NSString *recurrenceTime;

  event = nil;
  ex = nil;

  calendar = [self calendar: NO secure: NO];
  if (calendar)
    {
      if (_recurrenceId)
	{
	  // If _recurrenceId is defined, find the specified occurence
	  // within the repeating vEvent.
	  recurrenceTime = [NSString stringWithFormat: @"%f", [_recurrenceId timeIntervalSince1970]];
	  event = (iCalEvent*)[self lookupOccurence: recurrenceTime];
	  
	  if (event == nil)
	    // If no occurence found, create one
	    event = (iCalEvent*)[self newOccurenceWithID: recurrenceTime];
	}
      else
	// No specific occurence specified; return the first vEvent of
	// the vCalendar.
	event = (iCalEvent*)[calendar firstChildWithTag: [self componentTag]];
    }
  if (event)
    {
      // owerUser will actually be the owner of the calendar
      // where the participation change on the event has
      // actually occured. The particpation change will of
      // course be on the attendee that is the owner of the
      // calendar where the participation change has occured.
      ownerUser = [SOGoUser userWithLogin: owner roles: nil];
      
      attendee = [event findParticipant: ownerUser];
      if (attendee)
	ex = [self _handleAttendee: attendee
		   ownerUser: ownerUser
		   statusChange: _status
		   inEvent: event];
      else
        ex = [NSException exceptionWithHTTPStatus: 404 // Not Found
                          reason: @"user does not participate in this "
                          @"calendar event"];
    }
  else
    ex = [NSException exceptionWithHTTPStatus: 500 // Server Error
                      reason: @"unable to parse event record"];
  
  return ex;
}

- (void) prepareDeleteOccurence: (iCalEvent *) occurence
{
  iCalEvent *event;
  SOGoUser *ownerUser, *currentUser;
  NSArray *attendees;
  NSCalendarDate *recurrenceId;

  if ([[context request] handledByDefaultHandler])
    {
      ownerUser = [SOGoUser userWithLogin: owner roles: nil];
      event = [self component: NO secure: NO];

      if (occurence == nil)
	{
	  // No occurence specified; use the master event.
	  occurence = event;
	  recurrenceId = nil;
	}
      else
	// Retrieve this occurence ID.
	recurrenceId = [occurence recurrenceId];

      if ([event userIsOrganizer: ownerUser])
	{
	  // The organizer deletes an occurence.
	  currentUser = [context activeUser];
	  attendees = [occurence attendeesWithoutUser: currentUser];

#warning Make sure this is correct ..
	  if (![attendees count] && event != occurence)
	    attendees = [event attendeesWithoutUser: currentUser];

	  if ([attendees count])
	    {
	      // Remove the event from all attendees calendars
	      // and send them an email.
	      [self _handleRemovedUsers: attendees
		    withRecurrenceId: recurrenceId];
	      [self sendEMailUsingTemplateNamed: @"Deletion"
		    forObject: [occurence itipEntryWithMethod: @"cancel"]
		    previousObject: nil
		    toAttendees: attendees];
	    }
	}
      else if ([occurence userIsParticipant: ownerUser])
	// The current user deletes the occurence; let the organizer know that
	// the user has declined this occurence.
	[self changeParticipationStatus: @"DECLINED" forRecurrenceId: recurrenceId];
    }
}

- (void) prepareDelete
{
  [self prepareDeleteOccurence: nil];
}

/* message type */

- (NSString *) outlookMessageClass
{
  return @"IPM.Appointment";
}

- (NSDictionary *) _partStatsFromCalendar: (iCalCalendar *) calendar
{
  NSMutableDictionary *partStats;
  NSArray *allEvents;
  int count, max;
  iCalEvent *currentEvent;
  iCalPerson *ownerParticipant;
  NSString *key;
  SOGoUser *ownerUser;

  ownerUser = [SOGoUser userWithLogin: owner roles: nil];

  allEvents = [calendar events];
  max = [allEvents count];
  partStats = [NSMutableDictionary dictionaryWithCapacity: max];

  for (count = 0; count < max; count++)
    {
      currentEvent = [allEvents objectAtIndex: count];
      ownerParticipant = [currentEvent userAsParticipant: ownerUser];
      if (ownerParticipant)
        {
          if (count == 0)
            key = @"master";
          else
            key = [[currentEvent recurrenceId] iCalFormattedDateTimeString];
          [partStats setObject: ownerParticipant forKey: key];
        }
    }

  return partStats;
}

- (void) _setupResponseCalendarInRequest: (WORequest *) rq
{
  iCalCalendar *calendar, *putCalendar;
  NSData *newContent;
  NSArray *keys;
  NSDictionary *partStats, *newPartStats;
  NSString *partStat, *key;
  int count, max;

  calendar = [self calendar: NO secure: NO];
  partStats = [self _partStatsFromCalendar: calendar];
  keys = [partStats allKeys];
  max = [keys count];
  if (max > 0)
    {
      putCalendar = [iCalCalendar parseSingleFromSource: [rq contentAsString]];
      newPartStats = [self _partStatsFromCalendar: putCalendar];
      if ([keys isEqualToArray: [newPartStats allKeys]])
        {
          for (count = 0; count < max; count++)
            {
              key = [keys objectAtIndex: count];
              partStat = [[newPartStats objectForKey: key] partStat];
              [[partStats objectForKey: key] setPartStat: partStat];
            }
        }
    }

  newContent = [[calendar versitString]
                         dataUsingEncoding: [rq contentEncoding]];
  [rq setContent: newContent];
}

- (void) _decomposeGroupsInRequest: (WORequest *) rq
{
  iCalCalendar *calendar;
  NSArray *allEvents;
  iCalEvent *event;
  int i;
  BOOL modified;

  // If we decomposed at least one group, let's rewrite the content
  // of the request. Otherwise, leave it as is in case this rewrite
  // isn't totaly lossless.
  calendar = [iCalCalendar parseSingleFromSource: [rq contentAsString]];

  // The algorithm is pretty straightforward:
  //
  // We get all events
  //   We get all attendees
  //     If some are groups, we decompose them
  // We regenerate the iCalendar string
  //
  allEvents = [calendar events];
  modified = NO;

  for (i = 0; i < [allEvents count]; i++)
    {
      event = [allEvents objectAtIndex: i];
      modified |= [self expandGroupsInEvent: event];
    }

  // If we decomposed at least one group, let's rewrite the content
  // of the request. Otherwise, leave it as is in case this rewrite
  // isn't totaly lossless.
  if (modified)
    [rq setContent: [[calendar versitString] dataUsingEncoding: [rq contentEncoding]]];
}

//
// If we see "X-SOGo: NoGroupsDecomposition" in the HTTP headers, we
// simply invoke super's PUTAction.
//
- (id) PUTAction: (WOContext *) _ctx
{
  WORequest *rq;
  NSArray *roles;

  rq = [_ctx request];

  roles = [[context activeUser] rolesForObject: self inContext: context];
  if ([roles containsObject: @"ComponentResponder"]
      && ![roles containsObject: @"ComponentModifier"])
    [self _setupResponseCalendarInRequest: rq];
  else
    {
      if (![[rq headersForKey: @"X-SOGo"]
                         containsObject: @"NoGroupsDecomposition"])
        [self _decomposeGroupsInRequest: rq];
    }

  return [super PUTAction: _ctx];
}

@end /* SOGoAppointmentObject */
