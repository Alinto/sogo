/*
  Copyright (C) 2006-2016 Inverse inc.

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOGo; see the file COPYING. If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

/*
  UIxMailPartICalViewer
 
  Show plain/calendar mail parts.
*/

#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSValue.h>


#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGImap4/NGImap4EnvelopeAddress.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>

#import <SOGo/SOGoDateFormatter.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserManager.h>
#import <Appointments/iCalEntityObject+SOGo.h>
#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoAppointmentObject.h>
#import <Mailer/SOGoMailObject.h>
#import <Mailer/SOGoMailBodyPart.h>

#import "UIxMailPartICalViewer.h"

@implementation UIxMailPartICalViewer

- (void) dealloc
{
  [storedEventObject release];
  [storedEvent release];
  [inCalendar release];
  [dateFormatter release];
  [super dealloc];
}

/* maintain caches */

- (void) resetPathCaches
{
  [super resetPathCaches];
  inEvent = nil;
  [inCalendar release]; inCalendar = nil;
  [storedEventObject release]; storedEventObject = nil;
  [storedEvent release]; storedEvent = nil;
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
	inEvent = [events objectAtIndex: 0];
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

- (NSCalendarDate *) startCalendarDate
{
  NSCalendarDate *date;
  SOGoUserDefaults *ud;
 
  date = [[self inEvent] startDate];
  ud = [[context activeUser] userDefaults];
  [date setTimeZone: [ud timeZone]];
  
  return date;
}

/*
  In v3.0, we moved the template's logic here to format
  the event's start/end date-time. The previous logic was:

          <dd><var:string value="startDate" />
            <var:if condition="inEvent.isAllDay" const:negate="YES">
              <var:string value="startTime" />
            </var:if>
            <var:if condition="isEndDateOnSameDay">
              <var:if condition="inEvent.isAllDay" const:negate="YES">
                <var:string label:value="to" />
                <var:string value="endTime" />
              </var:if>
            </var:if>
            <var:if condition="isEndDateOnSameDay" const:negate="YES">
              <var:string label:value="to" />
              <var:string value="endDate" />
              <var:if condition="inEvent.isAllDay" const:negate="YES">
                <var:string value="endTime" />
              </var:if>
            </var:if>
          </dd>

*/
- (NSString *) formattedDateTime
{
  NSMutableString *s;

  s = [NSMutableString string];

  [s appendString: [self startDate]];

  if (![[self inEvent] isAllDay])
    [s appendFormat: @" %@", [self startTime]];

  if ([self isEndDateOnSameDay] &&
      ![[self inEvent] isAllDay])
    {
      [s appendFormat: @" %@", [self labelForKey: @"to"]];
      [s appendFormat: @" %@", [self endTime]];
    }
  else if (![self isEndDateOnSameDay])
    {
      [s appendFormat: @" %@", [self labelForKey: @"to"]];
      [s appendFormat: @" %@", [self endDate]];

      if (![[self inEvent] isAllDay])
        [s appendFormat: @" %@", [self endTime]];
    }

  return s;
}

- (NSString *) startDate
{
  return [[self dateFormatter] formattedDate: [self startCalendarDate]];
}

- (NSString *) startTime
{
  return [[self dateFormatter] formattedTime: [self startCalendarDate]];
}

- (NSCalendarDate *) endCalendarDate
{
  NSCalendarDate *date;
  SOGoUserDefaults *ud;
 
  date = [[self inEvent] endDate];
  ud = [[context activeUser] userDefaults];
  [date setTimeZone: [ud timeZone]];

  return date;
}

- (NSString *) endDate
{
  NSCalendarDate *aDate;
  if ([[self inEvent] isAllDay])
    aDate = [[self endCalendarDate] dateByAddingYears:0 months:0 days:0 hours:0 minutes:0 seconds:-1];
  else
    aDate = [self endCalendarDate];

  return [[self dateFormatter] formattedDate: aDate];
}

- (NSString *) endTime
{
  return [[self dateFormatter] formattedTime: [self endCalendarDate]];
}

- (BOOL) isEndDateOnSameDay
{
  NSCalendarDate *aDate;
  if ([[self inEvent] isAllDay])
    aDate = [[self endCalendarDate] dateByAddingYears:0 months:0 days:0 hours:0 minutes:0 seconds:-1];
  else
    aDate = [self endCalendarDate];
  return [[self startCalendarDate] isDateOnSameDay: aDate];
}

- (NSTimeInterval) duration
{
  return [[self endCalendarDate] timeIntervalSinceDate:[self startCalendarDate]];
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

  if (!storedEventFetched)
    {
      if ([self hasCalendarAccess])
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
      storedEventFetched = YES;
    }
 
  return storedEventObject;
}

- (BOOL) isEventStoredInCalendar
{
  NSCalendarDate *recurrenceId;
  NSString *recurrenceTime;
  BOOL isInCalendar;

  recurrenceId = [[self inEvent] recurrenceId];

  if (recurrenceId)
    {
      recurrenceTime = [NSString stringWithFormat: @"%f", [recurrenceId timeIntervalSince1970]];
      isInCalendar = ([[self storedEventObject] lookupOccurrence: recurrenceTime] != nil);
    }
  else
    isInCalendar = ([self storedEventObject] != nil);

  return isInCalendar;
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
	  storedEvent = (iCalEvent*)[[self storedEventObject] lookupOccurrence: recurrenceTime];

	  if (storedEvent == nil)
	    // If no occurence found, create one
	    storedEvent = (iCalEvent*)[storedEventObject newOccurenceWithID: recurrenceTime];

	  // Add organizer to occurence if not present
	  organizer = [storedEvent organizer];
	  if (organizer == nil || [organizer isVoid])
	    {
	      organizer = [(iCalEntityObject *)[[storedEvent parent] firstChildWithTag: [storedEventObject componentTag]] organizer];
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
  return [[self authorativeEvent] userIsAttendee: [context activeUser]];
}

/* derived fields */
- (BOOL) hasOrganizer
{
  iCalPerson *organizer;

  organizer = [[self authorativeEvent] organizer];

  if ([organizer isVoid])
    return NO;

  return YES;
}

- (NSString *) organizerDisplayName
{
  iCalPerson *organizer;
  NSString *value;

  organizer = [[self authorativeEvent] organizer];
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

  currentUser = [[self authorativeEvent] userAsAttendee: [context activeUser]];

  return currentUser;
}

- (iCalPerson *) _attendeeFromMailSenderInEvent: (iCalEvent *) e
{
  NSString *baseEmail;
  iCalPerson *p;

  baseEmail = [self replySenderBaseEMail];

  /*
    Note: -findAttendeeWithEmail: does not parse the email!
  */
  p = [e findAttendeeWithEmail: baseEmail];
  if (!p)
    p = [e findAttendeeWithEmail:[self replySenderEMail]];

  // We haven't found it yet, let's look in the identities
  // associated to this user
  if (!p)
    {
      SOGoUserManager *sm;
      NSString *uid;

      sm = [SOGoUserManager sharedUserManager];
      uid = [sm getUIDForEmail: [self replySenderBaseEMail]];

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
	      if ([email caseInsensitiveCompare: baseEmail] == NSOrderedSame)
		continue;

	      p = [e findAttendeeWithEmail: email];

	      if (p)
		break;
	    }
	}
    }

  return p;
}

