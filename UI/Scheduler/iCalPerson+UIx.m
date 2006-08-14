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
// $Id: UIxAppointmentEditor.m 181 2004-08-11 15:13:25Z helge $

#import <SOGo/AgenorUserManager.h>
#import "iCalPerson+UIx.h"
#import "common.h"

@implementation iCalPerson (Convenience)

+ (iCalPerson *) personWithUid: (NSString *) uid
{
  iCalPerson *person;
  AgenorUserManager *um;
  NSString *email, *cn;

  person = [self new];
  [person autorelease];
  
  um = [AgenorUserManager sharedUserManager];
  email = [um getEmailForUID: uid];
  cn = [um getCNForUID: uid];
  [person setCn: cn];
  [person setEmail: email];

  return person;
}

- (NSString *) cnForDisplay
{
  return [self cnWithoutQuotes];
}

@end /* iCalPerson(Convenience) */
