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
// $Id: SOGoFreeBusyObject.m 675 2005-07-06 20:56:09Z znek $

#include "SOGoFreeBusyObject.h"
#include "common.h"
#include <SOGo/AgenorUserManager.h>
#include <NGiCal/NGiCal.h>
#include <NGiCal/iCalRenderer.h>

@interface NSDate(UsedPrivates)
- (NSString *)icalString; // declared in NGiCal
@end

@interface SOGoFreeBusyObject (PrivateAPI)
- (NSString *)iCalStringForFreeBusyInfos:(NSArray *)_infos
  from:(NSCalendarDate *)_startDate
  to:(NSCalendarDate *)_endDate;
@end

@implementation SOGoFreeBusyObject

- (NSString *)iCalString {
  // for UI-X appointment viewer
  return [self contentAsString];
}

- (NSString *)contentAsString {
  NSCalendarDate *startDate, *endDate;
  
  startDate = [[[NSCalendarDate calendarDate] mondayOfWeek] beginOfDay];
  endDate   = [startDate dateByAddingYears:0
                                    months:0
                                      days:7
                                     hours:23
                                   minutes:59
                                   seconds:59];
  return [self contentAsStringFrom:startDate to:endDate];
}

- (NSString *)contentAsStringFrom:(NSCalendarDate *)_startDate
  to:(NSCalendarDate *)_endDate
{
  NSArray *infos;
  
  infos = [self fetchFreebusyInfosFrom:_startDate to:_endDate];
  return [self iCalStringForFreeBusyInfos:infos from:_startDate to:_endDate];
}

- (NSArray *)fetchFreebusyInfosFrom:(NSCalendarDate *)_startDate
  to:(NSCalendarDate *)_endDate
{
  id                userFolder, calFolder;
  NSArray           *infos;
  AgenorUserManager *um;
  NSString          *email;
  NSMutableArray    *filtered;
  unsigned          i, count;

  userFolder = [self container];
  calFolder  = [userFolder lookupName:@"Calendar" inContext:nil acquire:NO];
  infos      = [calFolder fetchFreebusyInfosFrom:_startDate to:_endDate];
  um         = [AgenorUserManager sharedUserManager];
  email      = [um getEmailForUID:[userFolder login]];
  count      = [infos count];
  filtered   = [[[NSMutableArray alloc] initWithCapacity:count] autorelease];

  for (i = 0; i < count; i++) {
    NSDictionary *info;
    NSArray      *partmails;
    unsigned     p, pCount;

    info      = [infos objectAtIndex:i];
    partmails = [[info objectForKey:@"partmails"]
                       componentsSeparatedByString:@"\n"];
    pCount    = [partmails count];
    for (p = 0; p < pCount; p++) {
      NSString *pEmail;
      
      pEmail = [partmails objectAtIndex:p];
      if ([pEmail isEqualToString:email]) {
        NSArray  *partstates;
        NSString *state;

        partstates = [[info objectForKey:@"partstates"]
                            componentsSeparatedByString:@"\n"];
        state      = [partstates objectAtIndex:p];
        if ([state intValue] == iCalPersonPartStatAccepted) {
          // TODO: add tentative apts as well, but put state and email
          //       into info
          [filtered addObject:info];
        }
        break;
      }
    }
  }
  return filtered;
}

/* Private API */

- (NSString *)iCalStringForFreeBusyInfos:(NSArray *)_infos
  from:(NSCalendarDate *)_startDate
  to:(NSCalendarDate *)_endDate
{
  AgenorUserManager *um;
  NSMutableString   *ms;
  NSString          *uid, *x;
  unsigned          i, count;

  um  = [AgenorUserManager sharedUserManager];
  uid = [[self container] login];
  ms  = [[[NSMutableString alloc] initWithCapacity:128] autorelease];

  /* preamble */
  [ms appendString:@"BEGIN:VCALENDAR\r\n"];
  [ms appendString:@"BEGIN:VFREEBUSY\r\n"];
  /* PRODID */
  [ms appendString:@"PRODID:SOGo/0.9\r\n"];
  /* VERSION */
  [ms appendString:@"VERSION:2.0\r\n"];
  /* DTSTAMP */
  [ms appendString:@"DTSTAMP:"];
  [ms appendString:[[NSCalendarDate calendarDate] icalString]];
  [ms appendString:@"\r\n"];
  
  /* ORGANIZER - strictly required but missing for now */

  /* ATTENDEE */
  [ms appendString:@"ATTENDEE"];
  if ((x = [um getCNForUID:uid])) {
    [ms appendString:@";CN=\""];
    [ms appendString:[x iCalDQUOTESafeString]];
    [ms appendString:@"\""];
  }
  if ((x = [um getEmailForUID:uid])) {
    [ms appendString:@":"]; /* sic! */
    [ms appendString:[x iCalSafeString]];
  }
  [ms appendString:@"\r\n"];

  /* DTSTART */
  [ms appendString:@"DTSTART:"];
  [ms appendString:[_startDate icalString]];
  [ms appendString:@"\r\n"];

  /* DTEND */
  [ms appendString:@"DTEND:"];
  [ms appendString:[_endDate icalString]];
  [ms appendString:@"\r\n"];

  /* FREEBUSY */
  count = [_infos count];
  for (i = 0; i < count; i++) {
    NSDictionary   *info;
    NSCalendarDate *startDate, *endDate;

    info      = [_infos objectAtIndex:i];
    startDate = [info objectForKey:@"startDate"];
    endDate   = [info objectForKey:@"endDate"];

    /* NOTE: currently we cannot differentiate between all the types defined
     *       in RFC2445, Section 4.2.9.
     *       These are: FREE" / "BUSY" / "BUSY-UNAVAILABLE" / "BUSY-TENTATIVE"
     */
    
    [ms appendString:@"FREEBUSY;FBTYPE=BUSY:"];
    [ms appendString:[startDate icalString]];
    [ms appendString:@"/"];
    [ms appendString:[endDate icalString]];
    [ms appendString:@"\r\n"];
  }

  /* postamble */
  [ms appendString:@"END:VFREEBUSY\r\n"];
  [ms appendString:@"END:VCALENDAR\r\n"];
  return ms;
}

/* deliver content without need for view method */

- (id)GETAction:(id)_ctx {
  WOResponse *r;
  NSData     *contentData;

  contentData = [[self contentAsString] dataUsingEncoding:NSUTF8StringEncoding];

  r = [(WOContext *)_ctx response];
  [r setHeader:@"text/calendar" forKey:@"content-type"];
  [r setContent:contentData];
  [r setStatus:200];
  return r;
}

@end
