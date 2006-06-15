/*
  Copyright (C) 2004 SKYRIX Software AG

  This file is part of OpenGroupware.org.

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

#include "SOGoAppointmentICalRenderer.h"
#include "SOGoAppointment.h"
#include <NGiCal/NGiCal.h>
#include <NGiCal/iCalRenderer.h>
#include "common.h"

// TODO: the basic renderer should be part of NGiCal

@interface NSDate(UsedPrivates)
- (NSString *)icalString; // declared in NGiCal
@end

@implementation SOGoAppointmentICalRenderer

static SOGoAppointmentICalRenderer *renderer = nil;

/* assume length of 1K - reasonable ? */
static unsigned DefaultICalStringCapacity = 1024;

+ (id)sharedAppointmentRenderer {
  if (renderer == nil)
    renderer = [[self alloc] init];
  return renderer;
}

/* renderer */

- (void)addPreambleForAppointment:(SOGoAppointment *)_apt
  toString:(NSMutableString *)s
{
  iCalCalendar *calendar;
  NSString     *x;

  calendar = [_apt calendar];
  
  [s appendString:@"BEGIN:VCALENDAR\r\n"];
  [s appendString:@"METHOD:"];
  if((x = [calendar method]))
    [s appendString:[x iCalSafeString]];
  else
    [s appendString:@"REQUEST"];
  [s appendString:@"\r\n"];
  
  [s appendString:@"PRODID:"];
  [s appendString:[calendar isNotNull] ? [calendar prodId] : @"SOGo/0.9"];
  [s appendString:@"\r\n"];
  
  [s appendString:@"VERSION:"];
  [s appendString:[calendar isNotNull] ? [calendar version] : @"2.0"];
  [s appendString:@"\r\n"];
}
- (void)addPostambleForAppointment:(SOGoAppointment *)_apt
  toString:(NSMutableString *)s
{
  [s appendString:@"END:VCALENDAR\r\n"];
}

- (void)addOrganizer:(iCalPerson *)p toString:(NSMutableString *)s {
  NSString *x;

  if (![p isNotNull]) return;
  
  [s appendString:@"ORGANIZER;CN=\""];
  if ((x = [p cn]))
    [s appendString:[x iCalDQUOTESafeString]];
  
  [s appendString:@"\""];
  if ((x = [p email])) {
    [s appendString:@":"]; /* sic! */
    [s appendString:[x iCalSafeString]];
  }
  [s appendString:@"\r\n"];
}

- (void)addAttendees:(NSArray *)persons toString:(NSMutableString *)s {
  unsigned   i, count;
  iCalPerson *p;

  count   = [persons count];
  for (i = 0; i < count; i++) {
    NSString *x;
    
    p = [persons objectAtIndex:i];
    [s appendString:@"ATTENDEE;"];
    
    if ((x = [p role])) {
      [s appendString:@"ROLE="];
      [s appendString:[x iCalSafeString]];
      [s appendString:@";"];
    }
    
    if ((x = [p partStat])) {
      if ([p participationStatus] != iCalPersonPartStatNeedsAction) {
        [s appendString:@"PARTSTAT="];
        [s appendString:[x iCalSafeString]];
        [s appendString:@";"];
      }
    }

    [s appendString:@"CN=\""];
    if ((x = [p cnWithoutQuotes])) {
      [s appendString:[x iCalDQUOTESafeString]];
    }
    [s appendString:@"\""];
    if ([(x = [p email]) isNotNull]) {
      [s appendString:@":"]; /* sic! */
      [s appendString:[x iCalSafeString]];
    }
    [s appendString:@"\r\n"];
  }
}

- (void)addVEventForAppointment:(SOGoAppointment *)_apt 
  toString:(NSMutableString *)s
{
  iCalEvent *event;

  event = [_apt event];
  
  [s appendString:@"BEGIN:VEVENT\r\n"];
  
  [s appendString:@"SUMMARY:"];
  [s appendString:[[_apt summary] iCalSafeString]];
  [s appendString:@"\r\n"];
  if ([_apt hasLocation]) {
    [s appendString:@"LOCATION:"];
    [s appendString:[[_apt location] iCalSafeString]];
    [s appendString:@"\r\n"];
  }
  [s appendString:@"UID:"];
  [s appendString:[_apt uid]];
  [s appendString:@"\r\n"];
  
  [s appendString:@"DTSTART:"];
  [s appendString:[[_apt startDate] icalString]];
  [s appendString:@"\r\n"];
  
  if ([_apt hasEndDate]) {
    [s appendString:@"DTEND:"];
    [s appendString:[[_apt endDate] icalString]];
    [s appendString:@"\r\n"];
  }
  if ([_apt hasDuration]) {
    [s appendString:@"DURATION:"];
    [s appendString:[event duration]];
    [s appendString:@"\r\n"];
  }
  if([_apt hasPriority]) {
    [s appendString:@"PRIORITY:"];
    [s appendString:[_apt priority]];
    [s appendString:@"\r\n"];
  }
  if([_apt hasCategories]) {
    NSString *catString;

    catString = [[_apt categories] componentsJoinedByString:@","];
    [s appendString:@"CATEGORIES:"];
    [s appendString:catString];
    [s appendString:@"\r\n"];
  }
  if([_apt hasComment]) {
    [s appendString:@"DESCRIPTION:"]; /* this is what iCal.app does */
    [s appendString:[[_apt comment] iCalSafeString]];
    [s appendString:@"\r\n"];
  }

  [s appendString:@"STATUS:"];
  [s appendString:[_apt status]];
  [s appendString:@"\r\n"];

  [s appendString:@"TRANSP:"];
  [s appendString:[_apt transparency]];
  [s appendString:@"\r\n"];

  [s appendString:@"CLASS:"];
  [s appendString:[_apt accessClass]];
  [s appendString:@"\r\n"];
  
  /* recurrence rules */
  if ([_apt hasRecurrenceRule]) {
    [s appendString:@"RRULE:"];
    [s appendString:[[_apt recurrenceRule] iCalRepresentation]];
    [s appendString:@"\r\n"];
  }

  [self addOrganizer:[_apt organizer] toString:s];
  [self addAttendees:[_apt attendees] toString:s];
  
  /* postamble */
  [s appendString:@"END:VEVENT\r\n"];
}

- (BOOL)isValidAppointment:(SOGoAppointment *)_apt {
  if (![_apt isNotNull])
    return NO;
  
  if ([[_apt uid] length] == 0) {
    [self warnWithFormat:@"got apt without uid, rejecting iCal generation: %@", 
            _apt];
    return NO;
  }
  if ([[[_apt startDate] icalString] length] == 0) {
    [self warnWithFormat:@"got apt without start date, "
            @"rejecting iCal generation: %@",
            _apt];
    return NO;
  }
  
  return YES;
}

- (NSString *)vEventStringForAppointment:(SOGoAppointment *)_apt {
  NSMutableString *s;
  
  if (![self isValidAppointment:_apt])
    return nil;
  
  s = [NSMutableString stringWithCapacity:DefaultICalStringCapacity];
  [self addVEventForAppointment:_apt toString:s];
  return s;
}

- (NSString *)stringForAppointment:(SOGoAppointment *)_apt {
  NSMutableString *s;
  
  if (![self isValidAppointment:_apt])
    return nil;
  
  s = [NSMutableString stringWithCapacity:DefaultICalStringCapacity];
  [self addPreambleForAppointment:_apt  toString:s];
  [self addVEventForAppointment:_apt    toString:s];
  [self addPostambleForAppointment:_apt toString:s];
  return s;
}

@end /* SOGoAppointmentICalRenderer */
