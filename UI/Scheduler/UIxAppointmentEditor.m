/* UIxAppointmentEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2011 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Francis Lachapelle <flachapelle@inverse.ca>
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

#import <NGObjWeb/SoObject.h>
#import <NGObjWeb/SoPermissions.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSCalendarDate+misc.h>

#import <NGCards/iCalAlarm.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalTrigger.h>
#import <NGCards/iCalRecurrenceRule.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/iCalDateTime.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoContentObject.h>
#import <SOGo/SOGoDateFormatter.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
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
      aptStartDate = nil;
      aptEndDate = nil;
      item = nil;
      event = nil;
      isAllDay = NO;
      isTransparent = NO;
      componentCalendar = nil;

      user = [[self context] activeUser];
      ASSIGN (dateFormatter, [user dateFormatterInContext: context]);
    }

  return self;
}

- (void) dealloc
{
  [item release];
  [[event parent] release];
  [aptStartDate release];
  [aptEndDate release];
  [dateFormatter release];
  [componentCalendar release];
  [super dealloc];
}

/* template values */
- (iCalEvent *) event
{
  if (!event)
    {
      event = (iCalEvent *) [[self clientObject] occurence];
      [[event parent] retain];
    }

  return event;
}

- (NSString *) saveURL
{
  return [NSString stringWithFormat: @"%@/saveAsAppointment",
		   [[self clientObject] baseURL]];
}

/* icalendar values */
- (BOOL) isAllDay
{
  NSString *hm;

  hm = [self queryParameterForKey: @"hm"];

  return (isAllDay
	  || [hm isEqualToString: @"allday"]);
}

- (void) setIsAllDay: (BOOL) newIsAllDay
{
  isAllDay = newIsAllDay;
}

- (BOOL) isTransparent
{
  return isTransparent;
}

- (void) setIsTransparent: (BOOL) newIsTransparent
{
  isTransparent = newIsTransparent;
}

- (void) setAptStartDate: (NSCalendarDate *) newAptStartDate
{
  ASSIGN (aptStartDate, newAptStartDate);
}

- (NSCalendarDate *) aptStartDate
{
  return aptStartDate;
}

- (void) setAptEndDate: (NSCalendarDate *) newAptEndDate
{
  ASSIGN (aptEndDate, newAptEndDate);
}

- (NSCalendarDate *) aptEndDate
{
  return aptEndDate;
}

- (void) setItem: (NSString *) newItem
{
  ASSIGN (item, newItem);
}

- (NSString *) item
{
  return item;
}

- (SOGoAppointmentFolder *) componentCalendar
{
  return componentCalendar;
}

- (void) setComponentCalendar: (SOGoAppointmentFolder *) _componentCalendar
{
  ASSIGN (componentCalendar, _componentCalendar);
}

/* read-only event */
- (NSString *) aptStartDateText
{
  return [dateFormatter formattedDate: aptStartDate];
}

- (NSString *) aptStartDateTimeText
{
  return [dateFormatter formattedDateAndTime: aptStartDate];
}

- (NSString *) aptEndDateText
{
  return [dateFormatter formattedDate: aptEndDate];
}

- (NSString *) aptEndDateTimeText
{
  return [dateFormatter formattedDateAndTime: aptEndDate];
}

- (BOOL) startDateIsEqualToEndDate
{
  return [aptStartDate isEqualToDate: aptEndDate];
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
  NSCalendarDate *startDate, *endDate;
  NSString *duration;
  NSTimeZone *timeZone;
  unsigned int total, hours, minutes;
  signed int offset;
  SOGoObject <SOGoComponentOccurence> *co;
  SOGoUserDefaults *ud;
  iCalTimeZone *eventTimeZone;

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
    }
  else
    {
      startDate = [event startDate];
      isAllDay = [event isAllDay];
      endDate = [event endDate];
      if (isAllDay)
	{
	  endDate = [endDate dateByAddingYears: 0 months: 0 days: -1];
	  
	  // Verify if the start date is "floating" (no timezone). In this case, convert it
	  // to the user's timezone.
	  eventTimeZone = [(iCalDateTime*)[event uniqueChildWithTag: @"dtstart"] timeZone];
	  if (eventTimeZone == nil)
	    {
	      offset = [timeZone secondsFromGMTForDate: startDate];
	      startDate = [startDate dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
					       seconds:-offset];
	      endDate = [endDate dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
					   seconds:-offset];
	    }
	}
      isTransparent = ![event isOpaque];
    }

  [startDate setTimeZone: timeZone];
  ASSIGN (aptStartDate, startDate);

  [endDate setTimeZone: timeZone];
  ASSIGN (aptEndDate, endDate);

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
  if ([objectId length])
    {
      sm = [SoSecurityManager sharedSecurityManager];
      if (![sm validatePermission: SoPerm_AddDocumentsImagesAndFiles
                         onObject: co
                        inContext: context])
        method = [NSString stringWithFormat:@"%@/%@.ics/editAsAppointment",
                           [co soURL], objectId] ;
      else
        method = [NSString stringWithFormat: @"%@/Calendar/personal/%@.ics/editAsAppointment",
                           [self userFolderPath], objectId];
      uri = [self completeHrefForMethod: method];
      result = [self redirectToLocation: uri];
    }
  else
    result = [NSException exceptionWithHTTPStatus: 500 /* Internal Error */
                          reason: @"could not create a unique ID"];

  return result;
}

