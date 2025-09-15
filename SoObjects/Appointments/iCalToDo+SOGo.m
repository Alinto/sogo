/* iCalToDot+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2008-2017 Inverse inc.
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGCards/NSString+NGCards.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalTimeZone.h>

#import <SoObjects/SOGo/WOContext+SOGo.h>

#import <SOGo/CardElement+SOGo.h>
#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import "iCalRepeatableEntityObject+SOGo.h"

#import "iCalToDo+SOGo.h"

@implementation iCalToDo (SOGoExtensions)

+ (NSString *) statusForCode: (int) statusCode
{
  if (statusCode == taskStatusCompleted)
    return @"completed";
  else if (statusCode == taskStatusInProcess)
    return @"in-process";
  else if (statusCode == taskStatusCancelled)
    return @"cancelled";
  else if (statusCode == taskStatusNeedsAction)
    return @"needs-action";

  return @"";
}

- (NSDictionary *) attributesInContext: (WOContext *) context
{
  BOOL isAllDayStartDate, isAllDayDueDate;
  NSCalendarDate *startDate, *dueDate, *completedDate;
  NSMutableDictionary *data;
  NSTimeZone *timeZone;
  SOGoUserDefaults *ud;

  ud = [[context activeUser] userDefaults];
  timeZone = [ud timeZone];

  startDate = [self startDate];
  isAllDayStartDate = [(iCalDateTime *) [self uniqueChildWithTag: @"dtstart"] isAllDay];
  if (!isAllDayStartDate)
    [startDate setTimeZone: timeZone];

  dueDate = [self due];
  isAllDayDueDate = [(iCalDateTime *) [self uniqueChildWithTag: @"due"] isAllDay];
  if (!isAllDayDueDate)
    [dueDate setTimeZone: timeZone];

  completedDate = [self completed];
  [completedDate setTimeZone: timeZone];

  data = [NSMutableDictionary dictionaryWithDictionary: [super attributesInContext: context]];

  if (startDate)
    [data setObject: [startDate iso8601DateString] forKey: @"startDate"];
  if (dueDate)
    [data setObject: [dueDate iso8601DateString] forKey: @"dueDate"];
  if (completedDate)
    [data setObject: [completedDate iso8601DateString] forKey: @"completedDate"];

  if ([[self percentComplete] length])
    [data setObject: [NSNumber numberWithInt: [[self percentComplete] intValue]] forKey: @"percentComplete"];

  return data;
}

/**
 * @see [iCalRepeatableEntityObject+SOGo setAttributes:inContext:]
 * @see [iCalEntityObject+SOGo setAttributes:inContext:]
 * @see [UIxAppointmentEditor saveAction]
 */
