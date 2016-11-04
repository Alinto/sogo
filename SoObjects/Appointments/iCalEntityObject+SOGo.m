/* iCalEntityObject+SOGo.m - this file is part of SOGo
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
#import <Foundation/NSTimeZone.h>

#import <GDLContentStore/GCSAlarmsFolder.h>
#import <GDLContentStore/GCSFolderManager.h>

#import <NGCards/iCalTrigger.h>
#import <NGCards/iCalRepeatableEntityObject.h>
#import <NGCards/NSString+NGCards.h>

#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import "SOGoAppointmentFolder.h"

#import <NGObjWeb/WOContext+SoObjects.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoSource.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserManager.h>

#import "iCalPerson+SOGo.h"
#import "iCalAlarm+SOGo.h"
#import "iCalCalendar+SOGo.h"
#import "iCalEntityObject+SOGo.h"

NSCalendarDate *iCalDistantFuture = nil;
NSNumber *iCalDistantFutureNumber = nil;

@implementation iCalEntityObject (SOGoExtensions)

+ (void) initializeSOGoExtensions
{
  if (!iCalDistantFuture)
    {
      iCalDistantFuture = [[NSCalendarDate distantFuture] retain];
      /* INT_MAX due to Postgres constraint */
      iCalDistantFutureNumber = [[NSNumber numberWithUnsignedInt: INT_MAX] retain];
    }
}

/**
 * @see [UIxAppointmentEditor viewAction]
 * @see [UIxTaskEditor viewAction]
 */
- (NSDictionary *) attributesInContext: (WOContext *) context
{
  NSArray *elements;
  NSMutableArray *attendees;
  NSDictionary *contactData;
  NSMutableDictionary *data, *organizerData, *attendeeData;
  NSEnumerator *attendeesList;
  NSString *uid, *domain, *sentBy;
  NSObject <SOGoSource> *source;
  SOGoUserManager *um;
  iCalPerson *organizer, *currentAttendee;
  id value;

  um = [SOGoUserManager sharedUserManager];

  data = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                [[self tag] lowercaseString], @"component",
                              [self summary], @"summary",
                              nil];

  value = [self priority];
  if ([value length]) [data setObject: [NSNumber numberWithInteger: [value intValue]] forKey: @"priority"];

  value = [self location];
  if ([value length]) [data setObject: value forKey: @"location"];

  value = [self comment];
  if ([value length]) [data setObject: value forKey: @"comment"];

  value = [self accessClass];
  if ([value length]) [data setObject: [value lowercaseString] forKey: @"classification"];

  value = [self status];
  if ([value length]) [data setObject: [value lowercaseString] forKey: @"status"];

  value = [self createdBy];
  if (value) [data setObject: value forKey: @"createdBy"];

  // Categories
  elements = [self categories];
  if ([elements count])
    [data setObject: elements forKey: @"categories"];

  // Send appointment notifications when the custom tag is *not* set
  value = [self firstChildWithTag: @"X-SOGo-Send-Appointment-Notifications"];
  [data setObject: [NSNumber numberWithBool: (value? 0:1)] forKey: @"sendAppointmentNotifications"];

  // Organizer
  organizer = [self organizer];
  if ([[organizer email] length])
    {
      organizerData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             [organizer rfc822Email], @"email",
                                           ([[organizer cnWithoutQuotes] length] ? [organizer cnWithoutQuotes] : [organizer rfc822Email]), @"name",
                                           nil];
      uid = [organizer uid];
      if ([uid length]) [organizerData setObject: uid forKey: @"uid"];
      sentBy = [organizer sentBy];
      if ([sentBy length]) [organizerData setObject: sentBy forKey: @"sentBy"];
      [data setObject: organizerData forKey: @"organizer"];
    }

  // Attendees
  attendees = [NSMutableArray array];
  attendeesList = [[self attendees] objectEnumerator];
  while ((currentAttendee = [attendeesList nextObject]))
    {
      attendeeData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                            [currentAttendee rfc822Email], @"email",
                                          ([[currentAttendee cnWithoutQuotes] length] ? [currentAttendee cnWithoutQuotes] : [currentAttendee rfc822Email]) , @"name",
                                          nil];
      if ((uid = [currentAttendee uid]))
        {
          [attendeeData setObject: uid forKey: @"uid"];
        }
      else
        {
          // Search for attendee in global contacts sources that are associated with a MS Exchange server
          domain = [[context activeUser] domain];
          elements = [um fetchContactsMatching: [currentAttendee rfc822Email] inDomain: domain];
          if ([elements count] == 1)
            {
              contactData = [elements lastObject];
              source = [contactData objectForKey: @"source"];
              if ([source conformsToProtocol: @protocol (SOGoDNSource)] &&
                  [[(NSObject <SOGoDNSource>*) source MSExchangeHostname] length])
                {
                  uid = [NSString stringWithFormat: @"%@:%@", [[context activeUser] login],
                          [contactData valueForKey: @"c_uid"]];
                  [attendeeData setObject: uid forKey: @"uid"];
                }
            }
        }
      [attendeeData setObject: [[currentAttendee partStat] lowercaseString] forKey: @"partstat"];
      [attendeeData setObject: [[currentAttendee role] lowercaseString] forKey: @"role"];
      if ([[currentAttendee delegatedTo] length])
	[attendeeData setObject: [[currentAttendee delegatedTo] rfc822Email] forKey: @"delegatedTo"];
      if ([[currentAttendee delegatedFrom] length])
	[attendeeData setObject: [[currentAttendee delegatedFrom] rfc822Email] forKey: @"delegatedFrom"];

      [attendees addObject: attendeeData];
    }
  if ([attendees count])
    [data setObject: attendees forKey: @"attendees"];

  return data;
}

