/* iCalEntityObject+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2015 Inverse inc.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSURL.h>

#import <NGCards/iCalAlarm.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalTrigger.h>
#import <NGCards/iCalRepeatableEntityObject.h>
#import <NGCards/NSString+NGCards.h>

#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NSNull+misc.h>

#import "SOGoAppointmentFolder.h"

#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import "iCalPerson+SOGo.h"

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
 */
- (NSDictionary *) attributes
{
  NSArray *elements;
  NSMutableArray *attendees;
  NSDictionary *organizerData;
  NSMutableDictionary *data, *attendeeData, *alarmData;
  NSEnumerator *attendeesList;
  iCalPerson *organizer, *currentAttendee;
  iCalAlarm *alarm;
  iCalTrigger *trigger;
  id value;

  data = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                [[self tag] lowercaseString], @"component",
                              [self summary], @"summary",
                              [self priority], @"priority",
                              nil];

  value = [self location];
  if (value) [data setObject: value forKey: @"location"];
  if ([self comment]) [data setObject: [self comment] forKey: @"comment"];
  if ([self attach]) [data setObject: [[self attach] absoluteString] forKey: @"attachUrl"];
  if ([self accessClass]) [data setObject: [[self accessClass] lowercaseString] forKey: @"classification"];
  if ([self status]) [data setObject: [self status] forKey: @"status"];
  if ([self createdBy]) [data setObject: [self createdBy] forKey: @"createdBy"];

  // Categories
  elements = [self categories];
  if ([elements count])
    [data setObject: elements forKey: @"categories"];

  // Send appointment notifications
  value = [self firstChildWithTag: @"X-SOGo-Send-Appointment-Notifications"];
  [data setObject: [NSNumber numberWithBool: (value? 1:0)] forKey: @"sendAppointmentNotifications"];

  // Organizer
  organizer = [self organizer];
  if (organizer)
    {
      organizerData = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [organizer rfc822Email], @"email",
                                    [organizer cnWithoutQuotes], @"name",
                                    nil];
      [data setObject: organizerData forKey: @"organizer"];
    }


  // Attendees
  attendees = [NSMutableArray array];
  attendeesList = [[self attendees] objectEnumerator];
  while ((currentAttendee = [attendeesList nextObject]))
    {
      attendeeData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                            [currentAttendee rfc822Email], @"email",
                                          [currentAttendee cnWithoutQuotes], @"name",
                                          nil];
      if ([currentAttendee uid]) [attendeeData setObject: [currentAttendee uid] forKey: @"uid"];
      // TODO: restore support for MS Exchange
      // uid = [um getUIDForEmail: [currentAttendee rfc822Email]];
      // if (uid != nil)
      //   [currentAttendeeData setObject: uid
      //   			forKey: @"uid"];
      // else
      //   {
      //     domain = [[context activeUser] domain];
      //     contacts = [um fetchContactsMatching: [currentAttendee rfc822Email] inDomain: domain];
      //     if ([contacts count] == 1)
      //       {
      //         contact = [contacts lastObject];
      //         source = [contact objectForKey: @"source"];
      //         if ([source conformsToProtocol: @protocol (SOGoDNSource)] &&
      //             [[(NSObject <SOGoDNSource>*) source MSExchangeHostname] length])
      //           {
      //             uid = [NSString stringWithFormat: @"%@:%@", [[context activeUser] login],
      //                         [contact valueForKey: @"c_uid"]];
      //             [currentAttendeeData setObject: uid forKey: @"uid"];
      //           }
      //       }
      //   }
      [attendeeData setObject: [[currentAttendee partStat] lowercaseString] forKey: @"status"];
      [attendeeData setObject: [[currentAttendee role] lowercaseString] forKey: @"role"];
      if ([[currentAttendee delegatedTo] length])
	[attendeeData setObject: [[currentAttendee delegatedTo] rfc822Email] forKey: @"delegatedTo"];
      if ([[currentAttendee delegatedFrom] length])
	[attendeeData setObject: [[currentAttendee delegatedFrom] rfc822Email] forKey: @"delegatedFrom"];

      [attendees addObject: attendeeData];
    }
  if ([attendees count])
    [data setObject: attendees forKey: @"attendees"];

  // Alarm
  if ([self hasAlarms])
    {
      alarm = [self firstSupportedAlarm]; // only consider the first alarm with a supported action
      trigger = [alarm trigger];
      if (![[trigger valueType] length] || [[trigger valueType] caseInsensitiveCompare: @"DURATION"] == NSOrderedSame)
        {
          alarmData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             [[alarm action] lowercaseString], @"action",
                                           nil];
          [alarmData addEntriesFromDictionary: [trigger asDictionary]];
          attendees = [NSMutableArray array];
          attendeesList = [[alarm attendees] objectEnumerator];
          while ((currentAttendee = [attendeesList nextObject]))
            {
              attendeeData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                    [currentAttendee rfc822Email], @"email",
                                                  [currentAttendee cnWithoutQuotes], @"name",
                                                  nil];
              if ([currentAttendee uid]) [attendeeData setObject: [currentAttendee uid] forKey: @"uid"];
              [attendees addObject: attendeeData];
            }
          if ([attendees count])
            [alarmData setObject: attendees forKey: @"attendees"];

          [data setObject: alarmData forKey: @"alarm"];
        }
    }

  return data;
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
  NSEnumerator *attendees;
  iCalPerson *currentAttendee, *userAttendee;

  userAttendee = nil;

  attendees = [[self attendees] objectEnumerator];
  while (!userAttendee
	 && (currentAttendee = [attendees nextObject]))
    if ([user hasEmail: [currentAttendee rfc822Email]])
      userAttendee = currentAttendee;

  return userAttendee;
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
  NSString *userID;

  userID = [user login];
  oldAttendees = [self attendees];
  max = [oldAttendees count];
  newAttendees = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      currentAttendee = [oldAttendees objectAtIndex: count];
      if (![[currentAttendee uid] isEqualToString: userID])
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

