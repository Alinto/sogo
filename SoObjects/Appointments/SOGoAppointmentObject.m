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

#import "SOGoAppointmentObject.h"

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalEventChanges.h>
#import <NGCards/iCalPerson.h>

#import <SOGo/AgenorUserManager.h>
#import <SOGo/SOGoObject.h>
#import <SOGo/SOGoPermissions.h>

#import "iCalEntityObject+Agenor.h"

#import "common.h"

#import "NSArray+Appointments.h"

@implementation SOGoAppointmentObject

- (NSString *) componentTag
{
  return @"vevent";
}

/* iCal handling */
- (NSArray *) attendeeUIDsFromAppointment: (iCalEvent *) _apt
{
  AgenorUserManager *um;
  NSMutableArray *uids;
  NSArray *attendees;
  unsigned i, count;
  NSString *email, *uid;
  
  if (![_apt isNotNull])
    return nil;
  
  if ((attendees = [_apt attendees]) == nil)
    return nil;
  count = [attendees count];
  uids = [NSMutableArray arrayWithCapacity:count + 1];
  
  um = [AgenorUserManager sharedUserManager];
  
  /* add organizer */
  
  email = [[_apt organizer] rfc822Email];
  if ([email isNotNull]) {
    uid = [um getUIDForEmail:email];
    if ([uid isNotNull]) {
      [uids addObject:uid];
    }
    else
      [self logWithFormat:@"Note: got no uid for organizer: '%@'", email];
  }

  /* add attendees */
  
  for (i = 0; i < count; i++)
    {
      iCalPerson *person;
    
      person = [attendees objectAtIndex:i];
      email  = [person rfc822Email];
      if (![email isNotNull]) continue;
    
      uid = [um getUIDForEmail:email];
      if (![uid isNotNull]) {
        [self logWithFormat:@"Note: got no uid for email: '%@'", email];
        continue;
      }
      if (![uids containsObject:uid])
        [uids addObject:uid];
    }

  return uids;
}

/* folder management */

- (id)lookupHomeFolderForUID:(NSString *)_uid inContext:(id)_ctx {
  // TODO: what does this do? lookup the home of the organizer?
  return [[self container] lookupHomeFolderForUID:_uid inContext:_ctx];
}
- (NSArray *)lookupCalendarFoldersForUIDs:(NSArray *)_uids inContext:(id)_ctx {
  return [[self container] lookupCalendarFoldersForUIDs:_uids inContext:_ctx];
}

/* store in all the other folders */

- (NSException *)saveContentString:(NSString *)_iCal inUIDs:(NSArray *)_uids {
  NSEnumerator *e;
  id folder;
  NSException *allErrors = nil;
  id ctx;

  ctx = [[WOApplication application] context];
  
  e = [[self lookupCalendarFoldersForUIDs:_uids inContext:ctx]
	     objectEnumerator];
  while ((folder = [e nextObject]) != nil) {
    NSException           *error;
    SOGoAppointmentObject *apt;
    
    if (![folder isNotNull]) /* no folder was found for given UID */
      continue;

    apt = [folder lookupName: [self nameInContainer] inContext:ctx
		  acquire: NO];
    if ([apt isKindOfClass: [NSException class]])
      {
        [self logWithFormat:@"Note: an exception occured finding '%@' in folder: %@",
	      [self nameInContainer], folder];
        [self logWithFormat:@"the exception reason was: %@",
              [(NSException *) apt reason]];
        continue;
      }

    if (![apt isNotNull]) {
      [self logWithFormat:@"Note: did not find '%@' in folder: %@",
	      [self nameInContainer], folder];
      continue;
    }
    if ([apt isKindOfClass: [NSException class]]) {
      [self logWithFormat:@"Exception: %@", [(NSException *) apt reason]];
      continue;
    }
    
    if ((error = [apt primarySaveContentString:_iCal]) != nil) {
      [self logWithFormat:@"Note: failed to save iCal in folder: %@", folder];
      // TODO: make compound
      allErrors = error;
    }
  }

  return allErrors;
}

- (NSException *)deleteInUIDs:(NSArray *)_uids {
  NSEnumerator *e;
  id folder;
  NSException *allErrors = nil;
  id ctx;
  
  ctx = [[WOApplication application] context];
  
  e = [[self lookupCalendarFoldersForUIDs:_uids inContext:ctx]
	     objectEnumerator];
  while ((folder = [e nextObject])) {
    NSException           *error;
    SOGoAppointmentObject *apt;
    
    apt = [folder lookupName:[self nameInContainer] inContext:ctx
		  acquire:NO];
    if ([apt isKindOfClass: [NSException class]]) {
      [self logWithFormat: @"%@", [(NSException *) apt reason]];
      continue;
    }
    
    if ((error = [apt primaryDelete]) != nil) {
      [self logWithFormat:@"Note: failed to delete in folder: %@", folder];
      // TODO: make compound
      allErrors = error;
    }
  }
  return allErrors;
}

