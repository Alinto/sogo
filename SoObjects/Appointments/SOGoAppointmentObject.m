/*
  Copyright (C) 2007-2019 Inverse inc.

  This file is part of SOGo

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
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalToDo.h>
#import <NGCards/NSCalendarDate+NGCards.h>
#import <SaxObjC/XMLNamespaces.h>

#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/iCalTimeZonePeriod.h>
#import <NGCards/iCalToDo.h>
#import <NGCards/NSString+NGCards.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSObject+DAV.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoDateFormatter.h>
#import <SOGo/SOGoGroup.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/WORequest+SOGo.h>

#import "iCalCalendar+SOGo.h"
#import "iCalEventChanges+SOGo.h"
#import "iCalEntityObject+SOGo.h"
#import "iCalPerson+SOGo.h"
#import "NSArray+Appointments.h"
#import "SOGoAppointmentFolder.h"
#import "SOGoAppointmentOccurence.h"
#import "SOGoFreeBusyObject.h"

#import "SOGoAppointmentObject.h"

@implementation SOGoAppointmentObject

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

/**
 * Return a new exception in the recurrent event.
 * @param theRecurrenceID the ID of the occurence.
 * @return a new occurence.
 */
- (iCalRepeatableEntityObject *) newOccurenceWithID: (NSString *) theRecurrenceID
{
  iCalEvent *newOccurence, *master;
  NSCalendarDate *date, *firstDate;
  unsigned int interval, nbrDays;

  newOccurence = (iCalEvent *) [super newOccurenceWithID: theRecurrenceID];
  date = [newOccurence recurrenceId];

  master = [self component: NO secure: NO];
  firstDate = [master startDate];

  interval = [[master endDate]
               timeIntervalSinceDate: firstDate];
  if ([newOccurence isAllDay])
    {
      nbrDays = ((float) abs (interval) / 86400);
      [newOccurence setAllDayWithStartDate: date
                                  duration: nbrDays];
    }
  else
    {
      [newOccurence setStartDate: date];
      [newOccurence setEndDate: [date addYear: 0
                                        month: 0
                                          day: 0
                                         hour: 0
                                       minute: 0
                                       second: interval]];
    }
  
  return newOccurence;
}

- (iCalRepeatableEntityObject *) lookupOccurrence: (NSString *) recID
{
  return [[self calendar: NO secure: NO] eventWithRecurrenceID: recID];
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
      if ([object isKindOfClass: [NSException class]] || [object isNew])
        {
          possibleName = [folder resourceNameForEventUID: eventUID];
          if (possibleName)
            {
              object = [folder lookupName: possibleName
                                inContext: context acquire: NO];
              if ([object isKindOfClass: [NSException class]] || [object isNew])
                object = nil;
            }
          else
            object = nil;
        }
    }
  
  if (!object)
    {
      // Create the event in the user's personal calendar.
      folder = [[SOGoUser userWithLogin: uid]
                 personalCalendarFolderInContext: context];
      object = [SOGoAppointmentObject objectWithName: nameInContainer
				                                 inContainer: folder];
      [object setIsNew: YES];
    }

  return object;
}

//
// This method will *ONLY* add or update event information in attendees' calendars.
// It will NOT touch to the organizer calendar in anyway. This method is meant
// to reflect changes in attendees' calendars when the organizer makes changes
// to the event.
//
- (void) _addOrUpdateEvent: (iCalEvent *) newEvent
                  oldEvent: (iCalEvent *) oldEvent
                    forUID: (NSString *) theUID
                     owner: (NSString *) theOwner
{
  if (![theUID isEqualToString: theOwner])
    {
      SOGoAppointmentObject *attendeeObject;
      iCalCalendar *iCalendarToSave;
      iCalPerson *attendee;
      SOGoUser *user;

      iCalendarToSave = nil;
      user = [SOGoUser userWithLogin: theUID];
      attendeeObject = [self _lookupEvent: [newEvent uid] forUID: theUID];
      attendee = [newEvent userAsAttendee: user];

      // If the atttende's role is NON-PARTICIPANT, we write nothing to its calendar
      if ([[attendee role] caseInsensitiveCompare: @"NON-PARTICIPANT"] == NSOrderedSame)
        {
          // If the attendee's previous role was not NON-PARTICIPANT we must also delete
          // the event from its calendar
          attendee = [oldEvent userAsAttendee: user];
          if ([[attendee role] caseInsensitiveCompare: @"NON-PARTICIPANT"] != NSOrderedSame)
            {
              NSString *currentUID;

              currentUID = [attendee uidInContext: context];
              if (currentUID)
                [self _removeEventFromUID: currentUID
                                    owner: owner
                         withRecurrenceId: [oldEvent recurrenceId]];

            }

          return;
        }

      if ([newEvent recurrenceId])
        {
          // We must add an occurence to a non-existing event.
          if ([attendeeObject isNew])
            {
              iCalEvent *ownerEvent;

              // We check if the attendee that was added to a single occurence is
              // present in the master component. If not, we create a calendar with
              // a single event for the occurence.
              ownerEvent = [[[newEvent parent] events] objectAtIndex: 0];

              if (![ownerEvent userAsAttendee: user])
                {
                  iCalendarToSave = [[[newEvent parent] mutableCopy] autorelease];
                  [iCalendarToSave removeChildren: [iCalendarToSave childrenWithTag: @"vevent"]];
                  [iCalendarToSave addChild: [[newEvent copy] autorelease]];
                }
            }
          else
            {
              // Only update this occurrence in attendee's calendar
              // TODO : when updating the master event, handle exception dates
              // in attendee's calendar (add exception dates and remove matching
              // occurrences) -- see _updateRecurrenceIDsWithEvent:
              NSCalendarDate *currentId;
              NSArray *occurences;
              iCalEvent *occurence;
              int max, count;

              iCalendarToSave = [attendeeObject calendar: NO  secure: NO];

              // If recurrenceId is defined, remove the occurence from
              // the repeating event. If a recurrenceId is defined in the
              // new event, let's make sure we don't already have one in
              // the calendar already. If so, also remove it.
              if ([oldEvent recurrenceId] || [newEvent recurrenceId])
                {
                  // FIXME: use  _eventFromRecurrenceId:...
                  occurences = [iCalendarToSave events];
                  currentId = ([oldEvent recurrenceId] ? [oldEvent recurrenceId]: [newEvent recurrenceId]);
                  if (currentId)
                    {
                      max = [occurences count];
                      count = 0;
                      while (count < max)
                        {
                          occurence = [occurences objectAtIndex: count];
                          if ([occurence recurrenceId] &&
                              [[occurence recurrenceId] compare: currentId] == NSOrderedSame)
                            {
                              [iCalendarToSave removeChild: occurence];
                              break;
                            }
                          count++;
                        }
                    }
                }
              
              [iCalendarToSave addChild: [[newEvent copy] autorelease]];
            }
        }
      else
        {
          iCalendarToSave = [newEvent parent];
        }

      // Save the event in the attendee's calendar
      if (iCalendarToSave)
        [attendeeObject saveCalendar: iCalendarToSave];
    }
}


//
// This method will *ONLY* delete event information in attendees' calendars.
// It will NOT touch to the organizer calendar in anyway. This method is meant
// to reflect changes in attendees' calendars when the organizer makes changes
// to the event.
//
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
      NSArray *occurences;
      int max, count;
      
      // Invitations are always written to the personal folder; it's not necessay
      // to look into all folders of the user
      // FIXME: why look only in the personal calendar here?
      folder = [[SOGoUser userWithLogin: theUID]
                personalCalendarFolderInContext: context];
      object = [folder lookupName: nameInContainer
                        inContext: context
                          acquire: NO];
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
              count = 0;
              while (count < max)
                {
                  currentOccurence = [occurences objectAtIndex: count];
                  currentId = [currentOccurence recurrenceId];
                  if (currentId && [currentId compare: recurrenceId] == NSOrderedSame)
                    {
                      [[calendar children] removeObject: currentOccurence];
                      break;
                    }
                  count++;
                }

              // Add an date exception.
              event = (iCalRepeatableEntityObject*)[calendar firstChildWithTag: [object componentTag]];
              if (event)
                {
                  [event addToExceptionDates: recurrenceId];
                  [event increaseSequence];
                  [event setLastModified: [NSCalendarDate calendarDate]];

                  // We save the updated iCalendar in the database.
                  [object saveCalendar: calendar];
                }
              else
                {
                  // No more child; kill the parent
                  [object delete];
                }
            }
        }
      else
        [self errorWithFormat: @"Unable to find event with UID %@ in %@'s calendar - skipping delete operation. This can be normal for NON-PARTICIPANT attendees.", nameInContainer, theUID];
    }
}

//
//
//
- (void) _handleRemovedUsers: (NSArray *) attendees
            withRecurrenceId: (NSCalendarDate *) recurrenceId
{
  NSEnumerator *enumerator;
  iCalPerson *currentAttendee;
  NSString *currentUID;

  enumerator = [attendees objectEnumerator];
  while ((currentAttendee = [enumerator nextObject]))
    {
      currentUID = [currentAttendee uidInContext: context];
      if (currentUID)
        [self _removeEventFromUID: currentUID
                            owner: owner
                 withRecurrenceId: recurrenceId];
    }
}

//
//
//
- (void) _removeDelegationChain: (iCalPerson *) delegate
                        inEvent: (iCalEvent *) event
{
  NSString *delegatedTo, *mailTo;

  delegatedTo = [delegate delegatedTo];
  if ([delegatedTo length] > 0)
    {
      mailTo = [delegatedTo rfc822Email];
      delegate = [event findAttendeeWithEmail: mailTo];
      if (delegate)
        {
          [self _removeDelegationChain: delegate
                               inEvent: event];
          [event removeFromAttendees: delegate];
        }
      else
        [self errorWithFormat:@"broken chain: delegate with email '%@' was not found", mailTo];
    }
}

//
// This method returns YES when any attendee has been removed
// and NO otherwise.
//
- (BOOL) _requireResponseFromAttendees: (iCalEvent *) event
{
  NSArray *attendees;
  iCalPerson *currentAttendee;
  BOOL listHasChanged = NO;
  int count, max;

  attendees = [event attendees];
  max = [attendees count];

  for (count = 0; count < max; count++)
    {
      currentAttendee = [attendees objectAtIndex: count];
      if ([[currentAttendee delegatedTo] length] > 0)
        {
          [self _removeDelegationChain: currentAttendee
                               inEvent: event];
          [currentAttendee setDelegatedTo: nil];
          listHasChanged = YES;
        }
      [currentAttendee setRsvp: @"TRUE"];
      [currentAttendee setParticipationStatus: iCalPersonPartStatNeedsAction];
    }

  return listHasChanged;
}

