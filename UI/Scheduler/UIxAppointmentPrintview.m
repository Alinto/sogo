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

#include "UIxAppointmentView.h"

@interface UIxAppointmentPrintview : UIxAppointmentView
{
}

- (BOOL)isMyApt;

@end

#include "common.h"
#include <SOGoUI/SOGoDateFormatter.h>
#include <SOGo/SOGoAppointment.h>
#include "UIxComponent+Agenor.h"

@implementation UIxAppointmentPrintview

- (NSString *)title {
  return [[self dateFormatter] stringForObjectValue:[self startTime]];
}

- (BOOL)isMyApt {
  id       apt;
  NSString *myEmail;

  apt     = [self appointment];
  myEmail = [self emailForUser];
#if 0 /* ZNeK 20041208 - Maxime says this isn't relevant to agenor */
  if ([apt isOrganizer:myEmail])
    return YES;
#endif
  return [apt isParticipant:myEmail];
}

- (NSString *)aptStyle {
  if (![self isMyApt])
    return @"aptprintview_apt_other";
  return nil;
}

@end /* UIxAppointmentPrintview */
