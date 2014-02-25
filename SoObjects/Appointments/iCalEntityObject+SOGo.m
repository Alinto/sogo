/* iCalEntityObject+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2014 Inverse inc.
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
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSTimeZone.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalPerson.h>

#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import "iCalPerson+SOGo.h"

#import "iCalEntityObject+SOGo.h"

NSCalendarDate *iCalDistantFuture = nil;
NSNumber *iCalDistantFutureNumber = nil;

@implementation iCalEntityObject (SOGoExtensions)

+ (void) initializeSOGoExtensions
{
  if (!iCalDistantFuture)
    {
      iCalDistantFuture = [[NSCalendarDate distantFuture] retain];
      /* INT_MAX due to Postgres constraint */
      iCalDistantFutureNumber = [[NSNumber numberWithUnsignedInt: INT_MAX] retain];
    }
}

- (BOOL) userIsAttendee: (SOGoUser *) user
{
  NSEnumerator *attendees;
  iCalPerson *currentAttendee;
  BOOL isAttendee;

  isAttendee = NO;

  attendees = [[self attendees] objectEnumerator];
  currentAttendee = [attendees nextObject];
  while (!isAttendee
	 && currentAttendee)
    if ([user hasEmail: [currentAttendee rfc822Email]])
      isAttendee = YES;
    else
      currentAttendee = [attendees nextObject];

  return isAttendee;
}

- (iCalPerson *) userAsAttendee: (SOGoUser *) user
{
  NSEnumerator *attendees;
  iCalPerson *currentAttendee, *userAttendee;

  userAttendee = nil;

  attendees = [[self attendees] objectEnumerator];
  while (!userAttendee
	 && (currentAttendee = [attendees nextObject]))
    if ([user hasEmail: [currentAttendee rfc822Email]])
      userAttendee = currentAttendee;

  return userAttendee;
}

- (BOOL) userIsOrganizer: (SOGoUser *) user
{
  NSString *mail;
  BOOL b;

  mail = [[self organizer] rfc822Email];
  b = [user hasEmail: mail];
  if (b) return YES;

  // We check for the SENT-BY
  mail = [[self organizer] sentBy];

  if ([mail length])
    return [user hasEmail: mail];
  
  return NO;
}

- (NSArray *) attendeeUIDs
{
  NSEnumerator *attendees;
  NSString *uid;
  iCalPerson *currentAttendee;
  NSMutableArray *uids;

  uids = [NSMutableArray array];

  attendees = [[self attendees] objectEnumerator];
  while ((currentAttendee = [attendees nextObject]))
    {
      uid = [currentAttendee uid];
      if (uid)
	[uids addObject: uid];
    }

  return uids;
}

#warning this method should be implemented in a category of iCalToDo
- (BOOL) isStillRelevant
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (id) itipEntryWithMethod: (NSString *) method
{
  iCalCalendar *newCalendar;
  iCalEntityObject *currentEvent, *newEntry;
  iCalPerson *organizer;

  NSArray *events;
  int i, count;
  
  newCalendar = [parent mutableCopy];
  [newCalendar autorelease];
  [newCalendar setMethod: method];
  
  events = [newCalendar childrenWithTag: tag];
  count = [events count];
  if (count > 1)
    {
      // If the event is recurrent, remove all occurences
      organizer = [[(iCalEntityObject *)[newCalendar firstChildWithTag: tag] organizer] mutableCopy];
      for (i = 0; i < count; i++)
	{
	  currentEvent = [events objectAtIndex: i];
	  [[newCalendar children] removeObject: currentEvent];
	}
      newEntry = [[self mutableCopy] autorelease];
      [newEntry setOrganizer: organizer];
      [newCalendar addChild: newEntry];
    }
  else
    newEntry = (iCalEntityObject *) [newCalendar firstChildWithTag: tag];

  return newEntry;
}

- (NSArray *) attendeesWithoutUser: (SOGoUser *) user
{
  NSMutableArray *newAttendees;
  NSArray *oldAttendees;
  unsigned int count, max;
  iCalPerson *currentAttendee;
  NSString *userID;

  userID = [user login];
  oldAttendees = [self attendees];
  max = [oldAttendees count];
  newAttendees = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      currentAttendee = [oldAttendees objectAtIndex: count];
      if (![[currentAttendee uid] isEqualToString: userID])
	[newAttendees addObject: currentAttendee];
    }

  return newAttendees;
}

- (NSNumber *) quickRecordDateAsNumber: (NSCalendarDate *) _date
			    withOffset: (int) offset
			     forAllDay: (BOOL) allDay
{
  NSTimeInterval seconds;
  NSNumber *dateNumber;

  if (_date == iCalDistantFuture)
    dateNumber = iCalDistantFutureNumber;
  else
    {
      seconds = [_date timeIntervalSince1970] + offset;
      if (allDay)
        seconds += [[_date timeZone] secondsFromGMT];

      dateNumber = [NSNumber numberWithInt: seconds];
    }

  return dateNumber;
}

- (NSMutableDictionary *) quickRecord
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (int) priorityNumber
{
  NSString *prio;
  NSRange r;
  int priorityNumber;

  prio = [self priority];
  if (prio)
    {
      r = [prio rangeOfString: @";"];
      if (r.length)
	prio = [prio substringToIndex:r.location];
      priorityNumber = [prio intValue];
    }
  else
    priorityNumber = 0;

  return priorityNumber;
}

- (NSString *) createdBy
{
  NSString *created_by;

  created_by = [[self firstChildWithTag: @"X-SOGo-Component-Created-By"] flattenedValuesForKey: @""];
  
  // We consider "SENT-BY" in case our custom header isn't found
  if (![created_by length])
    {
      created_by = [[self organizer] sentBy];
    }

  return created_by;
}

@end
