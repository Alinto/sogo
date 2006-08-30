/*
  Copyright (C) 2000-2005 SKYRIX Software AG
 
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

#include "SOGoAptMailNotification.h"
#include <SOGo/SOGoAppointment.h>
#include "common.h"

@interface SOGoAptMailNotification (PrivateAPI)
- (BOOL)isSubject;
- (void)setIsSubject:(BOOL)_isSubject;
@end

@implementation SOGoAptMailNotification

static NSCharacterSet *wsSet  = nil;
static NSTimeZone     *EST = nil;

+ (void)initialize {
  static BOOL didInit = NO;

  if (didInit) return;
  didInit = YES;

  wsSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];
  EST   = [[NSTimeZone timeZoneWithAbbreviation:@"EST"] retain];
}

- (void)dealloc {
  [self->oldApt       release];
  [self->newApt       release];
  [self->homePageURL  release];
  [self->viewTZ       release];

  [self->oldStartDate release];
  [self->newStartDate release];
  [super dealloc];
}

- (id)oldApt {
  return self->oldApt;
}
- (void)setOldApt:(id)_oldApt {
  ASSIGN(self->oldApt, _oldApt);
}

- (id)newApt {
  return self->newApt;
}
- (void)setNewApt:(id)_newApt {
  ASSIGN(self->newApt, _newApt);
}

- (NSString *)homePageURL {
  return self->homePageURL;
}
- (void)setHomePageURL:(NSString *)_homePageURL {
  ASSIGN(self->homePageURL, _homePageURL);
}

- (NSString *)appointmentURL {
  NSString *aptUID;
  
  aptUID = [[self newApt] uid];
  return [NSString stringWithFormat:@"%@/Calendar/%@/view?tab=participants",
                                    [self homePageURL],
                                    aptUID];
}

- (NSTimeZone *)viewTZ {
  if (self->viewTZ) return self->viewTZ;
  return EST;
}
- (void)setViewTZ:(NSTimeZone *)_viewTZ {
  ASSIGN(self->viewTZ, _viewTZ);
}

- (BOOL)isSubject {
  return self->isSubject;
}
- (void)setIsSubject:(BOOL)_isSubject {
  self->isSubject = _isSubject;
}


/* Helpers */

- (NSCalendarDate *)oldStartDate {
  if (!self->oldStartDate) {
    ASSIGN(self->oldStartDate, [[self oldApt] startDate]);
    [self->oldStartDate setTimeZone:[self viewTZ]];
  }
  return self->oldStartDate;
}

- (NSCalendarDate *)newStartDate {
  if (!self->newStartDate) {
    ASSIGN(self->newStartDate, [[self newApt] startDate]);
    [self->newStartDate setTimeZone:[self viewTZ]];
  }
  return self->newStartDate;
}

/* Generate Response */

- (NSString *)getSubject {
  NSString *subject;

  [self setIsSubject:YES];
  subject = [[[self generateResponse] contentAsString]
                                      stringByTrimmingCharactersInSet:wsSet];
  if (!subject) {
    [self errorWithFormat:@"Failed to properly generate subject! Please check "
                          @"template for component '%@'!",
                          [self name]];
    subject = @"ERROR: missing subject!";
  }
  return subject;
}

- (NSString *)getBody {
  [self setIsSubject:NO];
  return [[self generateResponse] contentAsString];
}

@end
