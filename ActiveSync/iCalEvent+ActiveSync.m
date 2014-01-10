/*

Copyright (c) 2014, Inverse inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the Inverse inc. nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/
#import "iCalEvent+ActiveSync.h"

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>

#include "iCalTimeZone+ActiveSync.h"
#include "NSDate+ActiveSync.h"
#include "NSString+ActiveSync.h"

@implementation iCalEvent (ActiveSync)

- (NSString *) activeSyncRepresentation
{
  NSMutableString *s;
  iCalTimeZone *tz;

  s = [NSMutableString string];
  
  // DTStamp -- http://msdn.microsoft.com/en-us/library/ee219470(v=exchg.80).aspx
  if ([self timeStampAsDate])
    [s appendFormat: @"<DTStamp xmlns=\"Calendar:\">%@</DTStamp>", [[self timeStampAsDate] activeSyncRepresentation]];
  else if ([self created])
    [s appendFormat: @"<DTStamp xmlns=\"Calendar:\">%@</DTStamp>", [[self created] activeSyncRepresentation]];
  
  // StartTime -- http://msdn.microsoft.com/en-us/library/ee157132(v=exchg.80).aspx
  if ([self startDate])
    [s appendFormat: @"<StartTime xmlns=\"Calendar:\">%@</StartTime>", [[self startDate] activeSyncRepresentation]];
  
  // EndTime -- http://msdn.microsoft.com/en-us/library/ee157945(v=exchg.80).aspx
  if ([self endDate])
    [s appendFormat: @"<EndTime xmlns=\"Calendar:\">%@</EndTime>", [[self endDate] activeSyncRepresentation]];
  
  // Timezone
  tz = [(iCalDateTime *)[self firstChildWithTag: @"dtstart"] timeZone];

  if (!tz)
    tz = [iCalTimeZone timeZoneForName: @"Europe/London"];

  [s appendFormat: @"<TimeZone xmlns=\"Calendar:\">%@</TimeZone>", [[tz activeSyncRepresentation] stringByReplacingString: @"\n" withString: @""]];;

  
  // Subject -- http://msdn.microsoft.com/en-us/library/ee157192(v=exchg.80).aspx
  if ([[self summary] length])
    [s appendFormat: @"<Subject xmlns=\"Calendar:\">%@</Subject>", [self summary]];
  
  // UID -- http://msdn.microsoft.com/en-us/library/ee159919(v=exchg.80).aspx
  if ([[self uid] length])
    [s appendFormat: @"<UID xmlns=\"Calendar:\">%@</UID>", [self uid]];
  
  // Sensitivity - FIXME
  [s appendFormat: @"<Sensitivity xmlns=\"Calendar:\">%d</Sensitivity>", 0];
  
  // BusyStatus -- http://msdn.microsoft.com/en-us/library/ee202290(v=exchg.80).aspx
  [s appendFormat: @"<BusyStatus xmlns=\"Calendar:\">%d</BusyStatus>", 0];
  
  // Reminder -- http://msdn.microsoft.com/en-us/library/ee219691(v=exchg.80).aspx

  return s;
}

//
//
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
}

@end