// From [UIxTimeDatePicker takeValuesFromRequest:inContext:]
- (void) adjustDate: (NSCalendarDate **) date
     withTimeString: (NSString *) timeString
          inContext: (WOContext *) context
{
  unsigned _year, _month, _day, _hour, _minute;
  SOGoUserDefaults *ud;
  NSArray *_time;

  _year = [*date yearOfCommonEra];
  _month  = [*date monthOfYear];
  _day    = [*date dayOfMonth];
  _time = [timeString componentsSeparatedByString: @":"];
  _hour = [[_time objectAtIndex: 0] intValue];
  _minute = [[_time objectAtIndex: 1] intValue];

  ud = [[context activeUser] userDefaults];
  *date = [NSCalendarDate dateWithYear: _year month: _month day: _day
                                 hour: _hour minute: _minute second: 0
                             timeZone: [ud timeZone]];
}

- (void) _setAttendees: (NSArray *) attendees
{
  NSMutableArray *newAttendees;
  NSUInteger count, max;
  NSString *currentEmail;
  iCalPerson *currentAttendee;
  NSString *role, *partstat;
  NSDictionary *currentData;

  if (attendees)
    {
      newAttendees = [NSMutableArray array];
      max = [attendees count];
      for (count = 0; count < max; count++)
        {
          currentData = [attendees objectAtIndex: count];
          currentEmail = [currentData objectForKey: @"email"];
          if ([currentEmail length] > 0)
            {
              role = [[currentData objectForKey: @"role"] uppercaseString];
              if (!role)
                role = @"REQ-PARTICIPANT";
              if ([role isEqualToString: @"NON-PARTICIPANT"])
                partstat = @"";
              else
                {
                  partstat = [[currentData objectForKey: @"partstat"] uppercaseString];
                  if (!partstat)
                    partstat = @"NEEDS-ACTION";
                }
              currentAttendee = [self findAttendeeWithEmail: currentEmail];
              if (!currentAttendee)
                {
                  currentAttendee = [iCalPerson elementWithTag: @"attendee"];
                  [currentAttendee setCn: [currentData objectForKey: @"name"]];
                  [currentAttendee setEmail: currentEmail];
                }
              if (!currentAttendee || ![[currentAttendee role] isEqualToString: role])
                // Set the RSVP only if this is a new attendee or the role has changed
                [currentAttendee
                    setRsvp: ([role isEqualToString: @"NON-PARTICIPANT"]
                              ? @"FALSE"
                              : @"TRUE")];
              [currentAttendee setRole: role];
              [currentAttendee setPartStat: partstat];
              [newAttendees addObject: currentAttendee];
            }
        }
      [self setAttendees: newAttendees];
    }
}

