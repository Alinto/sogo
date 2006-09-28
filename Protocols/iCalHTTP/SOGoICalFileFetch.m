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

#import <NGObjWeb/WODirectAction.h>
#import "SOGoICalHTTPHandler.h"
#import <SoObjects/Appointments/SOGoAppointmentFolder.h>

#import <NGCards/iCalEvent.h>

#import "common.h"

@interface SOGoICalFileFetch : WODirectAction
{
}

@end

@implementation SOGoICalFileFetch

/* clientObject */

- (id)clientObject {
  return [[super clientObject] aptFolderInContext:[self context]];
}

/* actions */

- (id)defaultAction {
  NSAutoreleasePool *pool;
  WOResponse      *response;
  iCalEvent *event;
  NSEnumerator    *e;
  NSArray         *events;

  response = [[self context] response];
  [response setHeader:@"text/plain" forKey:@"content-type"];

  pool = [[NSAutoreleasePool alloc] init];
  
  /* vcal preamble */
  
  [response appendContentString:@"BEGIN:VCALENDAR\r\nMETHOD:REQUEST\r\n"];
  [response appendContentString:@"PRODID:SOGo/0.9\r\n"];
  [response appendContentString:@"VERSION:2.0\r\n"];

  /* add events */
  
  events = [[self clientObject] fetchAllSOGoAppointments];
  [self debugWithFormat:@"generate %d appointments ...", [events count]];
  e = [events objectEnumerator];
  while ((event = [e nextObject]) != nil)
    [response appendContentString: [event versitString]];

  /* vcal postamble */
  [response appendContentString:@"END:VCALENDAR\r\n"];
  
  [pool release];
  return response;
}

@end /* SOGoICalFileFetch */
