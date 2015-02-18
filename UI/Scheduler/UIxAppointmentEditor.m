/* UIxAppointmentEditor.m - this file is part of SOGo
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

#include <math.h>

#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/SoObject.h>
#import <NGObjWeb/SoPermissions.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>

#import <NGCards/iCalAlarm.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalTrigger.h>
#import <NGCards/iCalRecurrenceRule.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/iCalDateTime.h>

#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoContentObject.h>
#import <SOGo/SOGoDateFormatter.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <Appointments/iCalCalendar+SOGo.h>
#import <Appointments/iCalEntityObject+SOGo.h>
#import <Appointments/iCalPerson+SOGo.h>
#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoAppointmentObject.h>
#import <Appointments/SOGoAppointmentOccurence.h>

#import <Appointments/SOGoComponentOccurence.h>

#import "UIxComponentEditor.h"
#import "UIxAppointmentEditor.h"

@implementation UIxAppointmentEditor

- (id) init
{
  SOGoUser *user;

  if ((self = [super init]))
    {
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

- (iCalEvent *) event
{
  return (iCalEvent *) component;
}

/*
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
*/

/*
- (id <WOActionResults>) defaultAction
{
  NSCalendarDate *startDate, *endDate;
  NSString *duration;
  NSTimeZone *timeZone;
  unsigned int total, hours, minutes;
  signed int offset;
  SOGoObject <SOGoComponentOccurence> *co;
  SOGoUserDefaults *ud;

  [self event];
  co = [self clientObject];

  ud = [[context activeUser] userDefaults];
  timeZone = [ud timeZone];

  if ([co isNew]
      && [co isKindOfClass: [SOGoCalendarComponent class]])
    {
      startDate = [self newStartDate];
      duration = [self queryParameterForKey:@"duration"];
      if ([duration length] > 0)
        {
          total = [duration intValue];
          hours = total / 100;
          minutes = total % 100;
        }
      else
        {
          hours = 1;
          minutes = 0;
        }
      endDate
        = [startDate dateByAddingYears: 0 months: 0 days: 0
                                 hours: hours minutes: minutes seconds: 0];
      sendAppointmentNotifications = YES;
    }
  else
    {
      startDate = [event startDate];
      isAllDay = [event isAllDay];
      endDate = [event endDate];
      if (isAllDay)
        {
          endDate = [endDate dateByAddingYears: 0 months: 0 days: -1];

          // Convert the dates to the user's timezone
          offset = [timeZone secondsFromGMTForDate: startDate];
          startDate = [startDate dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
                                           seconds:-offset];
          endDate = [endDate dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
                                       seconds:-offset];
        }
      isTransparent = ![event isOpaque];
      sendAppointmentNotifications = ([event firstChildWithTag: @"X-SOGo-Send-Appointment-Notifications"] ? NO : YES);
    }

  [startDate setTimeZone: timeZone];
  ASSIGN (aptStartDate, startDate);

  [endDate setTimeZone: timeZone];
  ASSIGN (aptEndDate, endDate);

  return self;
}
*/

- (void) _adjustRecurrentRules
{
  iCalEvent *event;
  iCalRecurrenceRule *rule;
  NSEnumerator *rules;
  NSCalendarDate *untilDate;
  SOGoUserDefaults *ud;
  NSTimeZone *timeZone;

  event = [self event];
  rules = [[event recurrenceRules] objectEnumerator];
  ud = [[context activeUser] userDefaults];
  timeZone = [ud timeZone];

  while ((rule = [rules nextObject]))
    {
      untilDate = [rule untilDate];
      if (untilDate)
        {
          // The until date must match the time of the end date
          NSCalendarDate *date;

          date = [[event endDate] copy];
          [date setTimeZone: timeZone];
          [untilDate setTimeZone: timeZone];
          untilDate = [untilDate dateByAddingYears:0
                                 months:0
                                 days:0
                                 hours:[date hourOfDay]
                                 minutes:[date minuteOfHour]
                                 seconds:0];
          [rule setUntilDate: untilDate];
          [date release];
        }
    }
}

