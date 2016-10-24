/* UIxTaskEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2016 Inverse inc.
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

#import <Foundation/NSValue.h>

#import <NGObjWeb/SoPermissions.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSCalendarDate+misc.h>

#import <NGCards/iCalAlarm.h>
#import <NGCards/iCalToDo.h>
#import <NGCards/iCalTrigger.h>
#import <NGCards/iCalDateTime.h>

#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoDateFormatter.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import <Appointments/iCalEntityObject+SOGo.h>
#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoTaskObject.h>
#import <Appointments/SOGoTaskOccurence.h>

#import "UIxComponentEditor.h"
#import "UIxTaskEditor.h"

@implementation UIxTaskEditor

- (id) init
{
  SOGoUser *user;

  if ((self = [super init]))
    {
      // item = nil;

      user = [[self context] activeUser];
      ASSIGN (dateFormatter, [user dateFormatterInContext: context]);
    }

  return self;
}

- (void) dealloc
{
  [dateFormatter release];
  [super dealloc];
}

/* template values */
- (iCalToDo *) todo
{
  return (iCalToDo *) component;
}

- (NSString *) saveURL
{
  return [NSString stringWithFormat: @"%@/saveAsTask",
                   [[self clientObject] baseURL]];
}

/* icalendar values */

// - (NSArray *) statusList
// {
//   static NSArray *statusItems = nil;

//   if (!statusItems)
//     {
//       statusItems = [NSArray arrayWithObjects: @"NEEDS-ACTION",
//                              @"IN-PROCESS",
//                              @"COMPLETED",
//                              @"CANCELLED",
//                              nil];
//       [statusItems retain];
//     }

//   return statusItems;
// }

// - (NSString *) itemStatusText
// {
//   if (!item)
//     {
//       item = status;
//       if (!item)
// 	item = @"NOT-SPECIFIED";
//     }
//   return [self labelForKey: [NSString stringWithFormat: @"status_%@", item]];
// }

// - (BOOL) statusDateDisabled
// {
//   return !([status isEqualToString: @"COMPLETED"] || statusDate);
// }

// - (BOOL) statusPercentDisabled
// {
//   return ([status length] == 0 || [status isEqualToString: @"CANCELLED"]);
// }

/* viewing read-only tasks */

// - (NSString *) taskStartDateTimeText
// {
//   return [dateFormatter formattedDateAndTime: taskStartDate];
// }

// - (NSString *) taskDueDateTimeText
// {
//   return [dateFormatter formattedDateAndTime: taskDueDate];
// }

// - (NSString *) statusDateText
// {
//   return [dateFormatter formattedDate: statusDate];
// }

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

// - (id <WOActionResults>) defaultAction
// {
//   NSCalendarDate *startDate, *dueDate;
//   NSString *duration;
//   NSTimeZone *timeZone;
//   SOGoUserDefaults *ud;
//   iCalToDo *todo;
//   unsigned int minutes;

//   ud = [[context activeUser] userDefaults];
//   timeZone = [ud timeZone];
//   todo = [self todo];
//   if (todo)
//     {
//       startDate = [todo startDate];
//       dueDate = [todo due];
//       if (startDate)
//         hasStartDate = YES;
//       else
//         startDate = [self newStartDate];
//       if (dueDate)
//         hasDueDate = YES;
//       else
//         dueDate = [self newStartDate];
      
//       ASSIGN (statusDate, [todo completed]);
//       [statusDate setTimeZone: timeZone];

//       ASSIGN (status, [todo status]);
      
//       if ([status length] == 0 && statusDate)
//         {
//           ASSIGN(status, @"COMPLETED");
//         }
//       else
//         {
//           ASSIGN (statusDate, [self newStartDate]);
//         }
//       ASSIGN (statusPercent, [todo percentComplete]);
//     }
//   else
//     {
//       startDate = [self newStartDate];
//       duration = [self queryParameterForKey:@"dur"];
//       if ([duration length] > 0)
//         minutes = [duration intValue];
//       else
//         minutes = 60;
//       dueDate = [startDate dateByAddingYears: 0 months: 0 days: 0
//         		   hours: 0 minutes: minutes seconds: 0];
//       hasStartDate = NO;
//       hasDueDate = NO;
//       ASSIGN (statusDate, [self newStartDate]);
//       ASSIGN (status, @"");
//       ASSIGN (statusPercent, @"");
//     }

//   /* here comes the code for initializing repeat, reminder and isAllDay... */

//   return self;
// }

