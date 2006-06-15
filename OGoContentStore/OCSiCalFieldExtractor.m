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

#include "OCSiCalFieldExtractor.h"
#include "common.h"
#include <SaxObjC/SaxObjC.h>
#include <NGiCal/NGiCal.h>
#include "iCalEntityObject+OCS.h"
#include "iCalRepeatableEntityObject+OCS.h"

@implementation OCSiCalFieldExtractor

static id<NSObject,SaxXMLReader> parser               = nil;
static SaxObjectDecoder          *sax                 = nil;
static OCSiCalFieldExtractor     *extractor           = nil;
static NSCalendarDate            *distantFuture       = nil;
static NSNumber                  *distantFutureNumber = nil;

+ (void)initialize {
  static BOOL didInit = NO;
  
  if (didInit) return;
  didInit = YES;

  parser = [[[SaxXMLReaderFactory standardXMLReaderFactory] 
		createXMLReaderForMimeType:@"text/calendar"]
	        retain];
  if (parser == nil)
    NSLog(@"ERROR: did not find a parser for text/calendar!");
  sax = [[SaxObjectDecoder alloc] initWithMappingNamed:@"NGiCal"];
  if (sax == nil)
      NSLog(@"ERROR: could not create the iCal SAX handler!");
  [parser setContentHandler:sax];
  [parser setErrorHandler:sax];

  distantFuture       = [[NSCalendarDate distantFuture] retain];
  /* INT_MAX due to Postgres constraint */
  distantFutureNumber = [[NSNumber numberWithUnsignedInt:INT_MAX] retain];
}

+ (id)sharedICalFieldExtractor {
  if (extractor == nil) extractor = [[self alloc] init];
  return extractor;
}

- (void)dealloc {
  [super dealloc];
}

/* operations */

- (NSNumber *)numberForDate:(NSCalendarDate *)_date {
  if (_date == distantFuture)
    return distantFutureNumber;
  return [NSNumber numberWithUnsignedInt:[_date timeIntervalSince1970]];
}