/**
 * @api {post} /so/:username/Calendar/:calendarId/:appointmentId/save Save event
 * @apiVersion 1.0.0
 * @apiName PostEventSave
 * @apiGroup Calendar
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/personal/71B6-54904400-1-7C308500.ics/save \
 *          -H 'Content-Type: application/json' \
 *          -d '{ "summary": "Meeting", "startDate": "2015-01-28", "startTime": "10:00", \
 *                "endDate": "2015-01-28", "endTime": "12:00" }'
 *
 * Save in [iCalEvent+SOGo setAttributes:inContext:]
 *
 * @apiParam {String} startDate               Start date (YYYY-MM-DD)
 * @apiParam {String} startTime               Start time (HH:MM)
 * @apiParam {String} endDate                 End date (YYYY-MM-DD)
 * @apiParam {String} endTime                 End time (HH:MM)
 * @apiParam {Number} [isAllDay]              1 if event is all-day
 * @apiParam {Number} isTransparent           1 if the event is not opaque
 *
 * Save in [iCalEntityObject+SOGo setAttributes:inContext:]
 *
 * @apiParam {Number} [sendAppointmentNotifications] 0 if notifications must not be sent
 * @apiParam {String} [summary]               Summary
 * @apiParam {String} [location]              Location
 * @apiParam {String} [comment]               Comment
 * @apiParam {String} [status]                Status
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
 * Save in [iCalRepeatbleEntityObject+SOGo setAttributes:inContext:]
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
 * Save in [UIxComponentEditor setAttributes:]
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
  NSString *jsonResponse;
  NSException *ex;
  iCalEvent *event;
  SOGoAppointmentFolder *previousCalendar;
  SOGoAppointmentObject *co;
  SoSecurityManager *sm;
  WORequest *request;

  event = [self event];
  co = [self clientObject];
  if ([co isKindOfClass: [SOGoAppointmentOccurence class]])
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

      if ([event hasRecurrenceRules])
        [self _adjustRecurrentRules];

      if ([co isNew])
        {
          if (componentCalendar
              && ![[componentCalendar ocsPath]
                    isEqualToString: [previousCalendar ocsPath]])
            {
              // New event in a different calendar -- make sure the user can
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

          // Save the event.
          ex = [co saveComponent: event];
        }
      else
        {
          // The event was modified -- save it.
          ex = [co saveComponent: event];

          if (componentCalendar
              && ![[componentCalendar ocsPath]
                    isEqualToString: [previousCalendar ocsPath]])
            {
              // The event was moved to a different calendar.
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
    jsonResponse = [NSDictionary dictionaryWithObjectsAndKeys:
                                   @"failure", @"status",
                                 [ex reason],
                                 @"message",
                                 nil];
  else
    jsonResponse = [NSDictionary dictionaryWithObjectsAndKeys:
                                   @"success", @"status", nil];

  return [self responseWithStatus: 200
            andJSONRepresentation: jsonResponse];
}

/**
 * @api {get} /so/:username/Calendar/:calendarId/:eventId/view Get event
 * @apiVersion 1.0.0
 * @apiName GetEventView
 * @apiGroup Calendar
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/personal/71B6-54904400-1-7C308500.ics/view
 *
 * @apiParam {Number} [resetAlarm] Mark alarm as triggered if set to 1
 * @apiParam {Number} [snoozeAlarm] Snooze the alarm for this number of minutes
 *
 * @apiSuccess (Success 200) {String} id                      Event ID
 * @apiSuccess (Success 200) {String} pid                     Calendar ID (event's folder)
 * @apiSuccess (Success 200) {String} calendar                Human readable name of calendar
 * @apiSuccess (Success 200) {String} startDate               Start date (ISO8601)
 * @apiSuccess (Success 200) {String} localizedStartDate      Formatted start date
 * @apiSuccess (Success 200) {String} [localizedStartTime]    Formatted start time
 * @apiSuccess (Success 200) {String} endDate                 End date (ISO8601)
 * @apiSuccess (Success 200) {String} localizedEndDate        Formatted end date
 * @apiSuccess (Success 200) {String} [localizedEndTime]      Formatted end time
 *
 * From [iCalEvent+SOGo attributes]
 *
 * @apiSuccess (Success 200) {Number} isAllDay                1 if event is all-day
 * @apiSuccess (Success 200) {Number} isTransparent           1 if the event is not opaque
 *
 * From [iCalEntityObject+SOGo attributes]
 *
 * @apiSuccess (Success 200) {Number} sendAppointmentNotifications 1 if notifications must be sent
 * @apiSuccess (Success 200) {String} component               "vevent"
 * @apiSuccess (Success 200) {String} summary                 Summary
 * @apiSuccess (Success 200) {String} [location]              Location
 * @apiSuccess (Success 200) {String} [comment]               Comment
 * @apiSuccess (Success 200) {String} [status]                Status
 * @apiSuccess (Success 200) {String} [attachUrl]             Attached URL
 * @apiSuccess (Success 200) {String} [createdBy]             Value of custom header X-SOGo-Component-Created-By or organizer's "SENT-BY"
 * @apiSuccess (Success 200) {Number} priority                Priority
 * @apiSuccess (Success 200) {NSString} [classification]      Either public, confidential or private
 * @apiSuccess (Success 200) {String[]} [categories]          Categories
 * @apiSuccess (Success 200) {Object} [organizer]             Appointment organizer
 * @apiSuccess (Success 200) {String} [organizer.name]        Organizer's name
 * @apiSuccess (Success 200) {String} organizer.email         Organizer's email address
 * @apiSuccess (Success 200) {String} [organizer.uid]         Organizer's user ID
 * @apiSuccess (Success 200) {String} [organizer.sentBy]      Email address of user that is acting on behalf of the calendar owner
 * @apiSuccess (Success 200) {Object[]} [attendees]           List of attendees
 * @apiSuccess (Success 200) {String} [attendees.name]        Attendee's name
 * @apiSuccess (Success 200) {String} attendees.email         Attendee's email address
 * @apiSuccess (Success 200) {String} [attendees.uid]         System user ID
 * @apiSuccess (Success 200) {String} attendees.status        Attendee's participation status
 * @apiSuccess (Success 200) {String} [attendees.role]        Either CHAIR, REQ-PARTICIPANT, OPT-PARTICIPANT, or NON-PARTICIPANT
 * @apiSuccess (Success 200) {String} [attendees.delegatedTo] User that the original request was delegated to
 * @apiSuccess (Success 200) {String} [attendees.delegatedFrom] User the request was delegated from
 * @apiSuccess (Success 200) {Object[]} [alarm]               Alarm definition
 * @apiSuccess (Success 200) {String} alarm.action            Either display or email
 * @apiSuccess (Success 200) {Number} alarm.quantity          Quantity of units
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
 * @apiSuccess (Success 200) {Object[]} [repeat.days]         List of days of the week (by day mask)
 * @apiSuccess (Success 200) {String} repeat.days.day         Day of the week (SU, MO, TU, WE, TH, FR, SA)
 * @apiSuccess (Success 200) {Number} [repeat.days.occurence] Occurrence of a specific day within the monthly or yearly rule (values are -5 to 5)
 * @apiSuccess (Success 200) {Number[]} [repeat.months]       List of months of the year (values are 1 to 12)
 * @apiSuccess (Success 200) {Number[]} [repeat.monthdays]    Days of the month (values are 1 to 31)
 */
