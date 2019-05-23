/* UIxAppointmentEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2018 Inverse inc.
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


#import <Foundation/NSTimeZone.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>

#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/iCalTrigger.h>
#import <NGCards/iCalRecurrenceRule.h>

#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoDateFormatter.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <Appointments/iCalAlarm+SOGo.h>
#import <Appointments/iCalCalendar+SOGo.h>
#import <Appointments/iCalEntityObject+SOGo.h>
#import <Appointments/iCalPerson+SOGo.h>
#import <Appointments/iCalRepeatableEntityObject+SOGo.h>
#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoAppointmentObject.h>
#import <Appointments/SOGoAppointmentOccurence.h>


#import "UIxComponentEditor.h"
#import "UIxAppointmentEditor.h"

@implementation UIxAppointmentEditor

- (id) initWithContext: (WOContext *) _context
{
  SOGoUser *user;

  if ((self = [super initWithContext: _context]))
    {
      user = [_context activeUser];
      ASSIGN (dateFormatter, [user dateFormatterInContext: _context]);
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

- (NSException *) _adjustRecurrentRules
{
  NSArray *events;
  NSCalendarDate *untilDate, *recurrenceId;
  NSEnumerator *rules;
  NSException *ex;
  NSTimeZone *timeZone;
  SOGoAppointmentObject *co;
  SOGoUserDefaults *ud;
  iCalCalendar *calendar;
  iCalEvent *event;
  iCalRecurrenceRule *rule;
  iCalRepeatableEntityObject *masterEvent, *occurrence;
  int count, max;

  co = [self clientObject];
  event = [self event];
  rules = [[event recurrenceRules] objectEnumerator];
  ex = nil;
  ud = [[context activeUser] userDefaults];
  timeZone = [ud timeZone];

  while ((rule = [rules nextObject]))
    {
      untilDate = [rule untilDate];
      if (untilDate)
        {
          if ([untilDate compare: [event endDate]] == NSOrderedAscending)
            {
              ex = [NSException exceptionWithHTTPStatus: 500
                                                 reason: [self labelForKey: @"validate_untilbeforeend"]];
              break;
            }
          else
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

  // Remove invalid occurrences
  calendar = [event parent];
  events = [calendar events];
  masterEvent = [events objectAtIndex: 0];
  max = [events count];
  for (count = max - 1; count > 0; count--)
    {
      occurrence = [events objectAtIndex: count];
      recurrenceId = [occurrence recurrenceId];
      if (recurrenceId && ![masterEvent doesOccurOnDate: recurrenceId])
        {
          [co prepareDeleteOccurence: (iCalEvent *)occurrence]; // notify attendees, update their calendars
          [calendar removeChild: occurrence];
        }
    }

  return ex;
}

/**
 * @api {post} /so/:username/Calendar/:calendarId/:appointmentId/rsvpAppointment Set participation state
 * @apiVersion 1.0.0
 * @apiName PostEventRsvp
 * @apiGroup Calendar
 * @apiDescription Set the participation state of an attendee.
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/personal/71B6-54904400-1-7C308500.ics/rsvpAppointment \
 *          -H 'Content-Type: application/json' \
 *          -d '{ "reply": 1, \
 *                "alarm": { { "quantity": 15, "unit": "MINUTES", "action": "display", "reference": "BEFORE", "relation": "START" } }'
 *
 * @apiParam {Number} reply                   0 if needs-action, 1 if accepted, 2 if declined, 3 if tentative, 4 if delegated
 * @apiParam {String} [delegatedTo]           Email address of delegated attendee
 * @apiParam {Object[]} [alarm]               Set an alarm for the attendee
 * @apiParam {String} alarm.action            Either display or email
 * @apiParam {Number} alarm.quantity          Quantity of units
 * @apiParam {String} alarm.unit              Either MINUTES, HOURS, or DAYS
 * @apiParam {String} alarm.reference         Either BEFORE or AFTER
 * @apiParam {String} alarm.relation          Either START or END
 * @apiParam {Boolean} [alarm.attendees]      Alert attendees by email if 1 and action is email
 * @apiParam {Boolean} [alarm.organizer]      Alert organizer by email if 1 and action is email
 */