/* "iCal multifolder saves" */

- (NSException *) saveContentString: (NSString *) _iCal
                       baseSequence: (int) _v
{
  /* 
     Note: we need to delete in all participants folders and send iMIP messages
           for all external accounts.
     
     Steps:
     - fetch stored content
     - parse old content
     - check if sequence matches (or if 0=ignore)
     - extract old attendee list + organizer (make unique)
     - parse new content (ensure that sequence is increased!)
     - extract new attendee list + organizer (make unique)
     - make a diff => new, same, removed
     - write to new, same
     - delete in removed folders
     - send iMIP mail for all folders not found
  */
  AgenorUserManager *um;
  iCalCalendar *newCalendar;
  iCalEvent *oldApt, *newApt;
  iCalEventChanges *changes;
  iCalPerson *organizer;
  NSString *oldContent, *uid;
  NSArray *uids, *props;
  NSMutableArray *attendees, *storeUIDs, *removedUIDs;
  NSException *storeError, *delError;
  BOOL updateForcesReconsider;
  
  updateForcesReconsider = NO;

  if ([_iCal length] == 0) {
    return [NSException exceptionWithHTTPStatus:400 /* Bad Request */
			reason:@"got no iCalendar content to store!"];
  }

  um = [AgenorUserManager sharedUserManager];

  /* handle old content */
  
  oldContent = [self contentAsString]; /* if nil, this is a new appointment */
  if ([oldContent length] == 0)
    {
    /* new appointment */
      [self debugWithFormat:@"saving new appointment: %@", _iCal];
      oldApt = nil;
    }
  else
    oldApt = (iCalEvent *) [self component];
  
  /* compare sequence if requested */

  if (_v != 0) {
    // TODO
  }
  
  
  /* handle new content */
  
  newCalendar = [iCalCalendar parseSingleFromSource: _iCal];
  newApt = (iCalEvent *) [newCalendar firstChildWithTag: [self componentTag]];
  if (newApt == nil) {
    return [NSException exceptionWithHTTPStatus:400 /* Bad Request */
			reason:@"could not parse iCalendar content!"];
  }
  
  /* diff */
  
  changes = [iCalEventChanges changesFromEvent: oldApt
                              toEvent: newApt];

  uids = [um getUIDsForICalPersons:[changes deletedAttendees]
                    applyStrictMapping:NO];
  removedUIDs = [NSMutableArray arrayWithArray:uids];

  uids = [um getUIDsForICalPersons:[newApt attendees]
                    applyStrictMapping:NO];
  storeUIDs = [NSMutableArray arrayWithArray:uids];
  props = [changes updatedProperties];

  /* detect whether sequence has to be increased */
  if ([changes hasChanges])
    [newApt increaseSequence];

  /* preserve organizer */

  organizer = [newApt organizer];
  uid = [um getUIDForICalPerson:organizer];
  if (uid) {
    if (![storeUIDs containsObject:uid])
      [storeUIDs addObject:uid];
    [removedUIDs removeObject:uid];
  }

  /* organizer might have changed completely */

  if (oldApt && ([props containsObject: @"organizer"])) {
    uid = [um getUIDForICalPerson:[oldApt organizer]];
    if (uid) {
      if (![storeUIDs containsObject:uid]) {
        if (![removedUIDs containsObject:uid]) {
          [removedUIDs addObject:uid];
        }
      }
    }
  }

  [self debugWithFormat:@"UID ops:\n  store: %@\n  remove: %@",
                        storeUIDs, removedUIDs];

  /* if time did change, all participants have to re-decide ...
   * ... exception from that rule: the organizer
   */

  if (oldApt != nil &&
      ([props containsObject:@"startDate"] ||
       [props containsObject:@"endDate"]   ||
       [props containsObject:@"duration"]))
  {
    NSArray  *ps;
    unsigned i, count;
    
    ps    = [newApt attendees];
    count = [ps count];
    for (i = 0; i < count; i++) {
      iCalPerson *p;
      
      p = [ps objectAtIndex:i];
      if (![p hasSameEmailAddress:organizer])
        [p setParticipationStatus:iCalPersonPartStatNeedsAction];
    }
    _iCal = [[newApt parent] versitString];
    updateForcesReconsider = YES;
  }

  /* perform storing */

  storeError = [self saveContentString:_iCal inUIDs:storeUIDs];
  delError = [self deleteInUIDs:removedUIDs];

  // TODO: make compound
  if (storeError != nil) return storeError;
  if (delError   != nil) return delError;

  /* email notifications */
  if ([self sendEMailNotifications])
    {
      attendees = [NSMutableArray arrayWithArray: [changes insertedAttendees]];
      [attendees removePerson: organizer];
      [self sendEMailUsingTemplateNamed: @"Invitation"
            forOldObject: nil
            andNewObject: newApt
            toAttendees: attendees];

      if (updateForcesReconsider) {
        attendees = [NSMutableArray arrayWithArray:[newApt attendees]];
        [attendees removeObjectsInArray:[changes insertedAttendees]];
        [attendees removePerson:organizer];
        [self sendEMailUsingTemplateNamed: @"Update"
              forOldObject: oldApt
              andNewObject: newApt
              toAttendees: attendees];
      }

      attendees = [NSMutableArray arrayWithArray:[changes deletedAttendees]];
      [attendees removePerson: organizer];
      if ([attendees count])
        {
          iCalEvent *canceledApt;
    
          canceledApt = [newApt copy];
          [(iCalCalendar *) [canceledApt parent] setMethod: @"cancel"];
          [self sendEMailUsingTemplateNamed: @"Removal"
                forOldObject: nil
                andNewObject: canceledApt
                toAttendees: attendees];
          [canceledApt release];
        }
    }

  return nil;
}

