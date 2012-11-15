/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import "iCalAttachment.h"
#import "iCalEvent.h"
#import "iCalPerson.h"
#import "iCalRecurrenceRule.h"
#import "iCalTrigger.h"
#import "iCalToDo.h"
#import "NSString+NGCards.h"

#import "iCalAlarm.h"

@implementation iCalAlarm

- (Class) classForTag: (NSString *) classTag
{
  Class tagClass;

  if ([classTag isEqualToString: @"TRIGGER"])
    tagClass = [iCalTrigger class];
  else if ([classTag isEqualToString: @"ATTACH"])
    tagClass = [iCalAttachment class];
  else if ([classTag isEqualToString: @"RRULE"])
    tagClass = [iCalRecurrenceRule class];
  else if ([classTag isEqualToString: @"ATTENDEE"])
    tagClass = [iCalPerson class];
  else if ([classTag isEqualToString: @"ACTION"]
           || [classTag isEqualToString: @"COMMENT"]
           || [classTag isEqualToString: @"DESCRIPTION"]
           || [classTag isEqualToString: @"SUMMARY"])
    tagClass = [CardElement class];
  else
    tagClass = [super classForTag: classTag];

  return tagClass;
}

/* accessors */

- (void) setTrigger: (iCalTrigger *) _value
{
  [self setUniqueChild: _value];
}

- (iCalTrigger *) trigger
{
  return (iCalTrigger *) [self uniqueChildWithTag: @"trigger"];
}

- (void) setAttach: (iCalAttachment *) _value
{
  [self setUniqueChild: _value];
}

- (iCalAttachment *) attach
{
  return (iCalAttachment *) [self uniqueChildWithTag: @"attach"];
}

- (void) setAction: (NSString *) _value
{
  [[self uniqueChildWithTag: @"action"] setSingleValue: _value
                                                forKey: @""];
}

- (NSString *) action
{
  return [[self uniqueChildWithTag: @"action"] flattenedValuesForKey: @""];
}

- (void) setSummary: (NSString *) _value
{
  [[self uniqueChildWithTag: @"summary"] setSingleValue: _value
                                                 forKey: @""];
}

- (NSString *) summary
{
  return [[self uniqueChildWithTag: @"summary"] flattenedValuesForKey: @""];
}

- (void) setComment: (NSString *) _value
{
  [[self uniqueChildWithTag: @"description"] setSingleValue: _value
                                                     forKey: @""];
}

- (NSString *) comment
{
  return [[self uniqueChildWithTag: @"description"] flattenedValuesForKey: @""];
}

- (void) setRecurrenceRule: (NSString *) _value
{
  [[self uniqueChildWithTag: @"rrule"] setSingleValue: _value
                                               forKey: @""];
}

- (void) setAttendees: (NSArray *) attendees
{
  [self removeAllAttendees];
  [self addChildren: attendees];
}

- (NSArray *) attendees
{
  return [self childrenWithTag: @"attendee"];
}

- (void) removeAllAttendees
{
  [children removeObjectsInArray: [self attendees]];
}

- (NSString *) recurrenceRule
{
  return [[self uniqueChildWithTag: @"rrule"] flattenedValuesForKey: @""];
}

- (NSCalendarDate *) nextAlarmDate
{
  NSCalendarDate *nextAlarmDate;

  // We currently have the following limitations for alarms:
  // - the alarm's trigger value type must be DURATION;

  if ([parent isKindOfClass: [iCalEvent class]]
      || [parent isKindOfClass: [iCalToDo class]])
    nextAlarmDate = [[self trigger] nextAlarmDate];
  else
    {
      nextAlarmDate = nil;
      [self errorWithFormat: @"alarms not handled for elements of class '%@'",
            NSStringFromClass ([parent class])];
    }

  return nextAlarmDate;
}

@end /* iCalAlarm */
