/* NSArray+Scheduler.m - this file is part of SOGo
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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NSNull+misc.h>

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

  selfTime = [[self objectAtIndex: eventStartDateIndex] intValue];
  otherTime = [[otherEvent objectAtIndex: eventStartDateIndex] intValue];
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

  selfTime = [[self objectAtIndex: eventEndDateIndex] intValue];
  otherTime = [[otherEvent objectAtIndex: eventEndDateIndex] intValue];
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

  selfTitle = [self objectAtIndex: eventTitleIndex];
  otherTitle = [otherEvent objectAtIndex: eventTitleIndex];

  return [selfTitle caseInsensitiveCompare: otherTitle];
}

- (NSComparisonResult) compareEventsLocationAscending: (NSArray *) otherEvent
{
  NSString *selfTitle, *otherTitle;

  selfTitle = [self objectAtIndex: eventLocationIndex];
  otherTitle = [otherEvent objectAtIndex: eventLocationIndex];

  return [selfTitle caseInsensitiveCompare: otherTitle];
}

- (NSComparisonResult) compareEventsCalendarNameAscending: (NSArray *) otherEvent
{
  NSString *selfCalendarName, *otherCalendarName;

  selfCalendarName = [self objectAtIndex: eventCalendarNameIndex];
  otherCalendarName = [otherEvent objectAtIndex: eventCalendarNameIndex];

  return [selfCalendarName caseInsensitiveCompare: otherCalendarName];
}

- (NSComparisonResult) compareTasksAscending: (NSArray *) otherTask
{
  NSComparisonResult result;
  unsigned int selfTime, otherTime;

  result = [self _compareCompletionWithStatus1: [self objectAtIndex: taskCalendarNameIndex]
                                    andStatus2: [otherTask objectAtIndex: taskCalendarNameIndex]];
  if (result == NSOrderedSame)
  {
    // End date
    selfTime = [[self objectAtIndex: taskEndDateIndex] intValue];
    otherTime = [[otherTask objectAtIndex: taskEndDateIndex] intValue];
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
      {
        // Calendar ID
        result = [[self objectAtIndex: taskFolderIndex]
                    compare: [otherTask objectAtIndex: taskFolderIndex]];
        if (result == NSOrderedSame)
          // Task name
          result = [[self objectAtIndex: taskTitleIndex]
                      compare: [otherTask objectAtIndex: taskTitleIndex]
                      options: NSCaseInsensitiveSearch];
      }
    }
  }

  return result;
}

- (NSComparisonResult) compareTasksPriorityAscending: (NSArray *) otherTask
{
  NSComparisonResult result;
  int selfPriority, otherPriority;

  selfPriority = [[self objectAtIndex: taskPriorityIndex] intValue];
  otherPriority = [[otherTask objectAtIndex: taskPriorityIndex] intValue];

  if (selfPriority && !otherPriority)
    result = NSOrderedAscending;
  else if (!selfPriority && otherPriority)
    result = NSOrderedDescending;
  else
  {
    if (selfPriority > otherPriority)
      result = NSOrderedDescending;
    else if (selfPriority < otherPriority)
      result = NSOrderedAscending;
    else
      result = NSOrderedSame;
  }
  return result;
}

- (NSComparisonResult) compareTasksTitleAscending: (NSArray *) otherTask
{
  NSString *selfTitle, *otherTitle;

  selfTitle = [self objectAtIndex: taskTitleIndex];
  otherTitle = [otherTask objectAtIndex: taskTitleIndex];

  return [selfTitle caseInsensitiveCompare: otherTitle];
}

- (NSComparisonResult) compareTasksEndAscending: (NSArray *) otherTask
{
  NSComparisonResult result;
  unsigned int selfTime, otherTime;

  // End date
  selfTime = [[self objectAtIndex: taskEndDateIndex] intValue];
  otherTime = [[otherTask objectAtIndex: taskEndDateIndex] intValue];
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
    {
      // Calendar ID
      result = [[self objectAtIndex: taskFolderIndex]
                  compare: [otherTask objectAtIndex: taskFolderIndex]];
      if (result == NSOrderedSame)
        // Task name
        result = [[self objectAtIndex: taskTitleIndex]
                    compare: [otherTask objectAtIndex: taskTitleIndex]
                    options: NSCaseInsensitiveSearch];
    }
  }

  return result;
}

- (NSComparisonResult) compareTasksLocationAscending: (NSArray *) otherTask
{
  NSString *selfLocation, *otherLocation;

  selfLocation = [self objectAtIndex: taskLocationIndex];
  otherLocation = [otherTask objectAtIndex: taskLocationIndex];

  return [selfLocation caseInsensitiveCompare: otherLocation];
}

- (NSComparisonResult) compareTasksCategoryAscending: (NSArray *) otherTask
{
  NSString *selfCategory, *otherCategory;
  NSComparisonResult result;

  selfCategory = [self objectAtIndex: taskCategoryIndex];
  otherCategory = [otherTask objectAtIndex: taskCategoryIndex];

  if ([selfCategory isNotNull] && [otherCategory isNotNull])
    result = [selfCategory caseInsensitiveCompare: otherCategory];
  else if ([selfCategory isNotNull])
    result = NSOrderedAscending;
  else if ([otherCategory isNotNull])
    result = NSOrderedDescending;
  else
    result = NSOrderedSame;

  return result;
}

- (NSComparisonResult) compareTasksCalendarNameAscending: (NSArray *) otherTask
{
  NSString *selfCalendarName, *otherCalendarName;

  selfCalendarName = [self objectAtIndex: taskCalendarNameIndex];
  otherCalendarName = [otherTask objectAtIndex: taskCalendarNameIndex];

  return [selfCalendarName caseInsensitiveCompare: otherCalendarName];
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