//
//
//
- (BOOL) _shouldScheduleEvent: (iCalPerson *) thePerson
{
  //NSArray *userAgents;
  NSString *v;
  BOOL b;
  //int i;

  b = YES;

  if (thePerson && (v = [thePerson value: 0  ofAttribute: @"SCHEDULE-AGENT"]))
    {
      if ([v caseInsensitiveCompare: @"NONE"] == NSOrderedSame ||
          [v caseInsensitiveCompare: @"CLIENT"] == NSOrderedSame)
        b = NO;
    }

  //
  // If we have to deal with Thunderbird/Lightning, we always send invitation
  // reponses, as Lightning v2.6 (at least this version) sets SCHEDULE-AGENT
  // to NONE/CLIENT when responding to an external invitation received by
  // SOGo - so no invitation responses are ever sent by Lightning. See
  // https://bugzilla.mozilla.org/show_bug.cgi?id=865726 and
  // https://bugzilla.mozilla.org/show_bug.cgi?id=997784
  //
  // This code has been disabled - see 0003274.
  //
#if 0
  userAgents = [[context request] headersForKey: @"User-Agent"];

  for (i = 0; i < [userAgents count]; i++)
    {
      if ([[userAgents objectAtIndex: i] rangeOfString: @"Thunderbird"].location != NSNotFound &&
          [[userAgents objectAtIndex: i] rangeOfString: @"Lightning"].location != NSNotFound)
        {
          b = YES;
          break;
        }
    }
#endif

  return b;
}

//
//
//
- (void) _handleSequenceUpdateInEvent: (iCalEvent *) newEvent
		    ignoringAttendees: (NSArray *) attendees
		         fromOldEvent: (iCalEvent *) oldEvent
{
  NSMutableArray *updateAttendees;
  NSEnumerator *enumerator;
  iCalPerson *currentAttendee;
  NSString *currentUID;

  updateAttendees = [NSMutableArray arrayWithArray: [newEvent attendees]];
  [updateAttendees removeObjectsInArray: attendees];

  enumerator = [updateAttendees objectEnumerator];
  while ((currentAttendee = [enumerator nextObject]))
    {
      currentUID = [currentAttendee uidInContext: context];
      if (currentUID)
        [self _addOrUpdateEvent: newEvent
                       oldEvent: oldEvent
                         forUID: currentUID
                          owner: owner];
    }

  if ([self _shouldScheduleEvent: [newEvent organizer]])
    [self sendEMailUsingTemplateNamed: @"Update"
			    forObject: [newEvent itipEntryWithMethod: @"request"]
		       previousObject: oldEvent
			  toAttendees: updateAttendees
			     withType: @"calendar:invitation-update"];
}

// This method scans the list of attendees.
- (NSException *) _handleAttendeesAvailability: (NSArray *) theAttendees
                                      forEvent: (iCalEvent *) theEvent
{
  iCalPerson *currentAttendee;
  SOGoUser *user;
  SOGoUserSettings *us;
  NSMutableArray *unavailableAttendees;
  NSEnumerator *enumerator;
  NSString *currentUID, *ownerUID;
  NSMutableString *reason;
  NSDictionary *values;
  NSMutableDictionary *value, *moduleSettings;
  id whiteList;
  
  int i, count;
  
  i = count = 0;

  // Build list of the attendees uids
  unavailableAttendees = [[NSMutableArray alloc] init];
  enumerator = [theAttendees objectEnumerator];
  ownerUID = [[[self context] activeUser] login];

  while ((currentAttendee = [enumerator nextObject]))
    {
      currentUID = [currentAttendee uidInContext: context];

      if (currentUID)
        {
          user = [SOGoUser userWithLogin: currentUID];
          us = [user userSettings];
          moduleSettings = [us objectForKey:@"Calendar"];
          
          // Check if the user prevented their account from beeing invited to events
          if ([[moduleSettings objectForKey:@"PreventInvitations"] boolValue])
            {
              // Check if the user have a whiteList
              whiteList = [moduleSettings objectForKey:@"PreventInvitationsWhitelist"];

              // For backward <= 2.2.17 compatibility
              if ([whiteList isKindOfClass: [NSString class]])
                whiteList = [whiteList objectFromJSONString];
          
              // If the filter have a hit, do not add the currentUID to the unavailableAttendees array
              if (![whiteList objectForKey:ownerUID])
                {
                  values = [NSDictionary dictionaryWithObject:[user cn] forKey:@"Cn"];
                  [unavailableAttendees addObject:values];
                }
            }
        }
    }

  count = [unavailableAttendees count];
  
  if (count > 0)
    {
      reason = [NSMutableString stringWithString:[self labelForKey: @"Inviting the following persons is prohibited:"]];
      
      // Add all the unavailable users in the warning message
      for (i = 0; i < count; i++)
        {
          value = [unavailableAttendees objectAtIndex:i];
          [reason appendString:[value keysWithFormat: @"\n %{Cn}"]];
          if (i < count-2)
            [reason appendString:@", "];
        }
      
      [unavailableAttendees release];
      
      return [NSException exceptionWithHTTPStatus:409 reason: reason];
    }

  [unavailableAttendees release];

  return nil;
}

