/* UIxTaskEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2009 Inverse inc.
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

#import <Foundation/NSDictionary.h>

#import <NGObjWeb/SoObject.h>
#import <NGObjWeb/SoPermissions.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSCalendarDate+misc.h>

#import <NGCards/iCalAlarm.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalToDo.h>
#import <NGCards/iCalTrigger.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/iCalDateTime.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/SOGoContentObject.h>
#import <SOGo/SOGoDateFormatter.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoTaskObject.h>

#import "UIxComponentEditor.h"
#import "UIxTaskEditor.h"

@implementation UIxTaskEditor

- (id) init
{
  SOGoUser *user;

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

      user = [[self context] activeUser];
      ASSIGN (dateFormatter, [user dateFormatterInContext: context]);
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
  [dateFormatter release];
  [[todo parent] release];
  [super dealloc];
}

/* template values */
- (iCalToDo *) todo
{
  if (!todo)
    {
      todo = (iCalToDo *) [[self clientObject] component: YES secure: YES];
      [[todo parent] retain];
    }

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
  if (!item)
    {
      item = status;
      if (!item)
	item = @"NOT-SPECIFIED";
    }
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

/* viewing read-only tasks */

- (NSString *) taskStartDateTimeText
{
  return [dateFormatter formattedDateAndTime: taskStartDate];
}

- (NSString *) taskDueDateTimeText
{
  return [dateFormatter formattedDateAndTime: taskDueDate];
}

- (NSString *) statusDateText
{
  return [dateFormatter formattedDate: statusDate];
}

/* actions */
- (NSCalendarDate *) newStartDate
{
  NSCalendarDate *newStartDate, *now;
  NSTimeZone *timeZone;
  SOGoUserDefaults *ud;
  int hour, minute;
  unsigned int uStart, uEnd;

  newStartDate = [self selectedDate];
  if (![[self queryParameterForKey: @"hm"] length])
    {
      ud = [[context activeUser] userDefaults];
      timeZone = [ud timeZone];
      now = [NSCalendarDate calendarDate];
      [now setTimeZone: timeZone];

      uStart = [ud dayStartHour];
      if ([now isDateOnSameDay: newStartDate])
        {
	  uEnd = [ud dayEndHour];
          hour = [now hourOfDay];
          minute = [now minuteOfHour];
          if (minute % 15)
            minute += 15 - (minute % 15);
          if (hour < uStart)
            newStartDate = [now hour: uStart minute: 0];
          else if (hour > uEnd)
            newStartDate = [[now tomorrow] hour: uStart minute: 0];
          else
            newStartDate = [now hour: [now hourOfDay] minute: minute];
        }
      else
        newStartDate = [newStartDate hour: uStart minute: 0];
    }

  return newStartDate;
}

- (id <WOActionResults>) defaultAction
{
  NSCalendarDate *startDate, *dueDate;
  NSString *duration;
  NSTimeZone *timeZone;
  SOGoUserDefaults *ud;
  unsigned int minutes;

  ud = [[context activeUser] userDefaults];
  timeZone = [ud timeZone];
  [self todo];
  if (todo)
    {
      startDate = [todo startDate];
      dueDate = [todo due];
      if (startDate)
        hasStartDate = YES;
      else
        startDate = [self newStartDate];
      if (dueDate)
        hasDueDate = YES;
      else
        dueDate = [self newStartDate];
      ASSIGN (status, [todo status]);
      if ([status isEqualToString: @"COMPLETED"])
	{
	  ASSIGN (statusDate, [todo completed]);
	  [statusDate setTimeZone: timeZone];
	}
      else
	{
	  ASSIGN (statusDate, [self newStartDate]);
	}
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

  [startDate setTimeZone: timeZone];
  ASSIGN (taskStartDate, startDate);
  
  [dueDate setTimeZone: timeZone];
  ASSIGN (taskDueDate, dueDate);

  /* here comes the code for initializing repeat, reminder and isAllDay... */

  return self;
}

- (id <WOActionResults>) newAction
{
  NSString *objectId, *method, *uri;
  id <WOActionResults> result;
  SOGoAppointmentFolder *co;
  SoSecurityManager *sm;

  co = [self clientObject];
  objectId = [co globallyUniqueObjectId];
  if ([objectId length] > 0)
    {
      sm = [SoSecurityManager sharedSecurityManager];
      if (![sm validatePermission: SoPerm_AddDocumentsImagesAndFiles
	      onObject: co
	      inContext: context])
	{
	  method = [NSString stringWithFormat:@"%@/%@.ics/editAsTask",
			     [co soURL], objectId];
	}
      else
	{
	  method = [NSString stringWithFormat: @"%@/Calendar/personal/%@.vcf/editAsTask",
			     [self userFolderPath], objectId];
	}
      uri = [self completeHrefForMethod: method];
      result = [self redirectToLocation: uri];
    }
  else
    result = [NSException exceptionWithHTTPStatus: 500 /* Internal Error */
                          reason: @"could not create a unique ID"];

  return result;
}

#warning this method could be replaced with a method common with UIxAppointmentEditor...
- (id <WOActionResults>) saveAction
{
  NSString *newCalendar;
  SOGoAppointmentFolder *thisFolder, *newFolder;
  SOGoTaskObject *co;
  SoSecurityManager *sm;

  co = [self clientObject];
  [co saveComponent: todo];

  newCalendar = [self queryParameterForKey: @"moveToCalendar"];
  if ([newCalendar length])
    {
      sm = [SoSecurityManager sharedSecurityManager];

      thisFolder = [co container];
      if (![sm validatePermission: SoPerm_DeleteObjects
	       onObject: thisFolder
	       inContext: context])
	{
	  newFolder = [[thisFolder container] lookupName: newCalendar
                                               inContext: context
                                                 acquire: NO];
	  if (![sm validatePermission: SoPerm_AddDocumentsImagesAndFiles
		   onObject: newFolder
		   inContext: context])
            [co moveToFolder: newFolder];
	}
    }

  return [self jsCloseWithRefreshMethod: @"refreshTasks()"];
}

// - (id <WOActionResults>) saveAction
// {
//   SOGoTaskObject *clientObject;
//   NSString *iCalString;

//   clientObject = [self clientObject];
//   iCalString = [[clientObject calendar: NO secure: NO] versitString];
//   [clientObject saveContentString: iCalString];

//   return [self jsCloseWithRefreshMethod: @"refreshTasks()"];
// }

- (id <WOActionResults>) viewAction
{
  WOResponse *result;
  NSDictionary *data;
  NSCalendarDate *startDate, *dueDate;
  NSTimeZone *timeZone;
  SOGoUserDefaults *ud;
  BOOL resetAlarm;

  [self todo];

  result = [self responseWithStatus: 200];
  ud = [[context activeUser] userDefaults];
  timeZone = [ud timeZone];
  startDate = [todo startDate];
  [startDate setTimeZone: timeZone];
  dueDate = [todo due];
  [dueDate setTimeZone: timeZone];
  
  resetAlarm = [[[context request] formValueForKey: @"resetAlarm"] boolValue];
  if (resetAlarm && [todo hasAlarms] && ![todo hasRecurrenceRules])
    {
      iCalAlarm *anAlarm;
      iCalTrigger *aTrigger;
      SOGoCalendarComponent *co;

      anAlarm = [[todo alarms] objectAtIndex: 0];
      aTrigger = [anAlarm trigger];
      [aTrigger setValue: 0 ofAttribute: @"x-webstatus" to: @"triggered"];
      
      co = [self clientObject];
      [co saveComponent: todo];
    }
  
  data = [NSDictionary dictionaryWithObjectsAndKeys:
		       [todo tag], @"component",
		       (startDate? (id)[dateFormatter formattedDate: startDate] : (id)@""), @"startDate",
		       (startDate? (id)[dateFormatter formattedTime: startDate] : (id)@""), @"startTime",
		       (dueDate? (id)[dateFormatter formattedDate: dueDate] : (id)@""), @"dueDate",
		       (dueDate? (id)[dateFormatter formattedTime: dueDate] : (id)@""), @"dueTime",
		       ([todo hasRecurrenceRules]? @"1": @"0"), @"isReccurent",
		       [todo summary], @"summary",
		       [todo location], @"location",
		       [todo comment], @"description",
		       nil];
  
  [result appendContentString: [data jsonRepresentation]];

  return result;
}

- (BOOL) shouldTakeValuesFromRequest: (WORequest *) request
                           inContext: (WOContext*) context
{
  NSString *actionName;

  actionName = [[request requestHandlerPath] lastPathComponent];

  return ([[self clientObject] conformsToProtocol: @protocol (SOGoComponentOccurence)]
	  && [actionName hasPrefix: @"save"]);
}

- (void) takeValuesFromRequest: (WORequest *) _rq
                     inContext: (WOContext *) _ctx
{
  SOGoUserDefaults *ud;
  iCalTimeZone *tz;

  [self todo];

  [super takeValuesFromRequest: _rq inContext: _ctx];

  if (hasStartDate)
    [todo setStartDate: taskStartDate];
  else
    {
      [todo setStartDate: nil];
      [todo removeAllAlarms];
    }

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

  if ([[self clientObject] isNew])
    {
      ud = [[context activeUser] userDefaults];
      tz = [iCalTimeZone timeZoneForName: [ud timeZoneName]];
      
      if (hasStartDate || hasDueDate)
	{
	  [[todo parent] addTimeZone: tz];
	}

      if (hasStartDate)
	[(iCalDateTime *)[todo uniqueChildWithTag: @"dtstart"] setTimeZone: tz];

      if (hasDueDate)
	[(iCalDateTime *)[todo uniqueChildWithTag: @"due"] setTimeZone: tz];
    }

}

// TODO: add tentatively

// - (id) acceptOrDeclineAction: (BOOL) _accept
// {
//   [[self clientObject] changeParticipationStatus:
//                          _accept ? @"ACCEPTED" : @"DECLINED"];

//   return self;
// }

// - (id) acceptAction
// {
//   return [self acceptOrDeclineAction: YES];
// }

// - (id) declineAction
// {
//   return [self acceptOrDeclineAction: NO];
// }

- (id) changeStatusAction
{
  NSString *newStatus;

  [self todo];
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
      [[self clientObject] saveComponent: todo];
    }

  return [self responseWith204];
}

@end
