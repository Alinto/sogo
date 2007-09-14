/* UIxTaskEditor.m - this file is part of SOGo
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

#import <NGObjWeb/SoObject.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSCalendarDate+misc.h>

#import <NGCards/iCalToDo.h>
#import <NGCards/iCalPerson.h>

#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoContentObject.h>
#import <SoObjects/Appointments/SOGoAppointmentFolder.h>
#import <SoObjects/Appointments/SOGoTaskObject.h>

#import "UIxComponentEditor.h"
#import "UIxTaskEditor.h"

@implementation UIxTaskEditor

- (id) init
{
  if ((self = [super init]))
    {
      taskStartDate = nil;
      taskDueDate = nil;
      statusDate = nil;
      hasStartDate = NO;
      hasDueDate = NO;
      status = nil;
      statusPercent = nil;
      item = nil;
      todo = nil;
    }

  return self;
}

- (void) dealloc
{
  [taskStartDate release];
  [taskDueDate release];
  [statusDate release];
  [status release];
  [statusPercent release];
  [super dealloc];
}

/* template values */
- (iCalToDo *) todo
{
  return todo;
}

- (NSString *) saveURL
{
  return [NSString stringWithFormat: @"%@/saveAsTask",
                   [[self clientObject] baseURL]];
}

/* icalendar values */
- (void) setTaskStartDate: (NSCalendarDate *) newTaskStartDate
{
  ASSIGN (taskStartDate, newTaskStartDate);
}

- (NSCalendarDate *) taskStartDate
{
  return taskStartDate;
}

- (void) setHasStartDate: (BOOL) newHasStartDate
{
  hasStartDate = newHasStartDate;
}

- (BOOL) hasStartDate
{
  return hasStartDate;
}

- (BOOL) startDateDisabled
{
  return !hasStartDate;
}

- (void) setTaskDueDate: (NSCalendarDate *) newTaskDueDate
{
  ASSIGN (taskDueDate, newTaskDueDate);
}

- (NSCalendarDate *) taskDueDate
{
  return taskDueDate;
}

- (void) setHasDueDate: (BOOL) newHasDueDate
{
  hasDueDate = newHasDueDate;
}

- (BOOL) hasDueDate
{
  return hasDueDate;
}

- (BOOL) dueDateDisabled
{
  return !hasDueDate;
}

- (NSArray *) repeatList
{
  static NSArray *repeatItems = nil;

  if (!repeatItems)
    {
      repeatItems = [NSArray arrayWithObjects: @"DAILY",
                             @"WEEKLY",
                             @"BI-WEEKLY",
                             @"EVERY WEEKDAY",
                             @"MONTHLY",
                             @"YEARLY",
                             @"-",
                             @"CUSTOM",
                             nil];
      [repeatItems retain];
    }

  return repeatItems;
}

- (NSString *) itemRepeatText
{
  NSString *text;

  if ([item isEqualToString: @"-"])
    text = item;
  else
    text = [self labelForKey: [NSString stringWithFormat: @"repeat_%@", item]];

  return text;
}

- (NSArray *) statusList
{
  static NSArray *statusItems = nil;

  if (!statusItems)
    {
      statusItems = [NSArray arrayWithObjects: @"NEEDS-ACTION",
                             @"IN-PROCESS",
                             @"COMPLETED",
                             @"CANCELLED",
                             nil];
      [statusItems retain];
    }

  return statusItems;
}

- (NSString *) itemStatusText
{
  return [self labelForKey: [NSString stringWithFormat: @"status_%@", item]];
}

- (void) setItem: (NSString *) newItem
{
  item = newItem;
}

- (NSString *) item
{
  return item;
}

- (NSString *) repeat
{
  return @"";
}

- (void) setRepeat: (NSString *) newRepeat
{
}

- (NSString *) status
{
  return status;
}

- (void) setStatus: (NSString *) newStatus
{
  status = newStatus;
}

- (void) setStatusDate: (NSCalendarDate *) newStatusDate
{
  ASSIGN (statusDate, newStatusDate);
}

- (NSCalendarDate *) statusDate
{
  return statusDate;
}

- (BOOL) statusDateDisabled
{
  return ![status isEqualToString: @"COMPLETED"];
}

- (BOOL) statusPercentDisabled
{
  return ([status length] == 0
	  || [status isEqualToString: @"CANCELLED"]);
}

- (void) setStatusPercent: (NSString *) newStatusPercent
{
  ASSIGN (statusPercent, newStatusPercent);
}

- (NSString *) statusPercent
{
  return statusPercent;
}

/* actions */
- (NSCalendarDate *) newStartDate
{
  NSCalendarDate *newStartDate, *now;
  int hour;
  NSTimeZone *timeZone;

  timeZone = [[context activeUser] timeZone];

  newStartDate = [self selectedDate];
  if ([[self queryParameterForKey: @"hm"] length] == 0)
    {
      now = [NSCalendarDate calendarDate];
      [now setTimeZone: timeZone];
      if ([now isDateOnSameDay: newStartDate])
        {
          hour = [now hourOfDay];
          if (hour < 8)
            newStartDate = [now hour: 8 minute: 0];
          else if (hour > 18)
            newStartDate = [[now tomorrow] hour: 8 minute: 0];
          else
            newStartDate = now;
        }
      else
        newStartDate = [newStartDate hour: 8 minute: 0];
    }

  return newStartDate;
}

