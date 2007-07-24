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
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import "iCalEntityObject+OCS.h"
#import "iCalRepeatableEntityObject+OCS.h"

#import "OCSiCalFieldExtractor.h"

@implementation OCSiCalFieldExtractor

static NSCalendarDate *distantFuture = nil;
static NSNumber *distantFutureNumber = nil;

+ (void) initialize
{
  if (!distantFuture)
    {
      distantFuture = [[NSCalendarDate distantFuture] retain];
      /* INT_MAX due to Postgres constraint */
      distantFutureNumber = [[NSNumber numberWithUnsignedInt: INT_MAX] retain];
    }
}

+ (id) sharedICalFieldExtractor
{
  static OCSiCalFieldExtractor *extractor = nil;

  if (!extractor)
    extractor = [self new];

  return extractor;
}

/* operations */

- (NSNumber *) numberForDate: (NSCalendarDate *) _date
{
  return ((_date == distantFuture)
	  ? distantFutureNumber
	  : [NSNumber numberWithUnsignedInt: [_date timeIntervalSince1970]]);
}

- (NSMutableDictionary *) extractQuickFieldsFromEvent: (iCalEvent *) _event
{
  NSMutableDictionary *row;
  NSCalendarDate *startDate, *endDate;
  NSArray *attendees;
  NSString *uid, *title, *location, *status;
  NSNumber *sequence, *dateNumber;
  id organizer;
  id participants, partmails;
  NSMutableString *partstates;
  unsigned int i, count;
  BOOL isAllDay;
  iCalAccessClass accessClass;

  if (_event == nil)
    return nil;

  /* extract values */
 
  startDate = [_event startDate];
  endDate = [_event endDate];
  uid = [_event uid];
  title = [_event summary];
  location = [_event location];
  sequence = [_event sequence];
  accessClass = [_event symbolicAccessClass];
  isAllDay = [_event isAllDay];
  status = [[_event status] uppercaseString];

  attendees = [_event attendees];
  partmails = [attendees valueForKey: @"rfc822Email"];
  partmails = [partmails componentsJoinedByString: @"\n"];
  participants = [attendees valueForKey: @"cn"];
  participants = [participants componentsJoinedByString: @"\n"];

  /* build row */

  row = [NSMutableDictionary dictionaryWithCapacity:8];

  [row setObject: @"vevent" forKey: @"c_component"];
 
  if ([uid isNotNull]) 
    [row setObject:uid forKey: @"c_uid"];
  else
    [self logWithFormat: @"WARNING: could not extract a uid from event!"];


  [row setObject: [NSNumber numberWithBool: isAllDay]
       forKey: @"c_isallday"];
  [row setObject: [NSNumber numberWithBool: [_event isRecurrent]]
       forKey: @"c_iscycle"];
  [row setObject: [NSNumber numberWithBool: [_event isOpaque]]
       forKey: @"c_isopaque"];
  [row setObject: [NSNumber numberWithInt: [_event priorityNumber]]
       forKey: @"c_priority"];

  if ([title isNotNull]) [row setObject: title forKey: @"c_title"];
  if ([location isNotNull]) [row setObject: location forKey: @"c_location"];
  if ([sequence isNotNull]) [row setObject: sequence forKey: @"c_sequence"];

  if ([startDate isNotNull])
    [row setObject: [self numberForDate: startDate]
	 forKey: @"c_startdate"];
  if ([endDate isNotNull])
    {
      if (endDate == distantFuture)
	dateNumber = distantFutureNumber;
      else
	{
	  if (isAllDay)
	    i = 1;
	  else
	    i = 0;
	  dateNumber
	    = [NSNumber numberWithUnsignedInt:
			  [endDate timeIntervalSince1970] - i];
	}
      [row setObject: dateNumber forKey: @"c_enddate"];
    }

  if ([_event isRecurrent]) {
    NSCalendarDate *date;
 
    date = [_event lastPossibleRecurrenceStartDate];
    if (!date) {
      /* this could also be *nil*, but in the end it makes the fetchspecs
	 more complex - thus we set it to a "reasonable" distant future */
      date = distantFuture;
    }
    [row setObject:[self numberForDate:date] forKey: @"c_cycleenddate"];
    [row setObject:[_event cycleInfo] forKey: @"c_cycleinfo"];
  }

  if ([participants length] > 0)
    [row setObject: participants forKey: @"c_participants"];
  if ([partmails length] > 0)
    [row setObject: partmails forKey: @"c_partmails"];

  if ([status isNotNull]) {
    int code = 1;
 
    if ([status isEqualToString: @"TENTATIVE"])
      code = 2;
    else if ([status isEqualToString: @"CANCELLED"])
      code = 0;
    [row setObject:[NSNumber numberWithInt:code] forKey: @"c_status"];
  }
  else {
    /* confirmed by default */
    [row setObject: [NSNumber numberWithInt:1] forKey: @"c_status"];
  }

  [row setObject: [NSNumber numberWithUnsignedInt: accessClass]
       forKey: @"c_classification"];

  organizer = [_event organizer];
  if (organizer) {
    NSString *email;
 
    email = [organizer valueForKey: @"rfc822Email"];
    if (email)
      [row setObject:email forKey: @"c_orgmail"];
  }
 
  /* construct partstates */
  count = [attendees count];
  partstates = [[NSMutableString alloc] initWithCapacity:count * 2];
  for ( i = 0; i < count; i++) {
    iCalPerson *p;
    iCalPersonPartStat stat;
 
    p = [attendees objectAtIndex:i];
    stat = [p participationStatus];
    if(i != 0)
      [partstates appendString: @"\n"];
    [partstates appendFormat: @"%d", stat];
  }
  [row setObject:partstates forKey: @"c_partstates"];
  [partstates release];
  return row;
}