//
// This methods scans the list of attendees. If they are
// considered as resource, it checks for conflicting
// dates for the event and potentially auto-accept/decline
// the invitation.
//
// For normal attendees, it'll return an exception with
// conflicting dates, unless we force the save.//
// We check for between startDate + 1 second and
// endDate - 1 second
//
// Note that it doesn't matter if it changes the participation
// status since in case of an error, nothing will get saved.
//
- (NSException *) _handleAttendeesConflicts: (NSArray *) theAttendees
                                   forEvent: (iCalEvent *) theEvent
                                      force: (BOOL) forceSave
{
  iCalPerson *currentAttendee;
  NSMutableArray *attendees;
  NSEnumerator *enumerator;
  NSString *currentUID;
  SOGoUser *user, *currentUser;

  _resourceHasAutoAccepted = NO;

  // Build a list of the attendees uids
  attendees = [NSMutableArray arrayWithCapacity: [theAttendees count]];
  enumerator = [theAttendees objectEnumerator];
  while ((currentAttendee = [enumerator nextObject]))
    {
      currentUID = [currentAttendee uidInContext: context];
      if (currentUID)
        {
          [attendees addObject: currentUID];
        }
    }
      
  // If the active user is not the owner of the calendar, check possible conflict when
  // the owner is a resource
  currentUser = [context activeUser];
  if (!activeUserIsOwner && ![currentUser isSuperUser])
    {
      [attendees addObject: owner];
    }
  
  enumerator = [attendees objectEnumerator];
  while ((currentUID = [enumerator nextObject]))
    {
      NSCalendarDate *start, *end, *rangeStartDate, *rangeEndDate;
      SOGoAppointmentFolder *folder;
      SOGoFreeBusyObject *fb;
      NGCalendarDateRange *range;
      NSMutableArray *fbInfo;
      NSArray *allOccurences;
          
      BOOL must_delete;
      int i, j, delta;

      user = [SOGoUser userWithLogin: currentUID];

      // We get the start/end date for our conflict range. If the event to be added is recurring, we
      // check for at least a year to start with.
      start = [[theEvent startDate] dateByAddingYears: 0  months: 0  days: 0  hours: 0  minutes: 0  seconds: 1];
      end = [[theEvent endDate] dateByAddingYears: ([theEvent isRecurrent] ? 1 : 0)  months: 0  days: 0  hours: 0  minutes: 0  seconds: -1];
          
      folder = [user personalCalendarFolderInContext: context];

      // Deny access to the resource if the ACLs don't allow the user
      if ([user isResource] && ![folder aclSQLListingFilter])
        {
          NSDictionary *values;
          NSString *reason;
              
          values = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [user cn], @"Cn",
                                 [user systemEmail], @"SystemEmail", nil];
          reason = [values keysWithFormat: [self labelForKey: @"Cannot access resource: \"%{Cn} %{SystemEmail}\""]];
          return [NSException exceptionWithHTTPStatus:409 reason: reason];
        }

      fb = [SOGoFreeBusyObject objectWithName: @"freebusy.ifb" inContainer: [user homeFolderInContext: context]];
      fbInfo = (NSMutableArray *)[fb fetchFreeBusyInfosFrom: start to: end];

      //
      // We must also check here for repetitive events that don't overlap our event.
      // We remove all events that don't overlap. The events here are already
      // decomposed.
      //
      if ([theEvent isRecurrent])
        allOccurences = [theEvent recurrenceRangesWithinCalendarDateRange: [NGCalendarDateRange calendarDateRangeWithStartDate: start
                                                                                                                       endDate: end]
                                           firstInstanceCalendarDateRange: [NGCalendarDateRange calendarDateRangeWithStartDate: [theEvent startDate]
                                                                                                                       endDate: [theEvent endDate]]];
      else
        allOccurences = nil;

      for (i = [fbInfo count]-1; i >= 0; i--)
        {
	  // We first remove any occurences in the freebusy that corresponds to the
	  // current event. We do this to avoid raising a conflict if we move a 1 hour
	  // meeting from 12:00-13:00 to 12:15-13:15. We would overlap on ourself otherwise.
          if ([[[fbInfo objectAtIndex: i] objectForKey: @"c_uid"] compare: [theEvent uid]] == NSOrderedSame)
            {
              [fbInfo removeObjectAtIndex: i];
              continue;
            }

          // Ignore transparent events
          if (![[[fbInfo objectAtIndex: i] objectForKey: @"c_isopaque"] boolValue])
            {
              [fbInfo removeObjectAtIndex: i];
              continue;
            }

          // No need to check if the event isn't recurrent here as it's handled correctly
          // when we compute the "end" date.
          if ([allOccurences count])
            {
              must_delete = YES;

              // We MUST use the -uniqueChildWithTag method here because the event has been flattened, so its timezone has been
              // modified in SOGoAppointmentFolder: -fixupCycleRecord: ....
              rangeStartDate = [[fbInfo objectAtIndex: i] objectForKey: @"startDate"];
              delta = [[rangeStartDate timeZoneDetail] timeZoneSecondsFromGMT] - [[[(iCalDateTime *)[theEvent uniqueChildWithTag: @"dtstart"] timeZone] periodForDate: [theEvent startDate]] secondsOffsetFromGMT];
              rangeStartDate = [rangeStartDate dateByAddingYears: 0  months: 0  days: 0  hours: 0  minutes: 0  seconds: delta];

              rangeEndDate = [[fbInfo objectAtIndex: i] objectForKey: @"endDate"];
              delta = [[rangeEndDate timeZoneDetail] timeZoneSecondsFromGMT] - [[[(iCalDateTime *)[theEvent uniqueChildWithTag: @"dtend"] timeZone] periodForDate: [theEvent endDate]] secondsOffsetFromGMT];
              rangeEndDate = [rangeEndDate dateByAddingYears: 0  months: 0  days: 0  hours: 0  minutes: 0  seconds: delta];

              range = [NGCalendarDateRange calendarDateRangeWithStartDate: rangeStartDate
                                                                  endDate: rangeEndDate];

              for (j = 0; j < [allOccurences count]; j++)
                {
                  if ([range doesIntersectWithDateRange: [allOccurences objectAtIndex: j]])
                    {
                      must_delete = NO;
                      break;
                    }
                }
              if (must_delete)
                [fbInfo removeObjectAtIndex: i];
            }
        }

      // Find the attendee associated to the current UID
      currentAttendee = nil;
      for (i = 0; i < [theAttendees count]; i++)
        {
          currentAttendee = [theAttendees objectAtIndex: i];
          if ([[currentAttendee uidInContext: context] isEqualToString: currentUID])
            break;
          else
            currentAttendee = nil;
        }

      if ([fbInfo count])
        {
          SOGoDateFormatter *formatter;

          formatter = [[context activeUser] dateFormatterInContext: context];
          
          if ([user isResource])
            {
              // If we always force the auto-accept if numberOfSimultaneousBookings <= 0 (ie., no limit
              // is imposed) or if numberOfSimultaneousBookings is greater than the number of
              // overlapping events
              if ([user numberOfSimultaneousBookings] <= 0 ||
                  [user numberOfSimultaneousBookings] > [fbInfo count])
                {
                  if (currentAttendee)
                    {
                      [[currentAttendee attributes] removeObjectForKey: @"RSVP"];
                      [currentAttendee setParticipationStatus: iCalPersonPartStatAccepted];
		      _resourceHasAutoAccepted = YES;
                    }
                }
              else
                {
                  iCalCalendar *calendar;
                  NSDictionary *values, *info;
                  NSString *reason;
                  iCalEvent *event;

                  calendar =  [iCalCalendar parseSingleFromSource: [[fbInfo objectAtIndex: 0] objectForKey: @"c_content"]];
                  event = [[calendar events] lastObject];

                  values = [NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSString stringWithFormat: @"%d", [user numberOfSimultaneousBookings]], @"NumberOfSimultaneousBookings",
                                         [user cn], @"Cn",
                                         [user systemEmail], @"SystemEmail",
                                  ([event summary] ? [event summary] : @""), @"EventTitle",
                                      [formatter formattedDateAndTime: [[fbInfo objectAtIndex: 0] objectForKey: @"startDate"]], @"StartDate",
                                         nil];

                  reason = [values keysWithFormat: [self labelForKey: @"Maximum number of simultaneous bookings (%{NumberOfSimultaneousBookings}) reached for resource \"%{Cn} %{SystemEmail}\". The conflicting event is \"%{EventTitle}\", and starts on %{StartDate}."]];

                  info = [NSDictionary dictionaryWithObject: reason forKey: @"reject"];

                  return [NSException exceptionWithHTTPStatus: 409
                                                       reason: [info jsonRepresentation]];
                }
            }
          //
          // We are dealing with a normal attendee. Lets check if we have conflicts, unless
          // we are being asked to force the save anyway
          //
          else if (!forceSave)
            {
              NSMutableDictionary *info;
              NSMutableArray *conflicts;
              NSString *formattedEnd;
              SOGoUser *ownerUser;
              id o;

              info = [NSMutableDictionary dictionary];
              conflicts = [NSMutableArray array];

              if (currentAttendee)
                {
                  if ([currentAttendee cn])
                    [info setObject: [currentAttendee cn]  forKey: @"attendee_name"];
                  if ([currentAttendee rfc822Email])
                    [info setObject: [currentAttendee rfc822Email]  forKey: @"attendee_email"];
                }
              else if ([owner isEqualToString: currentUID])
                {
                  ownerUser = [SOGoUser userWithLogin: owner];
                  if ([ownerUser cn])
                    [info setObject: [ownerUser cn]  forKey: @"attendee_name"];
                  if ([ownerUser systemEmail])
                    [info setObject: [ownerUser systemEmail]  forKey: @"attendee_email"];
                }

              for (i = 0; i < [fbInfo count]; i++)
                {
                  o = [fbInfo objectAtIndex: i];
                  end = [o objectForKey: @"endDate"];
                  if ([[o objectForKey: @"startDate"] isDateOnSameDay: end])
                    formattedEnd = [formatter formattedTime: end];
                  else
                    formattedEnd = [formatter formattedDateAndTime: end];

                  [conflicts addObject: [NSDictionary dictionaryWithObjectsAndKeys: [formatter formattedDateAndTime: [o objectForKey: @"startDate"]], @"startDate",
                                                      formattedEnd, @"endDate", nil]];
                }

              [info setObject: conflicts  forKey: @"conflicts"];

              // We immediately raise an exception, without processing the possible other attendees.
              return [NSException exceptionWithHTTPStatus: 409
                                                   reason: [info jsonRepresentation]];
            }
        } // if ([fbInfo count]) ...
      else if (currentAttendee && [user isResource])
        {
          // No conflict, we auto-accept. We do this for resources automatically if no
          // double-booking is observed. If it's not the desired behavior, just don't
          // set the resource as one!
          [[currentAttendee attributes] removeObjectForKey: @"RSVP"];
          [currentAttendee setParticipationStatus: iCalPersonPartStatAccepted];
	  _resourceHasAutoAccepted = YES;
        }
    }

  return nil;
}

//
//
//
- (NSException *) _handleAddedUsers: (NSArray *) attendees
                          fromEvent: (iCalEvent *) newEvent
                              force: (BOOL) forceSave
{
  iCalPerson *currentAttendee;
  NSEnumerator *enumerator;
  NSString *currentUID;
  NSException *e;
  
  // We check for conflicts
  if ((e = [self _handleAttendeesConflicts: attendees  forEvent: newEvent  force: forceSave]))
    return e;
  if ((e = [self _handleAttendeesAvailability: attendees  forEvent: newEvent]))
    return e;
  
  enumerator = [attendees objectEnumerator];
  while ((currentAttendee = [enumerator nextObject]))
    {
      currentUID = [currentAttendee uidInContext: context];
      if (currentUID)
      [self _addOrUpdateEvent: newEvent
                     oldEvent: nil
                       forUID: currentUID
                        owner: owner];
    }
  
  return nil;
}


//
//
//
- (void) _addOrDeleteAttendees: (NSArray *) theAttendees
inRecurrenceExceptionsForEvent: (iCalEvent *) theEvent
                           add: (BOOL) shouldAdd
{
  
  NSArray *events;
  iCalEvent *e;
  int i,j;

  // We don't add/delete attendees to all recurrence exceptions if
  // the modification was actually NOT made on the master event
  if ([theEvent recurrenceId])
    return;
  
  events = [[theEvent parent] events];
  
  for (i = 0; i < [events count]; i++)
    {
      e = [events objectAtIndex: i];
      if ([e recurrenceId])
        for (j = 0; j < [theAttendees count]; j++) {
          if (shouldAdd)
            [e addToAttendees: [theAttendees objectAtIndex: j]];
          else
            [e removeFromAttendees: [theAttendees objectAtIndex: j]];
        }
    }
}

//
//
//
- (NSException *) _handleUpdatedEvent: (iCalEvent *) newEvent
		         fromOldEvent: (iCalEvent *) oldEvent
                                force: (BOOL) forceSave
{
  NSArray *addedAttendees, *deletedAttendees, *updatedAttendees;
  iCalEventChanges *changes;
  NSException *ex;

  addedAttendees = nil;
  deletedAttendees = nil;
  updatedAttendees = nil;

  changes = [newEvent getChangesRelativeToEvent: oldEvent];
  if ([changes sequenceShouldBeIncreased])
    {
      // Set new attendees status to "needs action" and recompute changes when
      // the list of attendees has changed. The list might have changed since
      // by changing a major property of the event, we remove all the delegation
      // chains to "other" attendees
      if ([self _requireResponseFromAttendees: newEvent])
        changes = [newEvent getChangesRelativeToEvent: oldEvent];
    }

  deletedAttendees = [changes deletedAttendees];

  if ([deletedAttendees count])
    {
      // We delete the attendees in all exception occurences, if
      // the attendees were removed from the master event.
      [self _addOrDeleteAttendees: deletedAttendees
            inRecurrenceExceptionsForEvent: newEvent
                              add: NO];

      [self _handleRemovedUsers: deletedAttendees
               withRecurrenceId: [newEvent recurrenceId]];
      if ([self _shouldScheduleEvent: [newEvent organizer]])
	[self sendEMailUsingTemplateNamed: @"Deletion"
				forObject: [newEvent itipEntryWithMethod: @"cancel"]
			   previousObject: oldEvent
			      toAttendees: deletedAttendees
				 withType: @"calendar:cancellation"];
    }
  
  if ((ex = [self _handleAttendeesConflicts: [newEvent attendees] forEvent: newEvent  force: forceSave]))
    return ex;
  if ((ex = [self _handleAttendeesAvailability: [newEvent attendees] forEvent: newEvent]))
    return ex;

  addedAttendees = [changes insertedAttendees];

  // We insert the attendees in all exception occurences, if
  // the attendees were added to the master event.
  [self _addOrDeleteAttendees: addedAttendees
        inRecurrenceExceptionsForEvent: newEvent
                          add: YES];

  if ([changes sequenceShouldBeIncreased])
    {
      [newEvent increaseSequence];
      
      // Update attendees calendars and send them an update
      // notification by email. We ignore the newly added
      // attendees as we don't want to send them invitation
      // update emails
      [self _handleSequenceUpdateInEvent: newEvent
                       ignoringAttendees: addedAttendees
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
          
          updatedAttendees = [newEvent attendees];
          enumerator = [updatedAttendees objectEnumerator];
          while ((currentAttendee = [enumerator nextObject]))
            {
              currentUID = [currentAttendee uidInContext: context];
              if (currentUID)
                [self _addOrUpdateEvent: newEvent
                               oldEvent: oldEvent
                                 forUID: currentUID
                                  owner: owner];
            }
        }
    }

  if ([addedAttendees count])
    {
      // Send an invitation to new attendees
      if ((ex = [self _handleAddedUsers: addedAttendees fromEvent: newEvent  force: forceSave]))
        return ex;

      if ([self _shouldScheduleEvent: [newEvent organizer]])
	[self sendEMailUsingTemplateNamed: @"Invitation"
				forObject: [newEvent itipEntryWithMethod: @"request"]
			   previousObject: oldEvent
			      toAttendees: addedAttendees
				 withType: @"calendar:invitation"];
    }

  if ([changes hasMajorChanges])
    [self sendReceiptEmailForObject: newEvent
                     addedAttendees: addedAttendees
                   deletedAttendees: deletedAttendees
                   updatedAttendees: updatedAttendees
                          operation: EventUpdated];

  return nil;
}

