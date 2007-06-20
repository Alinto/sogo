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

/*
  UIxMailPartICalViewer
  
  Show plain/calendar mail parts.
*/

#import <SOGoUI/SOGoDateFormatter.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/Appointments/SOGoAppointmentFolder.h>
#import <SoObjects/Appointments/SOGoAppointmentObject.h>
#import <SoObjects/Mailer/SOGoMailObject.h>
#import <NGCards/NGCards.h>
#import <NGImap4/NGImap4EnvelopeAddress.h>
#import "common.h"

#import "UIxMailPartICalViewer.h"

@implementation UIxMailPartICalViewer

- (void)dealloc {
  [self->storedEventObject release];
  [self->storedEvent   release];
  [self->attendee      release];
  [self->item          release];
  [self->inCalendar    release];
  [self->inEvent       release];
  [self->dateFormatter release];
  [super dealloc];
}

/* maintain caches */

- (void)resetPathCaches {
  [super resetPathCaches];
  [self->inEvent           release]; self->inEvent           = nil;
  [self->inCalendar        release]; self->inCalendar        = nil;
  [self->storedEventObject release]; self->storedEventObject = nil;
  [self->storedEvent       release]; self->storedEvent       = nil;
  
  /* not strictly path-related, but useless without it anyway: */
  [self->attendee release]; self->attendee = nil;
  [self->item     release]; self->item     = nil;
}

/* raw content handling */