- (id <WOActionResults>) rsvpAction
{
  iCalPerson *delegatedAttendee;
  NSDictionary *params, *jsonResponse;
  WOResponse *response;
  WORequest *request;
  iCalAlarm *anAlarm;
  NSException *ex;
  NSString *status;
  id alarm;
  
  int replyList;
  
  request = [context request];
  params = [[request contentAsString] objectFromJSONString];

  delegatedAttendee = nil;
  anAlarm = nil;
  status = nil;

  replyList = [[params objectForKey: @"reply"] intValue];

  switch (replyList)
    {
    case iCalPersonPartStatAccepted:
      status =  @"ACCEPTED";
      break;

    case iCalPersonPartStatDeclined:
      status = @"DECLINED";
      break;

    case iCalPersonPartStatNeedsAction:
      status = @"NEEDS-ACTION";
      break;

    case iCalPersonPartStatTentative:
      status = @"TENTATIVE";
      break;

    case iCalPersonPartStatDelegated:
    default:
      {
        NSString *delegatedEmail, *delegatedUid;
        SOGoUser *user;
        
        status = @"DELEGATED";
        delegatedEmail = [[params objectForKey: @"delegatedTo"] stringByTrimmingSpaces];

        if ([delegatedEmail length])
          {
            user = [context activeUser];
            delegatedAttendee = [iCalPerson new];
            [delegatedAttendee autorelease];
            [delegatedAttendee setEmail: delegatedEmail];
            delegatedUid = [delegatedAttendee uidInDomain: [user domain]];
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
          }
        else
          {
            jsonResponse = [NSDictionary dictionaryWithObjectsAndKeys:
                                           @"failure", @"status",
                                         @"missing 'delegatedTo' parameter", @"message",
                                         nil];
            return [self responseWithStatus: 400
                                  andString: [jsonResponse jsonRepresentation]];
          }
      }
      break;
    }

  // Set an alarm for the user
  alarm = [params objectForKey: @"alarm"];
  if ([alarm isKindOfClass: [NSDictionary class]])
    {
      NSString *reminderAction, *reminderUnit, *reminderQuantity, *reminderReference, *reminderRelation;
      BOOL reminderEmailAttendees, reminderEmailOrganizer;

      reminderAction = [alarm objectForKey: @"action"];
      reminderUnit = [alarm objectForKey: @"unit"];
      reminderQuantity = [alarm objectForKey: @"quantity"];
      reminderReference = [alarm objectForKey: @"reference"];
      reminderRelation = [alarm objectForKey: @"relation"];
      reminderEmailAttendees = [[alarm objectForKey: @"attendees"] boolValue];
      reminderEmailOrganizer = [[alarm objectForKey: @"organizer"] boolValue];
      anAlarm = [iCalAlarm alarmForEvent: [self event]
                                   owner: [[self clientObject] ownerInContext: context]
                                  action: reminderAction
                                    unit: reminderUnit
                                quantity: reminderQuantity
                               reference: reminderReference
                        reminderRelation: reminderRelation
                          emailAttendees: reminderEmailAttendees
                          emailOrganizer: reminderEmailOrganizer];
    }

  ex = [[self clientObject] changeParticipationStatus: status
                                         withDelegate: delegatedAttendee
                                                alarm: anAlarm];

  if (ex)
    {
      jsonResponse = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [ex reason], @"message",
                                   nil];
      response = [self responseWithStatus: [ex httpStatus]
                                andString: [jsonResponse jsonRepresentation]];
    }
  else
    response = [self responseWith204];

  return response;
}