//
// Workflow :                             +----------------------+
//                                        |                      |
// [saveComponent:]---> _handleAddedUsers:fromEvent: <-+         |
//       |                                             |         v
//       +------------> _handleUpdatedEvent:fromOldEvent: ---> _addOrUpdateEvent:oldEvent:forUID:owner:  <-----------+
//                               |           |                   ^                                          |
//                               v           v                   |                                          |
//  _handleRemovedUsers:withRecurrenceId:  _handleSequenceUpdateInEvent:ignoringAttendees:fromOldEvent:     |
//                     |                                                                                    |
//                     |             [DELETEAction:]                                                        |
//                     |                    |              {_handleAdded/Updated...}<--+                    |
//                     |                    v                                          |                    |
//                     |         [prepareDeleteOccurence:]                    [PUTAction:]                  |
//                     |               |              |                            |                        |
//                     v               v              v                            v                        |
// _removeEventFromUID:owner:withRecurrenceId:  [changeParticipationStatus:withDelegate:forRecurrenceId:]   |                    
//                     |                                          |                                         |
//                     |                                          v                                         |
//                     +------------------------> _handleAttendee:withDelegate:ownerUser:statusChange:inEvent: ---> [sendResponseToOrganizer:from:]
//                                                  |
//                                                  v
//  _updateAttendee:withDelegate:ownerUser:forEventUID:withRecurrenceId:withSequence:forUID:shouldAddSentBy:      
//
//
- (NSException *) saveComponent: (iCalEvent *) newEvent
{
  return [self saveComponent: newEvent  force: NO];
}

- (NSException *) saveComponent: (iCalEvent *) newEvent
                          force: (BOOL) forceSave
{
  iCalEvent *oldEvent, *oldMasterEvent;
  NSCalendarDate *recurrenceId;
  NSString *recurrenceTime;
  SOGoUser *ownerUser;
  NSArray *attendees;
  NSException *ex;

  [[newEvent parent] setMethod: @""];
  ownerUser = [SOGoUser userWithLogin: owner];

  [self expandGroupsInEvent: newEvent];

  // We first update the event. It is important to do this initially
  // as the event's UID might get modified.
  [super updateComponent: newEvent];

  if ([self isNew])
    {
      // New event -- send invitation to all attendees
      attendees = [newEvent attendeesWithoutUser: ownerUser];
      
      // We catch conflicts and abort the save process immediately
      // in case of one with resources
      if ((ex = [self _handleAddedUsers: attendees fromEvent: newEvent  force: forceSave]))
        return ex;
      
      if ([attendees count])
        {
	  if ([self _shouldScheduleEvent: [newEvent organizer]])
	    [self sendEMailUsingTemplateNamed: @"Invitation"
				    forObject: [newEvent itipEntryWithMethod: @"request"]
			       previousObject: nil
				  toAttendees: attendees
				     withType: @"calendar:invitation"];
        }
      
      [self sendReceiptEmailForObject: newEvent
                       addedAttendees: attendees
                     deletedAttendees: nil
                     updatedAttendees: nil
                            operation: EventCreated];
    }
  else
    {
      BOOL hasOrganizer;
      
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
          oldEvent = (iCalEvent*)[self lookupOccurrence: recurrenceTime];
          if (oldEvent == nil) // If no occurence found, create one
            oldEvent = (iCalEvent *)[self newOccurenceWithID: recurrenceTime];
        }
      
      oldMasterEvent = (iCalEvent *)[[oldEvent parent] firstChildWithTag: [self componentTag]];
      hasOrganizer = [[[oldMasterEvent organizer] email] length];
      
      if (!hasOrganizer || [oldMasterEvent userIsOrganizer: ownerUser])
      // The owner is the organizer of the event; handle the modifications. We aslo
      // catch conflicts just like when the events are created
        if ((ex = [self _handleUpdatedEvent: newEvent fromOldEvent: oldEvent  force: forceSave]))
          return ex;
    }
      
  [super saveComponent: newEvent];
  [self flush];

  return nil;
}

//
// This method is used to update the status of an attendee.
//
// - theOwnerUser is owner of the calendar where the attendee
//   participation state has changed.
// - uid is the actual UID of the user for whom we must
//   update the calendar event (with the participation change)
// - delegate is the delegate attendee if any
//
// This method is called multiple times, in order to update the
// status of the attendee in calendars for the particular event UID.
// 
- (NSException *) _updateAttendee: (iCalPerson *) attendee
                     withDelegate: (iCalPerson *) delegate
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
  iCalPerson *otherAttendee, *otherDelegate;
  NSString *recurrenceTime, *delegateEmail;
  NSException *error;
  BOOL addDelegate, removeDelegate;

  // If the atttende's role is NON-PARTICIPANT, we write nothing to its calendar
  if ([[attendee role] caseInsensitiveCompare: @"NON-PARTICIPANT"] == NSOrderedSame)
    return nil;

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
          event = [eventObject lookupOccurrence: recurrenceTime];
          
          if (event == nil)
          // If no occurence found, create one
          event = [eventObject newOccurenceWithID: recurrenceTime];
        }
      
      if ([[event sequence] intValue] <= [sequence intValue])
        {
          SOGoUser *currentUser;
          
          currentUser = [context activeUser];
          otherAttendee = [event userAsAttendee: theOwnerUser];
          
          delegateEmail = [otherAttendee delegatedTo];
          if ([delegateEmail length])
            delegateEmail = [delegateEmail rfc822Email];
          if ([delegateEmail length])
            otherDelegate = [event findAttendeeWithEmail: delegateEmail];
          else
            otherDelegate = nil;
          
          /* we handle the addition/deletion of delegate users */
          addDelegate = NO;
          removeDelegate = NO;
          if (delegate)
            {
              if (otherDelegate)
                {
                  if (![delegate hasSameEmailAddress: otherDelegate])
                    {
                      removeDelegate = YES;
                      addDelegate = YES;
                    }
                }
              else
                addDelegate = YES;
            }
          else
            {
              if (otherDelegate)
                removeDelegate = YES;
            }
          
          if (removeDelegate)
            {
              while (otherDelegate)
                {
                  [event removeFromAttendees: otherDelegate];
                  
                  // Verify if the delegate was already delegate
                  delegateEmail = [otherDelegate delegatedTo];
                  if ([delegateEmail length])
                    delegateEmail = [delegateEmail rfc822Email];
                  
                  if ([delegateEmail length])
                    otherDelegate = [event findAttendeeWithEmail: delegateEmail];
                  else
                    otherDelegate = nil;
                }
            }
          if (addDelegate)
            [event addToAttendees: delegate];
          
          [otherAttendee setPartStat: [attendee partStat]];
          [otherAttendee setDelegatedTo: [attendee delegatedTo]];
          [otherAttendee setDelegatedFrom: [attendee delegatedFrom]];
          
          // Remove the RSVP attribute, as an action from the attendee
          // was actually performed, and this confuses iCal (bug #1850)
          [[otherAttendee attributes] removeObjectForKey: @"RSVP"];
          
          // If one has accepted / declined an invitation on behalf of
          // the attendee, we add the user to the SENT-BY attribute.
          if (b && ![[currentUser login] isEqualToString: [theOwnerUser login]])
            {
              NSString *currentEmail, *quotedEmail;
              currentEmail = [[currentUser allEmails] objectAtIndex: 0];
              quotedEmail = [NSString stringWithFormat: @"\"MAILTO:%@\"", currentEmail];
              [otherAttendee setValue: 0 ofAttribute: @"SENT-BY"
                                   to: quotedEmail];
            }
          else
            {
              // We must REMOVE any SENT-BY here. This is important since if A accepted
              // the event for B and then, B changes by theirself their participation status,
              // we don't want to keep the previous SENT-BY attribute there.
              [(NSMutableDictionary *)[otherAttendee attributes] removeObjectForKey: @"SENT-BY"];
            }
        }
      
      // We save the updated iCalendar in the database.
      [event setLastModified: [NSCalendarDate calendarDate]];
      error = [eventObject saveCalendar: [event parent]];
    }
      
  return error;
}