- (NSString *) createdBy
{
  NSString *created_by;

  created_by = [[self firstChildWithTag: @"X-SOGo-Component-Created-By"] flattenedValuesForKey: @""];
  
  // We consider "SENT-BY" in case our custom header isn't found
  if (![created_by length])
    {
      created_by = [[self organizer] sentBy];
    }

  return created_by;
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

- (void) updateNextAlarmDateInRow: (NSMutableDictionary *) row
                     forContainer: (id) theContainer
{
  NSCalendarDate *nextAlarmDate;

  nextAlarmDate = nil;

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
          if (anAlarm)
            {
              webstatus = [[anAlarm trigger] value: 0 ofAttribute: @"x-webstatus"];
              if (!webstatus
                  || ([webstatus caseInsensitiveCompare: @"TRIGGERED"]
                      != NSOrderedSame))
                nextAlarmDate = [anAlarm nextAlarmDate];
            }
          else
            {
              // TODO: handle email alarms here
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
                          anAlarm = [self firstDisplayOrAudioAlarm];
                          if (anAlarm)
                            {
                              webstatus = [[anAlarm trigger] value: 0 ofAttribute: @"x-webstatus"];
                              if (!webstatus
                                  || ([webstatus caseInsensitiveCompare: @"TRIGGERED"]
                                      != NSOrderedSame))
                                
                                v = delta;
                              nextAlarmDate = [NSDate dateWithTimeIntervalSince1970: [[[alarms objectAtIndex: i] objectForKey: @"c_nextalarm"] intValue]];
                            }
                          else
                            {
                              // TODO: handle email alarms here
                            }
                        }
                    }
                } // for ( ... )
            } // if (theContainer)
        }
    }
  
  if ([nextAlarmDate isNotNull])
    [row setObject: [NSNumber numberWithInt: [nextAlarmDate timeIntervalSince1970]]
            forKey: @"c_nextalarm"];
  else
    [row setObject: [NSNumber numberWithInt: 0] forKey: @"c_nextalarm"];
}

@end