/**
 * @api {post} /so/:username/Calendar/:calendarId/:todoId/save Save todo
 * @apiVersion 1.0.0
 * @apiName PostToDoSave
 * @apiGroup Calendar
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/personal/2142-54198E00-F-821E450.ics/save \
 *          -H 'Content-Type: application/json' \
 *          -d '{ "Summary": "Todo", "startDate": "2015-01-28", "startTime": "10:00", \
 *                "dueDate": "2015-01-28", "status": "in-process", "percentComplete": 25 }'
 *
 * @apiParam {_} . _Save in [iCalToDo+SOGo setAttributes:inContext:]_
 *
 * @apiParam {String} [startDate]             Start date (YYYY-MM-DD)
 * @apiParam {String} [startTime]             Start time (HH:MM)
 * @apiParam {String} [dueDate]               End date (YYYY-MM-DD)
 * @apiParam {String} [dueTime]               End time (HH:MM)
 * @apiParam {String} [completedDate]         End date (YYYY-MM-DD)
 * @apiParam {String} [completedTime]         End time (HH:MM)
 * @apiParam {Number} percentComplete         Percent completion (0-100)
 *
 * @apiParam {_} .. _Save in [iCalEntityObject+SOGo setAttributes:inContext:]_
 *
 * @apiParam {Number} [sendAppointmentNotifications] 0 if notifications must not be sent
 * @apiParam {String} [summary]               Summary
 * @apiParam {String} [location]              Location
 * @apiParam {String} [comment]               Comment
 * @apiParam {String} [status]                Status (needs-action, in-process, completed, or cancelled)
 * @apiParam {String} [attachUrl]             Attached URL
 * @apiParam {Number} [priority]              Priority
 * @apiParam {NSString} [classification]      Either public, confidential or private
 * @apiParam {String[]} [categories]          Categories
 * @apiParam {Object[]} [attendees]           List of attendees
 * @apiParam {String} [attendees.name]        Attendee's name
 * @apiParam {String} attendees.email         Attendee's email address
 * @apiParam {String} [attendees.uid]         System user ID
 * @apiParam {String} attendees.status        Attendee's participation status
 * @apiParam {String} [attendees.role]        Either CHAIR, REQ-PARTICIPANT, OPT-PARTICIPANT, or NON-PARTICIPANT
 * @apiParam {String} [attendees.delegatedTo] User that the original request was delegated to
 * @apiParam {String} [attendees.delegatedFrom] User the request was delegated from
 * @apiParam {Object[]} [alarm]               Alarm definition
 * @apiParam {String} alarm.action            Either display or email
 * @apiParam {Number} alarm.quantity          Quantity of units
 * @apiParam {String} alarm.unit              Either MINUTES, HOURS, or DAYS
 * @apiParam {String} alarm.reference         Either BEFORE or AFTER
 * @apiParam {String} alarm.relation          Either START or END
 * @apiParam {Boolean} [alarm.attendees]      Alert attendees by email if true and action is email
 * @apiParam {Object} [alarm.organizer]       Alert organizer at this email address if action is email
 * @apiParam {String} [alarm.organizer.name]  Attendee's name
 * @apiParam {String} alarm.organizer.email   Attendee's email address
 *
 * @apiParam {_} ... _Save in [iCalRepeatbleEntityObject+SOGo setAttributes:inContext:]_
 *
 * @apiParam {Object} [repeat]                Recurrence rule definition
 * @apiParam {String} repeat.frequency        Either daily, every weekday, weekly, bi-weekly, monthly, or yearly
 * @apiParam {Number} repeat.interval         Intervals the recurrence rule repeats
 * @apiParam {String} [repeat.count]          Number of occurrences at which to range-bound the recurrence
 * @apiParam {String} [repeat.until]          A date (YYYY-MM-DD) that bounds the recurrence rule in an inclusive manner
 * @apiParam {Object[]} [repeat.days]         List of days of the week (by day mask)
 * @apiParam {String} [repeat.days.day]       Day of the week (SU, MO, TU, WE, TH, FR, SA)
 * @apiParam {Number} [repeat.days.occurence] Occurrence of a specific day within the monthly or yearly rule (values are -5 to 5)
 * @apiParam {Number[]} [repeat.months]       List of months of the year (values are 1 to 12)
 * @apiParam {Number[]} [repeat.monthdays]    Days of the month (values are 1 to 31)
 *
 * @apiParam {_} .... _Save in [UIxComponentEditor setAttributes:]_
 *
 * @apiParam {Object} [organizer]             Appointment organizer
 * @apiParam {String} organizer.name          Organizer's name
 * @apiParam {String} organizer.email         Organizer's email address
 *
 * @apiError (Error 500) {Object} error The error message
 */
