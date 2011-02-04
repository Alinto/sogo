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
#include <mapistore/mapistore_nameid.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSObject+Logs.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalTimeZone.h>

#import <SOGo/SOGoGCSFolder.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import <GDLContentStore/GCSFolder.h>

#import "MAPIStoreTypes.h"

#import "SOGoAppointmentObject+MAPIStore.h"


@implementation SOGoAppointmentObject (MAPIStoreMessage)

/* TODO: merge with tasks */
- (void) setMAPIProperties: (NSDictionary *) properties
{
  iCalCalendar *vCalendar;
  iCalEvent *vEvent;
  id value;
  SOGoUserDefaults *ud;
  NSCalendarDate *now;
  iCalTimeZone *tz;
  iCalDateTime *start, *end;

  [self logWithFormat: @"event props:"];
  MAPIStoreDumpMessageProperties (properties);

#if 1
  // We *ALWAYS* use the MAPIContent - as we do NOT want
  // to modify the real object since it'll confuse the
  // SOGo calendaring scheduling code.
  if (![self MAPIContent])
    {
      vEvent = [self component: YES secure: NO];
      vCalendar = [vEvent parent];
      [vCalendar setProdID: @"-//Inverse inc.//OpenChange+SOGo//EN"];

      [self setMAPIContent: [vCalendar versitString]];
    }

  // FIXME: this will NOT work with recurring events
  vCalendar = [iCalCalendar parseSingleFromSource: [self MAPIContent]];
  vEvent = [[vCalendar events] objectAtIndex: 0];
#else
  vEvent = [self component: YES secure: NO];
  vCalendar = [vEvent parent];
#endif

  // summary
  value = [properties
            objectForKey: MAPIPropertyKey (PR_NORMALIZED_SUBJECT_UNICODE)];
  if (value)
    [vEvent setSummary: value];

  // Location
  value = [properties objectForKey: MAPIPropertyKey (PidLidLocation)];
  if (value)
    [vEvent setLocation: value];

  ud = [[SOGoUser userWithLogin: owner] userDefaults];
  tz = [iCalTimeZone timeZoneForName: [ud timeZoneName]];
  [vCalendar addTimeZone: tz];

  // start
  value = [properties objectForKey: MAPIPropertyKey (PR_START_DATE)];
  if (!value)
    value = [properties objectForKey: MAPIPropertyKey (PidLidAppointmentStartWhole)];
  if (value)
    {
      start = (iCalDateTime *) [vEvent uniqueChildWithTag: @"dtstart"];
      [start setTimeZone: tz];
      [start setDateTime: value];
    }

  // end
  value = [properties objectForKey: MAPIPropertyKey (PR_END_DATE)];
  if (!value)
    value = [properties objectForKey: MAPIPropertyKey (PidLidAppointmentEndWhole)];
  if (value)
    {
      end = (iCalDateTime *) [vEvent uniqueChildWithTag: @"dtend"];
      [end setTimeZone: tz];
      [end setDateTime: value];
    }

  now = [NSCalendarDate date];
  if ([self isNew])
    {
      [vEvent setCreated: now];
    }
  [vEvent setTimeStampAsDate: now];

  // Organizer and attendees
  value = [properties objectForKey: @"recipients"];

  if (value)
    {
      NSArray *recipients;
      NSDictionary *dict;
      iCalPerson *person;
      int i;


      dict = [[context activeUser] primaryIdentity];
      person = [iCalPerson new];
      [person setCn: [dict objectForKey: @"fullName"]];
      [person setEmail: [dict objectForKey: @"email"]];
      [vEvent setOrganizer: person];
      [person release];

      recipients = [value objectForKey: @"to"];
      
      for (i = 0; i < [recipients count]; i++)
	{
	  dict = [recipients objectAtIndex: i];
	  person = [iCalPerson new];

	  [person setCn: [dict objectForKey: @"fullName"]];
	  [person setEmail: [dict objectForKey: @"email"]];
	  [person setParticipationStatus: iCalPersonPartStatNeedsAction];
	  [person setRsvp: @"TRUE"];
	  [person setRole: @"REQ-PARTICIPANT"]; 

	  // FIXME: We must NOT always rely on this
	  if (![dict objectForKey: @"x500dn"]
              && ![vEvent isAttendee: [person rfc822Email]])
	    [vEvent addToAttendees: person];

	  [person release];
	}
    }


  // MAPIStoreDumpMessageProperties (properties);

#if 1
  // We set the new MAPI content, but we overwrite -MAPISave and reuse the 
  // MAPI content in order to trigger SOGo's calendar scheduling code.
  [self setMAPIContent: [vCalendar versitString]];
#else
  ASSIGN(content, [vCalendar versitString]);
  
  [fullCalendar release];
  fullCalendar = nil;
  [safeCalendar release];
  safeCalendar = nil;
#endif
}

#if 1
- (void) MAPISave
{
  iCalCalendar *calendar;
  iCalEvent *event;

  calendar = [iCalCalendar parseSingleFromSource: [self MAPIContent]];
  event = [[calendar events] objectAtIndex: 0];

  [self logWithFormat: @"-MAPISave in SOGoAppointmentObject+MAPIStore"];
  
  [self saveComponent: event];

  /* ideally, this should be performed from saveComponent: */
  [safeCalendar release];
  safeCalendar = nil;
  [fullCalendar release];
  fullCalendar = nil;
  [originalCalendar release];
  originalCalendar = nil;
}
#endif

@end