- (void) _appendAttendeesToEmailAlarm: (iCalAlarm *) alarm
{
  NSArray *attendees;
  NSMutableArray *aAttendees;
  int count, max;
  iCalPerson *currentAttendee, *aAttendee;

  attendees = [self attendees];
  max = [attendees count];
  aAttendees = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      currentAttendee = [attendees objectAtIndex: count];
      aAttendee = [iCalPerson elementWithTag: @"attendee"];
      [aAttendee setCn: [currentAttendee cn]];
      [aAttendee setEmail: [currentAttendee rfc822Email]];
      [aAttendees addObject: aAttendee];
    }
  [alarm setAttendees: aAttendees];
}

- (void) _setAlarm: (NSDictionary *) alarm
          forOwner: (NSString *) owner
{
  iCalAlarm *anAlarm;
  NSString *reminderAction, *reminderUnit, *reminderQuantity, *reminderReference, *reminderRelation;
  BOOL reminderEmailAttendees, reminderEmailOrganizer;

  reminderAction = [alarm objectForKey: @"action"];
  reminderUnit = [alarm objectForKey: @"unit"];
  reminderQuantity = [alarm objectForKey: @"quantity"];
  reminderReference = [alarm objectForKey: @"reference"];
  reminderRelation = [alarm objectForKey: @"relation"];
  reminderEmailAttendees = [[alarm objectForKey: @"attendees"] boolValue];
  reminderEmailOrganizer = [[alarm objectForKey: @"organizer"] boolValue];
  anAlarm = [iCalAlarm alarmForEvent: self
                               owner: owner
                              action: reminderAction
                                unit: reminderUnit
                            quantity: reminderQuantity
                           reference: reminderReference
                    reminderRelation: reminderRelation
                      emailAttendees: reminderEmailAttendees
                      emailOrganizer: reminderEmailOrganizer];

  // If there was an unsupported alarm defined in the event, it will be deleted.
  [self removeAllAlarms];
  if (anAlarm)
    {
      [self addToAlarms: anAlarm];
    }
}

/**
 * @see [UIxAppointmentEditor saveAction]
 */
- (void) setAttributes: (NSDictionary *) data
             inContext: (WOContext *) context
{
  NSString *owner;
  id o, sendAppointmentNotifications;

  o = [data objectForKey: @"summary"];
  if ([o isKindOfClass: [NSString class]])
    [self setSummary: o];

  o = [data objectForKey: @"priority"];
  if ([o isKindOfClass: [NSNumber class]])
    [self setPriority: [NSString stringWithFormat: @"%d", [o intValue]]];

  o = [data objectForKey: @"location"];
  if ([o isKindOfClass: [NSString class]])
    [self setLocation: o];

  o = [data objectForKey: @"comment"];
  if ([o isKindOfClass: [NSString class]])
    [self setComment: [o stringByReplacingString: @"\r\n" withString: @"\n"]];

  o = [data objectForKey: @"classification"];
  if ([o isKindOfClass: [NSString class]])
    [self setAccessClass: [o uppercaseString]];

  o = [data objectForKey: @"status"];
  if ([o isKindOfClass: [NSString class]])
    [self setStatus: [o uppercaseString]];

  o = [data objectForKey: @"categories"];
  if ([o isKindOfClass: [NSArray class]])
    [self setCategories: o];

  o = [data objectForKey: @"sendAppointmentNotifications"];
  if ([o isKindOfClass: [NSNumber class]])
    {
      sendAppointmentNotifications = [self firstChildWithTag: @"X-SOGo-Send-Appointment-Notifications"];
      if (!sendAppointmentNotifications && ![o boolValue])
        [self addChild: [CardElement simpleElementWithTag: @"X-SOGo-Send-Appointment-Notifications" value: @"NO"]];
      else if (sendAppointmentNotifications && [o boolValue])
        [self removeChild: sendAppointmentNotifications];
    }

  o = [data objectForKey: @"attendees"];
  if ([o isKindOfClass: [NSArray class]])
    [self _setAttendees: o];

  o = [data objectForKey: @"alarm"];
  if ([o isKindOfClass: [NSDictionary class]])
    {
      owner = [data objectForKey: @"owner"];
      [self _setAlarm: o forOwner: owner];
    }

  // Other attributes depend on the client object and therefore are set in [UIxComponentEditor setAttributes:]:
  // - organizer & "created-by"
  // - timestamps (creation/modification)
}

