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

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSCalendarDate+misc.h>

#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/NSCalendarDate+SOGo.h>
#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/NSObject+Utilities.h>
#import <SoObjects/Appointments/SOGoAppointmentFolder.h>

#import "../SOGoUI/SOGoDateFormatter.h"

#import "UIxCalListingActions.h"

@implementation UIxCalListingActions

- (id) init
{
  NSDictionary *locale;

  if ((self = [super init]))
    {
      componentsData = [NSMutableDictionary new];
      startDate = nil;
      endDate = nil;
      request = nil;
      locale = [[self context] valueForKey: @"locale"];
      dateFormatter = [[SOGoDateFormatter alloc] initWithLocale: locale];
      [dateFormatter setFullWeekdayNameAndDetails];
  }

  return self;
}

- (void) dealloc
{
  [dateFormatter release];
  [componentsData release];
  [startDate release];
  [endDate release];
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

  request = [context request];
  param = [request formValueForKey: @"filterpopup"];
  if ([param length] > 0)
    [self _setupDatesWithPopup: param andUserTZ: userTZ];
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

- (void) _updatePrivacyInComponent: (NSMutableDictionary *) component
			fromFolder: (SOGoAppointmentFolder *) folder
{
  int privacyFlag;
  NSString *roleString;

  privacyFlag = [[component objectForKey: @"classification"] intValue];
  roleString = [folder roleForComponentsWithAccessClass: privacyFlag
		       forUser: userLogin];
  if ([roleString isEqualToString: @"ComponentDAndTViewer"])
    {
      [component setObject: @"" forKey: @"title"];
      [component setObject: @"" forKey: @"location"];
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

- (NSArray *) _activeCalendarFolders
{
  NSMutableArray *activeFolders;
  NSEnumerator *folders;
  NSDictionary *currentFolderDict;
  SOGoAppointmentFolder *currentFolder, *clientObject;

  activeFolders = [NSMutableArray new];
  [activeFolders autorelease];

  clientObject = [self clientObject];

  folders = [[clientObject calendarFolders] objectEnumerator];
  currentFolderDict = [folders nextObject];
  while (currentFolderDict)
    {
      if ([[currentFolderDict objectForKey: @"active"] boolValue])
	{
	  currentFolder
	    = [self _aptFolder: [currentFolderDict objectForKey: @"folder"]
		    withClientObject: clientObject];
	  [activeFolders addObject: currentFolder];
	}

      currentFolderDict = [folders nextObject];
    }

  return activeFolders;
}

- (NSArray *) _fetchFields: (NSArray *) fields
	forComponentOfType: (NSString *) component
{
  NSEnumerator *folders, *currentInfos;
  SOGoAppointmentFolder *currentFolder;
  NSMutableDictionary *infos, *currentInfo, *newInfo;
  NSString *owner, *uid;
  NSNull *marker;

  marker = [NSNull null];

  infos = [NSMutableDictionary dictionary];
  folders = [[self _activeCalendarFolders] objectEnumerator];
  currentFolder = [folders nextObject];
  while (currentFolder)
    {
      owner = [currentFolder ownerInContext: context];
      currentInfos = [[currentFolder fetchCoreInfosFrom: startDate
				     to: endDate
				     component: component] objectEnumerator];
      newInfo = [currentInfos nextObject];
      while (newInfo)
	{
	  uid = [newInfo objectForKey: @"uid"];
	  currentInfo = [infos objectForKey: uid];
	  if (!currentInfo
	      || [owner isEqualToString: userLogin])
	    {
	      [self _updatePrivacyInComponent: newInfo
		    fromFolder: currentFolder];
	      [newInfo setObject: owner forKey: @"owner"];
	      [infos setObject: [newInfo objectsForKeys: fields
					 notFoundMarker: marker]
		     forKey: uid];
	    }
	  newInfo = [currentInfos nextObject];
	}
      currentFolder = [folders nextObject];
    }

  return [infos allValues];
}

- (WOResponse *) _responseWithData: (NSArray *) data
{
  WOResponse *response;

  response = [context response];
  [response setHeader: @"text/plain; charset=utf-8"
	    forKey: @"content-type"];
  [response setStatus: 200];
  [response appendContentString: [data jsonRepresentation]];

  return response;
}

- (WOResponse *) eventsListAction
{
  NSArray *fields, *oldEvent;
  NSEnumerator *events;
  NSString *date;
  NSMutableArray *newEvents, *newEvent;
  unsigned int interval;

  [self _setupContext];

  newEvents = [NSMutableArray array];
  fields = [NSArray arrayWithObjects: @"c_name", @"owner", @"status",
		    @"title", @"startdate", @"enddate", @"location",
		    @"isallday", nil];
  events = [[self _fetchFields: fields
		  forComponentOfType: @"vevent"] objectEnumerator];
  oldEvent = [events nextObject];
  while (oldEvent)
    {
      newEvent = [NSMutableArray arrayWithArray: oldEvent];
      interval = [[oldEvent objectAtIndex: 4] intValue];
      date
	= [dateFormatter stringForObjectValue:
			   [NSCalendarDate dateWithTimeIntervalSince1970: interval]];
      [newEvent addObject: date];
      interval = [[oldEvent objectAtIndex: 5] intValue];
      if ([[oldEvent objectAtIndex: 7] boolValue])
	interval -= 86400;
      date
	= [dateFormatter stringForObjectValue:
			   [NSCalendarDate dateWithTimeIntervalSince1970: interval]];
      [newEvent addObject: date];
      [newEvents addObject: newEvent];

      oldEvent = [events nextObject];
    }

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

  fields = [NSArray arrayWithObjects: @"c_name", @"owner", @"status",
		    @"title", @"enddate", nil];

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