/**
 * @api {post} /so/:username/Calendar/:calendarId/:appointmentId/save(AsAppointment) Save event
 * @apiVersion 1.0.0
 * @apiName PostEventSave
 * @apiGroup Calendar
 * @apiDescription When saving a new event, the action URL must be saveAsAppointment,
 *                 otherwise it is optional.
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/personal/71B6-54904400-1-7C308500.ics/save \
 *          -H 'Content-Type: application/json' \
 *          -d '{ "summary": "Meeting", "startDate": "2015-01-28", "startTime": "10:00", \
 *                "endDate": "2015-01-28", "endTime": "12:00" }'
 *
 * @apiParam {_} . _Save in [iCalEvent+SOGo setAttributes:inContext:]_
 *
 * @apiParam {String} startDate               Start date (YYYY-MM-DD)
 * @apiParam {String} startTime               Start time (HH:MM)
 * @apiParam {String} endDate                 End date (YYYY-MM-DD)
 * @apiParam {String} endTime                 End time (HH:MM)
 * @apiParam {Number} [isAllDay]              1 if event is all-day
 * @apiParam {Number} isTransparent           1 if the event is not opaque
 *
 * @apiParam {_} .. _Save in [iCalEntityObject+SOGo setAttributes:inContext:]_
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
 * @apiParam {String} attendees.partstat      Attendee's participation status
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
 * @apiParam {Boolean} [alarm.organizer]      Alert organizer by email if true and action is email
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
 * @apiParam {String} [destinationCalendar]   ID of destination calendar
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
  id error;

  unsigned int httpStatus;
  BOOL forceSave;

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
      forceSave = [[params objectForKey: @"ignoreConflicts"] boolValue];

      if ([event hasRecurrenceRules])
        ex = [self _adjustRecurrentRules];

      if (!ex)
        {
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
              ex = [co saveComponent: event  force: forceSave];
            }
          else
            {
              // The event was modified -- save it.
              ex = [co saveComponent: event  force: forceSave];

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
    }

  if (ex)
    {
      httpStatus = 500;

      if ([ex respondsToSelector: @selector(httpStatus)])
        httpStatus = [ex httpStatus];

      error = [[ex reason] objectFromJSONString];
      if (error == nil)
        error = [ex reason];
      jsonResponse = [NSDictionary dictionaryWithObjectsAndKeys:
                                     error, @"message", nil];
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
 * @api {get} /so/:username/Calendar/:calendarId/:eventId/view Get event
 * @apiVersion 1.0.0
 * @apiName GetEventView
 * @apiGroup Calendar
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/personal/71B6-54904400-1-7C308500.ics/view
 *
 * @apiParam {Number} [resetAlarm]    Mark alarm as triggered if set to 1
 * @apiParam {Number} [snoozeAlarm]   Snooze the alarm for this number of minutes
 *
 * @apiSuccess {_} . _From [UIxAppointmentEditor viewAction]_
 *
 * @apiSuccess (Success 200) {String} id                      Event ID
 * @apiSuccess (Success 200) {String} [occurrenceId]          Occurrence ID
 * @apiSuccess (Success 200) {String} pid                     Calendar ID (event's folder)
 * @apiSuccess (Success 200) {String} calendar                Human readable name of calendar
 * @apiSuccess (Success 200) {String} startDate               Start date (ISO8601)
 * @apiSuccess (Success 200) {String} localizedStartDate      Formatted start date
 * @apiSuccess (Success 200) {String} [localizedStartTime]    Formatted start time
 * @apiSuccess (Success 200) {String} endDate                 End date (ISO8601)
 * @apiSuccess (Success 200) {String} localizedEndDate        Formatted end date
 * @apiSuccess (Success 200) {String} [localizedEndTime]      Formatted end time
 * @apiSuccess (Success 200) {Number} isReadOnly              1 if event is read-only
 * @apiSuccess (Success 200) {Number} userHasRSVP             1 if owner is invited
 * @apiSuccess (Success 200) {Number} [reply]                 0 if needs-action, 1 if accepted, 2 if declined, 3 if tentative, 4 if delegated
 * @apiSuccess (Success 200) {Object[]} [attachUrls]          Attached URLs
 * @apiSuccess (Success 200) {String} attachUrls.value        URL
 *
 * @apiSuccess {_} .. _From [UIxComponentEditor alarm]_
 *
 * @apiSuccess (Success 200) {Object[]} [alarm]               Alarm definition
 * @apiSuccess (Success 200) {String} alarm.action            Either display or email
 * @apiSuccess (Success 200) {Number} alarm.quantity          Quantity of units
 * @apiSuccess (Success 200) {String} alarm.unit              Either MINUTES, HOURS, or DAYS
 * @apiSuccess (Success 200) {String} alarm.reference         Either BEFORE or AFTER
 * @apiSuccess (Success 200) {String} alarm.relation          Either START or END
 * @apiSuccess (Success 200) {Boolean} alarm.attendees        Alert attendees by email if true and action is email
 * @apiSuccess (Success 200) {Boolean} alarm.organizer        Alert organizer by email if true and action is email
 *
 * @apiSuccess {_} ... _From [iCalEvent+SOGo attributesInContext:]_
 *
 * @apiSuccess (Success 200) {Number} isAllDay                1 if event is all-day
 * @apiSuccess (Success 200) {Number} isTransparent           1 if the event is not opaque
 *
 * @apiSuccess {_} .... _From [iCalEntityObject+SOGo attributesInContext:]_
 *
 * @apiSuccess (Success 200) {Number} sendAppointmentNotifications 1 if notifications must be sent
 * @apiSuccess (Success 200) {String} component               "vevent"
 * @apiSuccess (Success 200) {String} summary                 Summary
 * @apiSuccess (Success 200) {String} [location]              Location
 * @apiSuccess (Success 200) {String} [comment]               Comment
 * @apiSuccess (Success 200) {String} [status]                Status (tentative, confirmed, or cancelled)
 * @apiSuccess (Success 200) {String} [createdBy]             Value of custom header X-SOGo-Component-Created-By or organizer's "SENT-BY"
 * @apiSuccess (Success 200) {Number} priority                Priority (0-9)
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
 * @apiSuccess (Success 200) {String} attendees.partstat      Attendee's participation status
 * @apiSuccess (Success 200) {String} [attendees.role]        Either CHAIR, REQ-PARTICIPANT, OPT-PARTICIPANT, or NON-PARTICIPANT
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
 * @apiSuccess (Success 200) {Object[]} [repeat.days]         List of days of the week (by day mask)
 * @apiSuccess (Success 200) {String} repeat.days.day         Day of the week (SU, MO, TU, WE, TH, FR, SA)
 * @apiSuccess (Success 200) {Number} [repeat.days.occurence] Occurrence of a specific day within the monthly or yearly rule (values are -5 to 5)
 * @apiSuccess (Success 200) {Number[]} [repeat.months]       List of months of the year (values are 1 to 12)
 * @apiSuccess (Success 200) {Number[]} [repeat.monthdays]    Days of the month (values are 1 to 31)
 * @apiSuccess (Success 200) {String[]} [repeat.dates]        Recurrence dates (ISO8601)
 */
