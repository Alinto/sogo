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
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalPerson.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import <Appointments/iCalEntityObject+SOGo.h>

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
  
  // StartTime -- http://msdn.microsoft.com/en-us/library/ee157132(v=exchg.80).aspx
  if ([self startDate])
    {
      if ([self isAllDay])
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
      if ([self isAllDay])
        [s appendFormat: @"<EndTime xmlns=\"Calendar:\">%@</EndTime>",
           [[[self endDate] dateByAddingYears: 0 months: 0 days: 0
                                        hours: 0 minutes: 0
                                      seconds: ([userTimeZone secondsFromGMTForDate: [self endDate]])*-1]
             activeSyncRepresentationWithoutSeparatorsInContext: context]];
      else
        [s appendFormat: @"<EndTime xmlns=\"Calendar:\">%@</EndTime>", [[self endDate] activeSyncRepresentationWithoutSeparatorsInContext: context]];
    }

  // Timezone
  tz = [(iCalDateTime *)[self firstChildWithTag: @"dtstart"] timeZone];

  if (!tz)
    tz = [iCalTimeZone timeZoneForName: [userTimeZone name]];

  [s appendFormat: @"<TimeZone xmlns=\"Calendar:\">%@</TimeZone>", [tz activeSyncRepresentationInContext: context]];
  
  // Organizer and other invitations related properties
  if ((organizer = [self organizer]))
    {
      meetingStatus = 1;  // meeting and the user is the meeting organizer.
      o = [organizer rfc822Email];
      if ([o length])
        {
          [s appendFormat: @"<Organizer_Email xmlns=\"Calendar:\">%@</Organizer_Email>", o];
          
          o = [organizer cn];
          if ([o length])
            [s appendFormat: @"<Organizer_Name xmlns=\"Calendar:\">%@</Organizer_Name>", o];
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
      meetingStatus = 0;  // appointment
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
  if ([[self uid] length])
    [s appendFormat: @"<UID xmlns=\"Calendar:\">%@</UID>", [self uid]];
  
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

  // Recurrence rules
  if ([self isRecurrent])
    {
      [s appendString: [[[self recurrenceRules] lastObject] activeSyncRepresentationInContext: context]];
    }

  // Comment
  o = [self comment];
  if ([o length])
    {
      // It is very important here to NOT set <Truncated>0</Truncated> in the response,
      // otherwise it'll prevent WP8 phones from sync'ing. See #3028 for details.
      o = [o activeSyncRepresentationInContext: context];

      if ([[[context request] headerForKey: @"MS-ASProtocolVersion"] isEqualToString: @"2.5"])
        {
          [s appendFormat: @"<Body xmlns=\"Calendar:\">%@</Body>", o];
          [s appendString: @"<BodyTruncated xmlns=\"Calendar:\">0</BodyTruncated>"];
        }
      else
        {
          [s appendString: @"<Body xmlns=\"AirSyncBase:\">"];
          [s appendFormat: @"<Type>%d</Type>", 1];
          [s appendFormat: @"<EstimatedDataSize>%d</EstimatedDataSize>", [o length]];
          [s appendFormat: @"<Data>%@</Data>", o];
          [s appendString: @"</Body>"];
       }
    }

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
  iCalDateTime *start, *end;
  NSTimeZone *userTimeZone;
  iCalTimeZone *tz;
  id o;

  BOOL isAllDay;
  
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
  if ([[[context request] headerForKey: @"MS-ASProtocolVersion"] isEqualToString: @"2.5"])
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

  if ((o = [theValues objectForKey: @"StartTime"]))
    {
      o = [o calendarDate];
      start = (iCalDateTime *) [self uniqueChildWithTag: @"dtstart"];
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

  //
  // iOS is plain stupid here. It seends event invitations with no Organizer.
  // We check this corner-case and if MeetingStatus == 1 (see http://msdn.microsoft.com/en-us/library/ee219342(v=exchg.80).aspx or details)
  // and there's no organizer, we fake one.
  //
  if ((o = [theValues objectForKey: @"MeetingStatus"]))
    {
      if ([o intValue] == 1 && ![theValues objectForKey: @"Organizer_Email"])
        {
          iCalPerson *person;
      
          person = [iCalPerson elementWithTag: @"organizer"];
          [person setEmail: [[[context activeUser] primaryIdentity] objectForKey: @"email"]];
          [person setCn: [[context activeUser] cn]];
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
      if ((o = [theValues objectForKey: @"Attendees"])&& [o isKindOfClass: [NSArray class]])
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

@end