- (void) _adjustRecurrentRules
{
  iCalRecurrenceRule *rule;
  NSEnumerator *rules;
  NSCalendarDate *untilDate;
  SOGoUserDefaults *ud;
  NSTimeZone *timeZone;
  
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

- (id <WOActionResults>) saveAction
{
  SOGoAppointmentFolder *previousCalendar;
  SOGoAppointmentObject *co;
  NSString *jsonResponse;
  SoSecurityManager *sm;
  NSException *ex;

  co = [self clientObject];
  if ([co isKindOfClass: [SOGoAppointmentOccurence class]])
    co = [co container];
  previousCalendar = [co container];
  sm = [SoSecurityManager sharedSecurityManager];
  ex = nil;

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
	       andString: [jsonResponse jsonRepresentation]];
}

- (id <WOActionResults>) viewAction
{
  WOResponse *result;
  NSDictionary *data;
  NSCalendarDate *eventStartDate, *eventEndDate;
  NSTimeZone *timeZone;
  SOGoUserDefaults *ud;
  SOGoCalendarComponent *co;
  BOOL resetAlarm;
  unsigned int snoozeAlarm;

  [self event];

  result = [self responseWithStatus: 200];
  ud = [[context activeUser] userDefaults];
  timeZone = [ud timeZone];
  eventStartDate = [event startDate];
  eventEndDate = [event endDate];
  [eventStartDate setTimeZone: timeZone];
  [eventEndDate setTimeZone: timeZone];
  co = [self clientObject];
  
  if (!componentCalendar)
    {
      componentCalendar = [co container];
      if ([componentCalendar isKindOfClass: [SOGoCalendarComponent class]])
	componentCalendar = [componentCalendar container];
      [componentCalendar retain];
    }
  
  if ([event hasAlarms] && ![event hasRecurrenceRules])
    {
      iCalAlarm *anAlarm;
      resetAlarm = [[[context request] formValueForKey: @"resetAlarm"] boolValue];
      snoozeAlarm = [[[context request] formValueForKey: @"snoozeAlarm"] intValue];
      if (resetAlarm)
        {
          iCalTrigger *aTrigger;
          
          anAlarm = [[event alarms] objectAtIndex: 0];
          aTrigger = [anAlarm trigger];
          [aTrigger setValue: 0 ofAttribute: @"x-webstatus" to: @"triggered"];
          
          [co saveComponent: event];
        }
      else if (snoozeAlarm)
        {
          anAlarm = [[event alarms] objectAtIndex: 0];
          if ([[anAlarm action] caseInsensitiveCompare: @"DISPLAY"] == NSOrderedSame)
            [co snoozeAlarm: snoozeAlarm];
        }
    }

  data = [NSDictionary dictionaryWithObjectsAndKeys:
		       [componentCalendar displayName], @"calendar",
		       [event tag], @"component",
		       [dateFormatter formattedDate: eventStartDate], @"startDate",
		       [dateFormatter formattedTime: eventStartDate], @"startTime",
		       [dateFormatter formattedDate: eventEndDate], @"endDate",
		       [dateFormatter formattedTime: eventEndDate], @"endTime",
		       ([event hasRecurrenceRules] ? @"1": @"0"), @"isRecurring",
		       ([event isAllDay] ? @"1": @"0"), @"isAllDay",
		       [event summary], @"summary",
		       [event location], @"location",
		       [event comment], @"description",
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
  int nbrDays;
  iCalDateTime *startDate;
  iCalTimeZone *tz;
  SOGoUserDefaults *ud;
  
  [self event];  
  [super takeValuesFromRequest: _rq inContext: _ctx];

  if (isAllDay)
    {
      nbrDays = ((float) abs ([aptEndDate timeIntervalSinceDate: aptStartDate])
		 / 86400) + 1;
      [event setAllDayWithStartDate: aptStartDate
                           duration: nbrDays];
    }
  else
    {
      [event setStartDate: aptStartDate];
      [event setEndDate: aptEndDate];
    }
  
  if (!isAllDay)
    {
      // Make sure there's a vTimeZone associated to the event unless it
      // is an all-day event.
      startDate = (iCalDateTime *)[event uniqueChildWithTag: @"dtstart"];
      if (![startDate timeZone])
        {
          ud = [[context activeUser] userDefaults];
          tz = [iCalTimeZone timeZoneForName: [ud timeZoneName]];
          if ([[event parent] addTimeZone: tz])
            {
              [startDate setTimeZone: tz];
              [(iCalDateTime *)[event uniqueChildWithTag: @"dtend"] setTimeZone: tz];
            }
        }
    }
  else if (![[self clientObject] isNew])
    {
      // Remove the vTimeZone when dealing with an all-day event.
      startDate = (iCalDateTime *)[event uniqueChildWithTag: @"dtstart"];
      tz = [startDate timeZone];
      if (tz)
        {
          [startDate setTimeZone: nil];
          [(iCalDateTime *)[event uniqueChildWithTag: @"dtend"] setTimeZone: nil];
          [[event parent] removeChild: tz];
        }
    }

  [event setTransparency: (isTransparent? @"TRANSPARENT" : @"OPAQUE")];
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
//	[delegatedAttendee setRole: @"NON-PARTICIPANT"];

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
