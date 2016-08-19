/*

Copyright (c) 2014, Inverse inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Inverse inc. nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

#import "iCalEvent+ActiveSync.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>

#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/NSCalendarDate+NGCards.h>
#import <NGCards/NSString+NGCards.h>
#import <NGCards/iCalCalendar.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/WORequest+SOGo.h>

#import <Appointments/iCalEntityObject+SOGo.h>
#import <Appointments/iCalRepeatableEntityObject+SOGo.h>
#import <Appointments/SOGoAppointmentObject.h>

#include "iCalAlarm+ActiveSync.h"
#include "iCalRecurrenceRule+ActiveSync.h"
#include "iCalTimeZone+ActiveSync.h"
#include "NSDate+ActiveSync.h"
#include "NSString+ActiveSync.h"

@implementation iCalEvent (ActiveSync)

- (int) _attendeeStatus: (iCalPerson *) attendee
{
  int  attendee_status;

  attendee_status = 5;
  if ([[attendee partStat] caseInsensitiveCompare: @"ACCEPTED"] == NSOrderedSame)
    attendee_status = 3;
  else if ([[attendee partStat] caseInsensitiveCompare: @"DECLINED"] == NSOrderedSame)
    attendee_status = 4;
  else if ([[attendee partStat] caseInsensitiveCompare: @"TENTATIVE"] == NSOrderedSame)
    attendee_status = 2;

  return attendee_status;
}

//
// Possible values are:
// 0  Free
// 1  Tentative
// 2  Busy
// 3  Out of Office
// 4  Working elsewhere
//
- (int) _busyStatus: (iCalPerson *) attendee
{
  int  attendee_status;

  attendee_status = 2;

  if ([[attendee partStat] caseInsensitiveCompare: @"DECLINED"] == NSOrderedSame)
    attendee_status = 0;
  else if ([[attendee partStat] caseInsensitiveCompare: @"TENTATIVE"] == NSOrderedSame)
    attendee_status = 1;

  return attendee_status;
}


- (NSString *) activeSyncRepresentationInContext: (WOContext *) context
{
  NSMutableString *s;
  NSArray *attendees, *categories;

  iCalPerson *organizer, *attendee;
  iCalTimeZone *tz;
  id o;

  int v, i, meetingStatus;

  NSTimeZone *userTimeZone;
  userTimeZone = [[[context activeUser] userDefaults] timeZone];

  s = [NSMutableString string];
  
  [s appendFormat: @"<AllDayEvent xmlns=\"Calendar:\">%d</AllDayEvent>", ([self isAllDay] ? 1 : 0)];

  // DTStamp -- http://msdn.microsoft.com/en-us/library/ee219470(v=exchg.80).aspx
  if ([self timeStampAsDate])
    [s appendFormat: @"<DTStamp xmlns=\"Calendar:\">%@</DTStamp>", [[self timeStampAsDate] activeSyncRepresentationWithoutSeparatorsInContext: context]];
  else if ([self created])
    [s appendFormat: @"<DTStamp xmlns=\"Calendar:\">%@</DTStamp>", [[self created] activeSyncRepresentationWithoutSeparatorsInContext: context]];
  
  // Timezone
  tz = [(iCalDateTime *)[self firstChildWithTag: @"dtstart"] timeZone];

  // StartTime -- http://msdn.microsoft.com/en-us/library/ee157132(v=exchg.80).aspx
  if ([self startDate])
    {
      if ([self isAllDay] && !tz)
        [s appendFormat: @"<StartTime xmlns=\"Calendar:\">%@</StartTime>",
           [[[self startDate] dateByAddingYears: 0 months: 0 days: 0
                                          hours: 0 minutes: 0
                                        seconds: ([userTimeZone secondsFromGMTForDate: [self startDate]])*-1]
             activeSyncRepresentationWithoutSeparatorsInContext: context]];
      else
        [s appendFormat: @"<StartTime xmlns=\"Calendar:\">%@</StartTime>", [[self startDate] activeSyncRepresentationWithoutSeparatorsInContext: context]];
    }

  // EndTime -- http://msdn.microsoft.com/en-us/library/ee157945(v=exchg.80).aspx
  if ([self endDate])
    {
      if ([self isAllDay] && !tz)
        [s appendFormat: @"<EndTime xmlns=\"Calendar:\">%@</EndTime>",
           [[[self endDate] dateByAddingYears: 0 months: 0 days: 0
                                        hours: 0 minutes: 0
                                      seconds: ([userTimeZone secondsFromGMTForDate: [self endDate]])*-1]
             activeSyncRepresentationWithoutSeparatorsInContext: context]];
      else
        [s appendFormat: @"<EndTime xmlns=\"Calendar:\">%@</EndTime>", [[self endDate] activeSyncRepresentationWithoutSeparatorsInContext: context]];
    }

  if (!tz)
    tz = [iCalTimeZone timeZoneForName: [userTimeZone name]];

  if (![self recurrenceId])
    [s appendFormat: @"<TimeZone xmlns=\"Calendar:\">%@</TimeZone>", [tz activeSyncRepresentationInContext: context]];
  
  // Organizer and other invitations related properties
  if ((organizer = [self organizer]))
    {
      meetingStatus = 1;  // meeting and the user is the meeting organizer.
      o = [organizer rfc822Email];
      if (![self recurrenceId] && [o length])
        {
          [s appendFormat: @"<Organizer_Email xmlns=\"Calendar:\">%@</Organizer_Email>", o];
          
          o = [organizer cn];
          if ([o length])
            [s appendFormat: @"<Organizer_Name xmlns=\"Calendar:\">%@</Organizer_Name>", [o activeSyncRepresentationInContext: context]];
        }
    }
  
  // Attendees
  attendees = [self attendees];
  
  if ([attendees count])
    {
      int i, attendee_status, attendee_type;
      
      [s appendString: @"<Attendees xmlns=\"Calendar:\">"];

      for (i = 0; i < [attendees count]; i++)
        {
          [s appendString: @"<Attendee xmlns=\"Calendar:\">"];

          attendee = [attendees objectAtIndex: i];
          [s appendFormat: @"<Attendee_Email xmlns=\"Calendar:\">%@</Attendee_Email>", [[attendee rfc822Email] activeSyncRepresentationInContext: context]];
          [s appendFormat: @"<Attendee_Name xmlns=\"Calendar:\">%@</Attendee_Name>", [[attendee cn] activeSyncRepresentationInContext: context]];
          
          attendee_status = [self _attendeeStatus: attendee];
            
          [s appendFormat: @"<Attendee_Status xmlns=\"Calendar:\">%d</Attendee_Status>", attendee_status];

          // FIXME: handle resource
          if ([[attendee role] caseInsensitiveCompare: @"REQ-PARTICIPANT"] == NSOrderedSame)
            attendee_type = 1;
          else
            attendee_type = 2;
          
          [s appendFormat: @"<Attendee_Type xmlns=\"Calendar:\">%d</Attendee_Type>", attendee_type];
          [s appendString: @"</Attendee>"];
        }
      [s appendString: @"</Attendees>"];
    }
   else
    {
      meetingStatus = 0;  // The event is an appointment, which has no attendees.
    }
  
  // This depends on the 'NEEDS-ACTION' parameter.
  // This will trigger the SendMail command
  if ([self userIsAttendee: [context activeUser]])
    {
      iCalPerson *attendee;
      
      int attendee_status;

      meetingStatus = 3; // event is a meeting, and the user is not the meeting organizer

      attendee = [self userAsAttendee: [context activeUser]];
      attendee_status = [self _attendeeStatus: attendee];
  
      [s appendFormat: @"<ResponseRequested xmlns=\"Calendar:\">%d</ResponseRequested>", 1];
      [s appendFormat: @"<ResponseType xmlns=\"Calendar:\">%d</ResponseType>", attendee_status];
      [s appendFormat: @"<DisallowNewTimeProposal xmlns=\"Calendar:\">%d</DisallowNewTimeProposal>", 1];
      
      // BusyStatus -- http://msdn.microsoft.com/en-us/library/ee202290(v=exchg.80).aspx
      [s appendFormat: @"<BusyStatus xmlns=\"Calendar:\">%d</BusyStatus>",  [self _busyStatus: attendee]];
    }
  else
    {
      // If it's a normal event (ie, with no organizer/attendee) or we are the organizer to an event
      // invitation, we set the busy status to 2 (Busy)
      [s appendFormat: @"<BusyStatus xmlns=\"Calendar:\">%d</BusyStatus>", 2];
    }

  [s appendFormat: @"<MeetingStatus xmlns=\"Calendar:\">%d</MeetingStatus>", meetingStatus];

  // Subject -- http://msdn.microsoft.com/en-us/library/ee157192(v=exchg.80).aspx
  if ([[self summary] length])
    [s appendFormat: @"<Subject xmlns=\"Calendar:\">%@</Subject>", [[self summary] activeSyncRepresentationInContext: context]];
  
  // Location
  if ([[self location] length])
    [s appendFormat: @"<Location xmlns=\"Calendar:\">%@</Location>", [[self location] activeSyncRepresentationInContext: context]];
  
  // Importance - NOT SUPPORTED - DO NOT ENABLE
  //o = [self priority];
  //if ([o isEqualToString: @"9"])
  //  v = 0;
  //else if ([o isEqualToString: @"1"])
  //  v = 2;
  //else
  //  v = 1;
  //[s appendFormat: @"<Importance xmlns=\"Calendar:\">%d</Importance>", v];

  // UID -- http://msdn.microsoft.com/en-us/library/ee159919(v=exchg.80).aspx
  if (![self recurrenceId] && [[self uid] length])
    [s appendFormat: @"<UID xmlns=\"Calendar:\">%@</UID>", [[self uid] activeSyncRepresentationInContext: context]];

  // Recurrence rules
  if ([self isRecurrent])
    [s appendString: [[[self recurrenceRules] lastObject] activeSyncRepresentationInContext: context]];

  // Comment
  o = [self comment];
  //if (![self recurrenceId] && [o length])
  if ([o length])
    {
      // It is very important here to NOT set <Truncated>0</Truncated> in the response,
      // otherwise it'll prevent WP8 phones from sync'ing. See #3028 for details.
      o = [o activeSyncRepresentationInContext: context];

      if ([[context valueForKey: @"ASProtocolVersion"] isEqualToString: @"2.5"])
        {
          [s appendFormat: @"<Body xmlns=\"Calendar:\">%@</Body>", o];
          [s appendString: @"<BodyTruncated xmlns=\"Calendar:\">0</BodyTruncated>"];
        }
      else
        {
          [s appendString: @"<Body xmlns=\"AirSyncBase:\">"];
          [s appendFormat: @"<Type>%d</Type>", 1];
          [s appendFormat: @"<EstimatedDataSize>%d</EstimatedDataSize>",  (int)[o length]];
          [s appendFormat: @"<Data>%@</Data>", o];
          [s appendString: @"</Body>"];
       }
    }

  // Sensitivity
  if ([[self accessClass] isEqualToString: @"PRIVATE"])
    v = 2;
  else if ([[self accessClass] isEqualToString: @"CONFIDENTIAL"])
    v = 3;
  else
    v = 0;

  [s appendFormat: @"<Sensitivity xmlns=\"Calendar:\">%d</Sensitivity>", v];

  categories = [self categories];

  if ([categories count])
    {
      [s appendFormat: @"<Categories xmlns=\"Calendar:\">"];
      for (i = 0; i < [categories count]; i++)
        {
          [s appendFormat: @"<Category xmlns=\"Calendar:\">%@</Category>", [[categories objectAtIndex: i] activeSyncRepresentationInContext: context]];
        }
      [s appendFormat: @"</Categories>"];
    }

  // Reminder -- http://msdn.microsoft.com/en-us/library/ee219691(v=exchg.80).aspx
  // TODO: improve this to handle more alarm types
  if ([self hasAlarms]) 
    {
      iCalAlarm *alarm;
      
      alarm = [self firstDisplayOrAudioAlarm];
      [s appendString: [alarm activeSyncRepresentationInContext: context]];
    }

  // Exceptions
  if ([self isRecurrent])
    {
      NSMutableArray *components, *exdates;
      iCalEvent *current_component;
      NSString *recurrence_id;

      unsigned int count, max, i;

      components = [NSMutableArray arrayWithArray: [[self parent] events]];
      max = [components count];

      if (max > 1 || [self hasExceptionDates])
        {
          exdates = [NSMutableArray arrayWithArray: [self exceptionDates]];

          [s appendString: @"<Exceptions xmlns=\"Calendar:\">"];

          for (count = 1; count < max; count++)
            {
              current_component = [components objectAtIndex: count] ;

              if ([self isAllDay])
                {
                  recurrence_id = [NSString stringWithFormat: @"%@",
                                            [[[current_component recurrenceId] dateByAddingYears: 0 months: 0 days: 0
                                                                                           hours: 0 minutes: 0
                                                                                         seconds: -[userTimeZone secondsFromGMTForDate:
                                                                                                                   [current_component recurrenceId]]]
                                              activeSyncRepresentationWithoutSeparatorsInContext: context]];
                }
              else
                {
                  recurrence_id = [NSString stringWithFormat: @"%@", [[current_component recurrenceId]
                                                                       activeSyncRepresentationWithoutSeparatorsInContext: context]];
                }

              [s appendString: @"<Exception>"];
              [s appendFormat: @"<Exception_StartTime xmlns=\"Calendar:\">%@</Exception_StartTime>", recurrence_id];
              [s appendFormat: @"%@", [current_component activeSyncRepresentationInContext: context]];
              [s appendString: @"</Exception>"];
            }

          for (i = 0; i < [exdates count]; i++)
            {
              [s appendString: @"<Exception>"];
              [s appendString: @"<Exception_Deleted>1</Exception_Deleted>"];

              if ([self isAllDay])
                {
                  recurrence_id = [NSString stringWithFormat: @"%@",
                                   [[[[exdates objectAtIndex: i] asCalendarDate] dateByAddingYears: 0 months: 0 days: 0
                                                                                             hours: 0 minutes: 0
                                                                                           seconds: -[userTimeZone secondsFromGMTForDate:
                                                                                                                 [[exdates objectAtIndex: i] asCalendarDate]]]
                                     activeSyncRepresentationWithoutSeparatorsInContext: context]];
                }
              else
                {
                  recurrence_id = [NSString stringWithFormat: @"%@", [[[exdates objectAtIndex: i] asCalendarDate]
                                                                       activeSyncRepresentationWithoutSeparatorsInContext: context]];
                }

              [s appendFormat: @"<Exception_StartTime xmlns=\"Calendar:\">%@</Exception_StartTime>", recurrence_id];
              [s appendString: @"</Exception>"];
            }

            [s appendString: @"</Exceptions>"];
        }
    }

  if (![self recurrenceId])
    [s appendFormat: @"<NativeBodyType xmlns=\"AirSyncBase:\">%d</NativeBodyType>", 1];

  return s;
}

//
// To understand meeting requests/responses, see:
//
// http://blogs.msdn.com/b/exchangedev/archive/2011/07/22/working-with-meeting-requests-in-exchange-activesync.aspx
// http://blogs.msdn.com/b/exchangedev/archive/2011/07/29/working-with-meeting-responses-in-exchange-activesync.aspx
//
//
// Here is an example of a Sync call when sogo10 accepts an invitation from sogo3:
//
// <Change>
//  <ServerId>2978-52EA9D00-1-A253E70.ics</ServerId>
//  <ApplicationData>
//   <TimeZone xmlns="Calendar:">LAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAsAAAABAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMAAAACAAIAAAAAAAAAxP///w==</TimeZone>
//   <AllDayEvent xmlns="Calendar:">0</AllDayEvent>
//   <StartTime xmlns="Calendar:">20140207T130000Z</StartTime>
//   <EndTime xmlns="Calendar:">20140207T140000Z</EndTime>
//   <DTStamp xmlns="Calendar:">20140130T185245Z</DTStamp>
//   <Subject xmlns="Calendar:">test 8</Subject>
//   <Sensitivity xmlns="Calendar:">0</Sensitivity>
//   <Body xmlns="AirSyncBase:">
//    <Type>1</Type>
//    <Data/>
//   </Body>
//   <Organizer_Email xmlns="Calendar:">sogo3@example.com</Organizer_Email>
//   <UID xmlns="Calendar:">2978-52EA9D00-1-A253E70</UID>
//   <Attendees xmlns="Calendar:">
//    <Attendee>
//     <Attendee_Name>sogo10</Attendee_Name>
//     <Attendee_Email>sogo10@example.com</Attendee_Email>
//     <Attendee_Type>1</Attendee_Type>
//    </Attendee>
//   </Attendees>
//   <BusyStatus xmlns="Calendar:">2</BusyStatus>
//   <MeetingStatus xmlns="Calendar:">3</MeetingStatus>
//   <Organizer_Name xmlns="Calendar:">Wolfgang Fritz</Organizer_Name>
//  </ApplicationData>
// </Change>
//
- (void) takeActiveSyncValues: (NSDictionary *) theValues
                    inContext: (WOContext *) context
{
  iCalDateTime *start, *end; //, *oldstart;
  NSCalendarDate *oldstart;
  NSTimeZone *userTimeZone;
  iCalTimeZone *tz;
  id o;
  int deltasecs;

  BOOL isAllDay;

  NSMutableArray *occurences;

  occurences = [NSMutableArray arrayWithArray: [[self parent] events]];

  if ((o = [theValues objectForKey: @"UID"]))
    [self setUid: o];
    
  // FIXME: merge with iCalToDo
  if ((o = [theValues objectForKey: @"Subject"]))
    [self setSummary: o];

  isAllDay = NO;
  if ([[theValues objectForKey: @"AllDayEvent"] intValue])
    {
      isAllDay = YES;
    }
  else if ([occurences count] && !([theValues objectForKey: @"AllDayEvent"]))
    {
      // If the occurence has no AllDay tag use it from master.
      isAllDay = [[occurences objectAtIndex: 0] isAllDay];
    }

  //
  // 0- free, 1- tentative, 2- busy and 3- out of office
  //
  if ((o = [theValues objectForKey: @"BusyStatus"]))
    {
      [o intValue];
    }

  //
  // 0- normal, 1- personal, 2- private and 3-confidential
  //
  if ((o = [theValues objectForKey: @"Sensitivity"]))
    {
      switch ([o intValue])
        {
        case 2:
          [self setAccessClass: @"PRIVATE"];
          break;
        case 3:
          [self setAccessClass: @"CONFIDENTIAL"];
          break;
        case 0:
        case 1:
        default:
          [self setAccessClass: @"PUBLIC"];
        }
    }

  // Categories
  if ((o = [theValues objectForKey: @"Categories"]) && [o length])
    [self setCategories: o];

  // We ignore TimeZone sent by mobile devices for now.
  // Some Windows devices don't send during event updates.
  //if ((o = [theValues objectForKey: @"TimeZone"]))
  //  {
  //  }
  //else
    {
      // We haven't received a timezone, let's use the user's timezone
      // specified in SOGo for now.
      userTimeZone = [[[context activeUser] userDefaults] timeZone];
      tz = [iCalTimeZone timeZoneForName: [userTimeZone name]];
      [(iCalCalendar *) parent addTimeZone: tz];
    }
  
  // FIXME: merge with iCalToDo
  if ([[context valueForKey: @"ASProtocolVersion"] isEqualToString: @"2.5"])
    {
      if ((o = [theValues objectForKey: @"Body"]))
        [self setComment: o];
    }
  else
    {
      if ((o = [[theValues objectForKey: @"Body"] objectForKey: @"Data"]))
        [self setComment: o];
    }

  if ((o = [theValues objectForKey: @"Location"]))
    [self setLocation: o];

  deltasecs = 0;
  start = nil;

  if ((o = [theValues objectForKey: @"StartTime"]))
    {
      o = [o calendarDate];
      start = (iCalDateTime *) [self uniqueChildWithTag: @"dtstart"];
      oldstart = [start dateTime];
      [start setTimeZone: tz];

      if (isAllDay)
	{
          [start setDate: o];
          [start setTimeZone: nil];
        }
      else
        {
          [start setDateTime: o];
        }

      // Calculate delta if start date has been changed.
      if (oldstart)
	deltasecs = [[start dateTime ] timeIntervalSinceDate: oldstart] * -1;
    }

  if ((o = [theValues objectForKey: @"EndTime"]))
    {
      o = [o calendarDate];
      end = (iCalDateTime *) [self uniqueChildWithTag: @"dtend"];
      [end setTimeZone: tz];

      if (isAllDay)
        {
          [end setDate: o];
          [end setTimeZone: nil];
        }
      else
        {
          [end setDateTime: o];
        }
    }

  //
  // If an alarm is deinfed with an action != DISPLAY, we ignore the alarm - don't want to overwrite. 
  //
  if ([self hasAlarms] && [[[[self alarms] objectAtIndex: 0] action] caseInsensitiveCompare: @"DISPLAY"] != NSOrderedSame)
    {
      // Ignore the alarm for now
    }
  else if ((o = [theValues objectForKey: @"Reminder"]))
    {           
      // NOTE: Outlook sends a 15 min reminder (18 hour for allday) if no reminder is specified  
      // although no default reminder is defined (File -> Options -> Clendar -> Calendar Options - > Default Reminders)
      //
      // http://answers.microsoft.com/en-us/office/forum/office_2013_release-outlook/desktop-outlook-calendar-creates-entries-with/9aef72d8-81bb-4a32-a6ab-bf7d216fb811?page=5&tm=1395690285088 
      //
      iCalAlarm *alarm;
      
      alarm = [[iCalAlarm alloc] init];
      [alarm takeActiveSyncValues: theValues  inContext: context];

      [self removeAllAlarms];
      [self addToAlarms: alarm];
      RELEASE(alarm);
    }
  else
    {
      // We remove existing alarm since no reminder in the ActiveSync payload
      [self removeAllAlarms];
    }
  
  // Recurrence
  if ((o = [theValues objectForKey: @"Recurrence"]))
    {
      iCalRecurrenceRule *rule;
      
      rule = [[iCalRecurrenceRule alloc] init];
      [self setRecurrenceRules: [NSArray arrayWithObject: rule]];
      RELEASE(rule);
      
      [rule takeActiveSyncValues: o  inContext: context];

      // Exceptions
      if ((o = [theValues objectForKey: @"Exceptions"]) && [o isKindOfClass: [NSArray class]])
        {
          NSCalendarDate *recurrenceId, *adjustedRecurrenceId, *currentId;
          NSMutableArray *exdates, *exceptionstouched;
          iCalEvent *currentOccurence;
          NSDictionary *exception;

          unsigned int i, count, max;

          [self removeAllExceptionDates];

          exdates = [NSMutableArray array];
          exceptionstouched = [NSMutableArray array];

          for (i = 0; i < [o count]; i++)
            {
              exception = [o objectAtIndex: i];

              if (![[exception objectForKey: @"Exception_Deleted"] intValue])
                {
                  recurrenceId = [[exception objectForKey: @"Exception_StartTime"] asCalendarDate];

                  if (isAllDay)
                    recurrenceId = [recurrenceId dateByAddingYears: 0 months: 0 days: 0
                                                             hours: 0 minutes: 0
                                                           seconds: [userTimeZone secondsFromGMTForDate:recurrenceId]];

                  // When moving the calendar entry (i.e. changing the startDate) iOS and Android sometimes send a value for
                  // Exception_StartTime which is not what we expect.
                  // With this we make sure the recurrenceId is always correct.
                  //
                  // iOS problem - If the master is a no-allday-event but the exception is, an invalid Exception_StartTime is in the request.
                  // e.g. it sends 20150409T040000Z instead of 20150409T060000Z;
                  // This might be a special case since iPhone doesn't allow an allday-exception on a non-allday-event.
                  if (!([[start dateTime] compare: [[start dateTime] hour:[recurrenceId hourOfDay] minute:[recurrenceId minuteOfHour]]] == NSOrderedSame))
                    recurrenceId = [recurrenceId hour:[[start dateTime] hourOfDay] minute:[[start dateTime] minuteOfHour]];

                  // We need to store the recurrenceIds and exception dates adjusted by deltasecs.
                  // This ensures that the adjustment in SOGoCalendarComponent->updateComponent->_updateRecurrenceIDsWithEvent gives the correct dates.
                  adjustedRecurrenceId = [recurrenceId dateByAddingYears: 0 months: 0 days: 0
                                                                   hours: 0 minutes: 0 seconds: deltasecs];

                  // search for an existing occurence and update it
                  max = [occurences count];
                  currentOccurence = nil;
                  count = 1;
                  while (count < max)
                    {
                      currentOccurence = [occurences objectAtIndex: count] ;
                      currentId = [currentOccurence recurrenceId];

                      if ([currentId compare: adjustedRecurrenceId] == NSOrderedSame)
                        {
                          [exceptionstouched addObject: adjustedRecurrenceId];
                          [currentOccurence takeActiveSyncValues: exception  inContext: context];

                          break;
                        }

                      count++;
                      currentOccurence = nil;
                    }

                  // Create a new occurence if we found none to update.
                  if (!currentOccurence)
                    {
                      iCalDateTime *recid;

                      currentOccurence = [self mutableCopy];
                      [currentOccurence removeAllRecurrenceRules];
                      [currentOccurence removeAllExceptionRules];
                      [currentOccurence removeAllExceptionDates];

                      [[self parent] addToEvents: currentOccurence];
                      [currentOccurence takeActiveSyncValues: exception  inContext: context];

                      recid = (iCalDateTime *)[currentOccurence uniqueChildWithTag: @"recurrence-id"];
                      if (isAllDay)
                        [recid setDate: adjustedRecurrenceId];
                      else
                        [recid setDateTime: adjustedRecurrenceId];

                      [exceptionstouched addObject: [recid dateTime]];
                    }
                }
              else if ([[exception objectForKey: @"Exception_Deleted"] intValue])
                {
                  recurrenceId = [[exception objectForKey: @"Exception_StartTime"] asCalendarDate];

                  if (isAllDay)
                    recurrenceId = [recurrenceId dateByAddingYears: 0 months: 0
                                                              days: 0 hours: 0 minutes: 0
                                                           seconds: [userTimeZone secondsFromGMTForDate:recurrenceId]];

                  // We add only valid exception dates.
                  if ([self doesOccurOnDate: recurrenceId] &&
                      ([[start dateTime] compare: [[start dateTime] hour:[recurrenceId hourOfDay]
                                                                  minute:[recurrenceId minuteOfHour]]] == NSOrderedSame))
                    {
                      // We need to store the recurrenceIds and exception dates adjusted by deltasecs.
                      // This ensures that the adjustment in SOGoCalendarComponent->updateComponent->_updateRecurrenceIDsWithEvent gives the correct dates.
                      [exdates addObject: [recurrenceId dateByAddingYears: 0 months: 0 days: 0 hours: 0 minutes: 0 seconds: deltasecs]];
                    }
                }
            }

          // Update exception dates in master event.
          max = [exdates count];
          if (max > 0)
            {
              for (count = 0; count < max; count++)
                {
                  if (([exceptionstouched indexOfObject: [exdates objectAtIndex: count]] == NSNotFound))
                    [self addToExceptionDates: [exdates objectAtIndex: count]];
                }
            }

          // Remove all exceptions included in the request.
          max = [occurences count];
          count = 1; // skip the master event
          while (count < max)
            {
              currentOccurence = [occurences objectAtIndex: count] ;
              currentId = [currentOccurence recurrenceId];

              // Delete all occurences which are not touched (modified/added).
              if (([exceptionstouched indexOfObject: currentId] == NSNotFound))
                [[[self parent] children] removeObject: currentOccurence];

              count++;
            }
        }
      else if ([self isRecurrent])
        {
          // We have no exceptions in request but there is a recurrence rule.
          // Remove all excpetions and exception dates.
          iCalEvent *currentOccurence;
          unsigned int count, max;

          [self removeAllExceptionDates];
          max = [occurences count];
          count = 1; // skip the master event
          while (count < max)
            {
              currentOccurence = [occurences objectAtIndex: count];
              [[[self parent] children] removeObject: currentOccurence];
              count++;
            }
        }
    }
  else if ([self isRecurrent])
    {
      // We have no recurrence rule in request.
      // Remove all exceptions, exception dates and recurrence rules.
      iCalEvent *currentOccurence;
      unsigned int count, max;

      [self removeAllRecurrenceRules];
      [self removeAllExceptionRules];
      [self removeAllExceptionDates];

      max = [occurences count];
      count = 1; // skip the master event
      while (count < max)
        {
          currentOccurence = [occurences objectAtIndex: count];
          [[[self parent] children] removeObject: currentOccurence];
          count++;
        }
    }

  // Organizer - we don't touch the value unless we're the organizer
  if ((o = [theValues objectForKey: @"Organizer_Email"]) &&
      ([self userIsOrganizer: [context activeUser]] || [[context activeUser] hasEmail: o]))
    {
      iCalPerson *person;

      person = [iCalPerson elementWithTag: @"organizer"];
      [person setEmail: o];
      [person setCn: [theValues objectForKey: @"Organizer_Name"]];
      [person setPartStat: @"ACCEPTED"];
      [self setOrganizer: person];
    }

  if ((o = [theValues objectForKey: @"MeetingStatus"]))
    {
     //
     // iOS is plain stupid here. It seends event invitations with no Organizer.
     // We check this corner-case and if MeetingStatus == 1 (see http://msdn.microsoft.com/en-us/library/ee219342(v=exchg.80).aspx or details)
     // and there's no organizer, we fake one.
     //
      if ([o intValue] == 1 && ![theValues objectForKey: @"Organizer_Email"] && ![[[self organizer] rfc822Email] length])
        {
          iCalPerson *person;
      
          person = [iCalPerson elementWithTag: @"organizer"];
          [person setEmail: [[[context activeUser] primaryIdentity] objectForKey: @"email"]];
          [person setCn: [[context activeUser] cn]];
          [person setPartStat: @"ACCEPTED"];
          [self setOrganizer: person];
        }

      //
      // When MeetingResponse fails Outlook still sends a new calendar entry with MeetingStatus=3.
      // Use the organizer from the request if the event has no organizer.
      //
      if ([o intValue] == 3 && [theValues objectForKey: @"Organizer_Email"] && ![[[self organizer] rfc822Email] length])
        {
          iCalPerson *person;
          person = [iCalPerson elementWithTag: @"organizer"];
          [person setEmail: [theValues objectForKey: @"Organizer_Email"]];
          [person setCn: [theValues objectForKey: @"Organizer_Name"]];
          [person setPartStat: @"ACCEPTED"];
          [self setOrganizer: person];
        }
    }
  

  // Attendees - we don't touch the values if we're an attendee. This is gonna
  // be done automatically by the ActiveSync client when invoking MeetingResponse.
  if (![self userIsAttendee: [context activeUser]])
    {
      // Windows phones sens sometimes an empty Attendees tag.
      // We check it's an array before processing it.
      if ((o = [theValues objectForKey: @"Attendees"]) && [o isKindOfClass: [NSArray class]])
        {
          NSMutableArray *attendees;
          NSDictionary *attendee;
          iCalPerson *person;
          int status, i;
          
          attendees = [NSMutableArray array];
          
          for (i = 0; i < [o count]; i++)
            {
              // Each attendee has is a dictionary similar to this:
              // { "Attendee_Email" = "sogo3@example.com"; "Attendee_Name" = "Wolfgang Fritz"; "Attendee_Status" = 5; "Attendee_Type" = 1; }
              attendee = [o objectAtIndex: i];
              
              person = [iCalPerson elementWithTag: @"attendee"];
              [person setCn: [attendee objectForKey: @"Attendee_Name"]];
              [person setEmail: [attendee objectForKey: @"Attendee_Email"]];
              
              status = [[attendee objectForKey: @"Attendee_Status"] intValue];
              
              switch (status)
                {
                case 2:
                  [person setPartStat: @"TENTATIVE"];
                  break;
                case 3:
                  [person setPartStat: @"ACCEPTED"];
                  break;
                case 4:
                  [person setPartStat: @"DECLINED"];
                  break;
                case 0:
                case 5:
                default:
                  [person setPartStat: @"NEEDS-ACTION"];
                  break;
                }
              
              // FIXME: handle Attendee_Type
              
              [attendees addObject: person];
            }
          
          [self setAttendees: attendees];
        }
    }
}

- (void) changeParticipationStatus: (NSDictionary *) theValues
                         inContext: (WOContext *) context
                         component: (id) component
{
  NSString *status;
  id o;

  // See: https://msdn.microsoft.com/en-us/library/ee202290(v=exchg.80).aspx
  //
  // 0 == Free
  // 1 == Tentative
  // 2 == Busy
  // 3 == Out of Office
  // 4 == Working elsehwere
  //
  if ((o = [theValues objectForKey: @"BusyStatus"]))
    {
      // We translate >= 2 into ACCEPTED
      if ([o intValue] == 0)
        status = @"NEEDS-ACTION";
      else if ([o intValue] >= 2)
        status = @"ACCEPTED";
      else
        status = @"TENTATIVE";

      // There's no delegate in EAS
      [(SOGoAppointmentObject *) component changeParticipationStatus: status
                                                        withDelegate: nil
                                                               alarm: nil];
    }
}

@end
