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
#include <NGCards/NGCards.h>
#include "iCalEntityObject+OCS.h"
#include "iCalRepeatableEntityObject+OCS.h"

@implementation OCSiCalFieldExtractor

static OCSiCalFieldExtractor     *extractor           = nil;
static NSCalendarDate            *distantFuture       = nil;
static NSNumber                  *distantFutureNumber = nil;

+ (void) initialize
{
  static BOOL didInit = NO;
  
  if (didInit) return;
  didInit = YES;

  distantFuture       = [[NSCalendarDate distantFuture] retain];
  /* INT_MAX due to Postgres constraint */
  distantFutureNumber = [[NSNumber numberWithUnsignedInt:INT_MAX] retain];
}

+ (id) sharedICalFieldExtractor
{
  if (extractor == nil)
    extractor = [self new];

  return extractor;
}

/* operations */

- (NSNumber *) numberForDate: (NSCalendarDate *) _date
{
  if (_date == distantFuture)
    return distantFutureNumber;

  return [NSNumber numberWithUnsignedInt:[_date timeIntervalSince1970]];
}

- (NSMutableDictionary *) extractQuickFieldsFromEvent: (iCalEvent *) _event
{
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

  [row setObject: @"vevent" forKey: @"component"];
  
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
    [row setObject: [self numberForDate: startDate] forKey:@"startdate"];
  if ([endDate isNotNull]) 
    [row setObject: [self numberForDate: endDate] forKey:@"enddate"];
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

- (NSMutableDictionary *) extractQuickFieldsFromTodo: (iCalToDo *) _task
{
  NSMutableDictionary *row;
  NSCalendarDate      *startDate, *dueDate;
  NSArray             *attendees;
  NSString            *uid, *title, *location, *status, *accessClass;
  NSNumber            *sequence;
  id                  organizer, date;
  id                  participants, partmails;
  NSMutableString     *partstates;
  unsigned            i, count, code;

  if (_task == nil)
    return nil;

  /* extract values */
  
  startDate    = [_task startDate];
  dueDate      = [_task due];
  uid          = [_task uid];
  title        = [_task summary];
  location     = [_task location];
  sequence     = [_task sequence];
  accessClass  = [[_task accessClass] uppercaseString];
  status       = [[_task status] uppercaseString];

  attendees    = [_task attendees];
  partmails    = [attendees valueForKey:@"rfc822Email"];
  partmails    = [partmails componentsJoinedByString:@"\n"];
  participants = [attendees valueForKey:@"cn"];
  participants = [participants componentsJoinedByString:@"\n"];

  /* build row */

  row = [NSMutableDictionary dictionaryWithCapacity:8];

  [row setObject: @"vtodo" forKey: @"component"];

  if ([uid isNotNull]) 
    [row setObject:uid forKey:@"uid"];
  else
    [self logWithFormat:@"WARNING: could not extract a uid from event!"];

  [row setObject:[NSNumber numberWithBool:[_task isRecurrent]]
       forKey:@"iscycle"];
  [row setObject:[NSNumber numberWithInt:[_task priorityNumber]]
       forKey:@"priority"];

  if ([title isNotNull]) [row setObject: title forKey:@"title"];
  if ([location isNotNull]) [row setObject: location forKey:@"location"];
  if ([sequence isNotNull]) [row setObject: sequence forKey:@"sequence"];
  
  if ([startDate isNotNull])
    date = [self numberForDate: startDate];
  else
    date = [NSNull null];
  [row setObject: date forKey: @"startdate"];

  if ([dueDate isNotNull]) 
    date = [self numberForDate: dueDate];
  else
    date = [NSNull null];
  [row setObject: date forKey: @"enddate"];

  if ([participants length] > 0)
    [row setObject:participants forKey:@"participants"];
  if ([partmails length] > 0)
    [row setObject:partmails forKey:@"partmails"];

  if ([status isNotNull]) {
    code = 0; /* NEEDS-ACTION */
    if ([status isEqualToString:@"COMPLETED"])
      code = 1;
    else if ([status isEqualToString:@"IN-PROCESS"])
      code = 2;
    else if ([status isEqualToString:@"CANCELLED"])
      code = 3;
    [row setObject: [NSNumber numberWithInt: code] forKey:@"status"];
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

  organizer = [_task organizer];
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

- (CardGroup *) firstElementFromCalendar: (iCalCalendar *) ical
{
  NSArray *elements;
  CardGroup *element;
  unsigned int count;
  
  elements = [ical allObjects];
  count = [elements count];
  if (count)
    {
      if (count > 1)
        [self logWithFormat:
                @"WARNING: given calendar contains more than one event: %@",
              ical];
      element = [elements objectAtIndex: 0];
    }
  else
    {
      [self logWithFormat:@"ERROR: given calendar contains no elements: %@", ical];
      element = nil;
    }

  return element;
}

- (NSMutableDictionary *)extractQuickFieldsFromContent:(NSString *)_content {
  NSAutoreleasePool *pool;
  NSDictionary *fields;
  id cal;
  
  if ([_content length] == 0)
    return nil;

  pool = [[NSAutoreleasePool alloc] init];
  cal = [iCalCalendar parseSingleFromSource: _content];
  
  fields = nil;
  if (cal)
    {
      if ([cal isKindOfClass:[iCalCalendar class]])
        cal = [self firstElementFromCalendar: cal];

      if ([cal isKindOfClass:[iCalEvent class]])
        fields = [[self extractQuickFieldsFromEvent:cal] retain];
      else if ([cal isKindOfClass:[iCalToDo class]])
        fields = [[self extractQuickFieldsFromTodo:cal] retain];
      else if ([cal isNotNull]) {
        [self logWithFormat:@"ERROR: unexpected iCalendar parse result: %@",
              cal];
      }
    }
  else
    [self logWithFormat:@"ERROR: parsing source didn't return anything"];

  [pool release];
  
  return [fields autorelease];
}

@end /* OCSiCalFieldExtractor */
