/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#import <Foundation/NSException.h>
#import <Foundation/NSUserDefaults.h>

#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalToDo.h>
#import <NGCards/iCalEventChanges.h>
#import <NGCards/iCalPerson.h>
#import <SOGo/LDAPUserManager.h>

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
  return [SOGoTaskOccurence occurenceWithComponent: occ
			    withMasterComponent: [self component: NO
						       secure: NO]
			    inContainer: self];
}

/* message type */

- (NSString *) outlookMessageClass
{
  return @"IPM.Task";
}

@end /* SOGoTaskObject */
