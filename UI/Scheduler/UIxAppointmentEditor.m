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
    }

  return self;
}

- (void) dealloc
{
  [item release];
  [event release];
  [aptStartDate release];
  [aptEndDate release];
  [super dealloc];
}

/* template values */
- (iCalEvent *) event
{
  if (!event)
    {
      event = (iCalEvent *) [[self clientObject] occurence];
      [event retain];
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
      startDate = [event startDate];
      isAllDay = [event isAllDay];
      if (isAllDay)
	endDate = [[event endDate] dateByAddingYears: 0 months: 0 days: -1];
      else
	endDate = [event endDate];
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

//
// This method needs to carefully handle the following cases :
//
// A- Alice creates an event in her calendar
// B- Alice creates an event in Bob's calendar (and invites herself or not)
// C- Alice moves an event to an other calendar
//
- (id <WOActionResults>) saveAction
{
  SOGoAppointmentFolder *thisFolder;
  SOGoAppointmentObject *co;
  SoSecurityManager *sm;
  NSException *ex;
  NSString *aOwner;

  // See A.
  co = [self clientObject];

  if (componentCalendar)
    {
      aOwner = [componentCalendar ownerInContext: context];
      
      // See B.
      if (![aOwner isEqualToString: [[context activeUser] login]])
	{
	  co = [componentCalendar lookupName: [co nameInContainer]
				  inContext: context
				  acquire: NO];
	}
    }
  
  // We save the component
  [co saveComponent: event];

  // See C.
  if (componentCalendar)
    {
      sm = [SoSecurityManager sharedSecurityManager];

      if ([co isKindOfClass: [SOGoAppointmentOccurence class]])
	co = [co container];
      thisFolder = [co container];
      if (componentCalendar != thisFolder)
	if (![sm validatePermission: SoPerm_DeleteObjects
		 onObject: thisFolder
		 inContext: context])
	  {
	    if (![sm validatePermission: SoPerm_AddDocumentsImagesAndFiles
		     onObject: componentCalendar
		     inContext: context])
	      ex = [co moveToFolder: componentCalendar]; // TODO: handle exception
	  }
    }

  return [self jsCloseWithRefreshMethod: @"refreshEventsAndDisplay()"];
}

- (id <WOActionResults>) viewAction
{
  WOResponse *result;
  NSDictionary *data;
  SOGoAppointmentFolder *co;
  SOGoDateFormatter *dateFormatter;
  SOGoUser *user;
  NSCalendarDate *startDate;

  result = [context response];
  user = [context activeUser];
  co = [self clientObject];
  dateFormatter = [user dateFormatterInContext: context];

  [self event];
  startDate = [[event startDate] copy];
  [startDate setTimeZone: [user timeZone]];

  data = [NSDictionary dictionaryWithObjectsAndKeys:
			 [dateFormatter formattedDate: startDate], @"startDate",
		       [dateFormatter formattedTime: startDate], @"startTime",
		       ([event hasRecurrenceRules]? @"1": @"0"), @"isReccurent",
		       ([event isAllDay] ? @"1": @"0"), @"isAllDay",
		       [event summary], @"summary",
		       [event location], @"location",
		       [event comment], @"description",
		       nil];
  [result appendContentString: [data jsonRepresentation]];
  [startDate release];

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
  SOGoAppointmentObject *clientObject;
  int nbrDays;

  clientObject = [self clientObject];
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