- (BOOL) userIsAttendee: (SOGoUser *) user
{
  NSEnumerator *attendees;
  iCalPerson *currentAttendee;
  BOOL isAttendee;

  isAttendee = NO;

  attendees = [[self attendees] objectEnumerator];
  currentAttendee = [attendees nextObject];
  while (!isAttendee
	 && currentAttendee)
    if ([user hasEmail: [currentAttendee rfc822Email]])
      isAttendee = YES;
    else
      currentAttendee = [attendees nextObject];

  return isAttendee;
}

- (iCalPerson *) userAsAttendee: (SOGoUser *) user
{
  iCalPerson *currentAttendee, *userAttendee;
  NSEnumerator *attendees;

  userAttendee = nil;

  attendees = [[self attendees] objectEnumerator];
  while (!userAttendee
	 && (currentAttendee = [attendees nextObject]))
    if ([user hasEmail: [currentAttendee rfc822Email]])
      userAttendee = currentAttendee;

  return userAttendee;
}

- (iCalPerson *) participantForUser:  (SOGoUser *) theUser
                           attendee: (iCalPerson *) theAttendee
{
  iCalPerson *currentAttendee;
  NSEnumerator *attendees;
  NSMutableArray *a;

  a = [NSMutableArray array];

  attendees = [[self attendees] objectEnumerator];
  while ((currentAttendee = [attendees nextObject]))
    if ([theUser hasEmail: [currentAttendee rfc822Email]])
      {
        // If the attendee is the same but the partStat is
        // different, we prioritize this one.
        if ([[currentAttendee rfc822Email] caseInsensitiveCompare: [theAttendee rfc822Email]] == NSOrderedSame &&
            [[currentAttendee partStat] caseInsensitiveCompare: [theAttendee partStat]] != NSOrderedSame)
          [a insertObject: currentAttendee  atIndex: 0];
        else if ([[currentAttendee rfc822Email] caseInsensitiveCompare: [theAttendee rfc822Email]] != NSOrderedSame)
          [a addObject: currentAttendee];
      }

  if ([a count] > 0)
    return [a objectAtIndex: 0];

  return theAttendee;
}

- (BOOL) userIsOrganizer: (SOGoUser *) user
{
  NSString *mail;
  BOOL b;

  mail = [[self organizer] rfc822Email];
  b = [user hasEmail: mail];
  if (b) return YES;

  // We check for the SENT-BY
  mail = [[self organizer] sentBy];

  if ([mail length])
    return [user hasEmail: mail];

  return NO;
}

/*
- (NSArray *) attendeeUIDs
{
  NSEnumerator *attendees;
  NSString *uid;
  iCalPerson *currentAttendee;
  NSMutableArray *uids;

  uids = [NSMutableArray array];

  attendees = [[self attendees] objectEnumerator];
  while ((currentAttendee = [attendees nextObject]))
    {
      uid = [currentAttendee uid];
      if (uid)
	[uids addObject: uid];
    }

  return uids;
}
*/

