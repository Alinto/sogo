/* iCalEvent+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>

#import "iCalRepeatableEntityObject+SOGo.h"

#import "iCalEvent+SOGo.h"

@implementation iCalEvent (SOGoExtensions)

- (BOOL) isStillRelevant
{
  NSCalendarDate *now;

  now = [NSCalendarDate calendarDate];

  return ([[self endDate] earlierDate: now] == now);
}

- (NSMutableDictionary *) quickRecord
{
  NSMutableDictionary *row;
  NSCalendarDate *startDate, *endDate;
  NSArray *attendees;
  NSString *uid, *title, *location, *status;
  NSNumber *sequence;
  id organizer;
  id participants, partmails;
  NSMutableString *partstates;
  unsigned int i, count, boolTmp;
  BOOL isAllDay;
  iCalAccessClass accessClass;

  /* extract values */

  startDate = [self startDate];
  endDate = [self endDate];
  uid = [self uid];
  title = [self summary];
  if (![title isNotNull])
    title = @"";
  location = [self location];
  sequence = [self sequence];
  accessClass = [self symbolicAccessClass];
  isAllDay = [self isAllDay];
  status = [[self status] uppercaseString];

  attendees = [self attendees];
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

  boolTmp = ((isAllDay) ? 1 : 0);
  [row setObject: [NSNumber numberWithInt: boolTmp]
       forKey: @"c_isallday"];
  boolTmp = (([self isRecurrent]) ? 1 : 0);
  [row setObject: [NSNumber numberWithInt: boolTmp]
       forKey: @"c_iscycle"];
  boolTmp = (([self isOpaque]) ? 1 : 0);
  [row setObject: [NSNumber numberWithInt: boolTmp]
       forKey: @"c_isopaque"];
  [row setObject: [NSNumber numberWithInt: [self priorityNumber]]
       forKey: @"c_priority"];

  [row setObject: title forKey: @"c_title"];
  if ([location isNotNull]) [row setObject: location forKey: @"c_location"];
  if ([sequence isNotNull]) [row setObject: sequence forKey: @"c_sequence"];

  if ([startDate isNotNull])
    {
      if (isAllDay)
	NSLog (@"start date...");
      [row setObject: [self quickRecordDateAsNumber: startDate
			    withOffset: 0 forAllDay: isAllDay]
	   forKey: @"c_startdate"];
    }
  if ([endDate isNotNull])
    [row setObject: [self quickRecordDateAsNumber: endDate
			  withOffset: ((isAllDay) ? -1 : 0)
			  forAllDay: isAllDay]
	 forKey: @"c_enddate"];

  if ([self isRecurrent])
    {
      NSCalendarDate *date;
      
      date = [self lastPossibleRecurrenceStartDate];
      if (!date)
	{
	  /* this could also be *nil*, but in the end it makes the fetchspecs
	     more complex - thus we set it to a "reasonable" distant future */
	  date = iCalDistantFuture;
	}
      [row setObject: [self quickRecordDateAsNumber: date
			    withOffset: 0 forAllDay: NO]
	   forKey: @"c_cycleenddate"];
      [row setObject: [self cycleInfo] forKey: @"c_cycleinfo"];
    }

  if ([participants length] > 0)
    [row setObject: participants forKey: @"c_participants"];
  if ([partmails length] > 0)
    [row setObject: partmails forKey: @"c_partmails"];

  if ([status isNotNull])
    {
      int code = 1;
 
      if ([status isEqualToString: @"TENTATIVE"])
	code = 2;
      else if ([status isEqualToString: @"CANCELLED"])
	code = 0;
      [row setObject:[NSNumber numberWithInt:code] forKey: @"c_status"];
    }
  else
    {
      /* confirmed by default */
      [row setObject: [NSNumber numberWithInt:1] forKey: @"c_status"];
    }

  [row setObject: [NSNumber numberWithUnsignedInt: accessClass]
       forKey: @"c_classification"];

  organizer = [self organizer];
  if (organizer)
    {
      NSString *email;
 
      email = [organizer valueForKey: @"rfc822Email"];
      if (email)
	[row setObject:email forKey: @"c_orgmail"];
    }
 
  /* construct partstates */
  count = [attendees count];
  partstates = [[NSMutableString alloc] initWithCapacity:count * 2];
  for (i = 0; i < count; i++)
    {
      iCalPerson *p;
      iCalPersonPartStat stat;
 
      p = [attendees objectAtIndex:i];
      stat = [p participationStatus];
      if (i)
	[partstates appendString: @"\n"];
      [partstates appendFormat: @"%d", stat];
    }
  [row setObject:partstates forKey: @"c_partstates"];
  [partstates release];

  return row;
}

@end
