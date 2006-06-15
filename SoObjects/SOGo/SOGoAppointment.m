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

#include "SOGoAppointment.h"
#include <SaxObjC/SaxObjC.h>
#include <NGiCal/NGiCal.h>
#include <EOControl/EOControl.h>
#include "SOGoAppointmentICalRenderer.h"
#include "common.h"

@interface SOGoAppointment (PrivateAPI)
- (NSArray *)_filteredAttendeesThinkingOfPersons:(BOOL)_persons;
@end

@implementation SOGoAppointment

static id<NSObject,SaxXMLReader> parser  = nil;
static SaxObjectDecoder          *sax    = nil;
static NGLogger                  *logger = nil;

+ (void)initialize {
  NGLoggerManager     *lm;
  SaxXMLReaderFactory *factory;
  static BOOL         didInit = NO;

  if (didInit) return;
  didInit = YES;

  lm      = [NGLoggerManager defaultLoggerManager];
  logger  = [lm loggerForClass:self];

  factory = [SaxXMLReaderFactory standardXMLReaderFactory];
  parser  = [[factory createXMLReaderForMimeType:@"text/calendar"]
    retain];
  if (parser == nil)
    [logger fatalWithFormat:@"did not find a parser for text/calendar!"];
  sax = [[SaxObjectDecoder alloc] initWithMappingNamed:@"NGiCal"];
  if (sax == nil)
    [logger fatalWithFormat:@"could not create the iCal SAX handler!"];
  
  [parser setContentHandler:sax];
  [parser setErrorHandler:sax];
}

- (id)initWithICalRootObject:(id)_root {
  if ((self = [super init])) {
#if 0
    [self logWithFormat:@"root is: %@", root];
#endif
    
    if ([_root isKindOfClass:[iCalEvent class]]) {
      self->event = [_root retain];
    }
    else if ([_root isKindOfClass:[NSDictionary class]]) {
      /* multiple vevents in the calendar */
      [self errorWithFormat:
              @"(%s): tried to initialize with multiple records: %@",
              __PRETTY_FUNCTION__, _root];
      [self release];
      return nil;
    }
    else {
      self->calendar = [_root retain];
      self->event    = [[[self->calendar events] lastObject] retain];
    }
  }
  return self;
}
- (id)initWithICalString:(NSString *)_iCal {
  id root;
  
  if ([_iCal length] == 0) {
    [self errorWithFormat:@"tried to init SOGoAppointment without iCal"];
    [self release];
    return nil;
  }
  if (parser == nil || sax == nil) {
    [self errorWithFormat:@"iCal parser not properly set up!"];
    [self release];
    return nil;
  }

  if ([_iCal length] > 0) {
    [parser parseFromSource:_iCal];
    root = [[sax rootObject] retain]; /* retain to keep it around */
    [sax reset];
  }
  else
    root = nil;

  self = [self initWithICalRootObject:root];
  [root release];
  return self;
}

- (void)dealloc {
  [self->calendar     release];
  [self->event        release];
  [self->participants release];
  [super dealloc];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  SOGoAppointment *new;
  
  new = [[[self class] allocWithZone:_zone] init];
  
  new->calendar      = [self->calendar     copyWithZone:_zone];
  new->event         = [self->event        copyWithZone:_zone];
  new->participants  = [self->participants copyWithZone:_zone];

  return new;
}

/* accessors */

- (id)calendar {
  return self->calendar;
}

- (id)event {
  return self->event;
}

- (NSString *)iCalString {
  return [[SOGoAppointmentICalRenderer sharedAppointmentRenderer]
	                                     stringForAppointment:self];
}
- (NSString *)vEventString {
  return [[SOGoAppointmentICalRenderer sharedAppointmentRenderer]
	                                     vEventStringForAppointment:self];
}

/* forwarded methods */

- (void)setUid:(NSString *)_value {
  [self->event setUid:_value];
}
- (NSString *)uid {
  return [self->event uid];
}

- (void)setSummary:(NSString *)_value {
  [self->event setSummary:_value];
}
- (NSString *)summary {
  return [self->event summary];
}

