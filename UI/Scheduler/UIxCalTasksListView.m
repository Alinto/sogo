/* UIxCalTasksListView.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse groupe conseil
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

#import <Foundation/NSDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSCalendarDate+misc.h>
#import <Appointments/SOGoAppointmentFolder.h>
#import <SOGoUI/SOGoDateFormatter.h>

#import "UIxCalTasksListView.h"

@implementation UIxCalTasksListView

- (id) init
{
  if ((self = [super init]))
    {
      startDate = nil;
      endDate = nil;
      knowsToShow = NO;
      showCompleted = NO;
    }

  return self;
}

- (void) setCurrentTask: (NSDictionary *) task
{
  currentTask = task;
}

- (NSDictionary *) currentTask
{
  return currentTask;
}

- (NSCalendarDate *) startDate
{
  return nil;
}

- (NSCalendarDate *) endDate
{
  return nil;
}

- (NSString *) getStatusClassForTask: (NSDictionary *) task
{
  NSCalendarDate *taskDate, *now;
  NSString *statusClass, *allClasses;
  NSNumber *taskDueStamp;

  if ([[task objectForKey: @"status"] intValue] == 1)
    statusClass = @"completed";
  else
    {
      taskDueStamp = [task objectForKey: @"enddate"];
      if ([taskDueStamp intValue])
        {
          now = [NSCalendarDate calendarDate];
          taskDate = [NSCalendarDate dateWithTimeIntervalSince1970:
                                       [taskDueStamp intValue]];
          if ([taskDate earlierDate: now] == taskDate)
            statusClass = @"overdue";
          else
            {
              if ([taskDate isToday])
                statusClass = @"duetoday";
              else
                statusClass = @"duelater";
            }
        }
      else
        statusClass = @"duelater";
    }

  allClasses = [NSString stringWithFormat: @"%@ ownerIs%@",
                         statusClass,
                         [task objectForKey: @"owner"]];

  return allClasses;
}

- (WOResponse *) tasksListAction
{
  WOResponse *response;
  NSDictionary *tasks;
  NSMutableArray *filteredTasks;
  BOOL showCompleted;
  unsigned i, count;

  response = [context response];
  filteredTasks = [NSMutableArray new];
  [filteredTasks autorelease];
  tasks = [self _fetchCoreInfosForComponent: @"vtodo"];
  showCompleted = [[self queryParameterForKey: @"show-completed"] intValue];
  
  count = [tasks count];
  for (i = 0; i < count; i++) {
    NSDictionary *task;
    NSArray *filteredTask;

    task = [tasks objectAtIndex: i];
    
    if ([[task objectForKey: @"status"] intValue] != 1 
	|| showCompleted)
      {
	filteredTask = [NSArray arrayWithObjects:
				  [task objectForKey: @"c_name"],
				[task objectForKey: @"owner"],
				[task objectForKey: @"status"],
				[task objectForKey: @"title"],
				[self getStatusClassForTask: task],
				nil];
      [filteredTasks addObject: filteredTask];
    }
  }
  
  [response setStatus: 200];
  [response appendContentString: [filteredTasks jsonRepresentation]];

  return response;
}

- (BOOL) shouldDisplayCurrentTask
{
  if (!knowsToShow)
    {
      showCompleted
        = [[self queryParameterForKey: @"show-completed"] intValue];
      knowsToShow = YES;
    }

  return ([[currentTask objectForKey: @"status"] intValue] != 1
	   || showCompleted);
}

- (BOOL) shouldShowCompletedTasks
{
  if (!knowsToShow)
    {
      showCompleted
        = [[self queryParameterForKey: @"show-completed"] intValue];
      knowsToShow = YES;
    }

  return showCompleted;
}

- (BOOL) isCurrentTaskCompleted
{
  return ([[currentTask objectForKey: @"status"] intValue] == 1);
}

@end
