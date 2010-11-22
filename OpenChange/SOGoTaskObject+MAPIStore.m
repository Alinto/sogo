/* SOGoTaskObject+MAPIStore.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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

#include <stdbool.h>
#include <gen_ndr/exchange.h>

#import <Foundation/NSDictionary.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSObject+Logs.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalTimeZone.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import "MAPIStoreTypes.h"

#import "SOGoTaskObject+MAPIStore.h"

@implementation SOGoTaskObject (MAPIStoreMessage)

/* TODO: merge with events */
- (void) setMAPIProperties: (NSDictionary *) properties
{
  MAPIStoreDumpMessageProperties (properties);

  /* --sendtask --dtstart="2008-11-01 18:00:00" --cardname="openchangeclient"
     --importance=HIGH --taskstatus=COMPLETED --body="my new task"

     0x0e070003 (PR_MESSAGE_FLAGS): 9 (NSIntNumber)
     0x0e1d001f (PR_NORMALIZED_SUBJECT_UNICODE): openchangeclient (GSCBufferString)
     0x1000001f (PR_BODY_UNICODE): my new task (GSCBufferString)
     0x30070040 (PR_CREATION_TIME): 2010-11-19 16:30:29 -0500 (NSCalendarDate)
     0x30080040 (PR_LAST_MODIFICATION_TIME): 2010-11-19 16:30:29 -0500 (NSCalendarDate)
     0x811f0040 (unknown): 2008-11-01 18:00:00 -0400 (NSCalendarDate)
     0x811e0040 (unknown): 2008-11-01 18:00:00 -0400 (NSCalendarDate)

     0x0e790003 (PR_TRUST_SENDER): 1 (NSIntNumber)
     0x0ff70003 (PR_ACCESS_LEVEL): 1 (NSIntNumber)
     0x001a001e (PR_MESSAGE_CLASS): IPM.Task (GSCBufferString)
     0x00360003 (PR_SENSITIVITY): 0 (NSIntNumber)
     0x10f3001e (PR_URL_COMP_NAME): No Subject.EML (GSCBufferString)
     0x81200003 (unknown): 2 (NSIntNumber)
     0x00170003 (PR_IMPORTANCE): 2 (NSIntNumber)
     0x66a10003 (PR_LOCALE_ID): 4095 (NSIntNumber)
     0x0ff40003 (PR_ACCESS): 3 (NSIntNumber)
     0x3ff10003 (PR_MESSAGE_LOCALE_ID): 4095 (NSIntNumber)
     0x0e1b000b (PR_HASATTACH): 0 (NSIntNumber)
     0x67090040 (PR_LOCAL_COMMIT_TIME): 2010-11-19 16:30:29 -0500 (NSCalendarDate)
     0x0070001f (PR_CONVERSATION_TOPIC_UNICODE): openchangeclient (GSCBufferString)
     0x0e62000b (PR_URL_COMP_NAME_SET): 0 (NSIntNumber)

     status:
     0x81200003 (unknown): 0 (NSIntNumber)
     0x0070001f (PR_CONVERSATION_TOPIC_UNICODE): openchangeclientNOTSTARTED (GSCBufferString)

     0x81200003 (unknown): 1 (NSIntNumber)
     0x0070001f (PR_CONVERSATION_TOPIC_UNICODE): openchangeclientPROGRESS (GSCBufferString)

     0x81200003 (unknown): 2 (NSIntNumber)
     0x0070001f (PR_CONVERSATION_TOPIC_UNICODE): openchangeclientCOMPLETED (GSCBufferString)

     0x81200003 (unknown): 3 (NSIntNumber)
     0x0070001f (PR_CONVERSATION_TOPIC_UNICODE): openchangeclientWAITING (GSCBufferString)

     0x81200003 (unknown): 4 (NSIntNumber)
     0x0070001f (PR_CONVERSATION_TOPIC_UNICODE): openchangeclientDEFERRED (GSCBufferString)

     importance:
     0x00170003 (PR_IMPORTANCE): 0 (NSIntNumber)
     0x0070001f (PR_CONVERSATION_TOPIC_UNICODE): openchangeclientLOW (GSCBufferString)

     0x00170003 (PR_IMPORTANCE): 1 (NSIntNumber)
     0x0070001f (PR_CONVERSATION_TOPIC_UNICODE): openchangeclientNORMAL (GSCBufferString)
     
     0x00170003 (PR_IMPORTANCE): 2 (NSIntNumber)
     0x0070001f (PR_CONVERSATION_TOPIC_UNICODE): openchangeclientHIGH (GSCBufferString)
  */

  iCalCalendar *vCalendar;
  iCalToDo *vToDo;
  id value;
  SOGoUserDefaults *ud;
  iCalTimeZone *tz;
  iCalDateTime *date;
  NSString *status, *priority;

  vToDo = [self component: YES secure: NO];
  vCalendar = [vToDo parent];
  [vCalendar setProdID: @"-//Inverse inc.//OpenChange+SOGo//EN"];

  // summary
  value = [properties
            objectForKey: MAPIPropertyNumber (PR_NORMALIZED_SUBJECT_UNICODE)];
  if (value)
    [vToDo setSummary: value];

  // comment
  value = [properties
            objectForKey: MAPIPropertyNumber (PR_BODY_UNICODE)];
  if (value)
    [vToDo setComment: value];

  // Location
  value = [properties objectForKey: MAPIPropertyNumber (0x810c001f)];
  if (value)
    [vToDo setLocation: value];

  /* created */
  value = [properties objectForKey: MAPIPropertyNumber (PR_CREATION_TIME)];
  if (value)
    [vToDo setCreated: value];

  /* last-modified + dtstamp */
  value = [properties objectForKey: MAPIPropertyNumber (PR_LAST_MODIFICATION_TIME)];
  if (value)
    {
      [vToDo setLastModified: value];
      [vToDo setTimeStampAsDate: value];
    }

  ud = [[SOGoUser userWithLogin: owner] userDefaults];
  tz = [iCalTimeZone timeZoneForName: [ud timeZoneName]];
  [vCalendar addTimeZone: tz];

  // start
  value = [properties objectForKey: MAPIPropertyNumber (0x811e0040)];
  if (value)
    {
      date = (iCalDateTime *) [vToDo uniqueChildWithTag: @"dtstart"];
      [date setTimeZone: tz];
      [date setDateTime: value];
    }

  // due
  value = [properties objectForKey: MAPIPropertyNumber (0x811f0040)];
  if (value)
    {
      date = (iCalDateTime *) [vToDo uniqueChildWithTag: @"due"];
      [date setTimeZone: tz];
      [date setDateTime: value];
    }

  // status
  value = [properties objectForKey: MAPIPropertyNumber (0x81200003)];
  if (value)
    {
      switch ([value intValue])
        {
        case 1: status = @"IN-PROCESS"; break;
        case 2: status = @"COMPLETED"; break;
        default: status = @"NEEDS-ACTION";
        }
      [vToDo setStatus: status];
    }

  // priority
  value = [properties objectForKey: MAPIPropertyNumber (PR_IMPORTANCE)];
  if (value)
    {
      switch ([value intValue])
        {
        case 0: // Low
          priority = @"9";
          break;
        case 2: // High
          priority = @"1";
          break;
        default: // Normal
          priority = @"5";
        }
    }
  else
    priority = @"0"; // None
  [vToDo setPriority: priority];

  // due
  // value = [properties objectForKey: MAPIPropertyNumber (PR_DUE_DATE)];
  // if (value)
  //   {
  //     due = (iCalDateTime *) [vToDo uniqueChildWithTag: @"due"];
  //     [due setTimeZone: tz];
  //     [due setDateTime: value];
  //   }

  // MAPIStoreDumpMessageProperties (properties);

  [self saveContentString: [vCalendar versitString]];
}

@end
