/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  
  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING. If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

/*
  UIxMailPartICalViewer
 
  Show plain/calendar mail parts.
*/

#import <NGObjWeb/WOResponse.h>

#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGImap4/NGImap4EnvelopeAddress.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalDateTime.h>

#import <SoObjects/SOGo/SOGoDateFormatter.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/iCalEntityObject+Utilities.h>
#import <SoObjects/Appointments/iCalEntityObject+SOGo.h>
#import <SoObjects/Appointments/SOGoAppointmentFolder.h>
#import <SoObjects/Appointments/SOGoAppointmentObject.h>
#import <SoObjects/Mailer/SOGoMailObject.h>
#import <SoObjects/Mailer/SOGoMailBodyPart.h>

#import "UIxMailPartICalViewer.h"

@implementation UIxMailPartICalViewer

- (void) dealloc
{
  [storedEventObject release];
  [storedEvent release];
  [attendee release];
  [item release];
  [inCalendar release];
  [inEvent release];
  [dateFormatter release];
  [super dealloc];
}

/* maintain caches */

- (void) resetPathCaches
{
  [super resetPathCaches];
  [inEvent release]; inEvent = nil;
  [inCalendar release]; inCalendar = nil;
  [storedEventObject release]; storedEventObject = nil;
  [storedEvent release]; storedEvent = nil;
 
  /* not strictly path-related, but useless without it anyway: */
  [attendee release]; attendee = nil;
  [item release]; item = nil;
}

/* accessors */

- (iCalCalendar *) inCalendar
{
  if (!inCalendar)
    {
      inCalendar
	= [iCalCalendar parseSingleFromSource: [self flatContentAsString]];
      [inCalendar retain];
    }

  return inCalendar;
}

- (BOOL) couldParseCalendar
{
  return ([self inCalendar] != nil);
}

- (iCalEvent *) inEvent
{
  NSArray *events;
 
  if (!inEvent)
    {
      events = [[self inCalendar] events];
      if ([events count] > 0)
	inEvent = [[events objectAtIndex: 0] retain];
    }

  return inEvent;
}

/* formatters */

- (SOGoDateFormatter *) dateFormatter
{
  if (!dateFormatter)
    {
      dateFormatter = [[context activeUser] dateFormatterInContext: context];
      [dateFormatter retain];
    }

  return dateFormatter;
}

/* below is copied from UIxAppointmentView, can we avoid that? */

- (void) setAttendee: (id) _attendee
{
  ASSIGN (attendee, _attendee);
}

- (id) attendee
{
  return attendee;
}

- (NSString *) _personForDisplay: (iCalPerson *) person
{
  NSString *fn, *email, *result;

  fn = [person cnWithoutQuotes];
  email = [person rfc822Email];
  if ([fn length])
    result = [NSString stringWithFormat: @"%@ <%@>",
		       fn, email];
  else
    result = email;

  return result;
}

- (NSString *) attendeeForDisplay
{
  return [self _personForDisplay: attendee];
}

- (void) setItem: (id) _item
{
  ASSIGN(item, _item);
}

- (id) item
{
  return item;
}

- (NSCalendarDate *) startTime
{
  NSCalendarDate *date;
  NSTimeZone *timeZone;
 
  date = [[self inEvent] startDate];
  timeZone = [[context activeUser] timeZone];
  [date setTimeZone: timeZone];

  return date;
}

- (NSCalendarDate *) endTime
{
  NSCalendarDate *date;
  NSTimeZone *timeZone;
 
  date = [[self inEvent] endDate];
  timeZone = [[context activeUser] timeZone];
  [date setTimeZone: timeZone];

  return date;
}

- (BOOL) isEndDateOnSameDay
{
  return [[self startTime] isDateOnSameDay:[self endTime]];
}

- (NSTimeInterval) duration
{
  return [[self endTime] timeIntervalSinceDate:[self startTime]];
}

/* calendar folder support */

- (SOGoAppointmentFolder *) calendarFolder
{
  /* return scheduling calendar of currently logged-in user */
  SOGoUser *user;
  id folder;

  user = [context activeUser];
  folder = [[user homeFolderInContext: context] lookupName: @"Calendar"
						inContext: context
						acquire: NO];

  return [folder lookupName: @"personal" inContext: context acquire: NO];
}

- (BOOL) hasCalendarAccess
{
  return [[context activeUser] canAccessModule: @"Calendar"];
}

- (SOGoAppointmentObject *) storedEventObject
{
  /* lookup object in the users Calendar */
  SOGoAppointmentFolder *calendar;
  NSString *filename;
 
  if ([self hasCalendarAccess])
    {
      if (!storedEventObject)
	{
	  calendar = [self calendarFolder];
	  if ([calendar isKindOfClass: [NSException class]])
	    [self errorWithFormat:@"Did not find Calendar folder: %@", calendar];
	  else
	    {
	      filename = [calendar resourceNameForEventUID:[[self inEvent] uid]];
	      if (filename)
		{
		  storedEventObject = [calendar lookupName: filename
						inContext: [self context]
						acquire: NO];
		  if ([storedEventObject isKindOfClass: [NSException class]])
		    storedEventObject = nil;
		  else
		    [storedEventObject retain];
		}
	    }
	}
    }
 
  return storedEventObject;
}

