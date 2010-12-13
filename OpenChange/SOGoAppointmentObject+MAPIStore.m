/* SOGoAppointmentObject+MAPIStore.m - this file is part of SOGo
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

#import "SOGoAppointmentObject+MAPIStore.h"

@implementation SOGoAppointmentObject (MAPIStoreMessage)

/* TODO: merge with tasks */
- (void) setMAPIProperties: (NSDictionary *) properties
{
  /* --dtstart=2007-06-01\ 22:00:00 --dtend=2007-06-01\ 22:35:00
     --busystatus=FREE --location=Home --subject=Check\ the\ Junk\ folder

     -> 
     2010-11-19 14:55:06.504 samba[13652] message properties (31):
     2010-11-19 14:55:06.504 samba[13652]   0x810c001f (unknown): Home (GSCBufferString)
     2010-11-19 14:55:06.505 samba[13652]   0x00600040 (PR_START_DATE): 2007-06-01 22:00:00 -0400 (NSGDate)
     2010-11-19 14:55:06.504 samba[13652]   0x00610040 (PR_END_DATE): 2007-06-01 22:35:00 -0400 (NSGDate)
     2010-11-19 14:55:06.505 samba[13652]   0x30080040 (PR_LAST_MODIFICATION_TIME): 2010-11-19 14:55:06 -0500 (NSGDate)
     2010-11-19 14:55:06.504 samba[13652]   0x30070040 (PR_CREATION_TIME): 2010-11-19 14:55:06 -0500 (NSGDate)
     2010-11-19 14:55:06.504 samba[13652]   0x0e1d001f (PR_NORMALIZED_SUBJECT_UNICODE): Check the Junk folder (GSCBufferString)

     2010-11-19 14:55:06.504 samba[13652]   0x81980040 (unknown): 2007-06-01 22:35:00 -0400 (NSGDate)
     2010-11-19 14:55:06.504 samba[13652]   0x0e1b000b (PR_HASATTACH): 0 (NSIntNumber)
     2010-11-19 14:55:06.504 samba[13652]   0x3ff10003 (PR_MESSAGE_LOCALE_ID): 4095 (NSIntNumber)
     2010-11-19 14:55:06.504 samba[13652]   0x0ff40003 (PR_ACCESS): 3 (NSIntNumber)
     2010-11-19 14:55:06.504 samba[13652]   0x0070001f (PR_CONVERSATION_TOPIC_UNICODE): Check the Junk folder (GSCBufferString)
     2010-11-19 14:55:06.504 samba[13652]   0x81e90003 (unknown): 30 (NSIntNumber)
     2010-11-19 14:55:06.504 samba[13652]   0x10f3001e (PR_URL_COMP_NAME): No Subject.EML (GSCBufferString)
     2010-11-19 14:55:06.504 samba[13652]   0x0ff70003 (PR_ACCESS_LEVEL): 1 (NSIntNumber)
     2010-11-19 14:55:06.504 samba[13652]   0x81990040 (unknown): 2007-06-01 22:00:00 -0400 (NSGDate)
     2010-11-19 14:55:06.504 samba[13652]   0x8224000b (unknown): 0 (NSIntNumber)
     2010-11-19 14:55:06.504 samba[13652]   0x82410003 (unknown): 0 (NSIntNumber)
     2010-11-19 14:55:06.504 samba[13652]   0x0e62000b (PR_URL_COMP_NAME_SET): 0 (NSIntNumber)
     2010-11-19 14:55:06.504 samba[13652]   0x66a10003 (PR_LOCALE_ID): 4095 (NSIntNumber)
     2010-11-19 14:55:06.504 samba[13652]   0x00170003 (PR_IMPORTANCE): 1 (NSIntNumber)
     2010-11-19 14:55:06.504 samba[13652]   0x818a0040 (unknown): 2007-06-01 22:35:00 -0400 (NSGDate)
     2010-11-19 14:55:06.504 samba[13652]   0x81900003 (PR_EMS_AB_INCOMING_MSG_SIZE_LIMIT): 0 (NSIntNumber)
     2010-11-19 14:55:06.504 samba[13652]   0x0e070003 (PR_MESSAGE_FLAGS): 1 (NSIntNumber)
     2010-11-19 14:55:06.505 samba[13652]   0x001a001e (PR_MESSAGE_CLASS): IPM.Appointment (GSCBufferString)
     2010-11-19 14:55:06.505 samba[13652]   0x00360003 (PR_SENSITIVITY): 0 (NSIntNumber)
     2010-11-19 14:55:06.505 samba[13652]   0x0e790003 (PR_TRUST_SENDER): 1 (NSIntNumber)
     2010-11-19 14:55:06.505 samba[13652]   0x67090040 (PR_LOCAL_COMMIT_TIME): 2010-11-19 14:55:06 -0500 (NSGDate)
     2010-11-19 14:55:06.505 samba[13652]   0x818f0040 (unknown): 2007-06-01 22:00:00 -0400 (NSGDate)
     2010-11-19 14:55:06.505 samba[13652]   0x81930003 (unknown): 0 (NSIntNumber) */
  iCalCalendar *vCalendar;
  iCalEvent *vEvent;
  id value;
  SOGoUserDefaults *ud;
  iCalTimeZone *tz;
  iCalDateTime *start, *end;

  [self logWithFormat: @"event props:"];
  MAPIStoreDumpMessageProperties (properties);

  vEvent = [self component: YES secure: NO];
  vCalendar = [vEvent parent];
  [vCalendar setProdID: @"-//Inverse inc.//OpenChange+SOGo//EN"];

  // summary
  value = [properties
            objectForKey: MAPIPropertyKey (PR_NORMALIZED_SUBJECT_UNICODE)];
  if (value)
    [vEvent setSummary: value];

  // Location
  value = [properties objectForKey: MAPIPropertyKey (0x810c001f)];
  if (value)
    [vEvent setLocation: value];

  ud = [[SOGoUser userWithLogin: owner] userDefaults];
  tz = [iCalTimeZone timeZoneForName: [ud timeZoneName]];
  [vCalendar addTimeZone: tz];

  // start
  value = [properties objectForKey: MAPIPropertyKey (PR_START_DATE)];
  if (value)
    {
      start = (iCalDateTime *) [vEvent uniqueChildWithTag: @"dtstart"];
      [start setTimeZone: tz];
      [start setDateTime: value];
    }

  // end
  value = [properties objectForKey: MAPIPropertyKey (PR_END_DATE)];
  if (value)
    {
      end = (iCalDateTime *) [vEvent uniqueChildWithTag: @"dtend"];
      [end setTimeZone: tz];
      [end setDateTime: value];
    }

  // MAPIStoreDumpMessageProperties (properties);
  ASSIGN (content, [vCalendar versitString]);
}

@end
