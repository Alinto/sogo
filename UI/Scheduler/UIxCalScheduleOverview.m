/*
 Copyright (C) 2004 SKYRIX Software AG
 
 This file is part of OpenGroupware.org
 
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

#include <SOGoUI/UIxComponent.h>

@class NSMutableArray;

@interface UIxCalScheduleOverview : UIxComponent
{
  NSMutableArray *userApts;
  NSMutableArray *foreignApts;
  id             item;
  NSMutableArray *partNames;
  NSMutableArray *partStates;
  NSString       *userParticipationStatus;
  unsigned       participantIndex;
  unsigned       userIndex;
}

- (NSCalendarDate *)startDate;
- (NSCalendarDate *)endDate;

- (NSArray *)userAppointments;
- (NSArray *)foreignAppointments;

- (BOOL)hasUserAppointments;
- (BOOL)hasForeignAppointments;
- (BOOL)hasAnyAppointments;

- (void)fetchInfos;

- (NSString *)appointmentBaseURL;

- (unsigned)participantsCount;
- (unsigned)maxRenderedParticipantsCount;
- (unsigned)renderedParticipantsCount;
- (unsigned)truncatedParticipantsCount;
- (BOOL)didTruncateParticipants;

- (NSString *)getUserPartStateFromApt:(id)_apt;

- (BOOL)shouldIgnoreRejectedAppointments;
- (BOOL)shouldIgnoreAcceptedAppointments;
- (BOOL)shouldShowRejectedAndAcceptedAppointments;
  
@end

#include <NGObjWeb/SoComponent.h>
#include "UIxComponent+Agenor.h"
#include "SoObjects/Appointments/SOGoAppointmentFolder.h"
#include "common.h"

@implementation UIxCalScheduleOverview

- (void)dealloc {
  [self->userApts                release];
  [self->foreignApts             release];
  [self->item                    release];
  [self->partNames               release];
  [self->partStates              release];
  [self->userParticipationStatus release];
  [super dealloc];
}


/* accessors */

- (void)setItem:(id)_item {
  NSString *ps, *email;
  NSArray  *partmails;
  unsigned idx;
  
  ASSIGN(self->item, _item);

  [self->partNames  release];
  [self->partStates release];
  ps               = [self->item valueForKey:@"participants"];
  self->partNames  = [[ps componentsSeparatedByString:@"\n"] mutableCopy];
  ps               = [self->item valueForKey:@"partstates"];
  self->partStates = [[ps componentsSeparatedByString:@"\n"] mutableCopy];
  ps               = [self->item valueForKey:@"partmails"];
  partmails        = [ps componentsSeparatedByString:@"\n"];

  /* reorder partNames/partStates */
  
  /* ensure organizer is first entry */
  email = [self->item valueForKey:@"orgmail"];
  if ([email isNotNull]) {
    idx = [partmails indexOfObject:email];
    if (idx != NSNotFound && idx != 0) {
      id obj;

      obj = [self->partNames objectAtIndex:idx];
      [self->partNames insertObject:obj atIndex:0]; /* frontmost */
      [self->partNames removeObjectAtIndex:idx + 1];
      obj = [self->partStates objectAtIndex:idx];
      [self->partStates insertObject:obj atIndex:0]; /* frontmost */
      [self->partStates removeObjectAtIndex:idx + 1];
    }
  }
  /* user is either second, first or none at all */
  [self->userParticipationStatus release];
  email     = [self emailForUser];
  idx       = [partmails indexOfObject:email];
  if (idx != NSNotFound && idx != 0 && idx != 1) {
    id obj;

    self->userIndex = 1;
    obj = [self->partNames objectAtIndex:idx];
    [self->partNames insertObject:obj atIndex:self->userIndex]; /* second */
    [self->partNames removeObjectAtIndex:idx + 1];
    obj = [self->partStates objectAtIndex:idx];
    [self->partStates insertObject:obj atIndex:self->userIndex]; /* second */
    [self->partStates removeObjectAtIndex:idx + 1];
  }
  else {
    self->userIndex = idx;
  }
  if (self->userIndex != NSNotFound)
    self->userParticipationStatus =
      [[self->partStates objectAtIndex:self->userIndex] retain];
  else
    self->userParticipationStatus = nil;
}
- (id)item {
  return self->item;
}

- (void)setParticipantIndex:(unsigned)_participantIndex {
  self->participantIndex = _participantIndex;
}
- (unsigned)participantIndex {
  return self->participantIndex;
}

- (unsigned)userIndex {
  return self->userIndex;
}

- (BOOL)isFirstParticipant {
  return self->participantIndex == 0 ? YES : NO;
}

- (BOOL)hasUserAppointments {
  // NOTE: this has been disabled for Agenor 0.8 on client's request
#if 1
  return NO;
#else
  return [[self userAppointments] count] > 0;
#endif
}
- (BOOL)hasForeignAppointments {
  return [[self foreignAppointments] count] > 0;
}
- (BOOL)hasAnyAppointments {
  return ([self hasUserAppointments] ||
          [self hasForeignAppointments]) ? YES : NO;
}

- (unsigned)participantsCount {
  return [self->partNames count];
}

- (NSString *)participant {
  return [self->partNames objectAtIndex:self->participantIndex];
}

- (NSString *)participationStatus {
  return [self->partStates objectAtIndex:self->participantIndex];
}

- (unsigned)maxRenderedParticipantsCount {
  return 3;
}

- (unsigned)renderedParticipantsCount {
  if ([self didTruncateParticipants])
    return [self maxRenderedParticipantsCount];
  return [self participantsCount];
}