- (void) setAttributes: (NSDictionary *) data
             inContext: (WOContext *) context
{
  BOOL isAllDayStartDate, isAllDayDueDate;
  NSCalendarDate *startDate, *dueDate, *completedDate;
  NSInteger percent;
  NSString *owner;
  SOGoUserDefaults *ud;
  iCalDateTime *todoStartDate, *todoDueDate;
  iCalTimeZone *tz;
  id o;

  [super setAttributes: data inContext: context];

  startDate = dueDate = completedDate = nil;

  // Handle start date
  isAllDayStartDate = YES;
  o = [data objectForKey: @"startDate"];
  if ([o isKindOfClass: [NSString class]] && [o length])
    startDate = [self dateFromString: o inContext: context];

  o = [data objectForKey: @"startTime"];
  if ([o isKindOfClass: [NSString class]] && [o length])
    {
      isAllDayStartDate = NO;
      [self adjustDate: &startDate withTimeString: o inContext: context];
    }

  if (startDate)
    [self setStartDate: startDate];
  else
    [self setStartDate: nil];

  // Handle due date
  isAllDayDueDate = YES;
  o = [data objectForKey: @"dueDate"];
  if ([o isKindOfClass: [NSString class]] && [o length])
    dueDate = [self dateFromString: o inContext: context];

  o = [data objectForKey: @"dueTime"];
  if ([o isKindOfClass: [NSString class]] && [o length])
    {
      isAllDayDueDate = NO;
      [self adjustDate: &dueDate withTimeString: o inContext: context];
    }

  if (dueDate)
    if (isAllDayDueDate)
      [self setAllDayDue: dueDate];
    else
      [self setDue: dueDate];
  else
    [self setDue: nil];

  if (!startDate && !dueDate)
    [self removeAllAlarms];

  // Handle time zone
  todoStartDate = (iCalDateTime *)[self uniqueChildWithTag: @"dtstart"];
  todoDueDate = (iCalDateTime *)[self uniqueChildWithTag: @"due"];
  tz = [todoStartDate timeZone];
  if (!tz)
    tz = [todoDueDate timeZone];

  if (isAllDayStartDate && isAllDayDueDate)
    {
      if (tz)
        [[self parent] removeChild: tz];
      [todoStartDate setTimeZone: nil];
      [todoDueDate setTimeZone: nil];
    }
  else
    {
      if (!tz)
        {
          ud = [[context activeUser] userDefaults];
          tz = [iCalTimeZone timeZoneForName: [ud timeZoneName]];
        }
      if (tz)
        {
          [[self parent] addTimeZone: tz];
          if (todoStartDate)
            {
              if (isAllDayStartDate)
                [todoStartDate setTimeZone: nil];
              else if (![todoStartDate timeZone])
                [todoStartDate setTimeZone: tz];
            }
          if (todoDueDate)
            {
              if (isAllDayDueDate)
                [todoDueDate setTimeZone: nil];
              else if (![todoDueDate timeZone])
                [todoDueDate setTimeZone: tz];
            }
        }
    }

  // Handle completed date
  o = [data objectForKey: @"completedDate"];
  if ([o isKindOfClass: [NSString class]] && [o length])
    {
      completedDate = [self dateFromString: o inContext: context];

      o = [data objectForKey: @"completedTime"];
      if ([o isKindOfClass: [NSString class]] && [o length])
        [self adjustDate: &completedDate withTimeString: o inContext: context];
    }
  else
    [(iCalDateTime *) [self uniqueChildWithTag: @"completed"] setDateTime: nil];

  o = [self status];
  if ([o length])
    {
      if ([o isEqualToString: @"COMPLETED"] && completedDate)
        // As specified in RFC5545, the COMPLETED property must use UTC time
        [self setCompleted: completedDate];
    }

  // Percent complete
  o = [data objectForKey: @"percentComplete"];
  if ([o isKindOfClass: [NSNumber class]])
    {
      percent = [o intValue];
      if (percent >= 0 && percent <= 100)
        [self setPercentComplete: [NSString stringWithFormat: @"%i", (int)percent]];
    }
  else
    [self setPercentComplete: @""];
  
  //To make an ics conforme with outlook live (bouh), valarm must be the last element of vevent
  //Try to set it here
  o = [data objectForKey: @"alarm"];
  if ([o isKindOfClass: [NSDictionary class]])
  {
    owner = [data objectForKey: @"owner"];
    [self _setAlarm: o forOwner: owner];
  }
}

- (NSMutableDictionary *) quickRecordFromContent: (NSString *) theContent
                                       container: (id) theContainer
                                 nameInContainer: (NSString *) nameInContainer
{
  NSMutableDictionary *row;
  NSCalendarDate *startDate, *dueDate, *completed;
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
  uid = [self uid];
  title = [self summary];
  if (![title isNotNull])
    title = @"";
  location = [self location];
  sequence = [self sequence];
  accessClass = [self symbolicAccessClass];
  completed = [self completed];
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

  if (completed || [status isNotNull])
    {
      code = 0;
      if (completed || [status isEqualToString: @"COMPLETED"])
        code = taskStatusCompleted;
      else if ([status isEqualToString: @"IN-PROCESS"])
        code = taskStatusInProcess;
      else if ([status isEqualToString: @"CANCELLED"])
        code = taskStatusCancelled;
      else if ([status isEqualToString: @"NEEDS-ACTION"])
        code = taskStatusNeedsAction;
      [row setObject: [NSNumber numberWithInt: code] forKey: @"c_status"];
    }
  else
    {
      /* confirmed by default */
      [row setObject: [NSNumber numberWithInt: 0] forKey: @"c_status"];
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

  /* handle alarms */
  [self updateNextAlarmDateInRow: row  forContainer: theContainer  nameInContainer: nameInContainer];

  categories = [self categories];
  if ([categories count] > 0)
    [row setObject: [categories componentsJoinedByString: @","]
            forKey: @"c_category"];
  else
    [row setObject: [NSNull null] forKey: @"c_category"];

  /* handle description */
  if ([self comment])
    [row setObject: [self comment]  forKey: @"c_description"];
  else
    [row setObject: [NSNull null] forKey: @"c_description"];

  return row;
}

- (NSTimeInterval) occurenceInterval
{
  if ([self due])
    return [[self due] timeIntervalSinceDate: [self startDate]];
  else
    // When no due date is defined, base recurrence calculation on a 60-minute duration
    return 3600;
}

@end
