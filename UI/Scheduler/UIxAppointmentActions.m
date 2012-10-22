/* UIxAppointmentActions.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc.
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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoPermissions.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>

#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <Appointments/iCalEvent+SOGo.h>
#import <Appointments/SOGoAppointmentObject.h>
#import <Appointments/SOGoAppointmentFolder.h>

#import <Common/WODirectAction+SOGo.h>

#import "UIxAppointmentActions.h"

@implementation UIxAppointmentActions

- (WOResponse *) adjustAction
{
  WOResponse *response;
  WORequest *rq;
  SOGoAppointmentObject *co;
  iCalEvent *event;
  NSCalendarDate *start, *newStart, *end, *newEnd;
  NSTimeInterval newDuration;
  SOGoUserDefaults *ud;
  NSString *daysDelta, *startDelta, *durationDelta;
  NSTimeZone *tz;

  rq = [context request];

  daysDelta = [rq formValueForKey: @"days"];
  startDelta = [rq formValueForKey: @"start"];
  durationDelta = [rq formValueForKey: @"duration"];
  if ([daysDelta length] > 0
      || [startDelta length] > 0 || [durationDelta length] > 0)
    {
      co = [self clientObject];
      event = (iCalEvent *) [[self clientObject] occurence];

      start = [event startDate];
      end = [event endDate];

      if ([event isAllDay])
        {
          newStart = [start dateByAddingYears: 0 months: 0
                                         days: [daysDelta intValue]
                                        hours: 0 minutes: 0
                                      seconds: 0];
          newDuration = (((float) abs ([end timeIntervalSinceDate: start])
                          + [durationDelta intValue] * 60)
                         / 86400);
          [event setAllDayWithStartDate: newStart duration: newDuration];
        }
      else
        {
          ud = [[context activeUser] userDefaults];
          tz = [ud timeZone];
          [start setTimeZone: tz];
          [end setTimeZone: tz];
          newStart = [start dateByAddingYears: 0 months: 0
                                         days: [daysDelta intValue]
                                        hours: 0 minutes: [startDelta intValue]
                                      seconds: 0];

          newDuration = ([end timeIntervalSinceDate: start]
                         + [durationDelta intValue] * 60);
          newEnd = [newStart addTimeInterval: newDuration];

          [event setStartDate: newStart];
          [event setEndDate: newEnd];
        }

      if ([event hasRecurrenceRules])
	[event updateRecurrenceRulesUntilDate: end];

      [co saveComponent: event];

      response = [self responseWith204];
    }
  else
    response
      = (WOResponse *) [NSException exceptionWithHTTPStatus: 400
                                                     reason: @"missing 'days', 'start' and/or 'duration' parameters"];

    
  return response;
}

- (WOResponse *) copyAction
{
  NSString *destination;
  NSArray *events;
  iCalCalendar *calendar;
  iCalRepeatableEntityObject *masterOccurence;
  SOGoAppointmentObject *thisEvent;
  SOGoAppointmentFolder *sourceCalendar, *destinationCalendar;
  SoSecurityManager *sm;
  WOResponse *response;
  WORequest *rq;

  rq = [context request];

  destination = [rq formValueForKey: @"destination"];
  if (![destination length])
    destination = @"personal";
  
  thisEvent = [self clientObject];
  sourceCalendar = [thisEvent container];
  destinationCalendar = [[sourceCalendar container] lookupName: destination
						     inContext: context
						       acquire: NO];
  if (destinationCalendar)
    {
      // Verify access rights to destination calendar
      sm = [SoSecurityManager sharedSecurityManager];
      if ([sm validatePermission: SoPerm_AddDocumentsImagesAndFiles
			onObject: destinationCalendar
		       inContext: context])
	{
	  response = [NSException exceptionWithHTTPStatus: 403
						   reason: @"Can't add event to destination calendar."];
	}
      // Verify that the destination calendar is not the source calendar
      else if ([[destinationCalendar nameInContainer] isEqualToString: [sourceCalendar nameInContainer]])
	{
	  response = [NSException exceptionWithHTTPStatus: 400
						   reason: @"Destination calendar is the source calendar."];
	}
      else
	{
	  // Remove attendees, recurrence exceptions and single occurences from the event
	  calendar = [thisEvent calendar: NO secure: NO];
	  events = [calendar events];
	  masterOccurence = [events objectAtIndex: 0];
	  
	  if ([masterOccurence hasAlarms])
	    [masterOccurence removeAllAlarms];
	  if ([masterOccurence hasRecurrenceRules])
	    {
	      [masterOccurence removeAllExceptionRules];
	      [masterOccurence removeAllExceptionDates];
	    }
	  if ([[masterOccurence attendees] count] > 0)
	    {
	      [masterOccurence setOrganizer: nil];
	      [masterOccurence removeAllAttendees];
	    }
	  [calendar setUniqueChild: masterOccurence];

	  // Perform the copy
	  if ([thisEvent copyComponent: calendar
			      toFolder: (SOGoGCSFolder *) destinationCalendar])
	    response = [NSException exceptionWithHTTPStatus: 500
						     reason: @"Can't copy event to destination calendar."];
	  else
	    response = [self responseWith204];
	}
    }
  else
    {
      response = [NSException exceptionWithHTTPStatus: 404
					       reason: @"Can't find destination calendar."];
    }
  
  return response;
}

@end
