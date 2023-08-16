/* iCalCalendar+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2012-2017 Inverse inc
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
#import <Foundation/NSString.h>

#import <NGCards/iCalEvent.h>
#import <NGCards/iCalRepeatableEntityObject.h>

#import "iCalCalendar+SOGo.h"
#import "iCalEntityObject+SOGo.h"
#import "NSArray+Appointments.h"

@implementation iCalCalendar (SOGoExtensions)

- (id) _occurrence: (NSString *) recID
           inArray: (NSArray *) components
{
  id occurrence;
  iCalRepeatableEntityObject *component;
  NSUInteger count, max, seconds, recSeconds;
  NSCalendarDate* recId;

  occurrence = nil;

  seconds = [recID intValue];

  max = [components count];

  /* master occurrence */
  component = [components objectAtIndex: 0];

  if ([component isRecurrent] || [component recurrenceId])
  {
    // Skip the master event if required
    count = ([component recurrenceId] ? 0 : 1);
    while (!occurrence && count < max)
	  {
	    component = [components objectAtIndex: count];
      recSeconds = [[component recurrenceId] timeIntervalSince1970];
	    if (recSeconds == seconds)
	      occurrence = component;
	    else
	      count++;
	  }
  }
  else
  {
    /* The "master" event could be that occurrence. */
    recSeconds = [[component recurrenceId] timeIntervalSince1970];
    if (recSeconds == seconds)
      occurrence = component;
  }

  return occurrence;
}

- (iCalEvent *) eventWithRecurrenceID: (NSString *) recID
{
  return [self _occurrence: recID inArray: [self events]];
}

- (iCalToDo *) todoWithRecurrenceID: (NSString *) recID;
{
  return [self _occurrence: recID inArray: [self todos]];
}

- (NSMutableDictionary *) quickRecordFromContent: (NSString *) theContent
				       container: (id) theContainer
				 nameInContainer: (NSString *) nameInContainer
{
  CardGroup *element;
  NSArray *elements;
  
  unsigned int count;
 
  elements = [self allObjects];
  count = [elements count];
  if (count)
    element = [elements objectAtIndex: 0];
  else
    {
      //NSLog(@"ERROR: given calendar contains no elements: %@", self);
      element = nil;
    }

  return [(id)element quickRecordFromContent: theContent  container: theContainer  nameInContainer: nameInContainer];
}

- (NSArray *) quickRecordsFromContent: (NSString *) theContent
                            container: (id) theContainer
                      nameInContainer: (NSString *) nameInContainer
{
  NSCalendarDate *recurrenceId;
  NSMutableDictionary *record;
  NSMutableArray *allRecords;
  NSNumber *dateSecs;
  NSArray *elements;

  int i;

  allRecords = [NSMutableArray array];

  // FIXME: what about tasks?
  elements = [self events];

  for (i = 0; i < [elements count]; i++)
    {
      record = [(id)[elements objectAtIndex: i] quickRecordFromContent: theContent  container: theContainer  nameInContainer: nameInContainer];
      recurrenceId = [[elements objectAtIndex: i] recurrenceId];
      dateSecs = [NSNumber numberWithDouble: [recurrenceId timeIntervalSince1970]];

      [record setObject: nameInContainer  forKey: @"c_name"];
      [record setObject: dateSecs forKey: @"c_recurrence_id"];

      [allRecords addObject: record];
    }

  return allRecords;
}

- (NSArray *) attendeesWithoutUser: (SOGoUser *) user
{
  NSMutableArray *allAttendees;
  NSArray *events, *attendees;
  iCalPerson *attendee;
  iCalEvent *event;

  int i, j;

  allAttendees = [NSMutableArray array];
  events = [self events];

  for (i = 0; i < [events count]; i++)
    {
      event = [events objectAtIndex: i];
      attendees = [event attendees];
      for (j = 0; j < [attendees count]; j++)
        {
          attendee = [attendees objectAtIndex: j];
          [allAttendees removePerson: attendee];
          [allAttendees addObject: attendee];
        }
    }

  return allAttendees;
}

@end