- (BOOL) isEventStoredInCalendar
{
  NSCalendarDate *recurrenceId;
  NSString *recurrenceTime;
  BOOL inCalendar;

  recurrenceId = [[self inEvent] recurrenceId];

  if (recurrenceId)
    {
      recurrenceTime = [NSString stringWithFormat: @"%f", [recurrenceId timeIntervalSince1970]];
      inCalendar = ([[self storedEventObject] lookupOccurence: recurrenceTime] != nil);
    }
  else
    inCalendar = ([self storedEventObject] != nil);

  return inCalendar;
}

- (iCalEvent *) storedEvent
{
  if (!storedEvent)
    {
      NSCalendarDate *recurrenceId;

      recurrenceId = [[self inEvent] recurrenceId];

      if (recurrenceId == nil)
	storedEvent = [[self storedEventObject] component: NO secure: NO];
      else
	{
	  // Find the specific occurence within the repeating vEvent.
	  NSString *recurrenceTime;
	  iCalPerson *organizer;

	  recurrenceTime = [NSString stringWithFormat: @"%f", [recurrenceId timeIntervalSince1970]];
	  storedEvent = (iCalEvent*)[[self storedEventObject] lookupOccurence: recurrenceTime];

	  if (storedEvent == nil)
	    // If no occurence found, create one
	    storedEvent = (iCalEvent*)[storedEventObject newOccurenceWithID: recurrenceTime];

	  // Add organizer to occurence if not present
	  organizer = [storedEvent organizer];
	  if (organizer == nil || [organizer isVoid])
	    {
	      organizer = [[[storedEvent parent] firstChildWithTag: [storedEventObject componentTag]] organizer];
	      [storedEvent setOrganizer: organizer];
	    }
	}
      
      [storedEvent retain];
    }

  return storedEvent;
}

/* organizer tracking */

- (NSString *) loggedInUserEMail
{
  NSDictionary *identity;

  identity = [[context activeUser] primaryIdentity];

  return [identity objectForKey: @"email"];
}

- (iCalEvent *) authorativeEvent
{
  iCalEvent *authorativeEvent;

  [self storedEvent];
  if (!storedEvent
      || ([storedEvent compare: [self inEvent]] == NSOrderedAscending))
    authorativeEvent = inEvent;
  else
    authorativeEvent = [self storedEvent];

  return authorativeEvent;
}

- (BOOL) isLoggedInUserTheOrganizer
{
  return [[self authorativeEvent] userIsOrganizer: [context activeUser]];
}

- (BOOL) isLoggedInUserAnAttendee
{
  return [[self authorativeEvent] userIsParticipant: [context activeUser]];
}

/* derived fields */

- (NSString *) organizerDisplayName
{
  iCalPerson *organizer;
  NSString *value;

  organizer = [[self authorativeEvent] organizer];
  if ([organizer isVoid])
    value = @"[todo: no organizer set, use 'from']";
  else
    value = [self _personForDisplay: organizer];

  return value;
}

/* replies */

- (NGImap4EnvelopeAddress *) replySenderAddress
{
  /* 
     The iMIP reply is the sender of the mail, the 'attendees' are NOT set to
     the actual attendees. BUT the attendee field contains the reply-status!
  */
  id tmp;
 
  tmp = [[self clientObject] fromEnvelopeAddresses];
  if ([tmp count] == 0) return nil;
  return [tmp objectAtIndex:0];
}

- (NSString *) replySenderEMail
{
  return [[self replySenderAddress] email];
}

- (NSString *) replySenderBaseEMail
{
  return [[self replySenderAddress] baseEMail];
}

- (iCalPerson *) inReplyAttendee
{
  NSArray *attendees;
 
  attendees = [[self inEvent] attendees];
  if ([attendees count] == 0)
    return nil;
  if ([attendees count] > 1)
    [self warnWithFormat:@"More than one attendee in REPLY: %@", attendees];
 
  return [attendees objectAtIndex:0];
}

- (iCalPerson *) currentUserAttendee
{
  iCalPerson *currentUser;

  currentUser = [[self authorativeEvent] findParticipant: [context activeUser]];

  return currentUser;
}

- (iCalPerson *) storedReplyAttendee
{
  /*
    TODO: since an attendee can have multiple email addresses, maybe we
    should translate the email to an internal uid and then retrieve
    all emails addresses for matching the participant.
 
    Note: -findParticipantWithEmail: does not parse the email!
  */
  iCalEvent *e;
  iCalPerson *p;

  p = nil;
 
  e = [self storedEvent];
  if (e)
    {
      p = [e findParticipantWithEmail: [self replySenderBaseEMail]];
      if (!p)
	p = [e findParticipantWithEmail:[self replySenderEMail]];
    }

  return p;
}

- (BOOL) isReplySenderAnAttendee
{
  return ([self storedReplyAttendee] != nil);
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

- (BOOL) hasSenderStatusChanged
{
  iCalPerson *emailParticipant, *calendarParticipant;

  [self inEvent];
  [self storedEvent];
  emailParticipant = [self _emailParticipantWithEvent: inEvent];
  calendarParticipant = [self _emailParticipantWithEvent: storedEvent];

  return ([[emailParticipant partStat]
	    caseInsensitiveCompare: [calendarParticipant partStat]]
	  != NSOrderedSame);
}

- (BOOL) canOriginalEventBeUpdated
{
  return ([self hasCalendarAccess]
	  && [self hasSenderStatusChanged]
	  && ([[inEvent sequence] compare: [storedEvent sequence]]
	      != NSOrderedAscending));
}

@end /* UIxMailPartICalViewer */
