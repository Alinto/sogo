/*
  Copyright (C) 2006-2012 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSException.h>

#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalToDo.h>
#import <NGCards/iCalEventChanges.h>
#import <NGCards/iCalPerson.h>
#import <SOGo/SOGoUserManager.h>

#import <SoObjects/SOGo/SOGoMailer.h>

#import "NSArray+Appointments.h"
#import "SOGoAptMailNotification.h"
#import "SOGoAppointmentFolder.h"
#import "SOGoTaskOccurence.h"

#import "SOGoTaskObject.h"

@implementation SOGoTaskObject

- (NSString *) componentTag
{
  return @"vtodo";
}

- (SOGoComponentOccurence *) occurence: (iCalRepeatableEntityObject *) occ
{
  NSArray *allTodos;

  allTodos = [[occ parent] todos];

  return [SOGoTaskOccurence occurenceWithComponent: occ
			    withMasterComponent: [allTodos objectAtIndex: 0]
			    inContainer: self];
}

#warning this code should be put in SOGoCalendarComponent once the UID hack\
  in SOGoAppointmentObject is resolved
- (NSException *) saveContentString: (NSString *) newContent
                        baseVersion: (unsigned int) newVersion
{
  NSException *ex;

  ex = [super saveContentString: newContent baseVersion: newVersion];
  [fullCalendar release];
  fullCalendar = nil;
  [safeCalendar release];
  safeCalendar = nil;
  [originalCalendar release];
  originalCalendar = nil;

  return ex;
}

@end /* SOGoTaskObject */
