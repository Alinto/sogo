/*
 Copyright (C) 2004-2005 SKYRIX Software AG

 This file is part of SOPE.

 SOPE is free software; you can redistribute it and/or modify it under
 the terms of the GNU Lesser General Public License as published by the
 Free Software Foundation; either version 2, or (at your option) any
 later version.

 SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
 WARRANTY; without even the implied warranty of MERCHANTABILITY or
 FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 License for more details.

 You should have received a copy of the GNU Lesser General Public
 License along with SOPE; see the file COPYING.  If not, write to the
 Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
 02111-1307, USA.
 */


#include "iCalEventChanges.h"
#include "iCalEvent.h"
#include "iCalPerson.h"
#include "common.h"

@interface iCalEventChanges (PrivateAPI)
- (void)_trackAttendeeChanges:(iCalEvent *)_from :(iCalEvent *)_to;
- (void)_trackAlarmChanges:(iCalEvent *)_from :(iCalEvent *)_to;
- (void)_trackPropertyChanges:(iCalEvent *)_from :(iCalEvent *)_to;
@end

@implementation iCalEventChanges

+ (id)changesFromEvent:(iCalEvent *)_from toEvent:(iCalEvent *)_to {
  return [[[self alloc] initWithFromEvent:_from toEvent:_to] autorelease];
}

- (id)initWithFromEvent:(iCalEvent *)_from toEvent:(iCalEvent *)_to {
  self = [super init];
  if(self) {
    self->insertedAttendees = [[NSMutableArray alloc] init];
    self->deletedAttendees  = [[NSMutableArray alloc] init];
    self->updatedAttendees  = [[NSMutableArray alloc] init];
    self->insertedAlarms    = [[NSMutableArray alloc] init];
    self->deletedAlarms     = [[NSMutableArray alloc] init];
    self->updatedAlarms     = [[NSMutableArray alloc] init];
    self->updatedProperties = [[NSMutableArray alloc] init];
    [self _trackAttendeeChanges:_from :_to];
    [self _trackPropertyChanges:_from :_to];
  }
  return self;
}

- (void)dealloc {
  [self->insertedAttendees release];
  [self->deletedAttendees  release];
  [self->updatedAttendees  release];
  [self->insertedAlarms    release];
  [self->deletedAlarms     release];
  [self->updatedAlarms     release];
  [self->updatedProperties release];
  [super dealloc];
}

- (void)_trackAttendeeChanges:(iCalEvent *)_from :(iCalEvent *)_to {
  unsigned f, t, fcount, tcount;
  NSArray *fromAttendees, *toAttendees;

  fromAttendees = [_from attendees];
  fcount = [fromAttendees count];
  toAttendees = [_to attendees];
  tcount = [toAttendees count];
  for(f = 0; f < fcount; f++) {
    iCalPerson *fp;
    BOOL found = NO;

    fp = [fromAttendees objectAtIndex:f];

    for(t = 0; t < tcount; t++) {
      iCalPerson *tp;

      tp = [toAttendees objectAtIndex:t];
      if([fp hasSameEmailAddress:tp]) {
        found = YES;
        if(![fp isEqualToPerson:tp]) {
          [self->updatedAttendees addObject:tp];
        }
        break;
      }
    }
    if(!found) {
      [self->deletedAttendees addObject:fp];
    }
  }
  for(t = 0; t < tcount; t++) {
    iCalPerson *tp;
    BOOL found = NO;

    tp = [toAttendees objectAtIndex:t];
    for(f = 0; f < fcount; f++) {
      iCalPerson *fp;

      fp = [fromAttendees objectAtIndex:f];
      if([tp hasSameEmailAddress:fp]) {
        found = YES;
        break;
      }
    }
    if(!found)
      [self->insertedAttendees addObject:tp];
  }
}

- (void)_trackAlarmChanges:(iCalEvent *)_from :(iCalEvent *)_to {
}

- (void)_trackPropertyChanges:(iCalEvent *)_from :(iCalEvent *)_to {
  if(!IS_EQUAL([_from startDate], [_to startDate], isEqualToDate:))
    [self->updatedProperties addObject:@"startDate"];
  if(!IS_EQUAL([_from endDate], [_to endDate], isEqualToDate:))
    [self->updatedProperties addObject:@"endDate"];
  if(!IS_EQUAL([_from created], [_to created], isEqualToDate:))
    [self->updatedProperties addObject:@"created"];
  if(!IS_EQUAL([_from lastModified], [_to lastModified], isEqualToDate:))
    [self->updatedProperties addObject:@"lastModified"];
  if(![_from durationAsTimeInterval] == [_to durationAsTimeInterval])
    [self->updatedProperties addObject:@"duration"];
  if(!IS_EQUAL([_from summary], [_to summary], isEqualToString:))
    [self->updatedProperties addObject:@"summary"];
  if(!IS_EQUAL([_from location], [_to location], isEqualToString:))
    [self->updatedProperties addObject:@"location"];
  if(!IS_EQUAL([_from comment], [_to comment], isEqualToString:))
    [self->updatedProperties addObject:@"comment"];
  if(!IS_EQUAL([_from priority], [_to priority], isEqualToString:))
    [self->updatedProperties addObject:@"priority"];
  if(!IS_EQUAL([_from status], [_to status], isEqualToString:))
    [self->updatedProperties addObject:@"status"];
  if(!IS_EQUAL([_from accessClass], [_to accessClass], isEqualToString:))
    [self->updatedProperties addObject:@"accessClass"];
  if(!IS_EQUAL([_from sequence], [_to sequence], isEqualToNumber:))
    [self->updatedProperties addObject:@"sequence"];
  if(!IS_EQUAL([_from organizer], [_to organizer], isEqual:))
    [self->updatedProperties addObject:@"organizer"];
}

- (BOOL)hasChanges {
  return [self hasAttendeeChanges]  ||
         [self hasAlarmChanges]     ||
         [self hasPropertyChanges];
}

- (BOOL)hasAttendeeChanges {
  return [[self insertedAttendees] count] > 0 ||
         [[self deletedAttendees]  count] > 0 ||
         [[self updatedAttendees]  count] > 0;
}

- (BOOL)hasAlarmChanges {
  return [[self insertedAlarms] count] > 0 ||
         [[self deletedAlarms]  count] > 0 ||
         [[self updatedAlarms]  count] > 0;
}

- (BOOL)hasPropertyChanges {
  return [[self updatedProperties] count] > 0;
}

- (NSArray *)insertedAttendees {
  return self->insertedAttendees;
}
- (NSArray *)deletedAttendees {
  return self->deletedAttendees;
}
- (NSArray *)updatedAttendees {
  return self->updatedAttendees;
}

- (NSArray *)insertedAlarms {
  return self->insertedAlarms;
}
- (NSArray *)deletedAlarms {
  return self->deletedAlarms;
}
- (NSArray *)updatedAlarms {
  return self->updatedAlarms;
}

- (NSArray *)updatedProperties {
  return self->updatedProperties;
}

/* descriptions */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  [ms appendFormat:@" updatedProperties=%@", self->updatedProperties];
  [ms appendFormat:@" insertedAttendees=%@", self->insertedAttendees];
  [ms appendFormat:@" deletedAttendees=%@", self->deletedAttendees];
  [ms appendFormat:@" updatedAttendees=%@", self->updatedAttendees];
  
  [ms appendString:@">"];
  return ms;
}

@end
