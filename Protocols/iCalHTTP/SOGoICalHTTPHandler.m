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

#include "SOGoICalHTTPHandler.h"
#include <SoObjects/Appointments/SOGoAppointmentFolder.h>
#include "common.h"
#include <NGObjWeb/WOContext+SoObjects.h>

@implementation SOGoICalHTTPHandler

- (void)dealloc {
  [super dealloc];
}

/* context */

- (WOContext *)context {
  return [[WOApplication application] context];
}

/* clientObject */

- (SOGoAppointmentFolder *)aptFolderInContext:(id)_ctx {
  /*
    The handler object is _not_ a method, its just a regular object
    itself! (because methods are defined on it).
  */
  SOGoAppointmentFolder *folder;
  NSArray *stack;
  
  stack = [_ctx objectTraversalStack];
  if ([stack count] == 0) {
    [self logWithFormat:@"ERROR: no objects in traversal stack: %@", _ctx];
    return nil;
  }
  if ([stack count] < 2) {
    [self logWithFormat:@"ERROR: not enough objects in traversal stack: %@",
	    stack];
    return nil;
  }
  
  folder = ([stack lastObject] != self) // TODO: hm, hm, not really OK
    ? [stack lastObject]
    : [stack objectAtIndex:[stack count] - 2];
  if (![folder isKindOfClass:NSClassFromString(@"SOGoAppointmentFolder")]) {
    [self logWithFormat:@"ERROR: unexpected object in stack: %@", folder];
    return nil;
  }
  return folder;
}

/* name lookup */

- (id)lookupName:(NSString *)_name inContext:(id)_ctx acquire:(BOOL)_flag {
  id obj;
  
  /* check superclass */
  
  if ((obj = [super lookupName:_name inContext:_ctx acquire:NO]) != nil)
    return obj;
  
  /* check whether name is an '.ics' file */
  
  if ([[_name pathExtension] isEqualToString:@"ics"]) {
    /*
      If I configure a WebDAV publish URL in Apple iCal.app, iCal.app adds
      a calendar filename. Eg:
        Base: /SOGo/so/helge/Calendar/ics
        File: /SOGo/so/helge/Calendar/ics/SOGo32Publish.ics
    */
    return self;
  }
  
  return nil;
}

/* actions */

- (id)updateEventsInContext:(id)_ctx {
  [self logWithFormat:@"updates iCal events from a full collection ..."];
  return [NSException exceptionWithHTTPStatus:501 /* Not Implemented */
		      reason:@"please use WebDAV for modifications!"];
}

@end /* SOGoICalHTTPHandler */