//
// This method is invoked from the SOGo Web interface or from the DAV interface.
//
// - theOwnerUser is owner of the calendar where the attendee
//   participation state has changed.
//
- (NSException *) _handleAttendee: (iCalPerson *) attendee
                     withDelegate: (iCalPerson *) delegate
                        ownerUser: (SOGoUser *) theOwnerUser
                     statusChange: (NSString *) newStatus
                          inEvent: (iCalEvent *) event
{
  iCalPerson *otherAttendee, *otherDelegate;
  NSString *currentStatus, *organizerUID;
  SOGoUser *ownerUser, *currentUser;
  NSString *delegateEmail;
  NSException *ex;

  BOOL addDelegate, removeDelegate;

  currentStatus = [attendee partStat];
  otherAttendee = attendee;
  ex = nil;
  
  delegateEmail = [otherAttendee delegatedTo];
  if ([delegateEmail length])
    delegateEmail = [delegateEmail rfc822Email];
  
  if ([delegateEmail length])
    otherDelegate = [event findAttendeeWithEmail: delegateEmail];
  else
    otherDelegate = nil;
  
  // We handle the addition/deletion of delegate users
  addDelegate = NO;
  removeDelegate = NO;
  if (delegate)
    {
      if (otherDelegate)
        {
          // There was already a delegate
          if (![delegate hasSameEmailAddress: otherDelegate])
            {
              // The delegate has changed
              removeDelegate = YES;
              addDelegate = YES;
            }
        }
      else
        // There was no previous delegate
        addDelegate = YES;
    }
  else
    {
      if (otherDelegate)
        // The user has removed the delegate
        removeDelegate = YES;
    }
 
  if (addDelegate || removeDelegate
                  || [currentStatus caseInsensitiveCompare: newStatus] != NSOrderedSame)
    {
      NSMutableArray *delegates;
      NSString *delegatedUID;

      delegatedUID = nil;
      [attendee setPartStat: newStatus];
      
      // If one has accepted / declined an invitation on behalf of
      // the attendee, we add the user to the SENT-BY attribute.
      currentUser = [context activeUser];
      if (![[currentUser login] isEqualToString: [theOwnerUser login]])
        {
          NSString *currentEmail, *quotedEmail;
          currentEmail = [[currentUser allEmails] objectAtIndex: 0];
          quotedEmail = [NSString stringWithFormat: @"\"MAILTO:%@\"", currentEmail];
          [attendee setValue: 0 ofAttribute: @"SENT-BY"
                          to: quotedEmail];
        }
      else
        {
          // We must REMOVE any SENT-BY here. This is important since if A accepted
          // the event for B and then, B changes by theirself their participation status,
          // we don't want to keep the previous SENT-BY attribute there.
          [(NSMutableDictionary *)[attendee attributes] removeObjectForKey: @"SENT-BY"];
        }
      
      [attendee setDelegatedTo: [delegate email]];
      
      if (removeDelegate)
        {
          delegates = [NSMutableArray array];
          
          while (otherDelegate)
            {
              [delegates addObject: otherDelegate];
              
              delegatedUID = [otherDelegate uidInContext: context];
              if (delegatedUID)
                // Delegate attendee is a local user; remove event from their calendar
                [self _removeEventFromUID: delegatedUID
                                    owner: [theOwnerUser login]
                         withRecurrenceId: [event recurrenceId]];
              
              [event removeFromAttendees: otherDelegate];
              
              // Verify if the delegate was already delegated
              delegateEmail = [otherDelegate delegatedTo];
              if ([delegateEmail length])
                delegateEmail = [delegateEmail rfc822Email];
              
              if ([delegateEmail length])
                otherDelegate = [event findAttendeeWithEmail: delegateEmail];
              else
                otherDelegate = nil;
            }

	  if ([self _shouldScheduleEvent: [event organizer]])
	    [self sendEMailUsingTemplateNamed: @"Deletion"
				    forObject: [event itipEntryWithMethod: @"cancel"]
			       previousObject: nil
				  toAttendees: delegates
				     withType: @"calendar:cancellation"];
        } // if (removeDelegate)
      
      if (addDelegate)
        {
          delegatedUID = [delegate uidInContext: context];
          delegates = [NSArray arrayWithObject: delegate];
          [event addToAttendees: delegate];
          
          if (delegatedUID)
            // Delegate attendee is a local user; add event to their calendar
            [self _addOrUpdateEvent: event
                           oldEvent: nil
                             forUID: delegatedUID
                              owner: [theOwnerUser login]];

	  if ([self _shouldScheduleEvent: [event organizer]])
	    [self sendEMailUsingTemplateNamed: @"Invitation"
				    forObject: [event itipEntryWithMethod: @"request"]
			       previousObject: nil
				  toAttendees: delegates
				     withType: @"calendar:invitation"];
        } // if (addDelegate)
      
      // If the current user isn't the organizer of the event
      // that has just been updated, we update the event and
      // send a notification
      ownerUser = [SOGoUser userWithLogin: owner];
      if (!(ex || [event userIsOrganizer: ownerUser]))
        {
          if ([event isStillRelevant])
            [self sendResponseToOrganizer: event
                                     from: ownerUser];
          
          organizerUID = [[event organizer] uidInContext: context];
          
          // Event is an exception to a recurring event; retrieve organizer from master event
          if (!organizerUID)
            organizerUID = [[(iCalEntityObject*)[[event parent] firstChildWithTag: [self componentTag]] organizer] uidInContext: context];
          
          if (organizerUID)
            // Update the attendee in organizer's calendar.
            ex = [self _updateAttendee: attendee
                          withDelegate: delegate
                             ownerUser: theOwnerUser
                           forEventUID: [event uid]
                      withRecurrenceId: [event recurrenceId]
                          withSequence: [event sequence]
                                forUID: organizerUID
                       shouldAddSentBy: YES];
        }
      
      // We update the calendar of all attendees that are
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
          uid = [att uidInContext: context];
          if (uid && att != attendee && ![uid isEqualToString: delegatedUID])
            [self _updateAttendee: attendee
                     withDelegate: delegate
                        ownerUser: theOwnerUser
                      forEventUID: [event uid]
                 withRecurrenceId: [event recurrenceId]
                     withSequence: [event sequence]
                           forUID: uid
                  shouldAddSentBy: YES];
        }
    }
      
  return ex;
}

//
//
//
- (NSDictionary *) _caldavSuccessCodeWithRecipient: (NSString *) recipient
{
  NSMutableArray *element;
  NSDictionary *code;

  element = [NSMutableArray array];
  [element addObject: davElementWithContent (@"recipient", XMLNS_CALDAV, recipient)];
  [element addObject: davElementWithContent (@"request-status", XMLNS_CALDAV, @"2.0;Success")];
  code = davElementWithContent (@"response", XMLNS_CALDAV, element);

  return code;
}

//
// Old CalDAV scheduling (draft 4 and below) methods. We keep them since we still
// advertise for its support but we do everything within the calendar-auto-scheduling code
// 
- (NSArray *) postCalDAVEventRequestTo: (NSArray *) recipients
                                  from: (NSString *) originator
{
  NSEnumerator *recipientsEnum;
  NSMutableArray *elements;
  NSString *recipient;
  
  elements = [NSMutableArray array];

  recipientsEnum = [recipients objectEnumerator];

  while ((recipient = [recipientsEnum nextObject]))
    if ([[recipient lowercaseString] hasPrefix: @"mailto:"])
      {
        [elements addObject: [self _caldavSuccessCodeWithRecipient: recipient]];
      }

  return elements;
}

- (NSArray *) postCalDAVEventCancelTo: (NSArray *) recipients
                                 from: (NSString *) originator
{
  NSEnumerator *recipientsEnum;
  NSMutableArray *elements;

  NSString *recipient;

  elements = [NSMutableArray array];

  recipientsEnum = [recipients objectEnumerator];

  while ((recipient = [recipientsEnum nextObject]))
    if ([[recipient lowercaseString] hasPrefix: @"mailto:"])
      {
        [elements addObject: [self _caldavSuccessCodeWithRecipient: recipient]];
      }

  return elements;
}

- (NSArray *) postCalDAVEventReplyTo: (NSArray *) recipients
                                from: (NSString *) originator
{
  NSEnumerator *recipientsEnum;
  NSMutableArray *elements;
  NSString *recipient;

  elements = [NSMutableArray array];
  recipientsEnum = [recipients objectEnumerator];

  while ((recipient = [recipientsEnum nextObject]))
    if ([[recipient lowercaseString] hasPrefix: @"mailto:"])
      {
        [elements addObject: [self _caldavSuccessCodeWithRecipient: recipient]];
      }

  return elements;
}

//
//
//
- (NSException *) changeParticipationStatus: (NSString *) status
                               withDelegate: (iCalPerson *) delegate
                                      alarm: (iCalAlarm *) alarm
{
  return [self changeParticipationStatus: status
                            withDelegate: delegate
                                   alarm: alarm
                         forRecurrenceId: nil];
}

//
//
//
- (NSException *) changeParticipationStatus: (NSString *) _status
                               withDelegate: (iCalPerson *) delegate
                                      alarm: (iCalAlarm *) alarm
                            forRecurrenceId: (NSCalendarDate *) _recurrenceId
{
  iCalCalendar *calendar;
  iCalEvent *event;
  iCalPerson *attendee;
  NSException *ex;
  SOGoUser *ownerUser, *delegatedUser;
  NSString *recurrenceTime, *delegatedUid;

  event = nil;
  ex = nil;
  delegatedUser = nil;

  calendar = [[self calendar: NO secure: NO] mutableCopy];
  [calendar autorelease];

  if (_recurrenceId)
    {
      // If _recurrenceId is defined, find the specified occurence
      // within the repeating vEvent.
      recurrenceTime = [NSString stringWithFormat: @"%f", [_recurrenceId timeIntervalSince1970]];
      event = (iCalEvent*)[self lookupOccurrence: recurrenceTime];

      // If no occurence found, create one
      if (event == nil)
        event = (iCalEvent*)[self newOccurenceWithID: recurrenceTime];
    }
  else
    // No specific occurence specified; return the first vEvent of
    // the vCalendar.
    event = (iCalEvent*)[calendar firstChildWithTag: [self componentTag]];
  
  if (event)
    {
      // ownerUser will actually be the owner of the calendar
      // where the participation change on the event occurs. The particpation
      // change will be on the attendee corresponding to the ownerUser.
      ownerUser = [SOGoUser userWithLogin: owner];
      
      attendee = [event userAsAttendee: ownerUser];
      if (attendee)
        {
          if (delegate && ![[delegate email] isEqualToString: [attendee delegatedTo]])
            {
              delegatedUid = [delegate uidInContext: context];
              if (delegatedUid)
                delegatedUser = [SOGoUser userWithLogin: delegatedUid];
              if (delegatedUser != nil && [event userIsOrganizer: delegatedUser])
                ex = [NSException exceptionWithHTTPStatus: 409
                                                   reason: @"delegate is organizer"];
              if ([event isAttendee: [[delegate email] rfc822Email]])
                ex = [NSException exceptionWithHTTPStatus: 409
                                                   reason: @"delegate is a participant"];
              else if ([SOGoGroup groupWithEmail: [[delegate email] rfc822Email]
                                        inDomain: [ownerUser domain]])
                ex = [NSException exceptionWithHTTPStatus: 409
                                                   reason: @"delegate is a group"];
            }
          if (ex == nil)
            {
              // Remove the RSVP attribute, as an action from the attendee
              // was actually performed, and this confuses iCal (bug #1850)
              [[attendee attributes] removeObjectForKey: @"RSVP"];
              ex = [self _handleAttendee: attendee
                            withDelegate: delegate
                               ownerUser: ownerUser
                            statusChange: _status
                                 inEvent: event];
            }
          if (ex == nil)
            {
              // We generate the updated iCalendar file and we save it in
              // the database. We do this ONLY when using SOGo from the
              // Web interface or over ActiveSync.
              // Over DAV, it'll be handled directly in PUTAction:
              if (![context request] ||
                  [[context request] handledByDefaultHandler] ||
                  [[[context request] requestHandlerKey] isEqualToString: @"Microsoft-Server-ActiveSync"])
                {
                  // If an alarm was specified, let's use it. This would happen if an attendee accepts/declines/etc. an
                  // event invitation and also sets an alarm along the way. This would happen ONLY from the web interface.
                  [event removeAllAlarms];

                  if (alarm)
                    {
                      [event addToAlarms: alarm];
                    }

                  [event setLastModified: [NSCalendarDate calendarDate]];
                  ex = [self saveCalendar: [event parent]];
                }
            }
        }
      else
        ex = [NSException exceptionWithHTTPStatus: 404 // Not Found
                                           reason: @"user does not participate in this calendar event"];
    }
      else
        ex = [NSException exceptionWithHTTPStatus: 500 // Server Error
                                           reason: @"unable to parse event record"];
  
  return ex;
}