- (void)setLocation:(NSString *)_value {
  [self->event setLocation:_value];
}
- (NSString *)location {
  return [self->event location];
}
- (BOOL)hasLocation {
  if (![[self location] isNotNull])
    return NO;
  return  [[self location] length] > 0 ? YES : NO;
}

- (void)setComment:(NSString *)_value {
  if([_value length] == 0)
    _value = nil;
  [self->event setComment:_value];
}
- (NSString *)comment {
  return [self->event comment];
}
- (BOOL)hasComment {
  NSString *s = [self comment];
  if(!s || [s length] == 0)
    return NO;
  return YES;
}

- (void)setUserComment:(NSString *)_userComment {
  [self->event setUserComment:_userComment];
}
- (NSString *)userComment {
  return [self->event userComment];
}

- (void)setPriority:(NSString *)_value {
  [self->event setPriority:_value];
}
- (NSString *)priority {
  return [self->event priority];
}
- (BOOL)hasPriority {
  NSString *prio = [self priority];
  NSRange r;
  
  if(!prio)
    return NO;
  
  r = [prio rangeOfString:@";"];
  if(r.length > 0) {
    prio = [prio substringToIndex:r.location];
  }
  return [prio isEqualToString:@"0"] ? NO : YES;
}

- (void)setCategories:(NSArray *)_value {
  NSString *catString;

  if(!_value || [_value count] == 0) {
    [self->event setCategories:nil];
    return;
  }
  _value = [_value sortedArrayUsingSelector:@selector(compareAscending:)];
  catString = [_value componentsJoinedByString:@","];
  [self->event setCategories:catString];
}
- (NSArray *)categories {
  NSString *catString;
  NSArray *cats;
  NSRange r;
  
  catString = [self->event categories];
  if (![catString isNotNull])
    return [NSArray array];
  
  r = [[catString stringValue] rangeOfString:@";"];
  if(r.length > 0) {
    catString = [catString substringToIndex:r.location];
  }
  cats = [catString componentsSeparatedByString:@","];
  return cats;
}
- (BOOL)hasCategories {
  return [self->event categories] != nil ? YES : NO;
}

- (void)setStatus:(NSString *)_value {
  [self->event setStatus:_value];
}
- (NSString *)status {
  return [self->event status];
}

- (void)setStartDate:(NSCalendarDate *)_date {
  [self->event setStartDate:_date];
}
- (NSCalendarDate *)startDate {
  return [self->event startDate];
}

- (void)setEndDate:(NSCalendarDate *)_date {
  [self->event setEndDate:_date];
}
- (NSCalendarDate *)endDate {
  return [self->event endDate];
}
- (BOOL)hasEndDate {
  return [self->event hasEndDate];
}

- (void)setDuration:(NSTimeInterval)_duration {
  // TODO
  [self warnWithFormat:@"could not apply duration!"];
}
- (BOOL)hasDuration {
  return [self->event hasDuration];
}
- (NSTimeInterval)duration {
  return [self->event durationAsTimeInterval];
}

- (void)setAccessClass:(NSString *)_value {
  [self->event setAccessClass:_value];
}
- (NSString *)accessClass {
  NSString *s;
  
  s = [self->event accessClass];
  if(!s)
    s = @"PUBLIC"; /* default for agenor */
  return s;
}
- (BOOL)isPublic {
  return [[self accessClass] isEqualToString:@"PUBLIC"];
}

- (void)setTransparency:(NSString *)_value {
  [self->event setTransparency:_value];
}
- (NSString *)transparency {
  return [self->event transparency];
}
- (BOOL)isTransparent {
  return [[self transparency] isEqualToString:@"TRANSPARENT"];
}

- (void)setMethod:(NSString *)_method {
  [self->calendar setMethod:_method];
}
- (NSString *)method {
  return [self->calendar method];
}

- (void)setOrganizer:(iCalPerson *)_organizer {
  [self->event setOrganizer:_organizer];
}
- (iCalPerson *)organizer {
  return [self->event organizer];
}