- (unsigned)truncatedParticipantsCount {
  return [self participantsCount] - [self renderedParticipantsCount];
}

- (BOOL)didTruncateParticipants {
  return [self participantsCount] >
         ([self maxRenderedParticipantsCount] + 1) ? YES : NO;
}

- (unsigned)rowspan {
  unsigned count;
  
  count = [self renderedParticipantsCount];
  if ([self didTruncateParticipants])
    count += 1;
  return count;
}

- (NSString *)userParticipationStatus {
  return self->userParticipationStatus;
}

- (BOOL)shouldIgnoreRejectedAppointments {
  return ![self shouldShowRejectedAndAcceptedAppointments];
}

- (BOOL)shouldIgnoreAcceptedAppointments {
  return ![self shouldShowRejectedAndAcceptedAppointments];
}

- (BOOL)shouldShowRejectedAndAcceptedAppointments {
  NSString *value;
  
  value = [[[self context] request] formValueForKey:@"dr"];
  if (!value) return NO;
  return [value boolValue];
}

- (NSString *)toggleShowHideAptsQueryParameter {
  BOOL shouldShow;
  
  shouldShow = [self shouldShowRejectedAndAcceptedAppointments];
  return shouldShow ? @"0" : @"1";
}

- (NSString *)toggleShowHideAptsText {
  if ([self shouldShowRejectedAndAcceptedAppointments])
    return @"Hide already accepted and rejected appointments";
  return @"Show already accepted and rejected appointments";
}


- (NSString *)getUserPartStateFromApt:(id)_apt {
  NSString *email;
  NSArray  *ps, *pms;
  unsigned idx;

  email = [self emailForUser];
  pms   = [[_apt valueForKey:@"partmails"]
                 componentsSeparatedByString:@"\n"];
  idx   = [pms indexOfObject:email];
  if (idx == NSNotFound) return nil;
  ps    = [[_apt valueForKey:@"partstates"]
                 componentsSeparatedByString:@"\n"];
  return [ps objectAtIndex:idx];
}


/* fetching */

- (NSCalendarDate *)startDate {
  return [[NSCalendarDate date] beginOfDay];
}

/* ZNeK: is a month ok? */
- (NSCalendarDate *)endDate {
  NSCalendarDate *date;
  
  date = [NSCalendarDate date];
  date = [date dateByAddingYears:0 months:1 days:0
                           hours:0 minutes:0 seconds:0];
  date = [date endOfDay];
  return date;
}

- (NSArray *)userAppointments {
  if (!self->userApts) {
    [self fetchInfos];
  }
  return self->userApts;
}

- (NSArray *)foreignAppointments {
  if (!self->foreignApts) {
    [self fetchInfos];
  }
  return self->foreignApts;
}

- (void) fetchInfos {
  static NSArray *orders = nil;
  id       aptFolder;
  NSArray  *apts;
  NSString *userEmail;
  unsigned i, count;

  if (!orders) {
    EOSortOrdering *so;
    so     = [EOSortOrdering sortOrderingWithKey:@"startDate"
                             selector:EOCompareAscending];
    orders = [[NSArray alloc] initWithObjects:so, nil];
  }

  aptFolder = [self clientObject];
  apts      = [aptFolder fetchCoreInfosFrom: [self startDate]
                         to: [self endDate]
                         component: @"vevent"];
  userEmail = [self emailForUser];
  count     = [apts count];

  self->userApts    = [[NSMutableArray alloc] initWithCapacity:count];
  self->foreignApts = [[NSMutableArray alloc] initWithCapacity:count];

  for (i = 0; i < count; i++) {
    id       apt;
    NSString *orgEmail;

    apt      = [apts objectAtIndex:i];
    orgEmail = [(NSDictionary *)apt objectForKey:@"orgmail"];
    if (orgEmail && [orgEmail isEqualToString:userEmail]) {
      [self->userApts addObject:apt];
    }
    else {
      BOOL shouldAdd = YES;

      if ([self shouldIgnoreAcceptedAppointments] ||
          [self shouldIgnoreRejectedAppointments])
      {
        NSString *userPartStat;

        userPartStat = [self getUserPartStateFromApt:apt];
        if (userPartStat) {
          if ([self shouldIgnoreAcceptedAppointments] &&
              [userPartStat isEqualToString:@"1"])
            shouldAdd = NO;
          else if ([self shouldIgnoreRejectedAppointments] &&
                   [userPartStat isEqualToString:@"2"])
            shouldAdd = NO;
        }
      }
      if (shouldAdd)
        [self->foreignApts addObject:apt];
    }
  }
  [self->userApts    sortUsingKeyOrderArray:orders];
  [self->foreignApts sortUsingKeyOrderArray:orders];
}


/* URLs */

- (NSString *)appointmentBaseURL {
  id pkey;
  
  if (![(pkey = [self->item valueForKey:@"uid"]) isNotNull])
    return nil;
  
  return [[self clientObject] baseURLForAptWithUID:[pkey stringValue]
                              inContext:[self context]];
}
- (NSString *)appointmentViewURL {
  return [[self appointmentBaseURL] stringByAppendingPathComponent:@"view"];
}
- (NSString *)acceptAppointmentURL {
  return [[self appointmentBaseURL] stringByAppendingPathComponent:@"accept"];
}
- (NSString *)declineAppointmentURL {
  return [[self appointmentBaseURL] stringByAppendingPathComponent:@"decline"];
}


/* access protection */

- (BOOL)canAccess {
  NSString *owner;
  
  owner = [[self clientObject] ownerInContext:[self context]];
  if (!owner)
    return NO;
  return [[[[self context] activeUser] login] isEqualToString:owner];
}

@end
