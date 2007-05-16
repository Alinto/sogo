/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id: SOGoFreeBusyObject.m 1052 2007-05-09 19:35:09Z wolfgang $

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalFreeBusy.h>
#import <NGCards/iCalPerson.h>

#import "common.h"

#import <SOGo/LDAPUserManager.h>
#import <SOGo/SOGoPermissions.h>

#import "SOGoFreeBusyObject.h"

@interface SOGoFreeBusyObject (PrivateAPI)
- (NSString *) iCalStringForFreeBusyInfos: (NSArray *) _infos
                                     from: (NSCalendarDate *) _startDate
                                       to: (NSCalendarDate *) _endDate;
@end

@implementation SOGoFreeBusyObject

- (NSString *) iCalString
{
  // for UI-X appointment viewer
  return [self contentAsString];
}

- (NSString *) contentAsString
{
  NSCalendarDate *today, *startDate, *endDate;
  NSTimeZone *timeZone;
  
  today = [[NSCalendarDate calendarDate] beginOfDay];
  timeZone = [[context activeUser] timeZone];
  [today setTimeZone: timeZone];

  startDate = [today dateByAddingYears: 0 months: 0 days: -14
                     hours: 0 minutes: 0 seconds: 0];
  endDate = [startDate dateByAddingYears: 0 months: 1 days: 0
                       hours: 0 minutes: 0 seconds: 0];

  return [self contentAsStringFrom: startDate to: endDate];
}

- (NSString *) contentAsStringFrom: (NSCalendarDate *) _startDate
                                to: (NSCalendarDate *) _endDate
{
  NSArray *infos;
  
  infos = [self fetchFreeBusyInfosFrom:_startDate to:_endDate];
  return [self iCalStringForFreeBusyInfos:infos from:_startDate to:_endDate];
}

- (NSArray *) fetchFreeBusyInfosFrom: (NSCalendarDate *) _startDate
                                  to: (NSCalendarDate *) _endDate
{
  id calFolder;
//   SoSecurityManager *sm;
  NSArray *infos;

  calFolder = [container lookupName: @"Calendar" inContext: nil acquire: NO];
//   sm = [SoSecurityManager sharedSecurityManager];
//   if (![sm validatePermission: SOGoPerm_FreeBusyLookup
//            onObject: calFolder
//            inContext: context])
    infos = [calFolder fetchFreeBusyInfosFrom: _startDate
                       to: _endDate];
//   else
//     {
//       infos = [NSArray new];
//       [infos autorelease];
//     }

  return infos;
}

/* Private API */
- (iCalFreeBusyType) _fbTypeForEventStatus: (NSNumber *) eventStatus
{
  unsigned int status;
  iCalFreeBusyType fbType;

  status = [eventStatus unsignedIntValue];
  if (status == 0)
    fbType = iCalFBBusyTentative;
  else if (status == 1)
    fbType = iCalFBBusy;
  else
    fbType = iCalFBFree;

  return fbType;    
}

- (iCalPerson *) iCalPersonWithUID: (NSString *) uid
{
  iCalPerson *person;
  LDAPUserManager *um;
  NSDictionary *contactInfos;

  um = [LDAPUserManager sharedUserManager];
  contactInfos = [um contactInfosForUserWithUIDorEmail: uid];

  person = [iCalPerson new];
  [person autorelease];
  [person setCn: [contactInfos objectForKey: @"cn"]];
  [person setEmail: [contactInfos objectForKey: @"c_email"]];

  return person;
}

- (NSString *) iCalStringForFreeBusyInfos: (NSArray *) _infos
                                     from: (NSCalendarDate *) _startDate
                                       to: (NSCalendarDate *) _endDate
{
  NSString *uid;
  NSEnumerator *events;
  iCalCalendar *calendar;
  iCalFreeBusy *freebusy;
  NSDictionary *info;
  iCalFreeBusyType type;

  uid = [[self container] login];

  calendar = [iCalCalendar groupWithTag: @"vcalendar"];
  [calendar setProdID: @"//Inverse groupe conseil/SOGo 0.9"];
  [calendar setVersion: @"2.0"];

  freebusy = [iCalFreeBusy groupWithTag: @"vfreebusy"];
  [freebusy addToAttendees: [self iCalPersonWithUID: uid]];
  [freebusy setTimeStampAsDate: [NSCalendarDate calendarDate]];
  [freebusy setStartDate: _startDate];
  [freebusy setEndDate: _endDate];

  /* ORGANIZER - strictly required but missing for now */

  /* ATTENDEE */
//   person = [self iCalPersonWithUid: uid];
//   [person setTag: @"ATTENDEE"];
//   [ms appendString: [person versitString]];

  /* FREEBUSY */
  events = [_infos objectEnumerator];
  info = [events nextObject];
  while (info)
    {
      if ([[info objectForKey: @"isopaque"] boolValue])
        {
          type = [self _fbTypeForEventStatus: [info objectForKey: @"status"]];
          [freebusy addFreeBusyFrom: [info objectForKey: @"startDate"]
                    to: [info objectForKey: @"endDate"]
                    type: type];
        }
      info = [events nextObject];
    }

  [calendar setUniqueChild: freebusy];

  return [calendar versitString];
}

/* deliver content without need for view method */

- (id) GETAction: (id)_ctx
{
  WOResponse *r;
  NSData     *contentData;

  contentData = [[self contentAsString] dataUsingEncoding: NSUTF8StringEncoding];

  r = [(WOContext *) _ctx response];
  [r setHeader: @"text/calendar" forKey: @"content-type"];
  [r setContent: contentData];
  [r setStatus: 200];

  return r;
}

@end