- (id <WOActionResults>) viewAction
{
  BOOL isAllDay;
  NSMutableDictionary *data;
  NSCalendarDate *eventStartDate, *eventEndDate;
  NSTimeZone *timeZone;
  SOGoUserDefaults *ud;
  SOGoCalendarComponent *co;
  iCalAlarm *anAlarm;
  iCalEvent *event;

  BOOL resetAlarm;
  unsigned int snoozeAlarm;

  event = [self event];
  co = [self clientObject];

  isAllDay = [event isAllDay];
  ud = [[context activeUser] userDefaults];
  timeZone = [ud timeZone];
  eventStartDate = [event startDate];
  eventEndDate = [event endDate];
  if (!isAllDay)
    {
      [eventStartDate setTimeZone: timeZone];
      [eventEndDate setTimeZone: timeZone];
    }

  // resetAlarm=yes is set only when we are about to show the alarm popup in the Web
  // interface of SOGo. See generic.js for details. snoozeAlarm=X is called when the
  // user clicks on "Snooze for" X minutes, when the popup is being displayed.
  // If either is set, we must find the right alarm.
  resetAlarm = [[[context request] formValueForKey: @"resetAlarm"] boolValue];
  snoozeAlarm = [[[context request] formValueForKey: @"snoozeAlarm"] intValue];

  if (resetAlarm || snoozeAlarm)
    {
      iCalEvent *master;

      master = event;
      [componentCalendar findEntityForClosestAlarm: &event
                                          timezone: timeZone
                                         startDate: &eventStartDate
                                           endDate: &eventEndDate];

      anAlarm = [event firstDisplayOrAudioAlarm];

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
                         [co nameInContainer], @"id",
                       [componentCalendar nameInContainer], @"pid",
                       [componentCalendar displayName], @"calendar",
                       [dateFormatter formattedDate: eventStartDate], @"localizedStartDate",
                       [dateFormatter formattedDate: eventEndDate], @"localizedEndDate",
                       nil];

  if (!isAllDay)
    {
      [data setObject: [dateFormatter formattedTime: eventStartDate] forKey: @"localizedStartTime"];
      [data setObject: [dateFormatter formattedTime: eventEndDate] forKey: @"localizedEndTime"];
    }

  // Add attributes from iCalEvent+SOGo, iCalEntityObject+SOGo and iCalRepeatableEntityObject+SOGo
  [data addEntriesFromDictionary: [event attributesInContext: context]];

  // Return JSON representation
  return [self responseWithStatus: 200 andJSONRepresentation: data];
}

