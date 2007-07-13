/*
  Copyright (C) 2000-2003 SKYRIX Software AG

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

#import <NGObjWeb/SoComponent.h>

@class NSArray, NSCalendarDate;

@interface UIxAptTableView : SoComponent
{
  NSArray *appointments;
  id      appointment;
}

/* accessors */

- (NSArray *)appointments;
- (id)appointment;

@end

@implementation UIxAptTableView

- (void)dealloc {
  [self->appointment  release];
  [self->appointments release];
  [super dealloc];
}

/* accessors */

- (void)setAppointments:(NSArray *)_apts {
  ASSIGN(self->appointments, _apts);
}
- (NSArray *)appointments {
  return self->appointments;
}

- (void)setAppointment:(id)_apt {
  ASSIGN(self->appointment, _apt);
}
- (id)appointment {
  return self->appointment;
}

- (NSString *)appointmentViewURL {
  id pkey;
  
  if ((pkey = [[self appointment] valueForKey:@"dateId"]) == nil)
    return nil;
  
  return [NSString stringWithFormat:@"%@/view", pkey];
}

@end /* UIxAptTableView */