- (id <WOActionResults>) saveAction
{
  NSDictionary *params;
  NSException *ex;
  NSString *jsonResponse;
  SOGoAppointmentFolder *previousCalendar;
  SOGoTaskObject *co;
  SoSecurityManager *sm;
  WORequest *request;
  iCalToDo *todo;
  unsigned int httpStatus;

  todo = [self todo];
  co = [self clientObject];
  if ([co isKindOfClass: [SOGoTaskOccurence class]])
    co = [co container];
  previousCalendar = [co container];
  sm = [SoSecurityManager sharedSecurityManager];

  ex = nil;
  request = [context request];
  params = [[request contentAsString] objectFromJSONString];
  if (params == nil)
    {
      ex = [NSException exceptionWithName: @"JSONParsingException"
                                   reason: @"Can't parse JSON string"
                                 userInfo: nil];
    }
  else
    {
      [self setAttributes: params];

      if ([co isNew])
        {
          if (componentCalendar
              && ![[componentCalendar ocsPath]
                    isEqualToString: [previousCalendar ocsPath]])
            {
              // New task in a different calendar -- make sure the user can
              // write to the selected calendar since the rights were verified
              // on the calendar specified in the URL, not on the selected
              // calendar of the popup menu.
              if (![sm validatePermission: SoPerm_AddDocumentsImagesAndFiles
                                 onObject: componentCalendar
                                inContext: context])
                co = [componentCalendar lookupName: [co nameInContainer]
                                         inContext: context
                                           acquire: NO];
            }

          // Save the task.
          ex = [co saveComponent: todo];
        }
      else
        {
          // The task was modified -- save it.
          ex = [co saveComponent: todo];

          if (componentCalendar
              && ![[componentCalendar ocsPath]
                    isEqualToString: [previousCalendar ocsPath]])
            {
              // The task was moved to a different calendar.
              if (![sm validatePermission: SoPerm_DeleteObjects
                                 onObject: previousCalendar
                                inContext: context])
                {
                  if (![sm validatePermission: SoPerm_AddDocumentsImagesAndFiles
                                     onObject: componentCalendar
                                    inContext: context])
                    ex = [co moveToFolder: componentCalendar];
                }
            }
        }
    }

  if (ex)
    {
      httpStatus = 500;
      jsonResponse = [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"failure", @"status",
                                   [ex reason], @"message",
                                   nil];
    }
  else
    {
      httpStatus = 200;
      jsonResponse = [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"success", @"status", nil];
    }

  return [self responseWithStatus: httpStatus
            andJSONRepresentation: jsonResponse];
}

