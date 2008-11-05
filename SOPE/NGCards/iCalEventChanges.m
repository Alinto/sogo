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

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import "iCalEventChanges.h"
#import "iCalEvent.h"
#import "iCalPerson.h"

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
    insertedAttendees = [NSMutableArray new];
    deletedAttendees  = [NSMutableArray new];
    updatedAttendees  = [NSMutableArray new];
    insertedAlarms    = [NSMutableArray new];
    deletedAlarms     = [NSMutableArray new];
    updatedAlarms     = [NSMutableArray new];
    updatedProperties = [NSMutableArray new];
    [self _trackAttendeeChanges:_from :_to];
    [self _trackPropertyChanges:_from :_to];
  }
  return self;
}

- (void)dealloc {
  [insertedAttendees release];
  [deletedAttendees  release];
  [updatedAttendees  release];
  [insertedAlarms    release];
  [deletedAlarms     release];
  [updatedAlarms     release];
  [updatedProperties release];
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
          [updatedAttendees addObject:tp];
        }
        break;
      }
    }
    if(!found) {
      [deletedAttendees addObject:fp];
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
      [insertedAttendees addObject:tp];
  }
}

- (void)_trackAlarmChanges:(iCalEvent *)_from :(iCalEvent *)_to {
}

- (void)_trackPropertyChanges:(iCalEvent *)_from :(iCalEvent *)_to {
  if(!IS_EQUAL([_from startDate], [_to startDate], isEqualToDate:))
    [updatedProperties addObject:@"startDate"];
  if(!IS_EQUAL([_from endDate], [_to endDate], isEqualToDate:))
    [updatedProperties addObject:@"endDate"];
  if(!IS_EQUAL([_from created], [_to created], isEqualToDate:))
    [updatedProperties addObject:@"created"];
  if(!IS_EQUAL([_from lastModified], [_to lastModified], isEqualToDate:))
    [updatedProperties addObject:@"lastModified"];
  if(![_from durationAsTimeInterval] == [_to durationAsTimeInterval])
    [updatedProperties addObject:@"duration"];
  if(!IS_EQUAL([_from summary], [_to summary], isEqualToString:))
    [updatedProperties addObject:@"summary"];
  if(!IS_EQUAL([_from location], [_to location], isEqualToString:))
    [updatedProperties addObject:@"location"];
  if(!IS_EQUAL([_from comment], [_to comment], isEqualToString:))
    [updatedProperties addObject:@"comment"];
  if(!IS_EQUAL([_from priority], [_to priority], isEqualToString:))
    [updatedProperties addObject:@"priority"];
  if(!IS_EQUAL([_from status], [_to status], isEqualToString:))
    [updatedProperties addObject:@"status"];
  if(!IS_EQUAL([_from accessClass], [_to accessClass], isEqualToString:))
    [updatedProperties addObject:@"accessClass"];
  if(!IS_EQUAL([_from sequence], [_to sequence], isEqualToNumber:))
    [updatedProperties addObject:@"sequence"];
  if(!IS_EQUAL([_from organizer], [_to organizer], isEqual:))
    [updatedProperties addObject:@"organizer"];
  if(!IS_EQUAL([_from recurrenceRules], [_to recurrenceRules], isEqual:))
    [updatedProperties addObject:@"rrule"];
  if(!IS_EQUAL([_from exceptionRules], [_to exceptionRules], isEqual:))
    [updatedProperties addObject:@"exrule"];
  if(!IS_EQUAL([_from exceptionDates], [_to exceptionDates], isEqual:))
    [updatedProperties addObject:@"exdate"];
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
  return insertedAttendees;
}
- (NSArray *)deletedAttendees {
  return deletedAttendees;
}
- (NSArray *)updatedAttendees {
  return updatedAttendees;
}

- (NSArray *)insertedAlarms {
  return insertedAlarms;
}
- (NSArray *)deletedAlarms {
  return deletedAlarms;
}
- (NSArray *)updatedAlarms {
  return updatedAlarms;
}

- (NSArray *)updatedProperties {
  return updatedProperties;
}

/* descriptions */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  [ms appendFormat:@" updatedProperties=%@", updatedProperties];
  [ms appendFormat:@" insertedAttendees=%@", insertedAttendees];
  [ms appendFormat:@" deletedAttendees=%@", deletedAttendees];
  [ms appendFormat:@" updatedAttendees=%@", updatedAttendees];
  
  [ms appendString:@">"];
  return ms;
}

@end
