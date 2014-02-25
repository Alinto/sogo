/*
  Copyright (C) 2007-2013 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalEventChanges.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalRecurrenceCalculator.h>
#import <NGCards/NSCalendarDate+NGCards.h>
#import <SaxObjC/XMLNamespaces.h>

#import <NGCards/NSString+NGCards.h>

#import <SOGo/SOGoConstants.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSObject+DAV.h>
#import <SOGo/SOGoObject.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoGroup.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoWebDAVValue.h>
#import <SOGo/WORequest+SOGo.h>

#import "iCalCalendar+SOGo.h"
#import "iCalEventChanges+SOGo.h"
#import "iCalEntityObject+SOGo.h"
#import "iCalPerson+SOGo.h"
#import "NSArray+Appointments.h"
#import "SOGoAppointmentFolder.h"
#import "SOGoAppointmentOccurence.h"
#import "SOGoCalendarComponent.h"

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
      folder = [[SOGoUser userWithLogin: uid]
                 personalCalendarFolderInContext: context];
      object = [SOGoAppointmentObject objectWithName: nameInContainer
				      inContainer: folder];
      [object setIsNew: YES];
    }

  return object;
}

//
//
//
- (void) _addOrUpdateEvent: (iCalEvent *) theEvent
		    forUID: (NSString *) theUID
		     owner: (NSString *) theOwner
{
  if (![theUID isEqualToString: theOwner])
    {
      SOGoAppointmentObject *attendeeObject;
      NSString *iCalString;

      iCalString = nil;
      attendeeObject = [self _lookupEvent: [theEvent uid] forUID: theUID];
      
      // We must add an occurence to a non-existing event. We have
      // to handle this with care, as in the postCalDAVEventRequestTo:from:
      if ([attendeeObject isNew] && [theEvent recurrenceId])
	{
	  iCalEvent *ownerEvent;
	  iCalPerson *person;
	  SOGoUser *user;

	  // We check if the attendee that was added to a single occurence is
	  // present in the master component. If not, we add it with a participation
	  // status set to "DECLINED".
	  ownerEvent = [[[theEvent parent] events] objectAtIndex: 0];
	  user = [SOGoUser userWithLogin: theUID];
	  if (![ownerEvent userAsAttendee: user])
	    {
	      // Update the master event in the owner's calendar with the
	      // status of the new attendee set as "DECLINED".
              person = [iCalPerson elementWithTag: @"attendee"];
              [person setCn: [user cn]];
              [person setEmail: [[user allEmails] objectAtIndex: 0]];
              [person setParticipationStatus: iCalPersonPartStatDeclined];
              [person setRsvp: @"TRUE"];
              [person setRole: @"REQ-PARTICIPANT"];
	      [ownerEvent addToAttendees: person];

              iCalString = [[ownerEvent parent] versitString];
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
      if (iCalString)
        [attendeeObject saveContentString: iCalString];
    }
}

//
//
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
      NSString *calendarContent;
      NSArray *occurences;
      int max, count;
      
      // Invitations are always written to the personal folder; it's not necessay
      // to look into all folders of the user
      folder = [[SOGoUser userWithLogin: theUID]
                 personalCalendarFolderInContext: context];
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
      currentUID = [currentAttendee uid];
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
        [self errorWithFormat:
               @"broken chain: delegate with email '%@' was not found",
              mailTo];
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
      currentUID = [currentAttendee uid];
      if (currentUID)
	[self _addOrUpdateEvent: newEvent
			 forUID: currentUID
			  owner: owner];
    }

  [self sendEMailUsingTemplateNamed: @"Update"
                          forObject: [newEvent itipEntryWithMethod: @"request"]
                     previousObject: oldEvent
                        toAttendees: updateAttendees
                           withType: @"calendar:invitation-update"];
}

//
// This methods scans the list of attendees. If they are
// considered as resource, it checks for conflicting
// dates for the event.
//
// We check for between startDate + 1 second and
// endDate - 1 second
//
//
// It also CHANGES the participation status of resources
// depending on constraints defined on them.
//
// Note that it doesn't matter if it changes the participation
// status since in case of an error, nothing will get saved.
//
- (NSException *) _handleResourcesConflicts: (NSArray *) theAttendees
                                   forEvent: (iCalEvent *) theEvent
{
  iCalPerson *currentAttendee;
  NSMutableArray *attendees;
  NSEnumerator *enumerator;
  NSString *currentUID;
  SOGoUser *user, *currentUser, *ownerUser;

  // Build a list of the attendees uids
  attendees = [NSMutableArray arrayWithCapacity: [theAttendees count]];
  enumerator = [theAttendees objectEnumerator];
  while ((currentAttendee = [enumerator nextObject]))
    {
      currentUID = [currentAttendee uid];
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
      ownerUser = [SOGoUser userWithLogin: owner];
      if ([ownerUser isResource])
        {
          [attendees addObject: owner];
        }
    }

  enumerator = [attendees objectEnumerator];
  while ((currentUID = [enumerator nextObject]))
    {
	  user = [SOGoUser userWithLogin: currentUID];
	  
	  if ([user isResource])
	    {
	      SOGoAppointmentFolder *folder;
	      NSCalendarDate *start, *end;
	      NGCalendarDateRange *range;
	      NSMutableArray *fbInfo;
	      NSArray *allOccurences;
  
	      BOOL must_delete;
  	      int i, j;

	      // We get the start/end date for our conflict range. If the event to be added is recurring, we
	      // check for at least a year to start with.
	      start = [[theEvent startDate] dateByAddingYears: 0  months: 0  days: 0  hours: 0  minutes: 0  seconds: 1];
	      end = [[theEvent endDate] dateByAddingYears: ([theEvent isRecurrent] ? 1 : 0)  months: 0  days: 0  hours: 0  minutes: 0  seconds: -1];

	      folder = [user personalCalendarFolderInContext: context];

	      // Deny access to the resource if the ACLs don't allow the user
	      if (![folder aclSQLListingFilter])
	        {
		  NSDictionary *values;
		  NSString *reason;

		  values = [NSDictionary dictionaryWithObjectsAndKeys:
		  		[user cn], @"Cn",
				[user systemEmail], @"SystemEmail"];
		  reason = [values keysWithFormat: [self labelForKey: @"Cannot access resource: \"%{Cn} %{SystemEmail}\""]];
	      	  return [NSException exceptionWithHTTPStatus:403 reason: reason];
	      	}

	      fbInfo = [NSMutableArray arrayWithArray: [folder fetchFreeBusyInfosFrom: start
							       to: end]];

	      // We first remove any occurences in the freebusy that corresponds to the
	      // current event. We do this to avoid raising a conflict if we move a 1 hour
	      // meeting from 12:00-13:00 to 12:15-13:15. We would overlap on ourself otherwise.
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
		  range = [NGCalendarDateRange calendarDateRangeWithStartDate: [[fbInfo objectAtIndex: i] objectForKey: @"startDate"]
								      endDate: [[fbInfo objectAtIndex: i] objectForKey: @"endDate"]];
		  
		  if ([[[fbInfo objectAtIndex: i] objectForKey: @"c_uid"] compare: [theEvent uid]] == NSOrderedSame)
		    {
		      [fbInfo removeObjectAtIndex: i];
		      continue;
		    }
		  
		  // No need to check if the event isn't recurrent here as it's handled correctly
		  // when we compute the "end" date.
		  if ([allOccurences count])
		    {
		      must_delete = YES;

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
              for (i = 0; i < [theAttendees count]; i++)
                {
                  currentAttendee = [theAttendees objectAtIndex: i];
                  if ([[currentAttendee uid] isEqualToString: currentUID])
                    break;
                  else
                    currentAttendee = nil;
                }

              if (currentAttendee)
                {
                  if ([fbInfo count])
                    {
                      // If we always force the auto-accept if numberOfSimultaneousBookings == 0 (ie., no limit
                      // is imposed) or if numberOfSimultaneousBookings is greater than the number of
                      // overlapping events
                      if ([user numberOfSimultaneousBookings] == 0 ||
                          [user numberOfSimultaneousBookings] > [fbInfo count])
                        {
                          [[currentAttendee attributes] removeObjectForKey: @"RSVP"];
                          [currentAttendee setParticipationStatus: iCalPersonPartStatAccepted];
                        }
                      else
                        {
                          iCalCalendar *calendar;
                          NSDictionary *values;
                          NSString *reason;
                          iCalEvent *event;

                          calendar =  [iCalCalendar parseSingleFromSource: [[fbInfo objectAtIndex: 0] objectForKey: @"c_content"]];
                          event = [[calendar events] lastObject];

                          values = [NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSString stringWithFormat: @"%d", [user numberOfSimultaneousBookings]], @"NumberOfSimultaneousBookings",
                                                 [user cn], @"Cn",
                                                 [user systemEmail], @"SystemEmail",
                                          ([event summary] ? [event summary] : @""), @"EventTitle",
                                                       [[fbInfo objectAtIndex: 0] objectForKey: @"startDate"], @"StartDate",
                                                 nil];

                          reason = [values keysWithFormat: [self labelForKey: @"Maximum number of simultaneous bookings (%{NumberOfSimultaneousBookings}) reached for resource \"%{Cn} %{SystemEmail}\". The conflicting event is \"%{EventTitle}\", and starts on %{StartDate}."]];

                          return [NSException exceptionWithHTTPStatus:403
                                                               reason: reason];
                        }
                    }
                  else
                    {
                      // No conflict, we auto-accept. We do this for resources automatically if no
                      // double-booking is observed. If it's not the desired behavior, just don't
                      // set the resource as one!
                      [[currentAttendee attributes] removeObjectForKey: @"RSVP"];
                      [currentAttendee setParticipationStatus: iCalPersonPartStatAccepted];
                    }
                }
            }
    }

  return nil;
}

//
//
//
- (NSException *) _handleAddedUsers: (NSArray *) attendees
		          fromEvent: (iCalEvent *) newEvent
{
  iCalPerson *currentAttendee;
  NSEnumerator *enumerator;
  NSString *currentUID;
  NSException *e;

  // We check for conflicts
  if ((e = [self _handleResourcesConflicts: attendees  forEvent: newEvent]))
    return e;

  enumerator = [attendees objectEnumerator];
  while ((currentAttendee = [enumerator nextObject]))
    {
      currentUID = [currentAttendee uid];
      if (currentUID)
	[self _addOrUpdateEvent: newEvent
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
	for (j = 0; j < [theAttendees count]; j++)
	  if (shouldAdd)
	    [e addToAttendees: [theAttendees objectAtIndex: j]];
	  else
	    [e removeFromAttendees: [theAttendees objectAtIndex: j]];

    }
}
		       
//
//
//
- (NSException *) _handleUpdatedEvent: (iCalEvent *) newEvent
		         fromOldEvent: (iCalEvent *) oldEvent
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

  // We delete the attendees in all exception occurences, if
  // the attendees were removed from the master event.
  [self _addOrDeleteAttendees: deletedAttendees
	inRecurrenceExceptionsForEvent: newEvent
			  add: NO];

  if ([deletedAttendees count])
    {
      [self _handleRemovedUsers: deletedAttendees
               withRecurrenceId: [newEvent recurrenceId]];
      [self sendEMailUsingTemplateNamed: @"Deletion"
                              forObject: [newEvent itipEntryWithMethod: @"cancel"]
                         previousObject: oldEvent
                            toAttendees: deletedAttendees
                               withType: @"calendar:cancellation"];
    }
  
  if ((ex = [self _handleResourcesConflicts: [newEvent attendees]
                                   forEvent: newEvent]))
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
      // notification by email
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
	      currentUID = [currentAttendee uid];
	      if (currentUID)
		[self _addOrUpdateEvent: newEvent
				 forUID: currentUID
				  owner: owner];
	    }
	}
    }

  if ([addedAttendees count])
    {
      // Send an invitation to new attendees
      if ((ex = [self _handleAddedUsers: addedAttendees fromEvent: newEvent]))
	return ex;
      
      [self sendEMailUsingTemplateNamed: @"Invitation"
                              forObject: [newEvent itipEntryWithMethod: @"request"]
                         previousObject: oldEvent
                            toAttendees: addedAttendees
                               withType: @"calendar:invitation"];
    }

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
//       +------------> _handleUpdatedEvent:fromOldEvent: ---> _addOrUpdateEvent:forUID:owner:  <-----------+
//                               |           |                   ^                                          |
//                               v           v                   |                                          |
//  _handleRemovedUsers:withRecurrenceId:  _handleSequenceUpdateInEvent:ignoringAttendees:fromOldEvent:      |
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
      if ((ex = [self _handleAddedUsers: attendees fromEvent: newEvent]))
        return ex;

      if ([attendees count])
	{
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
	  if (oldEvent == nil)
	    // If no occurence found, create one
	    oldEvent = (iCalEvent *)[self newOccurenceWithID: recurrenceTime];
	}

      oldMasterEvent = (iCalEvent *)[[oldEvent parent] firstChildWithTag: [self componentTag]];
      hasOrganizer = [[[oldMasterEvent organizer] email] length];

      if (!hasOrganizer || [oldMasterEvent userIsOrganizer: ownerUser])
	// The owner is the organizer of the event; handle the modifications. We aslo
	// catch conflicts just like when the events are created
	if ((ex = [self _handleUpdatedEvent: newEvent fromOldEvent: oldEvent]))
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
  NSString *iCalString, *recurrenceTime, *delegateEmail;
  NSException *error;
  BOOL addDelegate, removeDelegate;

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
            otherDelegate = NO;

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
		    otherDelegate = NO;
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
  NSString *currentStatus, *organizerUID;
  SOGoUser *ownerUser, *currentUser;
  NSException *ex;

  ex = nil;

  currentStatus = [attendee partStat];

  iCalPerson *otherAttendee, *otherDelegate;
  NSString *delegateEmail;
  BOOL addDelegate, removeDelegate;
  
  otherAttendee = attendee;
  
  delegateEmail = [otherAttendee delegatedTo];
  if ([delegateEmail length])
    delegateEmail = [delegateEmail rfc822Email];
  
  if ([delegateEmail length])
    otherDelegate = [event findAttendeeWithEmail: delegateEmail];
  else
    otherDelegate = nil;
  
  /* We handle the addition/deletion of delegate users */
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
      || [currentStatus caseInsensitiveCompare: newStatus]
      != NSOrderedSame)
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
 
      [attendee setDelegatedTo: [delegate email]];

      if (removeDelegate)
	{
	  delegates = [NSMutableArray array];

	  while (otherDelegate)
	    {
	      [delegates addObject: otherDelegate];

	      delegatedUID = [otherDelegate uid];
	      if (delegatedUID)
		// Delegate attendee is a local user; remove event from his calendar
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
		otherDelegate = NO;
	    }
	  
	  [self sendEMailUsingTemplateNamed: @"Deletion"
				  forObject: [event itipEntryWithMethod: @"cancel"]
			     previousObject: nil
				toAttendees: delegates
                                   withType: @"calendar:cancellation"];
	} // if (removeDelegate)

      if (addDelegate)
	{
	  delegatedUID = [delegate uid];
	  delegates = [NSArray arrayWithObject: delegate];
	  [event addToAttendees: delegate];
	
	  if (delegatedUID)
	    // Delegate attendee is a local user; add event to his calendar
	    [self _addOrUpdateEvent: event
			     forUID: delegatedUID
			      owner: [theOwnerUser login]];

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
	  
	  organizerUID = [[event organizer] uid];

	  // Event is an exception to a recurring event; retrieve organizer from master event
	  if (!organizerUID)
	    organizerUID = [[(iCalEntityObject*)[[event parent] firstChildWithTag: [self componentTag]] organizer] uid];

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
	  uid = [att uid];
          if (uid
	      && att != attendee
	      && ![uid isEqualToString: delegatedUID])
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

- (NSDictionary *) _caldavSuccessCodeWithRecipient: (NSString *) recipient
{
  NSMutableArray *element;
  NSDictionary *code;

  element = [NSMutableArray array];
  [element addObject: davElementWithContent (@"recipient", XMLNS_CALDAV,
					     recipient)];
  [element addObject: davElementWithContent (@"request-status",
					     XMLNS_CALDAV,
					     @"2.0;Success")];
  code = davElementWithContent (@"response", XMLNS_CALDAV,
				element);

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
{
  return [self changeParticipationStatus: status
			    withDelegate: delegate
                         forRecurrenceId: nil];
}

//
//
//
- (NSException *) changeParticipationStatus: (NSString *) _status
                               withDelegate: (iCalPerson *) delegate
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
      
      if (event == nil)
        // If no occurence found, create one
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
          if (delegate
              && ![[delegate email] isEqualToString: [attendee delegatedTo]])
            {
              delegatedUid = [delegate uid];
              if (delegatedUid)
                delegatedUser = [SOGoUser userWithLogin: delegatedUid];
              if (delegatedUser != nil && [event userIsOrganizer: delegatedUser])
                ex = [NSException exceptionWithHTTPStatus: 403
                                                   reason: @"delegate is organizer"];		
              if ([event isAttendee: [[delegate email] rfc822Email]])
                ex = [NSException exceptionWithHTTPStatus: 403
                                                   reason: @"delegate is a participant"];
              else if ([SOGoGroup groupWithEmail: [[delegate email] rfc822Email]
                                        inDomain: [ownerUser domain]])
                ex = [NSException exceptionWithHTTPStatus: 403
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
              if (![context request]
                  || [[context request] handledByDefaultHandler]
                  || [[[context request] requestHandlerKey] isEqualToString: @"Microsoft-Server-ActiveSync"])
                ex = [self saveContentString: [[event parent] versitString]];
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
- (BOOL) _shouldScheduleEvent: (iCalPerson *) theOrganizer
{
  NSString *v;
  BOOL b;
  
  b = YES;

  if (theOrganizer && (v = [theOrganizer value: 0  ofAttribute: @"SCHEDULE-AGENT"]))
    {
      if ([v caseInsensitiveCompare: @"NONE"] == NSOrderedSame ||
	  [v caseInsensitiveCompare: @"CLIENT"] == NSOrderedSame)
	b = NO;
    }

  return b;
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

  if (![self _shouldScheduleEvent: [event organizer]])
    return;

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
                                toAttendees: attendees
                                   withType: @"calendar:cancellation"];
	}
    }
  else if ([occurence userIsAttendee: ownerUser])
    {
      // The current user deletes the occurence; let the organizer know that
      // the user has declined this occurence.
      [self changeParticipationStatus: @"DECLINED" withDelegate: nil
		      forRecurrenceId: recurrenceId];
      send_receipt = NO;
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
	{
	  [event setTransparency: @"TRANSPARENT"];
        }
    }
}

/**
 * Verify vCalendar for any inconsistency or missing attributes.
 * Currently only check if the events have an end date or a duration.
 * @param rq the HTTP PUT request
 */
- (void) _adjustEventsInRequestCalendar: (iCalCalendar *) rqCalendar
{
  NSArray *allEvents;
  iCalEvent *event;
  NSUInteger i;

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
// This method is meant to be the common point of any save operation from web
// and DAV requests, as well as from code making use of SOGo as a library
// (OpenChange)
//
- (NSException *) updateContentWithCalendar: (iCalCalendar *) calendar
                                fromRequest: (WORequest *) rq
{
  NSException *ex;
  NSArray *roles;
  SOGoUser *ownerUser;

  if (calendar == fullCalendar
      || calendar == safeCalendar
      || calendar == originalCalendar)
    [NSException raise: NSInvalidArgumentException
                format: @"the 'calendar' argument must be a distinct instance"
                 @" from the original object"];

  ownerUser = [SOGoUser userWithLogin: owner];

  roles = [[context activeUser] rolesForObject: self
                                     inContext: context];
  //
  // We check if we gave only the "Respond To" right and someone is actually
  // responding to one of our invitation. In this case, _setupResponseCalendarInRequest
  // will only take the new attendee status and actually discard any other modifications.
  //
  if ([roles containsObject: @"ComponentResponder"]
      && ![roles containsObject: @"ComponentModifier"])
    calendar = [self _setupResponseInRequestCalendar: calendar];
  else
    {
      if (![[rq headersForKey: @"X-SOGo"]
             containsObject: @"NoGroupsDecomposition"])
        [self _decomposeGroupsInRequestCalendar: calendar];

      if ([[ownerUser domainDefaults] iPhoneForceAllDayTransparency]
	  && [rq isIPhone])
	{
	  [self _adjustTransparencyInRequestCalendar: calendar];
	}

      [self _adjustEventsInRequestCalendar: calendar];
    }

  //
  // We first check if it's a new event
  //
  if ([self isNew])
    {
      iCalEvent *event;
      NSArray *attendees;
      NSString *eventUID;
      BOOL scheduling;

      attendees = nil;

      event = [[calendar events] objectAtIndex: 0];
      eventUID = [event uid];
      scheduling = [self _shouldScheduleEvent: [event organizer]];

      // make sure eventUID doesn't conflict with an existing event -  see bug #1853
      // TODO: send out a no-uid-conflict (DAV:href) xml element (rfc4791 section 5.3.2.1)
      if ([container resourceNameForEventUID: eventUID])
        {
	  return [NSException exceptionWithHTTPStatus: 403
					       reason: [NSString stringWithFormat: @"Event UID already in use. (%s)", eventUID]];
        }
     
      //
      // New event and we're the organizer -- send invitation to all attendees
      //
      if (scheduling && [event userIsOrganizer: ownerUser])
	{ 
	  attendees = [event attendeesWithoutUser: ownerUser];
	  if ([attendees count])
	    {
	      if ((ex = [self _handleAddedUsers: attendees fromEvent: event]))
		return ex;
	      else
		{
		  // We might have auto-accepted resources here. If that's the
		  // case, let's regenerate the versitstring and replace the
		  // one from the request.
		  [rq setContent: [[[event parent] versitString] dataUsingEncoding: [rq contentEncoding]]];
		}

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
      else if (scheduling && [event userIsAttendee: ownerUser])
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
	  NSString *uid;
          
          // newEvent might be nil here, if we're deleting a RECURRENCE-ID with attendees
          // If that's the case, we use the oldEvent for now just to obtain the organizer
          // and we'll swap it back to nil once we're done.
          if (!newEvent)
            newEvent = oldEvent;

	  // We fetch the organizer's uid. Sometimes, the recurrence-id will
	  // have it, sometimes not. If it doesn't, we fetch it from the master event.
	  uid = [[newEvent organizer] uid];
	  
	  if (!uid && !recurrenceId)
	    uid = [[[[[newEvent parent] events] objectAtIndex: 0] organizer] uid];
	  	  
	  // With Thunderbird 10, if you create a recurring event with an exception
	  // occurence, and invite someone, the PUT will have the organizer in the
	  // recurrence-id and not in the master event. We must fix this, otherwise
	  // SOGo will break.
	  if (!recurrenceId && ![[[[[newEvent parent] events] objectAtIndex: 0] organizer] uid])
	    [[[[newEvent parent] events] objectAtIndex: 0]
	      setOrganizer: [newEvent organizer]];

          if (newEvent == oldEvent)
            newEvent = nil;

	  if (uid && [uid caseInsensitiveCompare: owner] == NSOrderedSame)
	    {
              // A RECCURENCE-ID was removed
              if (!newEvent && oldEvent)
                [self prepareDeleteOccurence: oldEvent];
              // The master event was changed, A RECCURENCE-ID was added or modified
              else if ((ex = [self _handleUpdatedEvent: newEvent  fromOldEvent: oldEvent]))
		return ex;
	    }
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
	      
	      attendee = [newEvent userAsAttendee: [SOGoUser userWithLogin: owner]];

	      // We first check of the sequences are alright. We don't accept attendees
	      // accepting "old" invitations. If that's the case, we return a 403
              if ([[newEvent sequence] intValue] < [[oldEvent sequence] intValue])
		return [NSException exceptionWithHTTPStatus:403
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
			forRecurrenceId: [self _addedExDate: oldEvent  newEvent: newEvent]];
		}
	      else if (attendee)
		{
		  [self changeParticipationStatus: [attendee partStat]
				     withDelegate: delegate
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

  ex = [self saveContentString: [calendar versitString]
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

@end /* SOGoAppointmentObject */
