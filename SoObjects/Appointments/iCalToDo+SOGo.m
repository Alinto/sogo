/* iCalEvent+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2008 Inverse inc.
 * Copyright (C) 2004-2005 SKYRIX Software AG
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
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalTrigger.h>
#import <NGCards/NSString+NGCards.h>

#import "iCalRepeatableEntityObject+SOGo.h"

#import "iCalToDo+SOGo.h"

@implementation iCalToDo (SOGoExtensions)

- (NSMutableDictionary *) quickRecord
{
  NSMutableDictionary *row;
  NSCalendarDate *startDate, *dueDate, *nextAlarmDate;
  NSArray *attendees, *categories;
  NSString *uid, *title, *location, *status;
  NSNumber *sequence;
  id organizer, date;
  id participants, partmails;
  NSMutableString *partstates;
  unsigned i, count, code;
  iCalAccessClass accessClass;

  /* extract values */
 
  startDate = [self startDate];
  dueDate = [self due];
  nextAlarmDate = nil;
  uid = [self uid];
  title = [self summary];
  if (![title isNotNull])
    title = @"";
  location = [self location];
  sequence = [self sequence];
  accessClass = [self symbolicAccessClass];
  status = [[self status] uppercaseString];

  attendees = [self attendees];
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

  [row setObject:[NSNumber numberWithBool:[self isRecurrent]]
       forKey: @"c_iscycle"];
  [row setObject:[NSNumber numberWithInt:[self priorityNumber]]
       forKey: @"c_priority"];

  [row setObject: [NSNumber numberWithBool: NO]
       forKey: @"c_isallday"];
  [row setObject: [NSNumber numberWithBool: NO]
       forKey: @"c_isopaque"];

  [row setObject: title forKey: @"c_title"];
  if ([location isNotNull]) [row setObject: location forKey: @"c_location"];
  if ([sequence isNotNull]) [row setObject: sequence forKey: @"c_sequence"];
 
  if ([startDate isNotNull])
    date = [self quickRecordDateAsNumber: startDate
		 withOffset: 0 forAllDay: NO];
  else
    date = [NSNull null];
  [row setObject: date forKey: @"c_startdate"];

  if ([dueDate isNotNull])
    date = [self quickRecordDateAsNumber: dueDate
		 withOffset: 0 forAllDay: NO];
  else
    date = [NSNull null];
  [row setObject: date forKey: @"c_enddate"];

  if ([self isRecurrent])
    {
      [row setObject: iCalDistantFutureNumber forKey: @"c_cycleenddate"];
      [row setObject: [self cycleInfo] forKey: @"c_cycleinfo"];
    }

  if ([participants length] > 0)
    [row setObject:participants forKey: @"c_participants"];
  if ([partmails length] > 0)
    [row setObject:partmails forKey: @"c_partmails"];

  if ([status isNotNull])
    {
      code = 0; /* NEEDS-ACTION */
      if ([status isEqualToString: @"COMPLETED"])
	code = 1;
      else if ([status isEqualToString: @"IN-PROCESS"])
	code = 2;
      else if ([status isEqualToString: @"CANCELLED"])
	code = 3;
      [row setObject: [NSNumber numberWithInt: code] forKey: @"c_status"];
    }
  else
    {
      /* confirmed by default */
      [row setObject:[NSNumber numberWithInt:1] forKey: @"c_status"];
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
      if(i != 0)
	[partstates appendString: @"\n"];
      [partstates appendFormat: @"%d", stat];
    }
  [row setObject:partstates forKey: @"c_partstates"];
  [partstates release];

  nextAlarmDate = nil;
  if (![self isRecurrent] && [self hasAlarms])
    {
      // We currently have the following limitations for alarms:
      // - the component must not be recurrent;
      // - only the first alarm is considered;
      // - the alarm's action must be of type DISPLAY;
      //
      // Morever, we don't update the quick table if the property X-WebStatus
      // of the trigger is set to "triggered".
      iCalAlarm *anAlarm;
      NSString *webstatus;

      anAlarm = [[self alarms] objectAtIndex: 0];
      if ([[anAlarm action] caseInsensitiveCompare: @"DISPLAY"]
          == NSOrderedSame)
        {
          webstatus = [[anAlarm trigger] value: 0 ofAttribute: @"x-webstatus"];
          if (!webstatus
              || ([webstatus caseInsensitiveCompare: @"TRIGGERED"]
                  != NSOrderedSame))
            nextAlarmDate = [anAlarm nextAlarmDate];
        }
    }
  if ([nextAlarmDate isNotNull])
    [row setObject: [NSNumber numberWithInt: [nextAlarmDate timeIntervalSince1970]]
	 forKey: @"c_nextalarm"];
  else
    [row setObject: [NSNumber numberWithInt: 0] forKey: @"c_nextalarm"];
  
  categories = [self categories];
  if ([categories count] > 0)
    [row setObject: [categories componentsJoinedByString: @","]
            forKey: @"c_category"];

  return row;
}

- (NGCalendarDateRange *) firstOccurenceRange
{
  return [NGCalendarDateRange calendarDateRangeWithStartDate: [self startDate]
			      endDate: [self due]];
}

- (unsigned int) occurenceInterval
{
  return [[self due] timeIntervalSinceDate: [self startDate]];
}

@end