- (id <WOActionResults>) viewAction
{
  BOOL isAllDay;
  NSArray *attachUrls;
  NSMutableDictionary *data;
  NSCalendarDate *eventStartDate, *eventEndDate;
  NSTimeZone *timeZone;
  SOGoUserDefaults *ud;
  SOGoCalendarComponent *co;
  iCalAlarm *anAlarm;
  iCalEvent *event;

  BOOL resetAlarm;
  NSUInteger snoozeAlarm;

  event = [self event];
  co = [self clientObject];

  isAllDay = [event isAllDay];
  ud = [[context activeUser] userDefaults];
  timeZone = [ud timeZone];
  eventStartDate = [event startDate];
  eventEndDate = [event endDate];

  if (isAllDay)
    {
      iCalDateTime *dt;
      iCalTimeZone *tz;
      NSInteger offset;

      // An all-day event usually doesn't have a timezone associated to its
      // start-end dates; however, if it does, we convert them to GMT.
      dt = (iCalDateTime*) [event uniqueChildWithTag: @"dtstart"];
      tz = [(iCalDateTime*) dt timeZone];
      if (tz)
        eventStartDate = [tz computedDateForDate: eventStartDate];
      dt = (iCalDateTime*) [event uniqueChildWithTag: @"dtend"];
      tz = [(iCalDateTime*) dt timeZone];
      if (tz)
        eventEndDate = [tz computedDateForDate: eventEndDate];

      eventEndDate = [eventEndDate dateByAddingYears: 0 months: 0 days: -1];

      // Convert the dates to the user's timezone
      offset = [timeZone secondsFromGMTForDate: eventStartDate];
      eventStartDate = [eventStartDate dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
                                                 seconds:-offset];
      offset = [timeZone secondsFromGMTForDate: eventEndDate];
      eventEndDate = [eventEndDate dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
                                             seconds:-offset];
    }

  [eventStartDate setTimeZone: timeZone];
  [eventEndDate setTimeZone: timeZone];

  // resetAlarm=yes is set only when we are about to show the alarm popup in the Web
  // interface of SOGo. See Alarm.service.js for details. snoozeAlarm=X is called when the
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
                       [componentCalendar nameInContainer], @"pid",
                       [componentCalendar displayName], @"calendar",
                       [NSNumber numberWithBool: isAllDay], @"isAllDay",
                       [NSNumber numberWithBool: [self isReadOnly]], @"isReadOnly",
                       [NSNumber numberWithBool: [self userHasRSVP]], @"userHasRSVP",
                       [eventStartDate iso8601DateString], @"startDate",
                       [eventEndDate iso8601DateString], @"endDate",
                       [dateFormatter formattedDate: eventStartDate], @"localizedStartDate",
                       [dateFormatter formattedDate: eventEndDate], @"localizedEndDate",
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

  attachUrls = [self attachUrls];
  if ([attachUrls count]) [data setObject: attachUrls forKey: @"attachUrls"];

  if (!isAllDay)
    {
      [data setObject: [dateFormatter formattedTime: eventStartDate] forKey: @"localizedStartTime"];
      [data setObject: [dateFormatter formattedTime: eventEndDate] forKey: @"localizedEndTime"];
    }

  if ([self userHasRSVP])
    [data setObject: [self reply] forKey: @"reply"];

  // Add attributes from iCalEvent+SOGo, iCalEntityObject+SOGo and iCalRepeatableEntityObject+SOGo
  [data addEntriesFromDictionary: [event attributesInContext: context]];

  // Return JSON representation
  return [self responseWithStatus: 200 andJSONRepresentation: data];
}

@end
