/* UIxTaskEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2015 Inverse inc.
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

#import <Appointments/iCalEntityObject+SOGo.h>
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
      todo = (iCalToDo *) [[self clientObject] occurence];
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
  return !([status isEqualToString: @"COMPLETED"] || statusDate);
}

- (BOOL) statusPercentDisabled
{
  return ([status length] == 0 || [status isEqualToString: @"CANCELLED"]);
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
      
      ASSIGN (statusDate, [todo completed]);
      [statusDate setTimeZone: timeZone];

      ASSIGN (status, [todo status]);
      
      if ([status length] == 0 && statusDate)
	{
          ASSIGN(status, @"COMPLETED");
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

/**
 * @api {get} /so/:username/Calendar/:calendarId/:todoId/view Get task
 * @apiVersion 1.0.0
 * @apiName GetTaskView
 * @apiGroup Calendar
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/personal/1A5-53489200-2D-6BD99880.ics/view
 *
 * @apiParam {Number} [resetAlarm] Mark alarm as triggered if set to 1
 * @apiParam {Number} [snoozeAlarm] Snooze the alarm for this number of minutes
 *
 * @apiSuccess (Success 200) {String} id                      Todo ID
 * @apiSuccess (Success 200) {String} pid                     Calendar ID (todo's folder)
 * @apiSuccess (Success 200) {String} calendar                Human readable name of calendar
 * @apiSuccess (Success 200) {String} startDate               Formatted start date
 * @apiSuccess (Success 200) {String} startTime               Formatted start time
 * @apiSuccess (Success 200) {String} dueDate                 Formatted due date
 * @apiSuccess (Success 200) {String} dueTime                 Formatted due time
 * @apiSuccess (Success 200) {NSNumber} percentComplete       Percent completion
 *
 * From [iCalEntityObject+SOGo attributes]
 *
 * @apiSuccess (Success 200) {String} component               "vtodo"
 * @apiSuccess (Success 200) {String} summary                 Summary
 * @apiSuccess (Success 200) {String} location                Location
 * @apiSuccess (Success 200) {String} comment                 Comment
 * @apiSuccess (Success 200) {String} createdBy               Value of custom header X-SOGo-Component-Created-By or organizer's "SENT-BY"
 * @apiSuccess (Success 200) {Number} priority                Priority
 * @apiSuccess (Success 200) {String[]} [categories]          Categories
 * @apiSuccess (Success 200) {Object} [organizer]             Appointment organizer
 * @apiSuccess (Success 200) {String} organizer.name          Organizer's name
 * @apiSuccess (Success 200) {String} organizer.email         Organizer's email address
 * @apiSuccess (Success 200) {Object[]} [attendees]           List of attendees
 * @apiSuccess (Success 200) {String} [attendees.name]        Attendee's name
 * @apiSuccess (Success 200) {String} attendees.email         Attendee's email address
 * @apiSuccess (Success 200) {String} [attendees.uid]         System user ID
 * @apiSuccess (Success 200) {String} attendees.status        Attendee's participation status
 * @apiSuccess (Success 200) {String} [attendees.role]        Attendee's role
 * @apiSuccess (Success 200) {String} [attendees.delegatedTo] User that the original request was delegated to
 * @apiSuccess (Success 200) {String} [attendees.delegatedFrom] User the request was delegated from
 * @apiSuccess (Success 200) {Object[]} [alarm]               Alarm definition
 * @apiSuccess (Success 200) {String} alarm.action            Either display or email
 * @apiSuccess (Success 200) {String} alarm.quantity          Quantity of units
 * @apiSuccess (Success 200) {String} alarm.unit              Either MINUTES, HOURS, or DAYS
 * @apiSuccess (Success 200) {String} alarm.reference         Either BEFORE or AFTER
 * @apiSuccess (Success 200) {String} alarm.relation          Either START or END
 * @apiSuccess (Success 200) {Object[]} [alarm.attendees]     List of attendees
 * @apiSuccess (Success 200) {String} [alarm.attendees.name]  Attendee's name
 * @apiSuccess (Success 200) {String} alarm.attendees.email   Attendee's email address
 * @apiSuccess (Success 200) {String} [alarm.attendees.uid]   System user ID
 *
 * From [iCalRepeatableEntityObject+SOGo attributes]
 *
 * @apiSuccess (Success 200) {Object} [repeat]                Recurrence rule definition
 * @apiSuccess (Success 200) {String} repeat.frequency        Either daily, (every weekday), weekly, (bi-weekly), monthly, or yearly
 * @apiSuccess (Success 200) {Number} repeat.interval         Intervals the recurrence rule repeats
 * @apiSuccess (Success 200) {String} [repeat.count]          Number of occurrences at which to range-bound the recurrence
 * @apiSuccess (Success 200) {String} [repeat.until]          A Unix epoch value that bounds the recurrence rule in an inclusive manner
 * @apiSuccess (Success 200) {Number[]} [repeat.days]         List of days of the week
 * @apiSuccess (Success 200) {String} repeat.days.day         Day of the week (SU, MO, TU, WE, TH, FR, SA)
 * @apiSuccess (Success 200) {Number} [repeat.days.occurence] Occurrence of a specific day within the monthly or yearly rule (valures are -5 to 5)
 * @apiSuccess (Success 200) {Number[]} [repeat.months]       List of months of the year (values are 1 to 12)
 * @apiSuccess (Success 200) {Number[]} [repeat.monthdays]    Days of the month (values are 1 to 31)
 */