- (NSException *)deleteWithBaseSequence:(int)_v {
  /* 
     Note: We need to delete in all participants folders and send iMIP messages
           for all external accounts.
	   Delete is basically identical to save with all attendees and the
	   organizer being deleted.

     Steps:
     - fetch stored content
     - parse old content
     - check if sequence matches (or if 0=ignore)
     - extract old attendee list + organizer (make unique)
     - delete in removed folders
     - send iMIP mail for all folders not found
  */
  iCalEvent *apt;
  NSArray *removedUIDs;
  NSMutableArray *attendees;

  /* load existing content */

  apt = (iCalEvent *) [self component];
  
  /* compare sequence if requested */

//   if (_v != 0) {
//     // TODO
//   }
  
  removedUIDs = [self attendeeUIDsFromAppointment:apt];

  if ([self sendEMailNotifications])
    {
      /* send notification email to attendees excluding organizer */
      attendees = [NSMutableArray arrayWithArray:[apt attendees]];
      [attendees removePerson:[apt organizer]];
  
      /* flag appointment as being canceled */
      [(iCalCalendar *) [apt parent] setMethod: @"cancel"];
      [apt increaseSequence];

      /* remove all attendees to signal complete removal */
      [apt removeAllAttendees];

      /* send notification email */
      [self sendEMailUsingTemplateNamed: @"Deletion"
            forOldObject: nil
            andNewObject: apt
            toAttendees: attendees];
    }

  /* perform */

  return [self deleteInUIDs:removedUIDs];
}

- (NSException *) saveContentString: (NSString *) _iCalString
{
  return [self saveContentString: _iCalString baseSequence: 0];
}

- (NSException *) changeParticipationStatus: (NSString *) _status
                                  inContext: (id) _ctx
{
  iCalEvent *apt;
  iCalPerson *p;
  NSString *newContent;
  NSException *ex;
  NSString *myEMail;
  
  ex = nil;

  // TODO: do we need to use SOGoAppointment? (prefer iCalEvent?)
  apt = (iCalEvent *) [self component];

  if (apt)
    {
      myEMail = [[_ctx activeUser] email];
      p = [apt findParticipantWithEmail: myEMail];
      if (p)
        {
  // TODO: send iMIP reply mails?
  
          [p setPartStat:_status];
          newContent = [[apt parent] versitString];
          if (newContent)
            {
              ex = [self saveContentString:newContent];
              if (ex)
                // TODO: why is the exception wrapped?
                /* Server Error */
                ex = [NSException exceptionWithHTTPStatus: 500
                                  reason: [ex reason]];
            }
          else
            ex
              = [NSException exceptionWithHTTPStatus: 500 /* Server Error */
                             reason: @"Could not generate iCalendar data ..."];
        }
      else
        ex = [NSException exceptionWithHTTPStatus: 404 /* Not Found */
                          reason: @"user does not participate in this "
                          @"appointment"];
    }
  else
    ex = [NSException exceptionWithHTTPStatus:500 /* Server Error */
                      reason:@"unable to parse appointment record"];

  return ex;
}


/* message type */

- (NSString *) outlookMessageClass
{
  return @"IPM.Appointment";
}

- (NSException *) saveContentString: (NSString *) contentString
                        baseVersion: (unsigned int) baseVersion
{
  NSString *newContentString, *oldContentString;
  iCalCalendar *eventCalendar;
  iCalEvent *event;
  NSArray *organizers;

  oldContentString = [self contentAsString];
  if (oldContentString)
    newContentString = contentString;
  else
    {
      eventCalendar = [iCalCalendar parseSingleFromSource: contentString];
      event = (iCalEvent *) [eventCalendar firstChildWithTag: [self componentTag]];
      organizers = [event childrenWithTag: @"organizer"];
      if ([organizers count])
        newContentString = contentString;
      else
        {
          [event setOrganizerWithUid: [[self container] ownerInContext: nil]];
          newContentString = [eventCalendar versitString];
        }
    }

  return [super saveContentString: newContentString
                baseVersion: baseVersion];
}

@end /* SOGoAppointmentObject */