- (id) _statusChangeAction: (NSString *) newStatus
{
  [[self clientObject] changeParticipationStatus: newStatus
                                    withDelegate: nil];

  return [self responseWith204];
}

- (id) acceptAction
{
  return [self _statusChangeAction: @"ACCEPTED"];
}

- (id) declineAction
{
  return [self _statusChangeAction: @"DECLINED"];
}

- (id) needsActionAction
{
  return [self _statusChangeAction: @"NEEDS-ACTION"];
}

- (id) tentativeAction
{
  return [self _statusChangeAction: @"TENTATIVE"];
}

- (id) delegateAction
{
//  BOOL receiveUpdates;
  NSString *delegatedEmail, *delegatedUid;
  iCalPerson *delegatedAttendee;
  SOGoUser *user;
  WORequest *request;
  WOResponse *response;

  response = nil;
  request = [context request];
  delegatedEmail = [request formValueForKey: @"to"];
  if ([delegatedEmail length])
    {
      user = [context activeUser];
      delegatedAttendee = [iCalPerson new];
      [delegatedAttendee autorelease];
      [delegatedAttendee setEmail: delegatedEmail];
      delegatedUid = [delegatedAttendee uid];
      if (delegatedUid)
        {
          SOGoUser *delegatedUser;
          delegatedUser = [SOGoUser userWithLogin: delegatedUid];
          [delegatedAttendee setCn: [delegatedUser cn]];
        }

      [delegatedAttendee setRole: @"REQ-PARTICIPANT"];
      [delegatedAttendee setRsvp: @"TRUE"];
      [delegatedAttendee setParticipationStatus: iCalPersonPartStatNeedsAction];
      [delegatedAttendee setDelegatedFrom:
               [NSString stringWithFormat: @"mailto:%@", [[user allEmails] objectAtIndex: 0]]];

//      receiveUpdates = [[request formValueForKey: @"receiveUpdates"] boolValue];
//      if (receiveUpdates)
//      [delegatedAttendee setRole: @"NON-PARTICIPANT"];

      response = (WOResponse*)[[self clientObject] changeParticipationStatus: @"DELEGATED"
                                                   withDelegate: delegatedAttendee];
    }
  else
    response = [NSException exceptionWithHTTPStatus: 400
                                             reason: @"missing 'to' parameter"];

  if (!response)
    response = [self responseWith204];

  return response;
}

@end