- (id <WOActionResults>) defaultAction
{
  NSCalendarDate *startDate, *dueDate;
  NSString *duration;
  unsigned int minutes;

  todo = (iCalToDo *) [[self clientObject] component: NO];
  if (todo)
    {
      startDate = [todo startDate];
      dueDate = [todo due];
      hasStartDate = (startDate != nil);
      hasDueDate = (dueDate != nil);
      ASSIGN (status, [todo status]);
      if ([status isEqualToString: @"COMPLETED"])
	ASSIGN (statusDate, [todo completed]);
      else
	ASSIGN (statusDate, [self newStartDate]);
      ASSIGN (statusPercent, [todo percentComplete]);
    }
  else
    {
      startDate = [self newStartDate];
      duration = [self queryParameterForKey:@"dur"];
      if ([duration length] > 0)
	minutes = [duration intValue];
      else
	minutes = 60;
      dueDate = [startDate dateByAddingYears: 0 months: 0 days: 0
			   hours: 0 minutes: minutes seconds: 0];
      hasStartDate = NO;
      hasDueDate = NO;
      ASSIGN (statusDate, [self newStartDate]);
      ASSIGN (status, @"");
      ASSIGN (statusPercent, @"");
    }

  ASSIGN (taskStartDate, startDate);
  ASSIGN (taskDueDate, dueDate);

  /* here comes the code for initializing repeat, reminder and isAllDay... */

  return self;
}

- (id <WOActionResults>) newAction
{
  NSString *objectId, *method, *uri;
  id <WOActionResults> result;
  SOGoAppointmentFolder *co;

  co = [self clientObject];
  objectId = [co globallyUniqueObjectId];
  if ([objectId length] > 0)
    {
      method = [NSString stringWithFormat:@"%@/%@/editAsTask",
                         [co soURL], objectId];
      uri = [self completeHrefForMethod: method];
      result = [self redirectToLocation: uri];
    }
  else
    result = [NSException exceptionWithHTTPStatus: 500 /* Internal Error */
                          reason: @"could not create a unique ID"];

  return result;
}

- (id <WOActionResults>) saveAction
{
  SOGoTaskObject *clientObject;
  NSString *iCalString;

  clientObject = [self clientObject];
  iCalString = [[clientObject calendar: NO] versitString];
  [clientObject saveContentString: iCalString];

  return [self jsCloseWithRefreshMethod: @"refreshTasks()"];
}

- (BOOL) shouldTakeValuesFromRequest: (WORequest *) request
                           inContext: (WOContext*) context
{
  NSString *actionName;

  actionName = [[request requestHandlerPath] lastPathComponent];

  return ([[self clientObject] isKindOfClass: [SOGoTaskObject class]]
	  && [actionName hasPrefix: @"save"]);
}

- (void) takeValuesFromRequest: (WORequest *) _rq
                     inContext: (WOContext *) _ctx
{
  SOGoTaskObject *clientObject;

  clientObject = [self clientObject];
  todo = (iCalToDo *) [clientObject component: YES];

  [super takeValuesFromRequest: _rq inContext: _ctx];

  if (hasStartDate)
    [todo setStartDate: taskStartDate];
  else
    [todo setStartDate: nil];

  if (hasDueDate)
    [todo setDue: taskDueDate];
  else
    [todo setDue: nil];

  if ([status isEqualToString: @"COMPLETED"])
    [todo setCompleted: statusDate];
  else
    [todo setCompleted: nil];
  if ([status length] > 0)
    {
      [todo setStatus: status];
      [todo setPercentComplete: statusPercent];
    }
  else
    {
      [todo setStatus: @""];
      [todo setPercentComplete: @""];
    }
}

// TODO: add tentatively

- (id) acceptOrDeclineAction: (BOOL) _accept
{
  [[self clientObject] changeParticipationStatus:
                         _accept ? @"ACCEPTED" : @"DECLINED"];

  return self;
}

- (id) acceptAction
{
  return [self acceptOrDeclineAction: YES];
}

- (id) declineAction
{
  return [self acceptOrDeclineAction: NO];
}

- (id) changeStatusAction
{
  SOGoTaskObject *clientObject;
  NSString *newStatus, *iCalString;

  clientObject = [self clientObject];
  todo = (iCalToDo *) [clientObject component: NO];
  if (todo)
    {
      newStatus = [self queryParameterForKey: @"status"];
      if ([newStatus intValue])
	[todo setCompleted: [NSCalendarDate date]];
      else
	{
	  [todo setCompleted: nil];
	  [todo setPercentComplete: @"0"];
	  [todo setStatus: @"IN-PROCESS"];
	}

      iCalString = [[clientObject calendar: NO] versitString];
      [clientObject saveContentString: iCalString];
    }

  return self;
}

@end