//
//
//
- (void) prepareDeleteOccurence: (iCalEvent *) occurence
{
  SOGoUser *ownerUser, *currentUser;
  NSCalendarDate *recurrenceId;
  NSArray *attendees;
  iCalEvent *event;
  BOOL send_receipt;

  ownerUser = [SOGoUser userWithLogin: owner];
  event = [self component: NO secure: NO];
  send_receipt = YES;

  if (occurence == nil)
    {
      // No occurence specified; use the master event.
      occurence = event;
      recurrenceId = nil;
    }
  else
    // Retrieve this occurence ID.
    recurrenceId = [occurence recurrenceId];

  if ([occurence userIsAttendee: ownerUser])
    {
      // The current user deletes the occurence; let the organizer know that
      // the user has declined this occurence.
      [self changeParticipationStatus: @"DECLINED"
                         withDelegate: nil
                                alarm: nil
                      forRecurrenceId: recurrenceId];
      send_receipt = NO;
    }
  else
    {
      // The organizer deletes an occurence.
      currentUser = [context activeUser];

      if (recurrenceId)
        attendees = [occurence attendeesWithoutUser: currentUser];
      else
        attendees = [[event parent] attendeesWithoutUser: currentUser];
      
      //if (![attendees count] && event != occurence)
      //attendees = [event attendeesWithoutUser: currentUser];
      
      if ([attendees count])
        {
          // Remove the event from all attendees calendars
          // and send them an email.
          [self _handleRemovedUsers: attendees
                   withRecurrenceId: recurrenceId];

	  if ([self _shouldScheduleEvent: [event organizer]])
	    [self sendEMailUsingTemplateNamed: @"Deletion"
				    forObject: [occurence itipEntryWithMethod: @"cancel"]
			       previousObject: nil
				  toAttendees: attendees
				     withType: @"calendar:cancellation"];
        }
    }

  if (send_receipt)
    [self sendReceiptEmailForObject: event
		     addedAttendees: nil
		   deletedAttendees: nil
		   updatedAttendees: nil
			  operation: EventDeleted];
}

- (NSException *) prepareDelete
{
  [self prepareDeleteOccurence: nil];

  return [super prepareDelete];
}

- (NSDictionary *) _partStatsFromCalendar: (iCalCalendar *) calendar
{
  NSMutableDictionary *partStats;
  NSArray *allEvents;
  int count, max;
  iCalEvent *currentEvent;
  iCalPerson *ownerAttendee;
  NSString *key;
  SOGoUser *ownerUser;

  ownerUser = [SOGoUser userWithLogin: owner];

  allEvents = [calendar events];
  max = [allEvents count];
  partStats = [NSMutableDictionary dictionaryWithCapacity: max];

  for (count = 0; count < max; count++)
    {
      currentEvent = [allEvents objectAtIndex: count];
      ownerAttendee = [currentEvent userAsAttendee: ownerUser];
      if (ownerAttendee)
        {
          if (count == 0)
            key = @"master";
          else
            key = [[currentEvent recurrenceId] iCalFormattedDateTimeString];
          [partStats setObject: ownerAttendee forKey: key];
        }
    }

  return partStats;
}

- (iCalCalendar *) _setupResponseInRequestCalendar: (iCalCalendar *) rqCalendar
{
  iCalCalendar *calendar;
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
      newPartStats = [self _partStatsFromCalendar: rqCalendar];
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

  return calendar;
}

- (void) _adjustTransparencyInRequestCalendar: (iCalCalendar *) rqCalendar
{
  NSArray *allEvents;
  iCalEvent *event;
  int i;

  allEvents = [rqCalendar events];
  for (i = 0; i < [allEvents count]; i++)
    {
      event = [allEvents objectAtIndex: i];
      if ([event isAllDay] && [event isOpaque])
          [event setTransparency: @"TRANSPARENT"];
    }
}

//
// iOS devices (and potentially others) send event invitations with no PARTSTAT defined.
// This confuses DAV clients like Thunderbird, or event SOGo web. The RFC says:
//
//    Description: This parameter can be specified on properties with a
//    CAL-ADDRESS value type. The parameter identifies the participation
//    status for the calendar user specified by the property value. The
//    parameter values differ depending on whether they are associated with
//    a group scheduled "VEVENT", "VTODO" or "VJOURNAL". The values MUST
//    match one of the values allowed for the given calendar component. If
//    not specified on a property that allows this parameter, the default
//    value is NEEDS-ACTION.
//
- (void) _adjustPartStatInRequestCalendar: (iCalCalendar *) rqCalendar
{
  NSArray *allObjects, *allAttendees;
  iCalPerson *attendee;
  id entity;
  
  int i, j;
  
  allObjects = [rqCalendar allObjects];

  for (i = 0; i < [allObjects count]; i++)
    {
      entity = [allObjects objectAtIndex: i];

      if ([entity isKindOfClass: [iCalEvent class]])
        {
          allAttendees = [entity attendees];

          for (j = 0; j < [allAttendees count]; j++)
            {
              attendee = [allAttendees objectAtIndex: j];

              if (![[attendee partStat] length])
                [attendee setPartStat: @"NEEDS-ACTION"];
            }
        }
    }
}

/**
 * Verify vCalendar for any inconsistency or missing attributes.
 * Currently only check if the events have an end date or a duration.
 * We also check for the default transparency parameters.
 * We also check for broken ORGANIZER such as "ORGANIZER;:mailto:sogo3@example.com"
 * @param rq the HTTP PUT request
 */
- (void) _adjustEventsInRequestCalendar: (iCalCalendar *) rqCalendar
{
  NSArray *allEvents;
  iCalEvent *event;
  NSUInteger i;
  int j;

  allEvents = [rqCalendar events];

  for (i = 0; i < [allEvents count]; i++)
    {
      event = [allEvents objectAtIndex: i];

      if (![event hasEndDate] && ![event hasDuration])
        {
          // No end date, no duration
          if ([event isAllDay])
            [event setDuration: @"P1D"];
          else
            [event setDuration: @"PT1H"];
          [self warnWithFormat: @"Invalid event: no end date; setting duration to %@", [event duration]];
        }

      if ([event organizer])
        {
          NSString *uid;

          if (![[[event organizer] cn] length])
            {
              [[event organizer] setCn: [[event organizer] rfc822Email]];
            }

          // We now make sure that the organizer, if managed by SOGo, is using
          // its default email when creating events and inviting attendees.
          uid = [[event organizer] uidInContext: context];
          if (uid)
            {
	      iCalPerson *attendee, *organizer;
              NSDictionary *defaultIdentity;
	      SOGoUser *organizerUser;
	      NSArray *allAttendees;

	      organizerUser = [SOGoUser userWithLogin: uid];
              defaultIdentity = [organizerUser defaultIdentity];
	      organizer = [[event organizer] copy];
              [organizer setCn: [defaultIdentity objectForKey: @"fullName"]];
              [organizer setEmail: [defaultIdentity objectForKey: @"email"]];

	      // We now check if one of the attendee is also the organizer. If so,
	      // we remove it. See bug #3905 (https://sogo.nu/bugs/view.php?id=3905)
	      // for more details. This is a Calendar app bug on Apple Yosemite.
	      allAttendees = [event attendees];

	      for (j = [allAttendees count]-1; j >= 0; j--)
		{
		  attendee = [allAttendees objectAtIndex: j];
		  if ([organizerUser hasEmail: [attendee rfc822Email]])
		    [event removeFromAttendees: attendee];
		}

	      // We reset the organizer
	      [event setOrganizer: organizer];
	      RELEASE(organizer);
            }
        }
    }
}

//
// This is similar to what we do in SOGoAppointmentFolder: -importCalendar:
//
- (void) _adjustFloatingTimeInRequestCalendar: (iCalCalendar *) rqCalendar
{
  iCalDateTime *startDate, *endDate;
  NSString *startDateAsString;
  SOGoUserDefaults *ud;
  NSArray *allEvents;
  iCalTimeZone *tz;
  iCalEvent *event;
  int i, delta;

  allEvents = [rqCalendar events];
  for (i = 0; i < [allEvents count]; i++)
    {
      event = [allEvents objectAtIndex: i];

      if ([event isAllDay])
	continue;

      startDate =  (iCalDateTime *)[event uniqueChildWithTag: @"dtstart"];
      startDateAsString = [[startDate valuesAtIndex: 0 forKey: @""] objectAtIndex: 0];

      if (![startDate timeZone] &&
	  ![startDateAsString hasSuffix: @"Z"] &&
	  ![startDateAsString hasSuffix: @"z"])
	{
	  ud = [[context activeUser] userDefaults];
          tz = [iCalTimeZone timeZoneForName: [ud timeZoneName]];
          if ([rqCalendar addTimeZone: tz])
            {
	      delta = [[tz periodForDate: [startDate dateTime]] secondsOffsetFromGMT];

	      [event setStartDate: [[event startDate] dateByAddingYears: 0  months: 0  days: 0  hours: 0  minutes: 0  seconds: -delta]];
	      [startDate setTimeZone: tz];

	      endDate = (iCalDateTime *) [event uniqueChildWithTag: @"dtend"];
	      if (endDate)
		{
		  [event setEndDate: [[event endDate] dateByAddingYears: 0  months: 0  days: 0  hours: 0  minutes: 0  seconds: -delta]];
		  [endDate setTimeZone: tz];
		}
            }
	}
    }
}

