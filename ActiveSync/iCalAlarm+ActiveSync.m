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
#import "iCalAlarm+ActiveSync.h"

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSString+misc.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <NGCards/iCalAlarm.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalTrigger.h>
#import <NGCards/NSCalendarDate+NGCards.h>

#include "NSDate+ActiveSync.h"

@implementation iCalAlarm (ActiveSync)

- (NSString *) activeSyncRepresentationInContext: (WOContext *) context
{
  NSMutableString *s;
  NSCalendarDate *nextAlarmDate;
  NSInteger delta;

  s = [NSMutableString string];

  nextAlarmDate = [self nextAlarmDate];
  delta = (int)(([[(iCalEvent *)parent startDate] timeIntervalSince1970] - [nextAlarmDate timeIntervalSince1970])/60);
  
  if ([parent isKindOfClass: [iCalEvent class]])
    {
      // don't send negative reminder - not supported
      if (delta > 0)
        [s appendFormat: @"<Reminder xmlns=\"Calendar:\">%d</Reminder>", (int)delta];
    }
  else
    {
      [s appendFormat: @"<ReminderTime xmlns=\"Task:\">%@</ReminderTime>", [nextAlarmDate activeSyncRepresentationInContext: context]];
    }
  
  return s;
}

- (void) takeActiveSyncValues: (NSDictionary *) theValues
                    inContext: (WOContext *) context
{
  iCalTrigger *trigger;
  id o;

  if ((o = [theValues objectForKey: @"Reminder"]))
    {
      // Outlook: if reminder is set to 0 minutes before starttime, save it as 1 minute since -> 0 minutes in not accepted by SOGo
      if ([o isEqualToString: @"0"])
        o = @"1";

      trigger = [iCalTrigger elementWithTag: @"TRIGGER"];
      [trigger setValueType: @"DURATION"];
      [self setTrigger: trigger];
      if (![self  action])
        [self setAction: @"DISPLAY"];

      // SOGo web ui only supports 1w but not 2w (custom reminder only supports min/hours/days)
      // 1week = -P1W
      // 2weeks > -PxD
      // xdays > -PxD
      // xhours -> -PTxH
      // xmin -> -PTxM
      if  ([o intValue] == 10080)
        [trigger setSingleValue: [NSString stringWithFormat: @"-P1W" ] forKey: @""];
      else
        {
          if (([o intValue] % 1440) == 0)
            [trigger setSingleValue: [NSString stringWithFormat: @"-P%dD", ([o intValue] / 1440)]  forKey: @""];
          else
            {
              if (([o intValue] % 60) == 0)
                [trigger setSingleValue: [NSString stringWithFormat: @"-PT%dH", ([o intValue] / 60)]  forKey: @""];
              else
                [trigger setSingleValue: [NSString stringWithFormat: @"-PT%@M", o]  forKey: @""];
            }
        }
    }
  else if ((o = [theValues objectForKey: @"ReminderTime"]))
    {
      o = [o calendarDate];
      trigger = [iCalTrigger elementWithTag: @"TRIGGER"];
      [trigger setValueType: @"DATE-TIME"];
      [trigger setSingleValue: [NSString stringWithFormat: @"%@Z", [o iCalFormattedDateTimeString]] forKey: @""];

      if  ((o = [theValues objectForKey: @"ReminderSet"]))
        {
          if ([o intValue] == 0)
             [trigger setValue: 0 ofAttribute: @"x-webstatus" to: @"triggered"];
        }

      [self setTrigger: trigger];
      if (![self  action])
        [self setAction: @"DISPLAY"];
    }
}

@end
