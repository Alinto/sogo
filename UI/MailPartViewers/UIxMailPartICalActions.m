/* UIxMailPartICalActions.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2008 Inverse inc.
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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSEnumerator.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>

#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>

#import <UI/Common/WODirectAction+SOGo.h>

#import <NGImap4/NGImap4EnvelopeAddress.h>

#import <SoObjects/Appointments/iCalEvent+SOGo.h>
#import <SoObjects/Appointments/iCalPerson+SOGo.h>
#import <SoObjects/Appointments/SOGoAppointmentObject.h>
#import <SoObjects/Appointments/SOGoAppointmentFolder.h>
#import <SoObjects/Mailer/SOGoMailObject.h>
#import <SoObjects/SOGo/SOGoParentFolder.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/iCalEntityObject+Utilities.h>
#import <SoObjects/Mailer/SOGoMailBodyPart.h>

#import "UIxMailPartICalActions.h"

@implementation UIxMailPartICalActions

- (iCalEvent *) _emailEvent
{
  NSData *content;
  NSString *eventString;
  iCalCalendar *emailCalendar;

  content = [[self clientObject] fetchBLOB];
  eventString = [[NSString alloc] initWithData: content
				  encoding: NSUTF8StringEncoding];
  if (!eventString)
    eventString = [[NSString alloc] initWithData: content
				    encoding: NSISOLatin1StringEncoding];
  emailCalendar = [iCalCalendar parseSingleFromSource: eventString];

  return (iCalEvent *) [emailCalendar firstChildWithTag: @"vevent"];
}

- (SOGoAppointmentObject *) _eventObjectWithUID: (NSString *) uid
					forUser: (SOGoUser *) user
{
  SOGoAppointmentFolder *folder;
  SOGoAppointmentObject *eventObject;
  NSArray *folders;
  NSEnumerator *e;
  NSString *cname;

  eventObject = nil;

  folders = [[user calendarsFolderInContext: context] subFolders];
  e = [folders objectEnumerator];
  while ( eventObject == nil && (folder = [e nextObject]) )
    {
      cname = [folder resourceNameForEventUID: uid];
      if (cname)
	{
	  eventObject = [folder lookupName: cname
				inContext: context acquire: NO];
	  if (![eventObject isKindOfClass: [SOGoAppointmentObject class]])
	    eventObject = nil;
	}
    }
  
  if (!eventObject)
    {
      folder = [user personalCalendarFolderInContext: context];
      eventObject = [SOGoAppointmentObject objectWithName: uid
					   inContainer: folder];
      [eventObject setIsNew: YES];
    }

  return eventObject;
}

- (SOGoAppointmentObject *) _eventObjectWithUID: (NSString *) uid
{
  return [self _eventObjectWithUID: uid forUser: [context activeUser]];
}

- (void) _fixOrganizerInEvent: (iCalEvent *) brokenEvent
{
  iCalPerson *organizer;
  SOGoMailObject *mail;
  NSArray *addresses;
  NGImap4EnvelopeAddress *from;
  id value;

  organizer = nil;

  mail = [[self clientObject] mailObject];

  addresses = [mail replyToEnvelopeAddresses];
  if (![addresses count])
    addresses = [mail fromEnvelopeAddresses];
  if ([addresses count] > 0)
    {
      from = [addresses objectAtIndex: 0];
      value = [from baseEMail];
      if ([value isNotNull])
	{
	  organizer = [iCalPerson elementWithTag: @"organizer"];
	  [organizer setEmail: value];
	  value = [from personalName];
	  if ([value isNotNull])
	    [organizer setCn: value];
	  [brokenEvent setOrganizer: organizer];
	}
    }

  if (!organizer)
    [self errorWithFormat: @"no organizer could be found, SOGo will crash"
	  @" if the user replies"];
}

- (iCalEvent *)
  _setupChosenEventAndEventObject: (SOGoAppointmentObject **) eventObject
{
  iCalEvent *emailEvent, *calendarEvent, *chosenEvent;
  iCalPerson *organizer;

  emailEvent = [self _emailEvent];
  if (emailEvent)
    {
      *eventObject = [self _eventObjectWithUID: [emailEvent uid]];
      if ([*eventObject isNew])
	chosenEvent = emailEvent;
      else
	{
	  if ([emailEvent recurrenceId])
	    {
	      // Event attached to email is not completed -- retrieve it
	      // from the database.
	      NSString *recurrenceTime;

	      recurrenceTime = [NSString stringWithFormat: @"%f", 
					 [[emailEvent recurrenceId] timeIntervalSince1970]];
	      calendarEvent = (iCalEvent *)[*eventObject lookupOccurence: recurrenceTime];
	    }
	  else
	    calendarEvent = (iCalEvent *) [*eventObject component: NO
							secure: NO];
	  
	  if (calendarEvent != nil)
	    {
	      // Calendar event still exists -- verify which of the calendar
	      // and email events is the most recent.
	      if ([calendarEvent compare: emailEvent] == NSOrderedAscending)
		chosenEvent = emailEvent;
	      else
		{
		  chosenEvent = calendarEvent;
		  if (![[[chosenEvent parent] method] length])
		    [[chosenEvent parent] setMethod: [[emailEvent parent] method]];
		}
	    }
	  else
	    chosenEvent = emailEvent;
	}

      organizer = [chosenEvent organizer];
      if (![[organizer rfc822Email] length])
	[self _fixOrganizerInEvent: chosenEvent];
    }
  else
    chosenEvent = nil;
  
  return chosenEvent;
}

#warning this is code copied from SOGoAppointmentObject...
- (void) _updateAttendee: (iCalPerson *) attendee
               ownerUser: (SOGoUser *) theOwnerUser
	       forEventUID: (NSString *) eventUID
	       withRecurrenceId: (NSCalendarDate *) recurrenceId
	       withSequence: (NSNumber *) sequence
	       forUID: (NSString *) uid
	       shouldAddSentBy: (BOOL) b
{
  SOGoAppointmentObject *eventObject;
  iCalCalendar *calendar;
  iCalEvent *event;
  iCalPerson *otherAttendee;
  NSArray *events;
  NSString *iCalString, *recurrenceTime;

  eventObject = [self _eventObjectWithUID: eventUID
		      forUser: [SOGoUser userWithLogin: uid roles: nil]];
  if (![eventObject isNew])
    {
      if (recurrenceId == nil)
	{
	  // We must update main event and all its occurences (if any).
	  calendar = [eventObject calendar: NO secure: NO];
	  event = (iCalEvent *)[calendar firstChildWithTag: [eventObject componentTag]];
	  events = [calendar allObjects];
	}
      else
	{
	  // If recurrenceId is defined, find the specified occurence
	  // within the repeating vEvent.
	  recurrenceTime = [NSString stringWithFormat: @"%f", [recurrenceId timeIntervalSince1970]];
	  event = (iCalEvent *)[eventObject lookupOccurence: recurrenceTime];
	  
	  if (event == nil)
	    // If no occurence found, create one
	    event = (iCalEvent *)[eventObject newOccurenceWithID: recurrenceTime];
	  
	  events = [NSArray arrayWithObject: event];
	}

      if ([[event sequence] compare: sequence]
	  == NSOrderedSame)
	{
	  SOGoUser *currentUser;
	  int i;
	  
	  currentUser = [context activeUser];
	  
	  for (i = 0; i < [events count]; i++)
	    {
	      event = [events objectAtIndex: i];

	      otherAttendee = [event findParticipant: theOwnerUser];
	      [otherAttendee setPartStat: [attendee partStat]];
	  
	      // If one has accepted / declined an invitation on behalf of
	      // the attendee, we add the user to the SENT-BY attribute.
	      if (b && ![[currentUser login] isEqualToString: [theOwnerUser login]])
		{
		  NSString *currentEmail;
		  currentEmail = [[currentUser allEmails] objectAtIndex: 0];
		  [otherAttendee addAttribute: @"SENT-BY"
				 value: [NSString stringWithFormat: @"\"MAILTO:%@\"", currentEmail]];
		}
	      else
		{
		  // We must REMOVE any SENT-BY here. This is important since if A accepted
		  // the event for B and then, B changes by himself his participation status,
		  // we don't want to keep the previous SENT-BY attribute there.
		  [(NSMutableDictionary *)[otherAttendee attributes] removeObjectForKey: @"SENT-BY"];
		}
	    }
	  iCalString = [[event parent] versitString];
	  [eventObject saveContentString: iCalString];
	}
    }
}

- (WOResponse *) _changePartStatusAction: (NSString *) newStatus
{
  WOResponse *response;
  SOGoAppointmentObject *eventObject;
  iCalEvent *chosenEvent;
  iCalPerson *user;
  iCalCalendar *emailCalendar, *calendar;
  NSString *rsvp, *method, *organizerUID;

  chosenEvent = [self _setupChosenEventAndEventObject: &eventObject];
  if (chosenEvent)
    {
      user = [chosenEvent findParticipant: [context activeUser]];
      [user setPartStat: newStatus];
      calendar = [chosenEvent parent];

      emailCalendar = [[self _emailEvent] parent];
      method = [[emailCalendar method] lowercaseString];
      if ([method isEqualToString: @"request"])
	{
	  [calendar setMethod: @""];
	  rsvp = [[user rsvp] lowercaseString];
	}
      else
	rsvp = nil;

      // We generate the updated iCalendar file and we save it
      // in the database.
      [eventObject saveContentString: [calendar versitString]];

      // Send a notification to the organizer if necessary
      if ([rsvp isEqualToString: @"true"] &&
	  [chosenEvent isStillRelevant])
	[eventObject sendResponseToOrganizer: chosenEvent
		     from: [context activeUser]];

      organizerUID = [[chosenEvent organizer] uid];
      if (organizerUID)
	// Update the event in the organizer's calendar
	[self _updateAttendee: user
	      ownerUser: [context activeUser]
	      forEventUID: [chosenEvent uid]
	      withRecurrenceId: [chosenEvent recurrenceId]
	      withSequence: [chosenEvent sequence]
	      forUID: organizerUID
	      shouldAddSentBy: YES];

      // We update the calendar of all participants that are
      // local to the system. This is useful in case user A accepts
      // invitation from organizer B and users C, D, E who are also
      // attendees need to verify if A has accepted.
      NSArray *attendees;
      iCalPerson *att;
      NSString *uid;
      int i;

      attendees = [chosenEvent attendees];

      for (i = 0; i < [attendees count]; i++)
	{
	  att = [attendees objectAtIndex: i];
	  
	  if (att == user) continue;
	  
	  uid = [[LDAPUserManager sharedUserManager]
		  getUIDForEmail: [att rfc822Email]];

	  if (uid)
	    {
	      [self _updateAttendee: user
		    ownerUser: [context activeUser]
		    forEventUID: [chosenEvent uid]
		    withRecurrenceId: [chosenEvent recurrenceId]
		    withSequence: [chosenEvent sequence]
		    forUID: uid
		    shouldAddSentBy: YES];
	    }
	}

      response = [self responseWith204];
    }
  else
    {
      response = [context response];
      [response setStatus: 409];
    }

  return response;
}

- (WOResponse *) acceptAction
{
  return [self _changePartStatusAction: @"ACCEPTED"];
}

- (WOResponse *) declineAction
{
  return [self _changePartStatusAction: @"DECLINED"];
}

- (WOResponse *) addToCalendarAction
{
  iCalEvent *emailEvent;
  SOGoAppointmentObject *eventObject;
  NSString *iCalString;
  WOResponse *response;

  emailEvent = [self _emailEvent];
  if (emailEvent)
    {
      eventObject = [self _eventObjectWithUID: [emailEvent uid]];      
      if ([eventObject isNew])
	{
	  iCalString = [[emailEvent parent] versitString];
	  [eventObject saveContentString: iCalString];
	  response = [self responseWith204];
	}
      else
	{
	  response = [self responseWithStatus: 409];
	}
    }
  else
    {
      response = [context response];
      [response setStatus: 409];
      response = [self responseWithStatus: 404];
    }

  return response;
}

- (WOResponse *) deleteFromCalendarAction
{
  iCalEvent *emailEvent;
  SOGoAppointmentObject *eventObject;
  WOResponse *response;

  emailEvent = [self _emailEvent];
  if (emailEvent)
    {
      eventObject = [self _eventObjectWithUID: [emailEvent uid]];
      [eventObject delete];
      response = [self responseWith204];
    }
  else
    {
      response = [context response];
      [response setStatus: 409];
    }

  return response;
}

- (iCalPerson *) _emailParticipantWithEvent: (iCalEvent *) event
{
  NSString *emailFrom;
  SOGoMailObject *mailObject;
  NGImap4EnvelopeAddress *address;

  mailObject = [[self clientObject] mailObject];
  address = [[mailObject fromEnvelopeAddresses] objectAtIndex: 0];
  emailFrom = [address baseEMail];

  return [event findParticipantWithEmail: emailFrom];
}

- (BOOL) _updateParticipantStatusInEvent: (iCalEvent *) calendarEvent
			       fromEvent: (iCalEvent *) emailEvent
				inObject: (SOGoAppointmentObject *) eventObject
{
  iCalPerson *calendarParticipant, *mailParticipant;
  NSString *partStat;
  BOOL result;

  calendarParticipant = [self _emailParticipantWithEvent: calendarEvent];
  mailParticipant = [self _emailParticipantWithEvent: emailEvent];
  if (calendarParticipant && mailParticipant)
    {
      result = YES;
      partStat = [mailParticipant partStat];
      if ([partStat caseInsensitiveCompare: [calendarParticipant partStat]]
	  != NSOrderedSame)
	{
	  [calendarParticipant setPartStat: [partStat uppercaseString]];
	  [eventObject saveComponent: calendarEvent];
	}
    }
  else
    result = NO;

  return result;
}

- (WOResponse *) updateUserStatusAction
{
  iCalEvent *emailEvent, *calendarEvent;
  SOGoAppointmentObject *eventObject;
  WOResponse *response;

  response = nil;

  emailEvent = [self _emailEvent];
  if (emailEvent)
    {
      eventObject = [self _eventObjectWithUID: [emailEvent uid]];
      calendarEvent = [eventObject component: NO secure: NO];
      if (([[emailEvent sequence] compare: [calendarEvent sequence]]
	  != NSOrderedAscending)
	  && ([self _updateParticipantStatusInEvent: calendarEvent
		    fromEvent: emailEvent
		    inObject: eventObject]))
	response = [self responseWith204];
    }

  if (!response)
    {
      response = [context response];
      [response setStatus: 409];
    }

  return response;
}

// - (WOResponse *) markTentativeAction
// {
//   return [self _changePartStatusAction: @"TENTATIVE"];
// }

// - (WOResponse *) addToCalendarAction
// {
//   return [self responseWithStatus: 404];
// }

// - (WOResponse *) deleteFromCalendarAction
// {
//   return [self responseWithStatus: 404];
// }

@end