- (void) _decomposeGroupsInRequestCalendar: (iCalCalendar *) rqCalendar
{
  NSArray *allEvents;
  iCalEvent *event;
  int i;

  // The algorithm is pretty straightforward:
  //
  // We get all events
  //   We get all attendees
  //     If some are groups, we decompose them
  // We regenerate the iCalendar string
  //
  allEvents = [rqCalendar events];
  for (i = 0; i < [allEvents count]; i++)
    {
      event = [allEvents objectAtIndex: i];
      [self expandGroupsInEvent: event];
    }
}


//
// If theRecurrenceId is nil, it returns immediately the
// first event that has a RECURRENCE-ID.
//
// Otherwise, it return values that matches.
//
- (iCalEvent *) _eventFromRecurrenceId: (NSCalendarDate *) theRecurrenceId
                                events: (NSArray *) allEvents
{
  iCalEvent *event;
  int i;

  for (i = 0; i < [allEvents count]; i++)
    {
      event = [allEvents objectAtIndex: i];
      
      if ([event recurrenceId] && !theRecurrenceId)
        return event;
      
      if ([event recurrenceId] && [[event recurrenceId] compare: theRecurrenceId] == NSOrderedSame)
        return event;
    }

  return nil;
}

//
//
//
- (NSCalendarDate *) _addedExDate: (iCalEvent *) oldEvent
                         newEvent: (iCalEvent *) newEvent
{
  NSArray *oldExDates, *newExDates;
  NSMutableArray *dates;
  int i;
  
  dates = [NSMutableArray array];
  
  newExDates = [newEvent childrenWithTag: @"exdate"];
  for (i = 0; i < [newExDates count]; i++)
    [dates addObject: [[newExDates objectAtIndex: i] dateTime]];

  oldExDates = [oldEvent childrenWithTag: @"exdate"];
  for (i = 0; i < [oldExDates count]; i++)
    [dates removeObject: [[oldExDates objectAtIndex: i] dateTime]];

  return [dates lastObject];
}


//
//
//
- (id) DELETEAction: (WOContext *) _ctx
{
  [self prepareDelete];
  return [super DELETEAction: _ctx];
}

//
// Let's check if our CalDAV client has sent us a broken SENT-BY. When Lightning is identity-aware,
// it'll stupidly send something like this:
// ORGANIZER;RSVP=TRUE;CN=John Doe;PARTSTAT=ACCEPTED;ROLE=CHAIR;SENT-BY="mail
// to:mailto:sogo3@example.com":mailto:sogo1@example.com
//
- (void) _fixupSentByForPerson: (iCalPerson *) person
{
  NSString *sentBy;

  sentBy = [person sentBy];
  if ([sentBy hasPrefix: @"mailto:"])
    [person setSentBy: [sentBy substringFromIndex: 7]];
}

