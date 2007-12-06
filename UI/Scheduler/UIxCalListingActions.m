/* UIxCalListingActions.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse groupe conseil
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSCalendarDate+misc.h>

#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoDateFormatter.h>
#import <SoObjects/SOGo/NSCalendarDate+SOGo.h>
#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/NSObject+Utilities.h>
#import <SoObjects/Appointments/SOGoAppointmentFolder.h>
#import <SoObjects/Appointments/SOGoAppointmentFolders.h>

#import <UI/Common/WODirectAction+SOGo.h>

#import "NSArray+Scheduler.h"

#import "UIxCalListingActions.h"

@implementation UIxCalListingActions

- (id) initWithRequest: (WORequest *) newRequest
{
  SOGoUser *user;

  if ((self = [super initWithRequest: newRequest]))
    {
      componentsData = [NSMutableDictionary new];
      startDate = nil;
      endDate = nil;
      ASSIGN (request, newRequest);
      user = [[self context] activeUser];
      dateFormatter = [user dateFormatterInContext: context];
      ASSIGN (userTimeZone, [user timeZone]);
    }

  return self;
}

- (void) dealloc
{
  [dateFormatter release];
  [request release];
  [componentsData release];
  [startDate release];
  [endDate release];
  [userTimeZone release];
  [super dealloc];
}

- (void) _setupDatesWithPopup: (NSString *) popupValue
		    andUserTZ: (NSTimeZone *) userTZ
{
  NSCalendarDate *newDate;
  NSString *param;

  if ([popupValue isEqualToString: @"view_today"])
    {
      newDate = [NSCalendarDate calendarDate];
      [newDate setTimeZone: userTZ];
      startDate = [newDate beginOfDay];
      endDate = [newDate endOfDay];
    }
  else if ([popupValue isEqualToString: @"view_all"])
    {
      startDate = nil;
      endDate = nil;
    }
  else if ([popupValue isEqualToString: @"view_next7"])
    {
      newDate = [NSCalendarDate calendarDate];
      [newDate setTimeZone: userTZ];
      startDate = [newDate beginOfDay];
      endDate = [[startDate dateByAddingYears: 0 months: 0 days: 6] endOfDay];
    }
  else if ([popupValue isEqualToString: @"view_next14"])
    {
      newDate = [NSCalendarDate calendarDate];
      [newDate setTimeZone: userTZ];
      startDate = [newDate beginOfDay];
      endDate = [[startDate dateByAddingYears: 0 months: 0 days: 13] endOfDay];
    }
  else if ([popupValue isEqualToString: @"view_next31"])
    {
      newDate = [NSCalendarDate calendarDate];
      [newDate setTimeZone: userTZ];
      startDate = [newDate beginOfDay];
      endDate = [[startDate dateByAddingYears: 0 months: 0 days: 30] endOfDay];
    }
  else if ([popupValue isEqualToString: @"view_thismonth"])
    {
      newDate = [NSCalendarDate calendarDate];
      [newDate setTimeZone: userTZ];
      startDate = [[newDate firstDayOfMonth] beginOfDay];
      endDate = [[newDate lastDayOfMonth] endOfDay];
    }
  else if ([popupValue isEqualToString: @"view_future"])
    {
      newDate = [NSCalendarDate calendarDate];
      [newDate setTimeZone: userTZ];
      startDate = [newDate beginOfDay];
      endDate = [NSCalendarDate distantFuture];
    }
  else if ([popupValue isEqualToString: @"view_selectedday"])
    {
      param = [request formValueForKey: @"day"];
      if ([param length] > 0)
	startDate = [[NSCalendarDate dateFromShortDateString: param
				     andShortTimeString: nil
				     inTimeZone: userTZ] beginOfDay];
      else
	{
	  newDate = [NSCalendarDate calendarDate];
	  [newDate setTimeZone: userTZ];
	  startDate = [newDate beginOfDay];
	}
      endDate = [startDate endOfDay];
    }
}

- (void) _setupContext
{
  SOGoUser *user;
  NSTimeZone *userTZ;
  NSString *param;

  user = [context activeUser];
  userLogin = [user login];
  userTZ = [user timeZone];

  param = [request formValueForKey: @"filterpopup"];
  if ([param length] > 0)
    {
      [self _setupDatesWithPopup: param andUserTZ: userTZ];
      title = [request formValueForKey: @"search"];
    }
  else
    {
      param = [request formValueForKey: @"sd"];
      if ([param length] > 0)
	startDate = [[NSCalendarDate dateFromShortDateString: param
				     andShortTimeString: nil
				     inTimeZone: userTZ] beginOfDay];
      else
	startDate = nil;
      
      param = [request formValueForKey: @"ed"];
      if ([param length] > 0)
	endDate = [[NSCalendarDate dateFromShortDateString: param
				   andShortTimeString: nil
				   inTimeZone: userTZ] endOfDay];
      else
	endDate = nil;
    }
}

- (SOGoAppointmentFolder *) _aptFolder: (NSString *) folder
		      withClientObject: (SOGoAppointmentFolder *) clientObject
{
  SOGoAppointmentFolder *aptFolder;
  NSArray *folderParts;

  if ([folder isEqualToString: @"/"])
    aptFolder = clientObject;
  else
    {
      folderParts = [folder componentsSeparatedByString: @":"];
      aptFolder
	= [clientObject lookupCalendarFolderForUID:
			  [folderParts objectAtIndex: 0]];
    }

  return aptFolder;
}

- (void) _fixComponentTitle: (NSMutableDictionary *) component
                   withType: (NSString *) type
{
  NSString *labelKey;

  labelKey = [NSString stringWithFormat: @"%@_class%@",
		       type, [component objectForKey: @"c_classification"]];
  [component setObject: [self labelForKey: labelKey]
	     forKey: @"c_title"];
}

- (NSArray *) _fetchFields: (NSArray *) fields
	forComponentOfType: (NSString *) component
{
  NSEnumerator *folders, *currentInfos;
  SOGoAppointmentFolder *currentFolder;
  NSMutableDictionary *newInfo;
  NSMutableArray *infos;
  NSNull *marker;
  SOGoAppointmentFolders *clientObject;

  marker = [NSNull null];

  clientObject = [self clientObject];

  folders = [[clientObject subFolders] objectEnumerator];
  currentFolder = [folders nextObject];

  infos = [NSMutableArray array];

  while (currentFolder)
    {
      if ([currentFolder isActive])
	{
	  currentInfos
	    = [[currentFolder fetchCoreInfosFrom: startDate
			      to: endDate
			      title: title
			      component: component] objectEnumerator];

	  while ((newInfo = [currentInfos nextObject]))
	    {
	      [newInfo setObject: [currentFolder nameInContainer]
		       forKey: @"c_folder"];
	      if (![[newInfo objectForKey: @"c_title"] length])
		[self _fixComponentTitle: newInfo withType: component];
	      [infos addObject: [newInfo objectsForKeys: fields
					 notFoundMarker: marker]];
	    }
	}
      currentFolder = [folders nextObject];
    }

  return infos;
}

- (WOResponse *) _responseWithData: (NSArray *) data
{
  WOResponse *response;

  response = [self responseWithStatus: 200];
  [response setHeader: @"text/plain; charset=utf-8"
	    forKey: @"content-type"];
  [response appendContentString: [data jsonRepresentation]];

  return response;
}

- (NSString *) _formattedDateForSeconds: (unsigned int) seconds
			      forAllDay: (BOOL) forAllDay
{
  NSCalendarDate *date;
  NSString *formattedDate;

  date = [NSCalendarDate dateWithTimeIntervalSince1970: seconds];
  [date setTimeZone: userTimeZone];
  if (forAllDay)
    formattedDate = [dateFormatter formattedDate: date];
  else
    formattedDate = [dateFormatter formattedDateAndTime: date];

  return formattedDate;    
}

- (NSString *) _adjustedDateForSeconds: (unsigned int) seconds
                             forAllDay: (BOOL) forAllDay
{
  NSCalendarDate *date;
  unsigned int newSeconds, offset;

  date = [NSCalendarDate dateWithTimeIntervalSince1970: seconds];
  [date setTimeZone: userTimeZone];

  offset = [userTimeZone secondsFromGMTForDate: date];
  if (forAllDay)
    newSeconds = seconds + [userTimeZone secondsFromGMT] - offset;
  else
    newSeconds = seconds + offset;

  return [NSString stringWithFormat: @"%u", newSeconds];
}

- (WOResponse *) eventsListAction
{
  NSArray *fields, *oldEvent;
  NSEnumerator *events;
  NSMutableArray *newEvents, *newEvent;
  unsigned int interval;
  BOOL isAllDay;
  NSString *sort, *ascending;

  [self _setupContext];

  newEvents = [NSMutableArray array];
  fields = [NSArray arrayWithObjects: @"c_name", @"c_folder", @"c_status",
		    @"c_title", @"c_startdate", @"c_enddate", @"c_location",
		    @"c_isallday", @"c_classification", nil];
  events = [[self _fetchFields: fields
		  forComponentOfType: @"vevent"] objectEnumerator];
  oldEvent = [events nextObject];
  while (oldEvent)
    {
      newEvent = [NSMutableArray arrayWithArray: oldEvent];
      isAllDay = [[oldEvent objectAtIndex: 7] boolValue];
      interval = [[oldEvent objectAtIndex: 4] intValue];
      [newEvent replaceObjectAtIndex: 4
		withObject: [self _adjustedDateForSeconds: interval
				  forAllDay: isAllDay]];
      [newEvent addObject: [self _formattedDateForSeconds: interval
				 forAllDay: isAllDay]];
      interval = [[oldEvent objectAtIndex: 5] intValue];
      [newEvent replaceObjectAtIndex: 5
		withObject: [self _adjustedDateForSeconds: interval
				  forAllDay: isAllDay]];
      [newEvent addObject: [self _formattedDateForSeconds: interval
				 forAllDay: isAllDay]];
      [newEvents addObject: newEvent];
      
      oldEvent = [events nextObject];
    }
  
  sort = [[context request] formValueForKey: @"sort"];
  if ([sort isEqualToString: @"title"])
    [newEvents sortUsingSelector: @selector (compareEventsTitleAscending:)];
  else if ([sort isEqualToString: @"end"])
    [newEvents sortUsingSelector: @selector (compareEventsEndDateAscending:)];
  else if ([sort isEqualToString: @"location"])
    [newEvents sortUsingSelector: @selector (compareEventsLocationAscending:)];
  else
    [newEvents sortUsingSelector: @selector (compareEventsStartDateAscending:)];
  
  ascending = [[context request] formValueForKey: @"asc"];
  if (![ascending boolValue])
    newEvents = [newEvents reversedArray];

  return [self _responseWithData: newEvents];
}

- (NSString *) _getStatusClassForStatusCode: (int) statusCode
			    andEndDateStamp: (unsigned int) endDateStamp
{
  NSCalendarDate *taskDate, *now;
  NSString *statusClass;

  if (statusCode == 1)
    statusClass = @"completed";
  else
    {
      if (endDateStamp)
        {
          now = [NSCalendarDate calendarDate];
          taskDate
	    = [NSCalendarDate dateWithTimeIntervalSince1970: endDateStamp];
          if ([taskDate earlierDate: now] == taskDate)
            statusClass = @"overdue";
          else
            {
              if ([taskDate isToday])
                statusClass = @"duetoday";
              else
                statusClass = @"duelater";
            }
        }
      else
        statusClass = @"duelater";
    }

  return statusClass;
}

- (WOResponse *) tasksListAction
{
  NSEnumerator *tasks;
  NSMutableArray *filteredTasks, *filteredTask;
  BOOL showCompleted;
  NSArray *fields, *task;
  int statusCode;
  unsigned int endDateStamp;
  NSString *statusFlag;

  filteredTasks = [NSMutableArray array];

  [self _setupContext];

  fields = [NSArray arrayWithObjects: @"c_name", @"c_folder", @"c_status",
		    @"c_title", @"c_enddate", @"c_classification", nil];

  tasks = [[self _fetchFields: fields
		 forComponentOfType: @"vtodo"] objectEnumerator];
  showCompleted = [[request formValueForKey: @"show-completed"] intValue];

  task = [tasks nextObject];
  while (task)
    {
      statusCode = [[task objectAtIndex: 2] intValue];
      if (statusCode != 1 || showCompleted)
	{
	  filteredTask = [NSMutableArray arrayWithArray: task];
	  endDateStamp = [[task objectAtIndex: 4] intValue];
	  statusFlag = [self _getStatusClassForStatusCode: statusCode
			     andEndDateStamp: endDateStamp];
	  [filteredTask addObject: statusFlag];
	  [filteredTasks addObject: filteredTask];
	}
      task = [tasks nextObject];
    }
  [filteredTasks sortUsingSelector: @selector (compareTasksAscending:)];

  return [self _responseWithData: filteredTasks];
}

// - (BOOL) shouldDisplayCurrentTask
// {
//   if (!knowsToShow)
//     {
//       showCompleted
//         = [[self queryParameterForKey: @"show-completed"] intValue];
//       knowsToShow = YES;
//     }

//   return ([[currentTask objectForKey: @"status"] intValue] != 1
// 	   || showCompleted);
// }

// - (BOOL) shouldShowCompletedTasks
// {
//   if (!knowsToShow)
//     {
//       showCompleted
//         = [[self queryParameterForKey: @"show-completed"] intValue];
//       knowsToShow = YES;
//     }

//   return showCompleted;
// }

@end
