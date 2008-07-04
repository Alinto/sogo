/* NSArray+Scheduler.m - this file is part of SOGo
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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NGCalendarDateRange.h>

#import "NSArray+Scheduler.h"

@implementation NSArray (SOGoEventComparison)

- (NSComparisonResult) _compareCompletionWithStatus1: (NSNumber *) status1
					  andStatus2: (NSNumber *) status2
{
  NSComparisonResult result;
  unsigned int ts1, ts2;

  ts1 = [status1 intValue];
  ts2 = [status2 intValue];
  if (ts1 == 1 && ts2 != 1)
    result = NSOrderedDescending;
  else if (ts1 != 1 && ts2 == 1)
    result = NSOrderedAscending;
  else
    result = NSOrderedSame;

  return result;
}

- (NSComparisonResult) compareEventsStartDateAscending: (NSArray *) otherEvent
{
  NSComparisonResult result;
  unsigned int selfTime, otherTime;

  selfTime = [[self objectAtIndex: 4] intValue];
  otherTime = [[otherEvent objectAtIndex: 4] intValue];
  if (selfTime > otherTime)
    result = NSOrderedDescending;
  else if (selfTime < otherTime)
    result = NSOrderedAscending;
  else
    result = NSOrderedSame;

  return result;
}

- (NSComparisonResult) compareEventsEndDateAscending: (NSArray *) otherEvent
{
  NSComparisonResult result;
  unsigned int selfTime, otherTime;

  selfTime = [[self objectAtIndex: 5] intValue];
  otherTime = [[otherEvent objectAtIndex: 5] intValue];
  if (selfTime > otherTime)
    result = NSOrderedDescending;
  else if (selfTime < otherTime)
    result = NSOrderedAscending;
  else
    result = NSOrderedSame;

  return result;
}

- (NSComparisonResult) compareEventsTitleAscending: (NSArray *) otherEvent
{
  NSString *selfTitle, *otherTitle;

  selfTitle = [self objectAtIndex: 3];
  otherTitle = [otherEvent objectAtIndex: 3];

  return [selfTitle caseInsensitiveCompare: otherTitle];
}

- (NSComparisonResult) compareEventsLocationAscending: (NSArray *) otherEvent
{
  NSString *selfTitle, *otherTitle;

  selfTitle = [self objectAtIndex: 6];
  otherTitle = [otherEvent objectAtIndex: 6];

  return [selfTitle caseInsensitiveCompare: otherTitle];
}

- (NSComparisonResult) compareTasksAscending: (NSArray *) otherTask
{
  NSComparisonResult result;
  unsigned int selfTime, otherTime;
  Class nullClass;

  result = [self _compareCompletionWithStatus1: [self objectAtIndex: 2]
		 andStatus2: [otherTask objectAtIndex: 2]];
  if (result == NSOrderedSame)
    {
      nullClass = [NSNull class];
      selfTime = [[self objectAtIndex: 4] intValue];
      otherTime = [[otherTask objectAtIndex: 4] intValue];
      if (selfTime && !otherTime)
	result = NSOrderedAscending;
      else if (!selfTime && otherTime)
	result = NSOrderedDescending;
      else
	{
	  if (selfTime > otherTime)
	    result = NSOrderedDescending;
	  else if (selfTime < otherTime)
	    result = NSOrderedAscending;
	  else
	    result = [[self objectAtIndex: 1]
		       compare: [otherTask objectAtIndex: 1]];
	}
    }

  return result;
}

- (NSArray *) reversedArray 
{
  return [[self reverseObjectEnumerator] allObjects];
}

@end

@implementation NSMutableArray (SOGoEventComparison)

- (void) reverseArray
{
  [self setArray: [self reversedArray]];
}

@end