//
// This method is meant to be the common point of any save operation from web
// and DAV requests, as well as from code making use of SOGo as a library
// (OpenChange)
//
- (NSException *) updateContentWithCalendar: (iCalCalendar *) calendar
                                fromRequest: (WORequest *) rq
{
  SOGoUser *ownerUser;
  NSException *ex;
  NSArray *roles;

  BOOL ownerIsOrganizer;

  if (calendar == fullCalendar || calendar == safeCalendar
                               || calendar == originalCalendar)
    [NSException raise: NSInvalidArgumentException format: @"the 'calendar' argument must be a distinct instance" @" from the original object"];

  ownerUser = [SOGoUser userWithLogin: owner];

  roles = [[context activeUser] rolesForObject: self
                                     inContext: context];
  //
  // We check if we gave only the "Respond To" right and someone is actually
  // responding to one of our invitation. In this case, _setupResponseCalendarInRequest
  // will only take the new attendee status and actually discard any other modifications.
  //
  if ([roles containsObject: @"ComponentResponder"] && ![roles containsObject: @"ComponentModifier"])
    calendar = [self _setupResponseInRequestCalendar: calendar];
  else
    {
      if (![[rq headersForKey: @"X-SOGo"] containsObject: @"NoGroupsDecomposition"])
        [self _decomposeGroupsInRequestCalendar: calendar];
      
      if ([[ownerUser domainDefaults] iPhoneForceAllDayTransparency] && [rq isIPhone])
	[self _adjustTransparencyInRequestCalendar: calendar];
      
      [self _adjustEventsInRequestCalendar: calendar];
      [self adjustClassificationInRequestCalendar: calendar];
      [self _adjustPartStatInRequestCalendar: calendar];
      [self _adjustFloatingTimeInRequestCalendar: calendar];
    }
      
  //
  // We first check if it's a new event
  //
  if ([self isNew])
    {
      iCalEvent *event;
      NSArray *attendees;
      NSString *eventUID;

      event = [[calendar events] objectAtIndex: 0];
      eventUID = [event uid];
      attendees = nil;

      // make sure eventUID doesn't conflict with an existing event -  see bug #1853
      // TODO: send out a no-uid-conflict (DAV:href) xml element (rfc4791 section 5.3.2.1)
      if ([container resourceNameForEventUID: eventUID])
        {
          return [NSException exceptionWithHTTPStatus: 409
                                               reason: [NSString stringWithFormat: @"Event UID already in use. (%@)", eventUID]];
        }
     
      //
      // New event and we're the organizer -- send invitation to all attendees
      //
      ownerIsOrganizer = [event userIsOrganizer: ownerUser];

      // We handle the situation where the SOGo Integrator extension isn't installed or
      // if the SENT-BY isn't set. That can happen if Bob invites Alice by creating the event
      // in Annie's calendar. Annie should be the organizer, and Bob the SENT-BY. But most
      // broken CalDAV client that aren't identity-aware will create the event in Annie's calendar
      // and set Bob as the organizer. We fix this for them. See #3368 for details.
      if (!ownerIsOrganizer &&
	  [[context activeUser] hasEmail: [[event organizer] rfc822Email]])
	{
	  [[event organizer] setCn: [ownerUser cn]];
	  [[event organizer] setEmail: [[ownerUser allEmails] objectAtIndex: 0]];
	  [[event organizer] setSentBy: [NSString stringWithFormat: @"\"MAILTO:%@\"", [[[context activeUser] allEmails] objectAtIndex: 0]]];
	  ownerIsOrganizer = YES;
	}

      if (ownerIsOrganizer)
	{
	  attendees = [event attendeesWithoutUser: ownerUser];
	  if ([attendees count])
	    {
	      [self _fixupSentByForPerson: [event organizer]];

	      if ((ex = [self _handleAddedUsers: attendees fromEvent: event  force: YES]))
		return ex;
	      else
		{
		  // We might have auto-accepted resources here. If that's the
		  // case, let's regenerate the versitstring and replace the
		  // one from the request.
		  [rq setContent: [[[event parent] versitString] dataUsingEncoding: [rq contentEncoding]]];
		}

	      if ([self _shouldScheduleEvent: [event organizer]])
		[self sendEMailUsingTemplateNamed: @"Invitation"
					forObject: [event itipEntryWithMethod: @"request"]
				   previousObject: nil
				      toAttendees: attendees
					 withType: @"calendar:invitation"];
	    }
	}
      //
      // We aren't the organizer but we're an attendee. That can happen when
      // we receive an external invitation (IMIP/ITIP) and we accept it
      // from a CUA - it gets added to a specific CalDAV calendar using a PUT
      //
      else if ([event userIsAttendee: ownerUser] && [self _shouldScheduleEvent: [event userAsAttendee: ownerUser]])
        {
          [self sendIMIPReplyForEvent: event
                                 from: ownerUser
                                   to: [event organizer]];
        }
      	      
      [self sendReceiptEmailForObject: event
		       addedAttendees: attendees
		     deletedAttendees: nil
		     updatedAttendees: nil
			    operation: EventCreated];
    }  // if ([self isNew])
  else
    {
      iCalCalendar *oldCalendar;
      iCalEvent *oldEvent, *newEvent;
      iCalEventChanges *changes;
      NSMutableArray *oldEvents, *newEvents;
      NSCalendarDate *recurrenceId;
      int i;

      //
      // We check what has changed in the event and react accordingly.
      //
      newEvents = [NSMutableArray arrayWithArray: [calendar events]];

      oldCalendar = [self calendar: NO secure: NO];
      oldEvents = [NSMutableArray arrayWithArray: [oldCalendar events]];
      recurrenceId = nil;

      for (i = [newEvents count]-1; i >= 0; i--)
        {
          newEvent = [newEvents objectAtIndex: i];
          
          if ([newEvent recurrenceId])
            {
              // Find the corresponding RECURRENCE-ID in the old calendar
              // If not present, we assume it was created before the PUT
              oldEvent = [self _eventFromRecurrenceId: [newEvent recurrenceId]
                                               events: oldEvents];
              
              if (oldEvent == nil)
                {
                  NSString *recurrenceTime;
                  recurrenceTime = [NSString stringWithFormat: @"%f", [[newEvent recurrenceId] timeIntervalSince1970]];
                  oldEvent = (iCalEvent *)[self newOccurenceWithID: recurrenceTime];
                }
              
              // If present, we look for changes
              changes = [iCalEventChanges changesFromEvent: oldEvent  toEvent: newEvent];
              
              if ([changes sequenceShouldBeIncreased] | [changes hasAttendeeChanges])
                {
                  // We found a RECURRENCE-ID with changes, we consider it
                  recurrenceId = [newEvent recurrenceId];
                  break;
                }
              else
                {
                  [newEvents removeObject: newEvent];
                  [oldEvents removeObject: oldEvent];
                }
            }
          
          oldEvent = nil;
          newEvent = nil;
        }

      // If no changes were observed, let's see if we have any left overs
      // in the oldEvents or in the newEvents array
      if (!oldEvent && !newEvent)
        {
          // We check if we only have to deal with the MASTER event
          if ([newEvents count] == [oldEvents count])
            {
              oldEvent = [oldEvents objectAtIndex: 0];
              newEvent = [newEvents objectAtIndex: 0];
            }
          // A RECURRENCE-ID was added
          else if ([newEvents count] > [oldEvents count])
            {
              oldEvent = nil;
              newEvent = [self _eventFromRecurrenceId: nil  events: newEvents];
              recurrenceId = [newEvent recurrenceId];
            }
          // A RECURRENCE-ID was removed
          else
            {
              oldEvent = [self _eventFromRecurrenceId: nil  events: oldEvents];
              newEvent = nil;
              recurrenceId = [oldEvent recurrenceId];
            }
        }
      
      // We check if the PUT call is actually an PART-STATE change
      // from one of the attendees - here's the logic :
      //
      // if owner == organizer
      //
      //    if [context activeUser] == organizer
      //      [send the invitation update]
      //    else
      //      [react on SENT-BY as someone else is acting for the organizer]
      //
      //
      if ([[newEvent attendees] count] || [[oldEvent attendees] count])
        {
          BOOL userIsOrganizer;

          // newEvent might be nil here, if we're deleting a RECURRENCE-ID with attendees
          // If that's the case, we use the oldEvent to obtain the organizer
          if (newEvent)
            {
              ownerIsOrganizer = [newEvent userIsOrganizer: ownerUser];
              userIsOrganizer = [newEvent userIsOrganizer: [context activeUser]];
            }
          else
            {
              ownerIsOrganizer = [oldEvent userIsOrganizer: ownerUser];
              userIsOrganizer = [oldEvent userIsOrganizer: [context activeUser]];
            }

	  // We handle the situation where the SOGo Integrator extension isn't installed or
	  // if the SENT-BY isn't set. That can happen if Bob invites Alice by creating the event
	  // in Annie's calendar. Annie should be the organizer, and Bob the SENT-BY. But most
	  // broken CalDAV client that aren't identity-aware will create the event in Annie's calendar
	  // and set Bob as the organizer. We fix this for them.  See #3368 for details.
          //
          // We also handle the case where Bob invites Alice and Bob has full access to Alice's calendar
          // After inviting ALice, Bob opens the event in Alice's calendar and accept/declines the event.
          //
	  if (!userIsOrganizer &&
              !ownerIsOrganizer &&
	      [[context activeUser] hasEmail: [[newEvent organizer] rfc822Email]])
	    {
	      [[newEvent organizer] setCn: [ownerUser cn]];
	      [[newEvent organizer] setEmail: [[ownerUser allEmails] objectAtIndex: 0]];
	      [[newEvent organizer] setSentBy: [NSString stringWithFormat: @"\"MAILTO:%@\"", [[[context activeUser] allEmails] objectAtIndex: 0]]];
	      ownerIsOrganizer = YES;
	    }

          // With Thunderbird 10, if you create a recurring event with an exception
          // occurence, and invite someone, the PUT will have the organizer in the
          // recurrence-id and not in the master event. We must fix this, otherwise
          // SOGo will break.
          if (!recurrenceId && ![[[[[newEvent parent] events] objectAtIndex: 0] organizer] uidInContext: context])
            [[[[newEvent parent] events] objectAtIndex: 0] setOrganizer: [newEvent organizer]];

          if (ownerIsOrganizer)
            {
	      // We check ACLs of the 'organizer' - in case someone forges the SENT-BY
	      NSString *uid;

	      [self _fixupSentByForPerson: [newEvent organizer]];

	      uid = [[oldEvent organizer] uidInContext: context];

	      if (uid && [[[context activeUser] login] caseInsensitiveCompare: uid] != NSOrderedSame)
		{
		  SOGoAppointmentObject *organizerObject;

		  organizerObject = [self _lookupEvent: [oldEvent uid] forUID: uid];
		  roles = [[context activeUser] rolesForObject: organizerObject
						     inContext: context];

		  if (![roles containsObject: @"ComponentModifier"])
		    {
		      return [NSException exceptionWithHTTPStatus: 409
							   reason: @"Not allowed to perform this action. Wrong SENT-BY being used regarding access rights on organizer's calendar."];
		    }
		}

              // A RECCURENCE-ID was removed
              if (!newEvent && oldEvent)
                [self prepareDeleteOccurence: oldEvent];
              // The master event was changed, A RECCURENCE-ID was added or modified
              else if ((ex = [self _handleUpdatedEvent: newEvent  fromOldEvent: oldEvent  force: YES]))
                return ex;
            } // if (ownerIsOrganizer) ..
          //
          // else => attendee is responding
          //
          //   if [context activeUser] == attendee
          //       [we change the PART-STATE]
          //   else
          //      [react on SENT-BY as someone else is acting for the attendee]
          else
            {
              iCalPerson *attendee, *delegate;
              NSString *delegateEmail;

              attendee = [oldEvent userAsAttendee: [SOGoUser userWithLogin: owner]];

              if (!attendee)
                attendee = [newEvent userAsAttendee: [SOGoUser userWithLogin: owner]];
              else
                {
                  // We must do an extra check here since Bob could have invited Alice
                  // using alice@example.com but she would have accepted with ATTENDEE set
                  // to sexy@example.com. That would duplicate the ATTENDEE and set the
                  // participation status to ACCEPTED for sexy@example.com but leave it
                  // to NEEDS-ACTION to alice@example. This can happen in Mozilla Thunderbird/Lightning
                  // when a user with multiple identities accepts an event invitation to one
                  // of its identity (which is different than the email address associated with
                  // the mail account) prior doing a calendar refresh.
                  NSMutableArray *attendees;
                  iCalPerson *participant;

                  attendees = [NSMutableArray arrayWithArray: [newEvent attendeesWithoutUser: [SOGoUser userWithLogin: owner]]];

                  participant = [newEvent participantForUser: [SOGoUser userWithLogin: owner]
                                                    attendee: attendee];
                  [attendee setPartStat: [participant partStat]];
                  [attendee setDelegatedFrom: [participant delegatedFrom]];
                  [attendee setDelegatedTo: [participant delegatedTo]];
                  [attendees addObject: attendee];
                  [newEvent setAttendees: attendees];
                }
              
              // We first check of the sequences are alright. We don't accept attendees
              // accepting "old" invitations. If that's the case, we return a 409
              if ([[newEvent sequence] intValue] < [[oldEvent sequence] intValue])
                return [NSException exceptionWithHTTPStatus: 409
                                                     reason: @"sequences don't match"];
              
              // Remove the RSVP attribute, as an action from the attendee
              // was actually performed, and this confuses iCal (bug #1850)
              [[attendee attributes] removeObjectForKey: @"RSVP"];
              
              delegate = nil;
              delegateEmail = [attendee delegatedTo];
              
              if ([delegateEmail length])
                {
                  delegateEmail = [delegateEmail substringFromIndex: 7];
                  if ([delegateEmail length])
                    delegate = [newEvent findAttendeeWithEmail: delegateEmail];
                }
              
              changes = [iCalEventChanges changesFromEvent: oldEvent  toEvent: newEvent];
              
              // The current user deletes the occurence; let the organizer know that
              // the user has declined this occurence.
              if ([[changes updatedProperties] containsObject: @"exdate"])
                {
                  [self changeParticipationStatus: @"DECLINED"
                                     withDelegate: nil // FIXME (specify delegate?)
                                            alarm: nil
                                  forRecurrenceId: [self _addedExDate: oldEvent  newEvent: newEvent]];
                }
              else if (attendee)
                {
                  [self changeParticipationStatus: [attendee partStat]
                                     withDelegate: delegate
                                            alarm: nil
                                  forRecurrenceId: recurrenceId];
                }
              // All attendees and the organizer field were removed. Apple iCal does
              // that when we remove the last attendee of an event.
              //
              // We must update previous's attendees' calendars to actually
              // remove the event in each of them.
              else
                {
                  [self _handleRemovedUsers: [changes deletedAttendees]
                           withRecurrenceId: recurrenceId];
                }
            }  
        } // if ([[newEvent attendees] count] || [[oldEvent attendees] count])
      else
        {
          changes = [iCalEventChanges changesFromEvent: oldEvent  toEvent: newEvent];
          if ([changes hasMajorChanges])
            [self sendReceiptEmailForObject: newEvent
                             addedAttendees: nil
                           deletedAttendees: nil
                           updatedAttendees: nil
                                  operation: EventUpdated];
        }
    }  // else of if (isNew) ...
      
  unsigned int baseVersion;
  // We must NOT invoke [super PUTAction:] here as it'll resave
  // the content string and we could have etag mismatches.
  baseVersion = (isNew ? 0 : version);
      
  ex = [self saveComponent: calendar
               baseVersion: baseVersion];
      
  return ex;
}

//
// If we see "X-SOGo: NoGroupsDecomposition" in the HTTP headers, we
// simply invoke super's PUTAction.
//
// We also check if we must force transparency on all day events
// from iPhone clients.
//
- (id) PUTAction: (WOContext *) _ctx
{
  NSException *ex;
  NSString *etag;
  WORequest *rq;
  WOResponse *response;
  iCalCalendar *rqCalendar;
  
  rq = [_ctx request];
  rqCalendar = [iCalCalendar parseSingleFromSource: [rq contentAsString]];

  // We are unable to parse the received calendar, we return right away
  // with a 400 error code.
  if (!rqCalendar)
    {
      return [NSException exceptionWithHTTPStatus: 400
                                           reason: @"Unable to parse event."];
    }
  
  if (![self isNew])
    {
      //
      // We must check for etag changes prior doing anything since an attendee could
      // have changed its participation status and the organizer didn't get the
      // copy and is trying to do a modification to the event.
      //
      ex = [self matchesRequestConditionInContext: context];
      if (ex)
        return ex;
    }
  
  ex = [self updateContentWithCalendar: rqCalendar fromRequest: rq];
  if (ex)
    response = (WOResponse *) ex;
  else
    {
      response = [_ctx response];
      if (isNew)
        [response setStatus: 201 /* Created */];
      else
        [response setStatus: 204 /* No Content */];
      etag = [self davEntityTag];
      if (etag)
        [response setHeader: etag forKey: @"etag"];
    }
      
  return response;
}

- (BOOL) resourceHasAutoAccepted
{
  return _resourceHasAutoAccepted;
}

@end /* SOGoAppointmentObject */
