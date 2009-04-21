/* iCalEvent+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse inc.
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

#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGCards/iCalAlarm.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalTrigger.h>
#import <NGCards/NSString+NGCards.h>

#import "iCalRepeatableEntityObject+SOGo.h"

#import "iCalEvent+SOGo.h"

@implementation iCalEvent (SOGoExtensions)

- (BOOL) isStillRelevant
{
  NSCalendarDate *now, *lastRecurrence;
  BOOL isStillRelevent;
  
  now = [NSCalendarDate calendarDate];

  if ([self isRecurrent])
    {
      lastRecurrence = [self lastPossibleRecurrenceStartDate];
      isStillRelevent = (lastRecurrence == nil || [lastRecurrence earlierDate: now] == now);
    }
  else
    isStillRelevent = ([[self endDate] earlierDate: now] == now);
  
  return isStillRelevent;
}

- (NSMutableDictionary *) quickRecord
{
  NSMutableDictionary *row;
  NSCalendarDate *startDate, *endDate, *nextAlarmDate;
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
  nextAlarmDate = nil;
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

  if ([self hasAlarms])
    {
      // We currently have the following limitations for alarms:
      // - only the first alarm is considered;
      // - the alarm's action must be of type DISPLAY;
      // - the alarm's trigger value type must be DURATION.
      
      iCalAlarm *anAlarm;
      iCalTrigger *aTrigger;
      NSCalendarDate *relationDate;
      NSString *relation;
      NSTimeInterval anInterval;

      anAlarm = [[self alarms] objectAtIndex: 0];
      aTrigger = [anAlarm trigger];
      relation = [aTrigger relationType];
      anInterval = [[aTrigger value] durationAsTimeInterval];

      if ([[anAlarm action] caseInsensitiveCompare: @"DISPLAY"] == NSOrderedSame &&
	  [[aTrigger valueType] caseInsensitiveCompare: @"DURATION"] == NSOrderedSame)
	{
	  if ([self isRecurrent])
	    {
	      if ([self isStillRelevant])
		{
		  NSArray *occurrences;
		  NSCalendarDate *now, *later;
		  NGCalendarDateRange *range;

		  // We only compute the next occurrence of the repeating event
		  // for the next 48 hours
		  now = [NSCalendarDate calendarDate];
		  later = [now addTimeInterval: (60*60*48)];
		  range = [NGCalendarDateRange calendarDateRangeWithStartDate: now
					       endDate: later];
		  occurrences = [self recurrenceRangesWithinCalendarDateRange: range];
		  if ([occurrences count] > 0)
		    {
		      range = [occurrences objectAtIndex: 0];
		      if ([relation caseInsensitiveCompare: @"END"] == NSOrderedSame)
			relationDate = [range endDate];
		      else
			relationDate = [range startDate];
		    }
		}
	    }
	  else
	    {
	      // Event is not reccurent
	      if ([relation caseInsensitiveCompare: @"END"] == NSOrderedSame)
		relationDate = endDate;
	      else
		relationDate = startDate;
	    }
	  
	  // Compute the next alarm date with respect to the reference date
	  if ([relationDate isNotNull])
	    nextAlarmDate = [relationDate addTimeInterval: anInterval];
	}
    }
  if ([nextAlarmDate isNotNull])
    [row setObject: [NSNumber numberWithInt: [nextAlarmDate timeIntervalSince1970]]
	 forKey: @"c_nextalarm"];
  else
    [row setObject: [NSNumber numberWithInt: 0] forKey: @"c_nextalarm"];


  return row;
}

- (NGCalendarDateRange *) firstOccurenceRange
{
  return [NGCalendarDateRange calendarDateRangeWithStartDate: [self startDate]
			      endDate: [self endDate]];
}

- (unsigned int) occurenceInterval
{
  return [[self endDate] timeIntervalSinceDate: [self startDate]];
}

@end
