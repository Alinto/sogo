/* SOGoTaskObject+MAPIStore.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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
#include <mapistore/mapistore_nameid.h>

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
  // MAPIStoreDumpMessageProperties (properties);

  iCalCalendar *vCalendar;
  iCalToDo *vToDo;
  id value;
  SOGoUserDefaults *ud;
  iCalTimeZone *tz;
  iCalDateTime *date;
  NSString *status, *priority;
  NSCalendarDate *now;

  vToDo = [self component: YES secure: NO];
  vCalendar = [vToDo parent];
  [vCalendar setProdID: @"-//Inverse inc.//OpenChange+SOGo//EN"];

  // summary
  value = [properties
            objectForKey: MAPIPropertyKey (PR_NORMALIZED_SUBJECT_UNICODE)];
  if (value)
    [vToDo setSummary: value];

  // comment
  value = [properties
            objectForKey: MAPIPropertyKey (PR_BODY_UNICODE)];
  if (value)
    [vToDo setComment: value];

  // Location
  value = [properties objectForKey: MAPIPropertyKey (PidLidLocation)];
  if (value)
    [vToDo setLocation: value];

  /* created */
  value = [properties objectForKey: MAPIPropertyKey (PR_CREATION_TIME)];
  if (value)
    [vToDo setCreated: value];

  /* last-modified + dtstamp */
  value = [properties objectForKey: MAPIPropertyKey (PR_LAST_MODIFICATION_TIME)];
  if (value)
    {
      [vToDo setLastModified: value];
      [vToDo setTimeStampAsDate: value];
    }

  ud = [[SOGoUser userWithLogin: owner] userDefaults];
  tz = [iCalTimeZone timeZoneForName: [ud timeZoneName]];
  [vCalendar addTimeZone: tz];

  // start
  value = [properties objectForKey: MAPIPropertyKey (PidLidTaskStartDate)];
  if (value)
    {
      date = (iCalDateTime *) [vToDo uniqueChildWithTag: @"dtstart"];
      [date setTimeZone: tz];
      [date setDateTime: value];
    }

  // due
  value = [properties objectForKey: MAPIPropertyKey (PidLidTaskDueDate)];
  if (value)
    {
      date = (iCalDateTime *) [vToDo uniqueChildWithTag: @"due"];
      [date setTimeZone: tz];
      [date setDateTime: value];
    }

  // status
  value = [properties objectForKey: MAPIPropertyKey (PidLidTaskStatus)];
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
  value = [properties objectForKey: MAPIPropertyKey (PR_IMPORTANCE)];
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

  now = [NSCalendarDate date];
  if ([self isNew])
    {
      [vToDo setCreated: now];
    }
  [vToDo setTimeStampAsDate: now];

  // due
  // value = [properties objectForKey: MAPIPropertyKey (PR_DUE_DATE)];
  // if (value)
  //   {
  //     due = (iCalDateTime *) [vToDo uniqueChildWithTag: @"due"];
  //     [due setTimeZone: tz];
  //     [due setDateTime: value];
  //   }

  // MAPIStoreDumpMessageProperties (properties);
  ASSIGN (content, [vCalendar versitString]);

  [fullCalendar release];
  fullCalendar = nil;
  [safeCalendar release];
  safeCalendar = nil;
}

@end
