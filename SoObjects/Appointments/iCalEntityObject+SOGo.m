/* iCalEntityObject+SOGo.m - this file is part of SOGo
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
#import <Foundation/NSEnumerator.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalPerson.h>

#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>

#import "iCalPerson+SOGo.h"

#import "iCalEntityObject+SOGo.h"

@implementation iCalEntityObject (SOGoExtensions)

- (BOOL) userIsParticipant: (SOGoUser *) user
{
  NSEnumerator *participants;
  iCalPerson *currentParticipant;
  BOOL isParticipant;

  isParticipant = NO;

  participants = [[self participants] objectEnumerator];
  currentParticipant = [participants nextObject];
  while (!isParticipant
	 && currentParticipant)
    if ([user hasEmail: [currentParticipant rfc822Email]])
      isParticipant = YES;
    else
      currentParticipant = [participants nextObject];

  return isParticipant;
}

#warning user could be a delegate, we will need to handle that someday
- (BOOL) userIsOrganizer: (SOGoUser *) user
{
  NSString *orgMail;

  orgMail = [[self organizer] rfc822Email];

  return [user hasEmail: orgMail];
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
  iCalEntityObject *newEntry;

  newCalendar = [parent mutableCopy];
  [newCalendar autorelease];
  [newCalendar setMethod: method];
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

@end
