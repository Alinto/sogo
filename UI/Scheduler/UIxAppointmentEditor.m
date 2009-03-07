/* UIxAppointmentEditor.m - this file is part of SOGo
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

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalRecurrenceRule.h>

#import <SoObjects/SOGo/NSDictionary+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoDateFormatter.h>
#import <SoObjects/SOGo/SOGoContentObject.h>
#import <SoObjects/SOGo/SOGoPermissions.h>
#import <SoObjects/Appointments/SOGoAppointmentFolder.h>
#import <SoObjects/Appointments/SOGoAppointmentObject.h>
#import <SoObjects/Appointments/SOGoAppointmentOccurence.h>

#import <SoObjects/Appointments/SOGoComponentOccurence.h>

#import "UIxComponentEditor.h"
#import "UIxAppointmentEditor.h"

@implementation UIxAppointmentEditor

- (id) init
{
  if ((self = [super init]))
    {
      aptStartDate = nil;
      aptEndDate = nil;
      item = nil;
      event = nil;
      isAllDay = NO;
      isTransparent = NO;
      componentCalendar = nil;
    }

  return self;
}

- (void) dealloc
{
  [item release];
  [[event parent] release];
  [aptStartDate release];
  [aptEndDate release];
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

/* actions */
- (NSCalendarDate *) newStartDate
{
  NSCalendarDate *newStartDate, *now;
  NSTimeZone *timeZone;
  SOGoUser *user;
  int hour;
  unsigned int uStart, uEnd;

  newStartDate = [self selectedDate];
  if (![[self queryParameterForKey: @"hm"] length])
    {
      now = [NSCalendarDate calendarDate];
      timeZone = [[context activeUser] timeZone];
      [now setTimeZone: timeZone];

      user = [context activeUser];
      uStart = [user dayStartHour];
      if ([now isDateOnSameDay: newStartDate])
        {
	  uEnd = [user dayEndHour];
          hour = [now hourOfDay];
          if (hour < uStart)
            newStartDate = [now hour: uStart minute: 0];
          else if (hour > uEnd)
            newStartDate = [[now tomorrow] hour: uStart minute: 0];
          else
            newStartDate = now;
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
  unsigned int minutes;
  SOGoObject <SOGoComponentOccurence> *co;

  [self event];
  co = [self clientObject];
  if ([co isNew]
      && [co isKindOfClass: [SOGoCalendarComponent class]])
    {
      startDate = [self newStartDate];
      duration = [self queryParameterForKey:@"dur"];
      if ([duration length] > 0)
	minutes = [duration intValue];
      else
	minutes = 60;
      endDate
	= [startDate dateByAddingYears: 0 months: 0 days: 0
		     hours: 0 minutes: minutes seconds: 0];
    }
  else
    {
      NSCalendarDate *firstDate;
      NSTimeZone *timeZone;
      iCalEvent *master;
      signed int daylightOffset;

      startDate = [event startDate];
      daylightOffset = 0;
      
      if ([co isNew] && [co isKindOfClass: [SOGoAppointmentOccurence class]])
	{
	  // We are creating a new exception in a recurrent event -- compute the daylight
	  // saving time with respect to the first occurrence of the recurrent event.
	  master = (iCalEvent*)[[event parent] firstChildWithTag: @"vevent"];
	  firstDate = [master startDate];
	  timeZone = [[context activeUser] timeZone];
	  
	  if ([timeZone isDaylightSavingTimeForDate: startDate] != [timeZone isDaylightSavingTimeForDate: firstDate])
	    {
	      daylightOffset = (signed int)[timeZone secondsFromGMTForDate: firstDate]
		- (signed int)[timeZone secondsFromGMTForDate: startDate];
	      startDate = [startDate dateByAddingYears:0 months:0 days:0 hours:0 minutes:0 seconds:daylightOffset];
	    }
	}
      
      isAllDay = [event isAllDay];
      if (isAllDay)
	endDate = [[event endDate] dateByAddingYears: 0 months: 0 days: -1];
      else
	endDate = [[event endDate] dateByAddingYears:0 months:0 days:0 hours:0 minutes:0 seconds:daylightOffset];
      isTransparent = ![event isOpaque];
    }

  ASSIGN (aptStartDate, startDate);
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
	{
	  method = [NSString stringWithFormat:@"%@/%@.ics/editAsAppointment",
			     [co soURL], objectId];
	}
      else
	{
	  method = [NSString stringWithFormat: @"%@/Calendar/personal/%@.vcf/editAsAppointment",
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

- (void) _adjustRecurrentRules
{
  iCalRecurrenceRule *rule;
  NSEnumerator *rules;
  NSCalendarDate *untilDate;
  
  rules = [[event recurrenceRules] objectEnumerator];
  while ((rule = [rules nextObject]))
    {
      untilDate = [rule untilDate];
      if (untilDate)
	{
	  // The until date must match the time of the start date
	  NSCalendarDate *date;

	  date = [[event startDate] copy];
	  [date setTimeZone: [[context activeUser] timeZone]];
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
  SoSecurityManager *sm;
  NSException *ex;

  co = [self clientObject];
  if ([co isKindOfClass: [SOGoAppointmentOccurence class]])
    co = [co container];
  previousCalendar = [co container];
  sm = [SoSecurityManager sharedSecurityManager];

  if ([event hasRecurrenceRules])
    [self _adjustRecurrentRules];

  if ([co isNew])
    {
      if (componentCalendar && componentCalendar != previousCalendar)
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
      [co saveComponent: event];
    }
  else
    {
      // The event was modified -- save it.
      [co saveComponent: event];

      if (componentCalendar && componentCalendar != previousCalendar)
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
  
  return [self jsCloseWithRefreshMethod: @"refreshEventsAndDisplay()"];
}

- (id <WOActionResults>) viewAction
{
  WOResponse *result;
  NSDictionary *data;
  NSCalendarDate *firstDate, *eventDate;
  NSTimeZone *timeZone;
  SOGoDateFormatter *dateFormatter;
  SOGoUser *user;
  SOGoCalendarComponent *co;
  iCalEvent *master;
  signed int daylightOffset;

  [self event];

  result = [self responseWithStatus: 200];
  user = [context activeUser];
  timeZone = [user timeZone];
  dateFormatter = [user dateFormatterInContext: context];
  eventDate = [event startDate];
  [eventDate setTimeZone: timeZone];
  co = [self clientObject];
  
  if ([co isNew] && [co isKindOfClass: [SOGoAppointmentOccurence class]])
    {
      // This is a new exception in a recurrent event -- compute the daylight
      // saving time with respect to the first occurrence of the recurrent event.
      master = (iCalEvent*)[[event parent] firstChildWithTag: @"vevent"];
      firstDate = [master startDate];

      if ([timeZone isDaylightSavingTimeForDate: eventDate] != [timeZone isDaylightSavingTimeForDate: firstDate])
	{
	  daylightOffset = (signed int)[timeZone secondsFromGMTForDate: firstDate] 
	    - (signed int)[timeZone secondsFromGMTForDate: eventDate];
	  eventDate = [eventDate dateByAddingYears:0 months:0 days:0 hours:0 minutes:0 seconds:daylightOffset];
	}
    }
  data = [NSDictionary dictionaryWithObjectsAndKeys:
		       [dateFormatter formattedDate: eventDate], @"startDate",
		       [dateFormatter formattedTime: eventDate], @"startTime",
		       ([event hasRecurrenceRules]? @"1": @"0"), @"isReccurent",
		       ([event isAllDay]? @"1": @"0"), @"isAllDay",
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

  [event setTransparency: (isTransparent? @"TRANSPARENT" : @"OPAQUE")];
}

// TODO: add tentatively

- (id) acceptAction
{
  [[self clientObject] changeParticipationStatus: @"ACCEPTED"];

  return self;
}

- (id) declineAction
{
  [[self clientObject] changeParticipationStatus: @"DECLINED"];

  return self;
}

@end