#warning this method should be implemented in a category of iCalToDo
- (BOOL) isStillRelevant
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (id) itipEntryWithMethod: (NSString *) method
{
  iCalCalendar *newCalendar;
  iCalEntityObject *currentEvent, *newEntry;
  iCalPerson *organizer;

  NSArray *events;
  int i, count;

  newCalendar = [parent mutableCopy];
  [newCalendar autorelease];
  [newCalendar setMethod: method];

  events = [newCalendar childrenWithTag: tag];
  count = [events count];
  if (count > 1)
    {
      // If the event is recurrent, remove all occurences
      organizer = [[(iCalEntityObject *)[newCalendar firstChildWithTag: tag] organizer] mutableCopy];
      for (i = 0; i < count; i++)
	{
	  currentEvent = [events objectAtIndex: i];
	  [[newCalendar children] removeObject: currentEvent];
	}
      newEntry = [[self mutableCopy] autorelease];
      [newEntry setOrganizer: organizer];
      [newCalendar addChild: newEntry];
    }
  else
    newEntry = (iCalEntityObject *) [newCalendar firstChildWithTag: tag];

  return newEntry;
}

- (NSArray *) attendeesWithoutUser: (SOGoUser *) user
{
  NSMutableArray *newAttendees;
  NSArray *oldAttendees;
  unsigned int count, max;
  iCalPerson *currentAttendee;
  NSString *userID, *domain;

  userID = [user login];
  domain = [user domain];
  oldAttendees = [self attendees];
  max = [oldAttendees count];
  newAttendees = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      currentAttendee = [oldAttendees objectAtIndex: count];
      if (![[currentAttendee uidInDomain: domain] isEqualToString: userID])
	[newAttendees addObject: currentAttendee];
    }

  return newAttendees;
}

- (NSNumber *) quickRecordDateAsNumber: (NSCalendarDate *) _date
			    withOffset: (int) offset
			     forAllDay: (BOOL) allDay
{
  NSTimeInterval seconds;
  NSNumber *dateNumber;

  if (_date == iCalDistantFuture)
    dateNumber = iCalDistantFutureNumber;
  else
    {
      seconds = [_date timeIntervalSince1970] + offset;
      if (allDay)
        seconds += [[_date timeZone] secondsFromGMT];

      dateNumber = [NSNumber numberWithInt: seconds];
    }

  return dateNumber;
}

- (NSMutableDictionary *) quickRecordFromContent: (NSString *) theContent
                                       container: (id) theContainer
				 nameInContainer: (NSString *) nameInContainer
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (int) priorityNumber
{
  NSString *prio;
  NSRange r;
  int priorityNumber;

  prio = [self priority];
  if (prio)
    {
      r = [prio rangeOfString: @";"];
      if (r.length)
	prio = [prio substringToIndex:r.location];
      priorityNumber = [prio intValue];
    }
  else
    priorityNumber = 0;

  return priorityNumber;
}

- (NSDictionary *) createdBy
{
  NSString *created_by, *created_by_name, *login;
  NSDictionary *createdByData;
  SOGoUser *user;

  created_by_name = nil;
  createdByData = nil;
  created_by = [[self firstChildWithTag: @"X-SOGo-Component-Created-By"] flattenedValuesForKey: @""];

  if (![created_by length])
    {
      // We consider "SENT-BY" in case our custom header isn't found
      created_by = [[self organizer] sentBy];
    }

  if ([created_by length])
    {
      login = [[SOGoUserManager sharedUserManager] getUIDForEmail: created_by];
      if (login)
        {
          user = [SOGoUser userWithLogin: login];
          if (user)
            created_by_name = [user cn];
        }

      createdByData = [NSDictionary dictionaryWithObjectsAndKeys: created_by, @"email",
                                    created_by_name, @"name",
                                    nil];
    }

  return createdByData;
}

//
// We ignore ACTION:PROCEDURE for now.
//
- (iCalAlarm *) firstSupportedAlarm
{
  iCalAlarm *anAlarm;
  NSArray *alarms;
  int i;

  alarms = [self alarms];

  for (i = 0; i < [alarms count]; i++)
    {
      anAlarm = [[self alarms] objectAtIndex: i];

      if ([[anAlarm action] caseInsensitiveCompare: @"DISPLAY"] == NSOrderedSame ||
          [[anAlarm action] caseInsensitiveCompare: @"AUDIO"] == NSOrderedSame ||
          [[anAlarm action] caseInsensitiveCompare: @"EMAIL"] == NSOrderedSame)
        return anAlarm;
    }

  return nil;
}