- (iCalPerson *) storedReplyAttendee
{
  iCalEvent *e;

  e = [self storedEvent];
  if (e)
    return [self _attendeeFromMailSenderInEvent: e];

  return nil;
}

- (BOOL) isReplySenderAnAttendee
{
  return ([self storedReplyAttendee] != nil);
}

- (iCalPerson *) _emailParticipantWithEvent: (iCalEvent *) event
{
  return [self _attendeeFromMailSenderInEvent: event];
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

- (id) renderedPart
{
  NSMutableDictionary *d;
  NSArray *participants;
  iCalPerson *person;
  NSMutableArray *a;
  int i;

  d = [NSMutableDictionary dictionaryWithDictionary: [super renderedPart]];

  // We also add our participants
  participants = [[self authorativeEvent] participants];
  a = [NSMutableArray array];

  for (i = 0; i < [participants count]; i++)
    {
      person = [participants objectAtIndex: i];

      if (![[person delegatedTo] length])
        [a addObject: [NSDictionary dictionaryWithObjectsAndKeys: ([[person cnWithoutQuotes] length] ? [person cnWithoutQuotes] : [person rfc822Email]), @"name",
                                    [person rfc822Email], @"email",
                                    [[person partStatWithDefault] lowercaseString], @"partstat", nil]];
    }

  [d setObject: a  forKey: @"participants"];

  return d;
}

@end /* UIxMailPartICalViewer */
