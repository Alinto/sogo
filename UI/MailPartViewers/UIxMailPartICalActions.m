/* UIxMailPartICalActions.m - this file is part of SOGo
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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGCards/iCalCalendar.h>

#import <NGImap4/NGImap4EnvelopeAddress.h>

#import <Appointments/iCalEvent+SOGo.h>
#import <Appointments/iCalEntityObject+SOGo.h>
#import <Appointments/iCalPerson+SOGo.h>
#import <Appointments/SOGoAppointmentObject.h>
#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoAppointmentFolders.h>
#import <Mailer/SOGoMailObject.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/NSString+Utilities.h>
#import <Mailer/SOGoMailBodyPart.h>

#import "UIxMailPartICalActions.h"

@implementation UIxMailPartICalActions

- (iCalEvent *) _emailEvent
{
  iCalCalendar *emailCalendar;
  NSString *eventString;
  NSData *content;

  content = [[self clientObject] fetchBLOB];
  eventString = [[NSString alloc] initWithData: content
				  encoding: NSUTF8StringEncoding];
  if (!eventString)
    eventString = [[NSString alloc] initWithData: content
				    encoding: NSISOLatin1StringEncoding];

  emailCalendar = [iCalCalendar parseSingleFromSource: eventString];
  [eventString release];

  return (iCalEvent *) [emailCalendar firstChildWithTag: @"vevent"];
}

//
//
//
- (SOGoAppointmentObject *) _eventObjectWithUID: (NSString *) uid
					forUser: (SOGoUser *) user
{
  SOGoAppointmentFolder *folder;
  SOGoAppointmentObject *eventObject;
  NSArray *folders;
  NSEnumerator *e;
  NSString *cname, *userLogin;

  eventObject = nil;

  userLogin = [user login];

  folders = [[user calendarsFolderInContext: context] subFolders];
  e = [folders objectEnumerator];
  while (eventObject == nil && (folder = [e nextObject]))
    {
      if ([[folder ownerInContext: nil] isEqualToString: userLogin])
        {
          cname = [folder resourceNameForEventUID: uid];
          if (cname)
            {
              eventObject = [folder lookupName: cname inContext: context
                                       acquire: NO];
              if ([eventObject isKindOfClass: [NSException class]])
                eventObject = nil;
            }
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

//
//
//
- (SOGoAppointmentObject *) _eventObjectWithUID: (NSString *) uid
{
#warning this will not work if Bob reads emails of Alice and accepts events for her
  return [self _eventObjectWithUID: uid forUser: [context activeUser]];
}

//
//
//						 
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

//
//
//
- (iCalEvent *) _setupChosenEventAndEventObject: (SOGoAppointmentObject **) eventObject
{
  iCalEvent *emailEvent, *calendarEvent, *chosenEvent;
  iCalPerson *organizer;

  emailEvent = [self _emailEvent];
  if (emailEvent)
    {
      *eventObject = [self _eventObjectWithUID: [emailEvent uid]];
      if ([*eventObject isNew])
	{
	  chosenEvent = emailEvent;
	  [*eventObject saveCalendar: [emailEvent parent]];
	}
      else
	{
	  if ([emailEvent recurrenceId])
	    {
	      // Event attached to email is not complete -- retrieve it
	      // from the database.
	      NSString *recurrenceTime;

	      recurrenceTime = [NSString stringWithFormat: @"%f", 
					 [[emailEvent recurrenceId] timeIntervalSince1970]];
	      calendarEvent = (iCalEvent *)[*eventObject lookupOccurrence: recurrenceTime];
	    }
	  else
	    calendarEvent = (iCalEvent *) [*eventObject component: NO  secure: NO];
	  
	  if (calendarEvent != nil)
	    {
	      // Calendar event still exists -- verify which of the calendar
	      // and email events is the most recent. We must also update
	      // the event (or recurrence-id) with the email's content, otherwise
	      // we would never get major properties updates
	      if ([calendarEvent compare: emailEvent] == NSOrderedAscending)
		{
		  iCalCalendar *parent;
		  
		  parent = [calendarEvent parent];
		  [parent removeChild: calendarEvent];
		  [parent addChild: emailEvent];
		  [*eventObject saveCalendar: parent];
		  [*eventObject flush];
		  chosenEvent = emailEvent;
		}
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

//
//
//
- (WOResponse *) _changePartStatusAction: (NSString *) newStatus
                            withDelegate: (iCalPerson *) delegate
{
  SOGoAppointmentObject *eventObject;
  WOResponse *response;
  iCalEvent *chosenEvent;
  iCalAlarm *alarm;

  chosenEvent = [self _setupChosenEventAndEventObject: &eventObject];
  if (chosenEvent)
    {
      // For invitations, we take the organizers's alarm to start with
      alarm = [[chosenEvent alarms] lastObject];      
      response = (WOResponse*)[eventObject changeParticipationStatus: newStatus
							withDelegate: delegate
                                                               alarm: alarm
						     forRecurrenceId: [chosenEvent recurrenceId]];
      if (!response)
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
  return [self _changePartStatusAction: @"ACCEPTED"
			  withDelegate: nil];
}

- (WOResponse *) declineAction
{
  return [self _changePartStatusAction: @"DECLINED"
			  withDelegate: nil];
}

- (WOResponse *) tentativeAction
{
  return [self _changePartStatusAction: @"TENTATIVE"
			  withDelegate: nil];
}

- (WOResponse *) delegateAction
{
//  BOOL receiveUpdates;
  NSString *delegatedEmail, *delegatedUid;
  iCalPerson *delegatedAttendee;
  NSDictionary *content;
  SOGoUser *user;
  WORequest *request;
  WOResponse *response;

  request = [context request];
  content = [[request contentAsString] objectFromJSONString];
  delegatedEmail = [content objectForKey: @"delegatedTo"];

  if ([delegatedEmail length])
    {
      user = [context activeUser];
      delegatedAttendee = [iCalPerson new];
      [delegatedAttendee autorelease];
      [delegatedAttendee setEmail: delegatedEmail];
      delegatedUid = [delegatedAttendee uidInDomain: [user domain]];
      if (delegatedUid)
	{
	  SOGoUser *delegatedUser;
	  delegatedUser = [SOGoUser userWithLogin: delegatedUid];
	  [delegatedAttendee setCn: [delegatedUser cn]];
	}

      [delegatedAttendee setRole: @"REQ-PARTICIPANT"];
      [delegatedAttendee setRsvp: @"TRUE"];
      [delegatedAttendee setParticipationStatus: iCalPersonPartStatNeedsAction];
      [delegatedAttendee setDelegatedFrom:
	       [NSString stringWithFormat: @"mailto:%@", [[user allEmails] objectAtIndex: 0]]];
      
//      receiveUpdates = [[content objectForKey: @"receiveUpdates"] boolValue];
//      if (receiveUpdates)
//	[delegatedAttendee setRole: @"NON-PARTICIPANT"];

      response = [self _changePartStatusAction: @"DELEGATED"
				  withDelegate: delegatedAttendee];
    }
  else
    response = [NSException exceptionWithHTTPStatus: 400
					     reason: @"missing 'to' parameter"];
  
  return response;
}

- (WOResponse *) addToCalendarAction
{
  iCalEvent *emailEvent;
  SOGoAppointmentObject *eventObject;
  SOGoUser *user;
  WOResponse *response;

  emailEvent = [self _emailEvent];
  if (emailEvent)
    {
      eventObject = [self _eventObjectWithUID: [emailEvent uid]];      
      if ([eventObject isNew])
	{
          user = [context activeUser];
          if (![emailEvent userIsOrganizer: user] && ![emailEvent userIsAttendee: user])
            {
              [emailEvent setOrganizer: nil];
              [emailEvent removeAllAttendees];
            }
	  [eventObject saveCalendar: [emailEvent parent]];
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
  NGImap4EnvelopeAddress *address;
  SOGoMailObject *mailObject;
  NSString *emailFrom;
  iCalPerson *p;

  mailObject = [[self clientObject] mailObject];
  address = [[mailObject fromEnvelopeAddresses] objectAtIndex: 0];
  emailFrom = [address baseEMail];
  p = [event findAttendeeWithEmail: emailFrom];

  // We haven't found it yet, let's look in the identities
  // associated to this user
  if (!p)
    {
      SOGoUserManager *sm;
      NSString *uid;

      sm = [SOGoUserManager sharedUserManager];
      uid = [sm getUIDForEmail: emailFrom];

      if (uid)
	{
	  NSArray *allEmails;
	  NSString *email;
	  SOGoUser *u;
	  int i;

	  u = [SOGoUser userWithLogin: uid];
	  allEmails = [u allEmails];
	  for (i = 0; i < [allEmails count]; i++)
	    {
	      email = [allEmails objectAtIndex: i];
	      if ([email caseInsensitiveCompare: emailFrom] == NSOrderedSame)
		continue;

	      p = [event findAttendeeWithEmail: email];

	      if (p)
		break;
	    }
	}
    }

  return p;
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
      if (calendarEvent)
        {
          if (([[emailEvent sequence] compare: [calendarEvent sequence]]
               != NSOrderedAscending)
              && ([self _updateParticipantStatusInEvent: calendarEvent
                                              fromEvent: emailEvent
                                               inObject: eventObject]))
            response = [self responseWith204];
        }
      else
        response = [self responseWithStatus: 404
                                  andString: @"Local event not found."];
    }

  if (!response)
    {
      response = [context response];
      [response setStatus: 409];
    }

  return response;
}

@end