- (id <WOActionResults>) viewAction
{
  NSMutableDictionary *data;
  NSCalendarDate *startDate, *dueDate;
  NSTimeZone *timeZone;
  SOGoCalendarComponent *co;
  SOGoAppointmentFolder *thisFolder;
  SOGoUserDefaults *ud;
  iCalAlarm *anAlarm;
  BOOL resetAlarm;
  BOOL snoozeAlarm;

  [self todo];

  co = [self clientObject];
  thisFolder = [co container];

  ud = [[context activeUser] userDefaults];
  timeZone = [ud timeZone];
  startDate = [todo startDate];
  [startDate setTimeZone: timeZone];
  dueDate = [todo due];
  [dueDate setTimeZone: timeZone];

  // resetAlarm=yes is set only when we are about to show the alarm popup in the Web
  // interface of SOGo. See generic.js for details. snoozeAlarm=X is called when the
  // user clicks on "Snooze for" X minutes, when the popup is being displayed.
  // If either is set to yes, we must find the right alarm.
  resetAlarm = [[[context request] formValueForKey: @"resetAlarm"] boolValue];
  snoozeAlarm = [[[context request] formValueForKey: @"snoozeAlarm"] intValue];
  
  if (resetAlarm || snoozeAlarm)
    {
      iCalToDo *master;

      master = todo;
      [thisFolder findEntityForClosestAlarm: &todo
                                   timezone: timeZone
                                  startDate: &startDate
                                    endDate: &dueDate];

      anAlarm = [todo firstDisplayOrAudioAlarm];

      if (resetAlarm)
        {
          iCalTrigger *aTrigger;
          
          aTrigger = [anAlarm trigger];
          [aTrigger setValue: 0 ofAttribute: @"x-webstatus" to: @"triggered"];
          
          [co saveComponent: master];
        }
      else if (snoozeAlarm)
        {
          [co snoozeAlarm: snoozeAlarm];
        }
    }
  resetAlarm = [[[context request] formValueForKey: @"resetAlarm"] boolValue];
  
  data = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                         [co nameInContainer], @"id",
                       [thisFolder nameInContainer], @"pid",
                       [thisFolder displayName], @"calendar",
		       (startDate? (id)[dateFormatter formattedDate: startDate] : (id)@""), @"startDate",
		       (startDate? (id)[dateFormatter formattedTime: startDate] : (id)@""), @"startTime",
		       (dueDate? (id)[dateFormatter formattedDate: dueDate] : (id)@""), @"dueDate",
		       (dueDate? (id)[dateFormatter formattedTime: dueDate] : (id)@""), @"dueTime",
                       [NSNumber numberWithInt: [[todo percentComplete] intValue]], @"percentComplete",
		       nil];
  
  // Add attributes from iCalEntityObject+SOGo and iCalRepeatableEntityObject+SOGo
  [data addEntriesFromDictionary: [todo attributes]];

  // Return JSON representation
  return [self responseWithStatus: 200 andJSONRepresentation: data];
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
