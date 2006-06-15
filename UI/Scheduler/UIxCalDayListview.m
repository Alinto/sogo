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

#include "UIxCalDayView.h"

/*
  UIxCalDayListview

  TODO: describe
*/

@class NSArray;

@interface UIxCalDayListview : UIxCalDayView
{
  NSArray *uids;
  id currentUid;
}

@end

#include "common.h"
#include <SOGoUI/SOGoAptFormatter.h>
#include <SOGo/AgenorUserManager.h>
#include <SoObjects/Appointments/SOGoAppointmentFolder.h>

@implementation UIxCalDayListview

- (void)dealloc {
  [self->uids       release];
  [self->currentUid release];
  [super dealloc];
}

- (void)configureFormatters {
  [super configureFormatters];
  
  [self->aptFormatter setShortTitleOnly];
}

/* accessors */

- (NSArray *)uids {
  if (self->uids == nil) {
    // TODO: use -copy?
    self->uids = [[[(SOGoAppointmentFolder *)[self clientObject] calendarUIDs]
                     sortedArrayUsingSelector:@selector(compareAscending:)]
                     retain];
  }
  return self->uids;
}

- (void)setCurrentUid:(id)_currentUid { // TODO: NSString?
  ASSIGN(self->currentUid, _currentUid);
}
- (id)currentUid {
  return self->currentUid;
}

- (NSString *)cnForCurrentUid {
  return [[AgenorUserManager sharedUserManager] getCNForUID:self->currentUid];
}

- (NSString *)shortTextForApt {
  if (![self canAccessApt])
    return @"";
  
  return [[self appointment] valueForKey:@"title"];
}

- (BOOL)isRowActive {
  AgenorUserManager *um;
  NSString *mailChunk;
  NSString *currentMail;
  
  um          = [AgenorUserManager sharedUserManager];
  currentMail = [um getEmailForUID:self->currentUid];
  mailChunk   = [self->appointment valueForKey:@"partmails"];
  
  return ([mailChunk rangeOfString:currentMail].length > 0) ? YES : NO;
}

@end /* UIxCalDayListview */