- (iCalAlarm *) firstDisplayOrAudioAlarm
{
  iCalAlarm *anAlarm;
  NSArray *alarms;
  int i;

  alarms = [self alarms];

  for (i = 0; i < [alarms count]; i++)
    {
      anAlarm = [[self alarms] objectAtIndex: i];

      if ([[anAlarm action] caseInsensitiveCompare: @"DISPLAY"] == NSOrderedSame ||
          [[anAlarm action] caseInsensitiveCompare: @"AUDIO"] == NSOrderedSame)
        return anAlarm;
    }

  return nil;
}

- (iCalAlarm *) firstEmailAlarm
{
  iCalAlarm *anAlarm;
  NSArray *alarms;
  int i;

  alarms = [self alarms];

  for (i = 0; i < [alarms count]; i++)
    {
      anAlarm = [[self alarms] objectAtIndex: i];

      if ([[anAlarm action] caseInsensitiveCompare: @"EMAIL"] == NSOrderedSame)
        return anAlarm;
    }

  return nil;
}



- (void) updateNextAlarmDateInRow: (NSMutableDictionary *) row
                     forContainer: (id) theContainer
		  nameInContainer: (NSString *) nameInContainer
{
  NSCalendarDate *nextAlarmDate;
  GCSAlarmsFolder *af;
  NSString *path;

  int alarm_number;

  if ([[SOGoSystemDefaults sharedSystemDefaults] enableEMailAlarms])
    {
      af = [[GCSFolderManager defaultFolderManager] alarmsFolder];
      path = [theContainer ocsPath];
    }
  else
    {
      af = nil;
      path = nil;
    }

  nextAlarmDate = nil;
  alarm_number = -1;

  if ([self hasAlarms])
    {
      // We currently have the following limitations for alarms:
      // - only the first alarm is considered;
      // - the alarm's action must be of type DISPLAY;
      //
      // Morever, we don't update the quick table if the property X-WebStatus
      // of the trigger is set to "triggered".
      iCalAlarm *anAlarm;
      NSString *webstatus;

      if (![(id)self isRecurrent])
        {
          anAlarm = [self firstDisplayOrAudioAlarm];
          if ((anAlarm = [self firstDisplayOrAudioAlarm]))
            {
              webstatus = [[anAlarm trigger] value: 0 ofAttribute: @"x-webstatus"];
              if (!webstatus
                  || ([webstatus caseInsensitiveCompare: @"TRIGGERED"]
                      != NSOrderedSame))
                nextAlarmDate = [anAlarm nextAlarmDate];
            }
	  else if ((anAlarm = [self firstEmailAlarm]) && af)
	    {
	      nextAlarmDate = [anAlarm nextAlarmDate];

	      // The email alarm is too old, let's just remove it
	      if ([nextAlarmDate earlierDate: [NSDate date]] == nextAlarmDate)
		nextAlarmDate = nil;
	      else
		{
		  alarm_number = [[self alarms] indexOfObject: anAlarm];

		  [af writeRecordForEntryWithCName: nameInContainer
				  inCalendarAtPath: path
					    forUID: [self uid]
				      recurrenceId: nil
				       alarmNumber: [NSNumber numberWithInt: alarm_number]
				      andAlarmDate: nextAlarmDate];
		}
	    }
        }
      // Recurring event/task
      else
        {
          NSCalendarDate *start, *end;
          NGCalendarDateRange *range;
          NSMutableArray *alarms;

          alarms = [NSMutableArray array];
          start = [NSCalendarDate date];
          end = [start addYear:1 month:0 day:0 hour:0 minute:0 second:0];
          range = [NGCalendarDateRange calendarDateRangeWithStartDate: start
                                                              endDate: end];

          // Always check if container is defined. If not, that means this method
          // call was reentrant.
          if (theContainer)
            {
              NSTimeInterval now;
              int i, v, delta, c_startdate, c_nextalarm;

              //
              // Here is the logic:
              //
              // We flatten the structure. When flattening it (or after), we compute the alarm based on the trigger for every single
              // event part of the recurrence rule. Exceptions can have their own triggers. Then, we start from NOW and move forward,
              // and we look at the closest one. When found one, we pick it and store it in c_nextalarm.
              //
              // When popping up the alarm, we must find for which occurence it is - so we can show the proper start/end time, or even
              // infos from the exception. It gets tricky because the user could have snoozed the alarm. So here is the logic:
              //
              // We flatten the structure and compute the alarms based on triggers. If c_nextalarm is a match, we have have a winner.
              // If we don't have a match, we pick the event for which its trigger is the closest to the c_nextalarm.
              //
              nextAlarmDate = nil;

              [theContainer flattenCycleRecord: (id)row
                                      forRange: range
                                     intoArray: alarms
                                  withCalendar: [self parent]];

              // We pickup the closest one from now. We remove the actual reminder (ie., 15 mins before - plus 1 minute for roundups)
              // so we don't pickup the same alarm over and over. This could happen if our alarm popups and the user clicks on "Cancel".
              // In case of a repetitive event, we want to pickup the next one (next day for example), and not the one that has just
              // popped up.
              now = [start timeIntervalSince1970];
              v = 0;
              for (i = 0; i < [alarms count]; i++)
                {
                  c_startdate = [[[alarms objectAtIndex: i] objectForKey: @"c_startdate"] intValue];
                  c_nextalarm = [[[alarms objectAtIndex: i] objectForKey: @"c_nextalarm"] intValue];
                  delta = (c_startdate - now - (c_startdate - c_nextalarm)) - 60;

                  // If value is not initialized, we grab it right away
                  if (!v && delta > 0)
                    v = delta;

                  // If we found a smaller delta than before, use it.
                  if (v > 0 && delta > 0 && delta <= v)
                    {
                      id o;

                      // Find the relevant component
                      if ([self respondsToSelector: @selector(endDate)])
                        o = [[self parent] eventWithRecurrenceID: [[alarms objectAtIndex: i] objectForKey: @"c_recurrence_id"]];
                      else
                        o = [[self parent] todoWithRecurrenceID: [[alarms objectAtIndex: i] objectForKey: @"c_recurrence_id"]];

                      if (!o)
                        o = self;

                      if ([[o alarms] count])
                        {
			  if ((anAlarm = [self firstDisplayOrAudioAlarm]))
                            {
                              webstatus = [[anAlarm trigger] value: 0 ofAttribute: @"x-webstatus"];
                              if (!webstatus
                                  || ([webstatus caseInsensitiveCompare: @"TRIGGERED"]
                                      != NSOrderedSame))
                                v = delta;
                              nextAlarmDate = [NSDate dateWithTimeIntervalSince1970: [[[alarms objectAtIndex: i] objectForKey: @"c_nextalarm"] intValue]];
                            }
			  else if ((anAlarm = [self firstEmailAlarm]) && af)
			    {
			      nextAlarmDate = [NSDate dateWithTimeIntervalSince1970: [[[alarms objectAtIndex: i] objectForKey: @"c_nextalarm"] intValue]];
			      alarm_number = [[self alarms] indexOfObject: anAlarm];

			      [af writeRecordForEntryWithCName: nameInContainer
					      inCalendarAtPath: path
							forUID: [self uid]
						  recurrenceId: [self recurrenceId]
						   alarmNumber: [NSNumber numberWithInt: alarm_number]
						  andAlarmDate: nextAlarmDate];
			    }
			}
                    }
                } // for ( ... )
            } // if (theContainer)
        }
    }

  // Don't update c_nextalarm in the quick table if it's an email alarm
  if ([nextAlarmDate isNotNull] && alarm_number < 0)
    {
      [row setObject: [NSNumber numberWithInt: [nextAlarmDate timeIntervalSince1970]]
	      forKey: @"c_nextalarm"];
    }
  else
    {
      [row setObject: [NSNumber numberWithInt: 0] forKey: @"c_nextalarm"];

      // Delete old email alarms
      if (alarm_number >= 0)
	[af deleteRecordForEntryWithCName: nameInContainer
			 inCalendarAtPath: [theContainer ocsPath]];
    }
}

@end