- (void)removeAllAttendees {
  [self setAttendees:nil];
}
- (void)addToAttendees:(iCalPerson *)_person {
  [self->event addToAttendees:_person];
}
- (void)appendAttendees:(NSArray *)_persons {
  unsigned i, count;
  
  count = [_persons count];
  for (i = 0; i < count; i++)
    [self addToAttendees:[_persons objectAtIndex:i]];
}
- (void)setAttendees:(NSArray *)_persons {
  [self->event removeAllAttendees];
  if ([_persons count] > 0) 
    [self appendAttendees:_persons];
}
- (NSArray *)attendees {
  return [self->event attendees];
}

- (NSArray *)participants {
  if (self->participants != nil)
    return self->participants;
  
  self->participants = [[self _filteredAttendeesThinkingOfPersons:YES] retain];
  return self->participants;
}
- (BOOL)hasParticipants {
  return [[self participants] count] != 0;
}

- (NSArray *)resources {
  return [self _filteredAttendeesThinkingOfPersons:NO];
}

- (NSArray *)_filteredAttendeesThinkingOfPersons:(BOOL)_persons {
  NSArray        *list;
  NSMutableArray *filtered;
  unsigned       i, count;

  list     = [self attendees];
  count    = [list count];
  filtered = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    iCalPerson *p;
    NSString   *role;
    
    p = [list objectAtIndex:i];
    role = [p role];
    if (_persons) {
      if (role == nil || ![role hasPrefix:@"NON-PART"])
	[filtered addObject:p];
    }
    else {
      if ([role hasPrefix:@"NON-PART"])
	[filtered addObject:p];
    }
  }
  return filtered;
}

- (BOOL)isOrganizer:(id)_email {
  return [[[self organizer] rfc822Email] isEqualToString:_email];
}

- (BOOL)isParticipant:(id)_email {
  NSArray *partEmails;
  
  _email     = [_email lowercaseString];
  partEmails = [[self participants] valueForKey:@"rfc822Email"];
  partEmails = [partEmails valueForKey:@"lowercaseString"];
  return [partEmails containsObject:_email];
}

- (iCalPerson *)findParticipantWithEmail:(id)_email {
  NSArray  *ps;
  unsigned i, count;
  
  _email = [_email lowercaseString];
  ps     = [self participants];
  count  = [ps count];
  
  for (i = 0; i < count; i++) {
    iCalPerson *p;
    
    p = [ps objectAtIndex:i];
    if ([[[p rfc822Email] lowercaseString] isEqualToString:_email])
      return p;
  }
  return nil; /* not found */
}


/*
 NOTE: this is not the same API as used by NGiCal!
 SOGo/OGo cannot deal with the complete NGiCal API properly, although
 SOGo COULD do so in the future
*/
- (void)setRecurrenceRule:(iCalRecurrenceRule *)_rrule {
  [_rrule retain];
  [self->event removeAllRecurrenceRules];
  if (_rrule)
    [self->event addToRecurrenceRules:_rrule];
  [_rrule release];
}
- (iCalRecurrenceRule *)recurrenceRule {
  if ([self->event hasRecurrenceRules])
    return [[self->event recurrenceRules] objectAtIndex:0];
  return nil;
}
- (BOOL)hasRecurrenceRule {
  return [self recurrenceRule] != nil;
}

- (NSArray *)recurrenceRangesWithinCalendarDateRange:(NGCalendarDateRange *)_r {
  return [self->event recurrenceRangesWithinCalendarDateRange:_r];
}

/* actions */

- (void)increaseSequence {
  [self->event increaseSequence];
}

- (void)cancelWithoutIncreasingSequence {
  [self setMethod:@"CANCEL"];
}
- (void)cancelAndIncreaseSequence {
  [self cancelWithoutIncreasingSequence];
  [self increaseSequence];
}

/* description */

- (void)appendAttributesToDescription:(NSMutableString *)_ms {
  [_ms appendFormat:@" uid=%@",  [self uid]];
  [_ms appendFormat:@" date=%@", [self startDate]];
}

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%08X[%@]:", self, NSStringFromClass([self class])];
  [self appendAttributesToDescription:ms];
  [ms appendString:@">"];
  return ms;
}

/* logging */

- (id)logger {
  return logger;
}

@end /* SOGoAppointment */