- (NSMutableDictionary *) extractQuickFieldsFromTodo: (iCalToDo *) _task
{
  NSMutableDictionary *row;
  NSCalendarDate *startDate, *dueDate;
  NSArray *attendees;
  NSString *uid, *title, *location, *status;
  NSNumber *sequence;
  id organizer, date;
  id participants, partmails;
  NSMutableString *partstates;
  unsigned i, count, code;
  iCalAccessClass accessClass;

  if (_task == nil)
    return nil;

  /* extract values */
 
  startDate = [_task startDate];
  dueDate = [_task due];
  uid = [_task uid];
  title = [_task summary];
  location = [_task location];
  sequence = [_task sequence];
  accessClass = [_task symbolicAccessClass];
  status = [[_task status] uppercaseString];

  attendees = [_task attendees];
  partmails = [attendees valueForKey: @"rfc822Email"];
  partmails = [partmails componentsJoinedByString: @"\n"];
  participants = [attendees valueForKey: @"cn"];
  participants = [participants componentsJoinedByString: @"\n"];

  /* build row */

  row = [NSMutableDictionary dictionaryWithCapacity:8];

  [row setObject: @"vtodo" forKey: @"c_component"];

  if ([uid isNotNull]) 
    [row setObject:uid forKey: @"c_uid"];
  else
    [self logWithFormat: @"WARNING: could not extract a uid from event!"];

  [row setObject:[NSNumber numberWithBool:[_task isRecurrent]]
       forKey: @"c_iscycle"];
  [row setObject:[NSNumber numberWithInt:[_task priorityNumber]]
       forKey: @"c_priority"];

  [row setObject: [NSNumber numberWithBool: NO]
       forKey: @"c_isallday"];
  [row setObject: [NSNumber numberWithBool: NO]
       forKey: @"c_isopaque"];

  if ([title isNotNull]) [row setObject: title forKey: @"c_title"];
  if ([location isNotNull]) [row setObject: location forKey: @"c_location"];
  if ([sequence isNotNull]) [row setObject: sequence forKey: @"c_sequence"];
 
  if ([startDate isNotNull])
    date = [self numberForDate: startDate];
  else
    date = [NSNull null];
  [row setObject: date forKey: @"c_startdate"];

  if ([dueDate isNotNull]) 
    date = [self numberForDate: dueDate];
  else
    date = [NSNull null];
  [row setObject: date forKey: @"c_enddate"];

  if ([participants length] > 0)
    [row setObject:participants forKey: @"c_participants"];
  if ([partmails length] > 0)
    [row setObject:partmails forKey: @"c_partmails"];

  if ([status isNotNull]) {
    code = 0; /* NEEDS-ACTION */
    if ([status isEqualToString: @"COMPLETED"])
      code = 1;
    else if ([status isEqualToString: @"IN-PROCESS"])
      code = 2;
    else if ([status isEqualToString: @"CANCELLED"])
      code = 3;
    [row setObject: [NSNumber numberWithInt: code] forKey: @"c_status"];
  }
  else {
    /* confirmed by default */
    [row setObject:[NSNumber numberWithInt:1] forKey: @"c_status"];
  }

  [row setObject: [NSNumber numberWithUnsignedInt: accessClass]
       forKey: @"c_classification"];

  organizer = [_task organizer];
  if (organizer) {
    NSString *email;
 
    email = [organizer valueForKey: @"rfc822Email"];
    if (email)
      [row setObject:email forKey: @"c_orgmail"];
  }
 
  /* construct partstates */
  count = [attendees count];
  partstates = [[NSMutableString alloc] initWithCapacity:count * 2];
  for ( i = 0; i < count; i++) {
    iCalPerson *p;
    iCalPersonPartStat stat;
 
    p = [attendees objectAtIndex:i];
    stat = [p participationStatus];
    if(i != 0)
      [partstates appendString: @"\n"];
    [partstates appendFormat: @"%d", stat];
  }
  [row setObject:partstates forKey: @"c_partstates"];
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
      [self logWithFormat: @"ERROR: given calendar contains no elements: %@", ical];
      element = nil;
    }

  return element;
}

- (NSMutableDictionary *)extractQuickFieldsFromContent:(NSString *)_content {
  NSDictionary *fields;
  id cal;
 
  if ([_content length] == 0)
    return nil;

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
	[self logWithFormat: @"ERROR: unexpected iCalendar parse result: %@",
	      cal];
      }
    }
  else
    [self logWithFormat: @"ERROR: parsing source didn't return anything"];

  return [fields autorelease];
}

@end /* OCSiCalFieldExtractor */