/**
 * @api {get} /so/:username/Calendar/:calendarId/:todoId/view Get todo
 * @apiVersion 1.0.0
 * @apiName GetToDoView
 * @apiGroup Calendar
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/personal/2142-54198E00-F-821E450.ics/view
 *
 * @apiParam {Number} [resetAlarm] Mark alarm as triggered if set to 1
 * @apiParam {Number} [snoozeAlarm] Snooze the alarm for this number of minutes
 *
 * @apiSuccess {_} . _From [UIxTaskEditor viewAction]_
 *
 * @apiSuccess (Success 200) {String} id                      Todo ID
 * @apiSuccess (Success 200) {String} pid                     Calendar ID (todo's folder)
 * @apiSuccess (Success 200) {String} calendar                Human readable name of calendar
 * @apiSuccess (Success 200) {String} localizedStartDate      Formatted start date
 * @apiSuccess (Success 200) {String} localizedStartTime      Formatted start time
 * @apiSuccess (Success 200) {String} localizedDueDate        Formatted due date
 * @apiSuccess (Success 200) {String} localizedDueTime        Formatted due time
 * @apiSuccess (Success 200) {String} localizedCompletedDate  Formatted completed date
 * @apiSuccess (Success 200) {String} localizedCompletedTime  Formatted completed time
 * @apiSuccess (Success 200) {Number} isReadOnly              1 if task is read-only
 * @apiSuccess (Success 200) {Object[]} [attachUrls]          Attached URLs
 * @apiSuccess (Success 200) {String} attachUrls.value        URL
 *
 * @apiSuccess {_} .. _From [iCalToDo+SOGo attributesInContext:]_
 *
 * @apiSuccess (Success 200) {String} startDate               Start date (ISO8601)
 * @apiSuccess (Success 200) {String} dueDate                 Due date (ISO8601)
 * @apiSuccess (Success 200) {String} completedDate           Completed date (ISO8601)
 * @apiSuccess (Success 200) {Number} percentComplete         Percent completion
 *
 * @apiSuccess {_} ... _From [UIxComponentEdtiror alarm]_
 *
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
 * @apiSuccess {_} .... _From [iCalEntityObject+SOGo attributesInContext:]_
 *
 * @apiSuccess (Success 200) {String} component               "vtodo"
 * @apiSuccess (Success 200) {String} summary                 Summary
 * @apiSuccess (Success 200) {String} location                Location
 * @apiSuccess (Success 200) {String} comment                 Comment
 * @apiSuccess (Success 200) {String} createdBy               Value of custom header X-SOGo-Component-Created-By or organizer's "SENT-BY"
 * @apiSuccess (Success 200) {Number} priority                Priority (0-9)
 * @apiSuccess (Success 200) {NSString} [classification]      Either public, confidential or private
 * @apiSuccess (Success 200) {String[]} [categories]          Categories
 * @apiSuccess (Success 200) {String} status                  Status (needs-action, in-process, completed, or cancelled)
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
 *
 * @apiSuccess {_} ..... _From [iCalRepeatableEntityObject+SOGo attributesInContext:]_
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
  NSArray *attachUrls;
  NSMutableDictionary *data;
  NSCalendarDate *startDate, *dueDate, *completedDate;
  NSTimeZone *timeZone;
  SOGoCalendarComponent *co;
  SOGoUserDefaults *ud;
  iCalAlarm *anAlarm;
  iCalToDo *todo;
  BOOL resetAlarm, snoozeAlarm;
  BOOL isAllDayStartDate, isAllDayDueDate;

  todo = [self todo];

  co = [self clientObject];

  ud = [[context activeUser] userDefaults];
  timeZone = [ud timeZone];

  startDate = [todo startDate];
  isAllDayStartDate = [(iCalDateTime *) [todo uniqueChildWithTag: @"dtstart"] isAllDay];
  if (!isAllDayStartDate)
    [startDate setTimeZone: timeZone];

  dueDate = [todo due];
  isAllDayDueDate = [(iCalDateTime *) [todo uniqueChildWithTag: @"due"] isAllDay];
  if (!isAllDayDueDate)
    [dueDate setTimeZone: timeZone];

  completedDate = [todo completed];
  [completedDate setTimeZone: timeZone];

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
      [componentCalendar findEntityForClosestAlarm: &todo
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
  
  data = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                       [componentCalendar nameInContainer], @"pid",
                       [componentCalendar displayName], @"calendar",
                       [NSNumber numberWithBool: [self isReadOnly]], @"isReadOnly",
                       [self alarm], @"alarm",
		       nil];

  if ([self isChildOccurrence])
    {
      [data setObject: [[co container] nameInContainer] forKey: @"id"];
      [data setObject: [co nameInContainer] forKey: @"occurrenceId"];
    }
  else
    {
      [data setObject: [co nameInContainer] forKey: @"id"];
    }

  if (startDate)
    {
      [data setObject: [dateFormatter formattedDate: startDate] forKey: @"localizedStartDate"];
      if (!isAllDayStartDate)
        [data setObject: [dateFormatter formattedTime: startDate] forKey: @"localizedStartTime"];
    }
  if (dueDate)
    {
      [data setObject: [dateFormatter formattedDate: dueDate] forKey: @"localizedDueDate"];
      if (!isAllDayDueDate)
        [data setObject: [dateFormatter formattedTime: dueDate] forKey: @"localizedDueTime"];
    }

  if (completedDate)
    {
      [data setObject: [dateFormatter formattedDate: completedDate] forKey: @"localizedCompletedDate"];
      [data setObject: [dateFormatter formattedTime: completedDate] forKey: @"localizedCompletedTime"];
    }

  attachUrls = [self attachUrls];
  if ([attachUrls count]) [data setObject: attachUrls forKey: @"attachUrls"];

  // Add attributes from iCalToDo+SOGo, iCalEntityObject+SOGo and iCalRepeatableEntityObject+SOGo
  [data addEntriesFromDictionary: [todo attributesInContext: context]];

  // Return JSON representation
  return [self responseWithStatus: 200 andJSONRepresentation: data];
}

- (id) changeStatusAction
{
  NSString *newStatus;
  iCalToDo *todo;

  todo = [self todo];
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