- (NSMutableDictionary *)extractQuickFieldsFromEvent:(iCalEvent *)_event {
  NSMutableDictionary *row;
  NSCalendarDate      *startDate, *endDate;
  NSArray             *attendees;
  NSString            *uid, *title, *location, *status, *accessClass;
  NSNumber            *sequence;
  id                  organizer;
  id                  participants, partmails;
  NSMutableString     *partstates;
  unsigned            i, count;

  if (_event == nil)
    return nil;

  /* extract values */
  
  startDate    = [_event startDate];
  endDate      = [_event endDate];
  uid          = [_event uid];
  title        = [_event summary];
  location     = [_event location];
  sequence     = [_event sequence];
  accessClass  = [[_event accessClass] uppercaseString];
  status       = [[_event status] uppercaseString];

  attendees    = [_event attendees];
  partmails    = [attendees valueForKey:@"rfc822Email"];
  partmails    = [partmails componentsJoinedByString:@"\n"];
  participants = [attendees valueForKey:@"cn"];
  participants = [participants componentsJoinedByString:@"\n"];

  /* build row */

  row = [NSMutableDictionary dictionaryWithCapacity:8];
  
  if ([uid isNotNull]) 
    [row setObject:uid forKey:@"uid"];
  else
    [self logWithFormat:@"WARNING: could not extract a uid from event!"];

  [row setObject:[NSNumber numberWithBool:[_event isAllDay]]
       forKey:@"isallday"];
  [row setObject:[NSNumber numberWithBool:[_event isRecurrent]]
       forKey:@"iscycle"];
  [row setObject:[NSNumber numberWithBool:[_event isOpaque]]
       forKey:@"isopaque"];
  [row setObject:[NSNumber numberWithInt:[_event priorityNumber]]
       forKey:@"priority"];

  if ([title    isNotNull]) [row setObject:title    forKey:@"title"];
  if ([location isNotNull]) [row setObject:location forKey:@"location"];
  if ([sequence isNotNull]) [row setObject:sequence forKey:@"sequence"];
  
  if ([startDate isNotNull]) 
    [row setObject:[self numberForDate:startDate] forKey:@"startdate"];
  if ([endDate isNotNull]) 
    [row setObject:[self numberForDate:endDate] forKey:@"enddate"];

  if ([_event isRecurrent]) {
    NSCalendarDate *date;
    
    date = [_event lastPossibleRecurrenceStartDate];
    if (!date) {
      /* this could also be *nil*, but in the end it makes the fetchspecs
         more complex - thus we set it to a "reasonable" distant future */
      date = distantFuture;
    }
    [row setObject:[self numberForDate:date] forKey:@"cycleenddate"];
    [row setObject:[_event cycleInfo] forKey:@"cycleinfo"];
  }
  if ([participants length] > 0)
    [row setObject:participants forKey:@"participants"];
  if ([partmails length] > 0)
    [row setObject:partmails forKey:@"partmails"];

  if ([status isNotNull]) {
    int code = 1;
    
    if ([status isEqualToString:@"TENTATIVE"])
      code = 0;
    else if ([status isEqualToString:@"CANCELLED"])
      code = 2;
    [row setObject:[NSNumber numberWithInt:code] forKey:@"status"];
  }
  else {
    /* confirmed by default */
    [row setObject:[NSNumber numberWithInt:1] forKey:@"status"];
  }

  if([accessClass isNotNull] && ![accessClass isEqualToString:@"PUBLIC"]) {
    [row setObject:[NSNumber numberWithBool:NO] forKey:@"ispublic"];
  }
  else {
    [row setObject:[NSNumber numberWithBool:YES] forKey:@"ispublic"];
  }

  organizer = [_event organizer];
  if (organizer) {
    NSString *email;
    
    email = [organizer valueForKey:@"rfc822Email"];
    if (email)
      [row setObject:email forKey:@"orgmail"];
  }
  
  /* construct partstates */
  count        = [attendees count];
  partstates   = [[NSMutableString alloc] initWithCapacity:count * 2];
  for ( i = 0; i < count; i++) {
    iCalPerson         *p;
    iCalPersonPartStat stat;
    
    p    = [attendees objectAtIndex:i];
    stat = [p participationStatus];
    if(i != 0)
      [partstates appendString:@"\n"];
    [partstates appendFormat:@"%d", stat];
  }
  [row setObject:partstates forKey:@"partstates"];
  [partstates release];
  return row;
}

- (NSMutableDictionary *)extractQuickFieldsFromCalendar:(iCalCalendar *)_cal {
  NSArray *events;
  
  if (_cal == nil)
    return nil;
  
  events = [_cal events];
  if ([events count] == 0) {
    [self logWithFormat:@"ERROR: given calendar contains no events: %@", _cal];
    return nil;
  }
  if ([events count] > 1) {
    [self logWithFormat:
	    @"WARNING: given calendar contains more than one event: %@",
	    _cal];
  }
  
  return [self extractQuickFieldsFromEvent:[events objectAtIndex:0]];
}

- (NSMutableDictionary *)extractQuickFieldsFromContent:(NSString *)_content {
  NSAutoreleasePool *pool;
  NSDictionary *fields;
  id cal;
  
  if (parser == nil || sax == nil)
    return nil;
  if ([_content length] == 0)
    return nil;

  pool = [[NSAutoreleasePool alloc] init];
  
  [parser parseFromSource:_content];
  cal = [sax rootObject];
  
  fields = nil;
  if ([cal isKindOfClass:[iCalEvent class]])
    fields = [[self extractQuickFieldsFromEvent:cal] retain];
  else if ([cal isKindOfClass:[iCalCalendar class]])
    fields = [[self extractQuickFieldsFromCalendar:cal] retain];
  else if ([cal isNotNull]) {
    [self logWithFormat:@"ERROR: unexpected iCalendar parse result: %@",
	    cal];
  }
  
  [sax reset];

  [pool release];
  
  return [fields autorelease];
}

@end /* OCSiCalFieldExtractor */
