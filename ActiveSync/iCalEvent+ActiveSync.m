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

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalPerson.h>

#include "iCalRecurrenceRule+ActiveSync.h"
#include "iCalTimeZone+ActiveSync.h"
#include "NSDate+ActiveSync.h"
#include "NSString+ActiveSync.h"

@implementation iCalEvent (ActiveSync)

- (NSString *) activeSyncRepresentation
{
  NSMutableString *s;
  NSArray *attendees;

  iCalPerson *organizer, *attendee;
  iCalTimeZone *tz;
  id o;

  int v;

  s = [NSMutableString string];
  
  // DTStamp -- http://msdn.microsoft.com/en-us/library/ee219470(v=exchg.80).aspx
  if ([self timeStampAsDate])
    [s appendFormat: @"<DTStamp xmlns=\"Calendar:\">%@</DTStamp>", [[self timeStampAsDate] activeSyncRepresentationWithoutSeparators]];
  else if ([self created])
    [s appendFormat: @"<DTStamp xmlns=\"Calendar:\">%@</DTStamp>", [[self created] activeSyncRepresentationWithoutSeparators]];
  
  // StartTime -- http://msdn.microsoft.com/en-us/library/ee157132(v=exchg.80).aspx
  if ([self startDate])
    [s appendFormat: @"<StartTime xmlns=\"Calendar:\">%@</StartTime>", [[self startDate] activeSyncRepresentationWithoutSeparators]];
  
  // EndTime -- http://msdn.microsoft.com/en-us/library/ee157945(v=exchg.80).aspx
  if ([self endDate])
    [s appendFormat: @"<EndTime xmlns=\"Calendar:\">%@</EndTime>", [[self endDate] activeSyncRepresentationWithoutSeparators]];
  
  // Timezone
  tz = [(iCalDateTime *)[self firstChildWithTag: @"dtstart"] timeZone];

  if (!tz)
    tz = [iCalTimeZone timeZoneForName: @"Europe/London"];

  [s appendFormat: @"<TimeZone xmlns=\"Calendar:\">%@</TimeZone>", [[tz activeSyncRepresentation] stringByReplacingString: @"\n" withString: @""]];;
  
  // Organizer
  if ((organizer = [self organizer]))
    {
      o = [organizer rfc822Email];
      if ([o length])
        [s appendFormat: @"<Organizer_Email xmlns=\"Calendar:\">%@</Organizer_Email>", o];

      o = [organizer cn];
      if ([o length])
        [s appendFormat: @"<Organizer_Name xmlns=\"Calendar:\">%@</Organizer_Name>", o];
    }
  
  // Attendees
  attendees = [self attendees];
  
  if ([attendees count])
    {
      int i, attendee_type, attendee_status;
      
      [s appendString: @"<Attendees xmlns=\"Calendar:\">"];

      for (i = 0; i < [attendees count]; i++)
        {
          [s appendString: @"<Attendee xmlns=\"Calendar:\">"];

          attendee = [attendees objectAtIndex: i];
          [s appendFormat: @"<Attendee_Email xmlns=\"Calendar:\">%@</Attendee_Email>", [attendee rfc822Email]];
          [s appendFormat: @"<Attendee_Name xmlns=\"Calendar:\">%@</Attendee_Name>", [attendee cn]];
          
          attendee_status = 5;
          if ([[attendee partStat] caseInsensitiveCompare: @"ACCEPTED"] == NSOrderedSame)
            attendee_status = 3;
          else if ([[attendee partStat] caseInsensitiveCompare: @"DECLINED"] == NSOrderedSame)
            attendee_status = 4;
          else if ([[attendee partStat] caseInsensitiveCompare: @"TENTATIVE"] == NSOrderedSame)
            attendee_status = 2;
            
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

  // Subject -- http://msdn.microsoft.com/en-us/library/ee157192(v=exchg.80).aspx
  if ([[self summary] length])
    [s appendFormat: @"<Subject xmlns=\"Calendar:\">%@</Subject>", [[self summary] activeSyncRepresentation]];
  
  // Location
  if ([[self location] length])
    [s appendFormat: @"<Location xmlns=\"Calendar:\">%@</Location>", [[self location] activeSyncRepresentation]];
  
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
  if ([[self accessClass] isEqualToString: @"CONFIDENTIAL"])
    v = 3;
  else
    v = 0;

  [s appendFormat: @"<Sensitivity xmlns=\"Calendar:\">%d</Sensitivity>", v];
  
  // BusyStatus -- http://msdn.microsoft.com/en-us/library/ee202290(v=exchg.80).aspx
  [s appendFormat: @"<BusyStatus xmlns=\"Calendar:\">%d</BusyStatus>", 0];
  
  // Reminder -- http://msdn.microsoft.com/en-us/library/ee219691(v=exchg.80).aspx
  // TODO

  // Recurrence rules
  if ([self isRecurrent])
    {
      [s appendString: [[[self recurrenceRules] lastObject] activeSyncRepresentation]];
    }

  // Comment
  o = [self comment];
  if ([o length])
    {
      o = [o activeSyncRepresentation];
      [s appendString: @"<Body xmlns=\"AirSyncBase:\">"];
      [s appendFormat: @"<Type>%d</Type>", 1];
      [s appendFormat: @"<EstimatedDataSize>%d</EstimatedDataSize>", [o length]];
      [s appendFormat: @"<Truncated>%d</Truncated>", 0];
      [s appendFormat: @"<Data>%@</Data>", o];
      [s appendString: @"</Body>"];
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
{
  iCalDateTime *start, *end;
  NSTimeZone *userTimeZone;
  iCalTimeZone *tz;
  id o;

  NSInteger tzOffset;
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
  //
  //
  if ((o = [theValues objectForKey: @"MeetingStatus"]))
    {
      [o intValue];
    }

  //
  // 0- normal, 1- personal, 2- private and 3-confidential
  //
  if ((o = [theValues objectForKey: @"Sensitivy"]))
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

  if ((o = [theValues objectForKey: @"TimeZone"]))
    {
      // Ugh, we ignore it for now.
      userTimeZone = [theValues objectForKey: @"SOGoUserTimeZone"];
      tz = [iCalTimeZone timeZoneForName: [userTimeZone name]];
      [(iCalCalendar *) parent addTimeZone: tz];
    }
  
  // FIXME: merge with iCalToDo
  if ((o = [[theValues objectForKey: @"Body"] objectForKey: @"Data"]))
    [self setComment: o];
  
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
          tzOffset = [userTimeZone secondsFromGMTForDate: o];
          o = [o dateByAddingYears: 0 months: 0 days: 0
                             hours: 0 minutes: 0
                           seconds: tzOffset];
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
          tzOffset = [userTimeZone secondsFromGMTForDate: o];
          o = [o dateByAddingYears: 0 months: 0 days: 0
                             hours: 0 minutes: 0
                           seconds: tzOffset];
          [end setDateTime: o];
        }
    }

  // Recurrence
  if ((o = [theValues objectForKey: @"Recurrence"]))
    {
      iCalRecurrenceRule *rule;
      
      rule = [[iCalRecurrenceRule alloc] init];
      [self setRecurrenceRules: [NSArray arrayWithObject: rule]];
      RELEASE(rule);
      
      [rule takeActiveSyncValues: o];
    }

  // Organizer
  if ((o = [theValues objectForKey: @"Organizer_Email"]))
    {
      iCalPerson *person;

      person = [iCalPerson elementWithTag: @"organizer"];
      [person setEmail: o];
      [person setCn: [theValues objectForKey: @"Organizer_Name"]];
      [person setPartStat: @"ACCEPTED"];
      [self setOrganizer: person];
    }

  // Attendees
  if ((o = [theValues objectForKey: @"Attendees"]))
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

@end