- (NSStringEncoding)fallbackStringEncoding {
  /*
    iCalendar invitations sent by Outlook 2002 have the annoying bug that the
    mail states an UTF-8 content encoding but the actual iCalendar content is
    encoding in Latin-1 (or Windows Western?).
    
    As a result the content decoding will fail (TODO: always?). In this case we
    try to decode with Latin-1.
    
    Note: we could check for the Outlook x-mailer, but it was considered better
          to try Latin-1 as a fallback in any case (be tolerant).
  */
  return NSISOLatin1StringEncoding;
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

- (BOOL)couldParseCalendar {
  return [[self inCalendar] isNotNull];
}

- (iCalEvent *)inEvent {
  NSArray *events;
  
  if (self->inEvent != nil)
    return [self->inEvent isNotNull] ? self->inEvent : nil;
  
  events = [[self inCalendar] events];
  if ([events count] > 0) {
    self->inEvent = [[events objectAtIndex:0] retain];
    return self->inEvent;
  }
  else {
    self->inEvent = [[NSNull null] retain];
    return nil;
  }
}

/* formatters */

- (SOGoDateFormatter *)dateFormatter {
  if (self->dateFormatter == nil) {
    dateFormatter = [[context activeUser] dateFormatterInContext: context];
    [dateFormatter retain];
  }

  return self->dateFormatter;
}

/* below is copied from UIxAppointmentView, can we avoid that? */

- (void)setAttendee:(id)_attendee {
  ASSIGN(self->attendee, _attendee);
}
- (id)attendee {
  return self->attendee;
}

- (NSString *) _personForDisplay: (iCalPerson *) person
{
  return [NSString stringWithFormat: @"%@ <%@>",
		   [person cnWithoutQuotes],
		   [person rfc822Email]];
}

- (NSString *) attendeeForDisplay
{
  return [self _personForDisplay: attendee];
}

- (void)setItem:(id)_item {
  ASSIGN(self->item, _item);
}
- (id)item {
  return self->item;
}

- (NSCalendarDate *) startTime
{
  NSCalendarDate *date;
  NSTimeZone *timeZone;
  
  date = [[self authorativeEvent] startDate];
  timeZone = [[context activeUser] timeZone];
  [date setTimeZone: timeZone];

  return date;
}

- (NSCalendarDate *) endTime
{
  NSCalendarDate *date;
  NSTimeZone *timeZone;
  
  date = [[self authorativeEvent] endDate];
  timeZone = [[context activeUser] timeZone];
  [date setTimeZone: timeZone];

  return date;
}

- (BOOL)isEndDateOnSameDay {
  return [[self startTime] isDateOnSameDay:[self endTime]];
}
- (NSTimeInterval)duration {
  return [[self endTime] timeIntervalSinceDate:[self startTime]];
}

/* calendar folder support */

- (id)calendarFolder {
  /* return scheduling calendar of currently logged-in user */
  SOGoUser *user;
  id folder;

  user = [context activeUser];
  folder = [[user homeFolderInContext: context] lookupName: @"Calendar"
						inContext: context
						acquire: NO];

  return folder;
}

- (id)storedEventObject {
  /* lookup object in the users Calendar */
  id calendar;
  
  if (self->storedEventObject != nil)
    return [self->storedEventObject isNotNull] ? self->storedEventObject : nil;
  
  calendar = [self calendarFolder];
  if ([calendar isKindOfClass:[NSException class]]) {
    [self errorWithFormat:@"Did not find Calendar folder: %@", calendar];
  }
  else {
    NSString *filename;
    
    filename = [calendar resourceNameForEventUID:[[self inEvent] uid]];
    if (filename != nil) {
      // TODO: When we get an exception, this might be an auth issue meaning
      //       that the UID indeed exists but that the user has no access to
      //       the object.
      //       Of course this is quite unusual for the private calendar though.
      id tmp;
      
      tmp = [calendar lookupName:filename inContext:[self context] acquire:NO];
      if ([tmp isNotNull] && ![tmp isKindOfClass:[NSException class]])
	self->storedEventObject = [tmp retain];
    }
  }
  
  if (self->storedEventObject == nil)
    self->storedEventObject = [[NSNull null] retain];
  
  return self->storedEventObject;
}

- (BOOL)isEventStoredInCalendar {
  return [[self storedEventObject] isNotNull];
}

- (iCalEvent *)storedEvent {
  return (iCalEvent *) [(SOGoAppointmentObject *)[self storedEventObject] component: NO];
}

/* organizer tracking */

- (NSString *)loggedInUserEMail {
  return [[[self context] activeUser] primaryEmail];
}

- (iCalEvent *)authorativeEvent {
  /* DB is considered master, when in DB, ignore mail organizer */
  return [self isEventStoredInCalendar]
    ? [self storedEvent]
    : [self inEvent];
}

- (BOOL)isLoggedInUserTheOrganizer {
  NSString *loginEMail;
  
  if ((loginEMail = [self loggedInUserEMail]) == nil) {
    [self warnWithFormat:@"Could not determine email of logged in user?"];
    return NO;
  }
  
  return [[self authorativeEvent] isOrganizer:loginEMail];
}

- (BOOL)isLoggedInUserAnAttendee {
  NSString *loginEMail;
  
  if ((loginEMail = [self loggedInUserEMail]) == nil) {
    [self warnWithFormat:@"Could not determine email of logged in user?"];
    return NO;
  }

  return [[self authorativeEvent] isParticipant:loginEMail];
}

/* derived fields */

- (NSString *) organizerDisplayName
{
  iCalPerson *organizer;
  NSString *value;

  organizer = [[self authorativeEvent] organizer];
  if (organizer)
    value = [self _personForDisplay: organizer];
  else
    value = @"[todo: no organizer set, use 'from']";

  return value;
}

/* replies */

- (NGImap4EnvelopeAddress *)replySenderAddress {
  /* 
     The iMIP reply is the sender of the mail, the 'attendees' are NOT set to
     the actual attendees. BUT the attendee field contains the reply-status!
  */
  id tmp;
  
  tmp = [[self clientObject] fromEnvelopeAddresses];
  if ([tmp count] == 0) return nil;
  return [tmp objectAtIndex:0];
}

- (NSString *)replySenderEMail {
  return [[self replySenderAddress] email];
}
- (NSString *)replySenderBaseEMail {
  return [[self replySenderAddress] baseEMail];
}

- (iCalPerson *)inReplyAttendee {
  NSArray *attendees;
  
  attendees = [[self inEvent] attendees];
  if ([attendees count] == 0)
    return nil;
  if ([attendees count] > 1)
    [self warnWithFormat:@"More than one attendee in REPLY: %@", attendees];
  
  return [attendees objectAtIndex:0];
}
- (iCalPerson *)storedReplyAttendee {
  /*
    TODO: since an attendee can have multiple email addresses, maybe we
          should translate the email to an internal uid and then retrieve
	  all emails addresses for matching the participant.
	  
    Note: -findParticipantWithEmail: does not parse the email!
  */
  iCalEvent  *e;
  iCalPerson *p;
  
  if ((e = [self storedEvent]) == nil)
    return nil;
  if ((p = [e findParticipantWithEmail:[self replySenderBaseEMail]]))
    return p;
  if ((p = [e findParticipantWithEmail:[self replySenderEMail]]))
    return p;
  return nil;
}
- (BOOL)isReplySenderAnAttendee {
  return [[self storedReplyAttendee] isNotNull];
}

/* action URLs */

- (id)acceptLink {
  return [[self pathToAttachmentObject] stringByAppendingString:@"/accept"];
}
- (id)declineLink {
  return [[self pathToAttachmentObject] stringByAppendingString:@"/decline"];
}
- (id)tentativeLink {
  return [[self pathToAttachmentObject] stringByAppendingString:@"/tentative"];
}

@end /* UIxMailPartICalViewer */
