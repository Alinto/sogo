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
#import <NGCards/iCalPerson.h>

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

static NSArray *eventsFields = nil;
static NSArray *tasksFields = nil;

#define dayLength 86400
#define quarterLength 900

@implementation UIxCalListingActions

+ (void) initialize
{
  if (!eventsFields)
    {
      eventsFields = [NSArray arrayWithObjects: @"c_name", @"c_folder",
			      @"c_status", @"c_title", @"c_startdate",
			      @"c_enddate", @"c_location", @"c_isallday",
			      @"c_classification", @"c_partmails",
			      @"c_partstates", @"c_owner", @"c_iscycle", nil];
      [eventsFields retain];
    }
  if (!tasksFields)
    {
      tasksFields = [NSArray arrayWithObjects: @"c_name", @"c_folder",
			     @"c_status", @"c_title", @"c_enddate",
			     @"c_classification", nil];
      [tasksFields retain];
    }
}

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
      dayBasedView = NO;
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
  if ([param length])
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

      param = [request formValueForKey: @"view"];
      dayBasedView = ![param isEqualToString: @"monthview"];
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
	      [newInfo setObject: [currentFolder ownerInContext: context]
		       forKey: @"c_owner"];
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

- (WOResponse *) eventsListAction
{
  NSArray *oldEvent, *participants, *states;
  NSEnumerator *events;
  NSMutableArray *newEvents, *newEvent;
  unsigned int interval, i;
  BOOL isAllDay;
  NSString *sort, *ascending, *participant, *state;
  SOGoUser *user;

  [self _setupContext];

  newEvents = [NSMutableArray array];
  events = [[self _fetchFields: eventsFields
		  forComponentOfType: @"vevent"] objectEnumerator];
  while ((oldEvent = [events nextObject]))
    {
      newEvent = [NSMutableArray arrayWithArray: oldEvent];
      isAllDay = [[oldEvent objectAtIndex: 7] boolValue];
      interval = [[oldEvent objectAtIndex: 4] intValue];
      [newEvent addObject: [self _formattedDateForSeconds: interval
				 forAllDay: isAllDay]];
      interval = [[oldEvent objectAtIndex: 5] intValue];
      [newEvent addObject: [self _formattedDateForSeconds: interval
				 forAllDay: isAllDay]];

      participants = nil;
      state = nil;
      if ([[oldEvent objectAtIndex: 9] length] > 0 &&
	  [[oldEvent objectAtIndex: 10] length] > 0)
	{
	  participants = [[oldEvent objectAtIndex: 9] componentsSeparatedByString: @"\n"];
	  states = [[oldEvent objectAtIndex: 10] componentsSeparatedByString: @"\n"];
	  for (i = 0; i < [participants count]; i++)
	    {
	      user = [SOGoUser userWithLogin: [oldEvent objectAtIndex: 11] roles: nil];
	      participant = [participants objectAtIndex: i];
	      if ([user hasEmail: participant]) {
		switch ([[states objectAtIndex: i] intValue]) {
		case iCalPersonPartStatNeedsAction:
		state = @"needs-action";
		break;
		case iCalPersonPartStatAccepted:
		  state = @"accepted";
		  break;
		case iCalPersonPartStatDeclined:
		  state = @"declined";
		  break;
		}
		[newEvent replaceObjectAtIndex: 9 withObject: state];
		break;
	      }
	    }
	}
      if (participants == nil || i == [participants count])
	[newEvent replaceObjectAtIndex: 9 withObject: @""];
      [newEvent removeObjectAtIndex: 11];
      [newEvent removeObjectAtIndex: 10];

      [newEvents addObject: newEvent];
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
    [newEvents reverseArray];

  return [self _responseWithData: newEvents];
}

static inline void
_feedBlockWithDayBasedData(NSMutableDictionary *block, unsigned int start,
			   unsigned int end, unsigned int dayStart)
{
  unsigned int delta, quarterStart, length;

  quarterStart = (start - dayStart) / quarterLength;
  delta = end - dayStart;
  if ((delta % quarterLength))
    delta += quarterLength;
  length = (delta / quarterLength) - quarterStart;
  if (!length)
    length = 1;
  [block setObject: [NSNumber numberWithUnsignedInt: quarterStart]
	 forKey: @"start"];
  [block setObject: [NSNumber numberWithUnsignedInt: length]
	 forKey: @"length"];
}

static inline void
_feedBlockWithMonthBasedData(NSMutableDictionary *block, unsigned int start,
			     NSTimeZone *userTimeZone,
			     SOGoDateFormatter *dateFormatter)
{
  NSCalendarDate *eventStartDate;
  NSString *startHour;

  eventStartDate = [NSCalendarDate dateWithTimeIntervalSince1970: start];
  [eventStartDate setTimeZone: userTimeZone];
  startHour = [dateFormatter formattedTime: eventStartDate];
  [block setObject: startHour forKey: @"starthour"];
  [block setObject: [NSNumber numberWithUnsignedInt: start]
	 forKey: @"start"];
}

- (NSMutableDictionary *) _eventBlockWithStart: (unsigned int) start
					   end: (unsigned int) end
					 cname: (NSString *) cName
					 onDay: (unsigned int) dayStart
				    recurrence: (BOOL) recurrence
{
  NSMutableDictionary *block;

  block = [NSMutableDictionary dictionary];

  if (dayBasedView)
    _feedBlockWithDayBasedData (block, start, end, dayStart);
  else
    _feedBlockWithMonthBasedData (block, start, userTimeZone, dateFormatter);
  [block setObject: cName forKey: @"cname"];
  if (recurrence)
    [block setObject: @"1" forKey: @"recurrence"];

  return block;
}

- (void) _fillBlocks: (NSArray *) blocks
	   withEvent: (NSArray *) event
{
  unsigned int currentDayStart, startSecs, endsSecs, currentStart, eventStart,
    eventEnd, offset;
  NSMutableArray *currentDay;
  NSMutableDictionary *eventBlock;
  NSString *eventCName;
  BOOL recurrence;

  startSecs = (unsigned int) [startDate timeIntervalSince1970];
  endsSecs = (unsigned int) [endDate timeIntervalSince1970];
  eventStart = [[event objectAtIndex: 4] unsignedIntValue];
  eventEnd = [[event objectAtIndex: 5] unsignedIntValue];

  recurrence = [[event objectAtIndex: 12] boolValue];

  currentStart = eventStart;
  if (currentStart < startSecs)
    {
      currentStart = startSecs;
      offset = 0;
    }
  else
    offset = ((currentStart - startSecs)
	      / dayLength);
  currentDay = [blocks objectAtIndex: offset];
  currentDayStart = startSecs + dayLength * offset;

  if (eventEnd > endsSecs)
    eventEnd = endsSecs;

  eventCName = [event objectAtIndex: 0];
  while (currentStart + dayLength < eventEnd)
    {
      eventBlock = [self _eventBlockWithStart: currentStart
			 end: currentDayStart + 86399
			 cname: eventCName
			 onDay: currentDayStart
			 recurrence: recurrence];
      [currentDay addObject: eventBlock];
      currentDayStart += dayLength;
      currentStart = currentDayStart;
      offset++;
      currentDay = [blocks objectAtIndex: offset];
    }
  eventBlock = [self _eventBlockWithStart: currentStart
		     end: eventEnd
		     cname: eventCName
		     onDay: currentDayStart
		     recurrence: recurrence];
  [currentDay addObject: eventBlock];
}

- (void) _prepareEventBlocks: (NSMutableArray **) blocks
		 withAllDays: (NSMutableArray **) allDayBlocks
{
  unsigned int count, nbrDays;
  int seconds;

  seconds = [endDate timeIntervalSinceDate: startDate];
  if (seconds > 0)
    {
      nbrDays = 1 + (unsigned int) (seconds / dayLength);
      *blocks = [NSMutableArray arrayWithCapacity: nbrDays];
      *allDayBlocks = [NSMutableArray arrayWithCapacity: nbrDays];
      for (count = 0; count < nbrDays; count++)
	{
	  [*blocks addObject: [NSMutableArray array]];
	  [*allDayBlocks addObject: [NSMutableArray array]];
	}
    }
  else
    {
      *blocks = nil;
      *allDayBlocks = nil;
    }
}

- (NSArray *) _horizontalBlocks: (NSMutableArray *) day
{
  NSMutableArray *quarters[96];
  NSMutableArray *currentBlock, *blocks;
  NSDictionary *currentEvent;
  unsigned int count, max, qCount, qMax, qOffset;

  blocks = [NSMutableArray array];

  bzero (quarters, 96 * sizeof (NSMutableArray *));

  max = [day count];
  for (count = 0; count < max; count++)
    {
      currentEvent = [day objectAtIndex: count];
      qMax = [[currentEvent objectForKey: @"length"] unsignedIntValue];
      qOffset = [[currentEvent objectForKey: @"start"] unsignedIntValue];
      for (qCount = 0; qCount < qMax; qCount++)
	{
	  currentBlock = quarters[qCount + qOffset];
	  if (!currentBlock)
	    {
	      currentBlock = [NSMutableArray array];
	      quarters[qCount + qOffset] = currentBlock;
	      [blocks addObject: currentBlock];
	    }
	  [currentBlock addObject: currentEvent];
	}
    }

  return blocks;
}

static inline unsigned int
_computeMaxBlockSiblings (NSArray *block)
{
  unsigned int count, max, maxSiblings, siblings;
  NSNumber *nbrEvents;

  max = [block count];
  maxSiblings = max;
  for (count = 0; count < max; count++)
    {
      nbrEvents = [[block objectAtIndex: count] objectForKey: @"siblings"];
      if (nbrEvents)
	{
	  siblings = [nbrEvents unsignedIntValue];
	  if (siblings > maxSiblings)
	    maxSiblings = siblings;
	}
    }

  return maxSiblings;
}

static inline void
_propagateBlockSiblings (NSArray *block, NSNumber *maxSiblings)
{
  unsigned int count, max;
  NSMutableDictionary *event;
  NSNumber *realSiblings;

  max = [block count];
  realSiblings = [NSNumber numberWithUnsignedInt: max];
  for (count = 0; count < max; count++)
    {
      event = [block objectAtIndex: count];
      [event setObject: maxSiblings forKey: @"siblings"];
      [event setObject: realSiblings forKey: @"realSiblings"];
    }
}

/* this requires two vertical passes */
static inline void
_computeBlocksSiblings (NSArray *blocks)
{
  NSArray *currentBlock;
  unsigned int count, max, maxSiblings;

  max = [blocks count];
  for (count = 0; count < max; count++)
    {
      currentBlock = [blocks objectAtIndex: count];
      maxSiblings = _computeMaxBlockSiblings (currentBlock);
      _propagateBlockSiblings (currentBlock,
			       [NSNumber numberWithUnsignedInt: maxSiblings]);
    }
}

static inline void
_computeBlockPosition (NSArray *block)
{
  unsigned int count, max, j, siblings;
  NSNumber *position;
  NSMutableDictionary *event;
  NSMutableDictionary **positions;

  max = [block count];
  event = [block objectAtIndex: 0];
  siblings = [[event objectForKey: @"siblings"] unsignedIntValue];
  positions = calloc (siblings, sizeof (NSMutableDictionary *));

  for (count = 0; count < max; count++)
    {
      event = [block objectAtIndex: count];
      position = [event objectForKey: @"position"];
      if (position)
	*(positions + [position unsignedIntValue]) = event;
      else
	{
	  j = 0;
	  while (j < max && *(positions + j))
	    j++;
	  *(positions + j) = event;
	  [event setObject: [NSNumber numberWithUnsignedInt: j]
		 forKey: @"position"];
	}
    }

  free (positions);
}

// static inline void
// _addBlockMultipliers (NSArray *block, NSMutableDictionary **positions)
// {
//   unsigned int count, max, limit, multiplier;
//   NSMutableDictionary *currentEvent, *event;

//   max = [block count];
//   event = [block objectAtIndex: 0];
//   limit = [[event objectForKey: @"siblings"] unsignedIntValue];

//   if (max < limit)
//     {
//       currentEvent = nil;
//       for (count = 0; count < limit; count++)
// 	{
// 	  multiplier = 1;
// 	  event = positions[count];
// 	  if ([[event objectForKey: @"realSiblings"] unsignedIntValue]
// 	      < limit)
// 	    {
// 	      if (event)
// 		{
// 		  if (currentEvent && multiplier > 1)
// 		    [currentEvent setObject: [NSNumber numberWithUnsignedInt: multiplier]
// 				  forKey: @"multiplier"];
// 		  currentEvent = event;
// 		  multiplier = 1;
// 		}
// 	      else
// 		multiplier++;
// 	    }
// 	}
//     }
// }

static inline void
_computeBlocksPosition (NSArray *blocks)
{
  NSArray *block;
  unsigned int count, max;
//   NSMutableDictionary **positions;

  max = [blocks count];
  for (count = 0; count < max; count++)
    {
      block = [blocks objectAtIndex: count];
      _computeBlockPosition (block);
//       _addBlockMultipliers (block, positions);
//       free (positions);
    }
}

- (void) _addBlocksWidth: (NSMutableArray *) day
{
  NSArray *blocks;

  blocks = [self _horizontalBlocks: day];
  _computeBlocksSiblings (blocks);
  _computeBlocksSiblings (blocks);
  _computeBlocksPosition (blocks);
  /* ... _computeBlocksMultiplier() ... */
}

- (WOResponse *) eventsBlocksAction
{
  int count, max;
  NSArray *events, *event, *eventsBlocks;
  NSMutableArray *allDayBlocks, *blocks, *currentDay;

  [self _setupContext];

  [self _prepareEventBlocks: &blocks withAllDays: &allDayBlocks];
  events = [self _fetchFields: eventsFields
		 forComponentOfType: @"vevent"];
  eventsBlocks
    = [NSArray arrayWithObjects: events, allDayBlocks, blocks, nil];
  max = [events count];
  for (count = 0; count < max; count++)
    {
      event = [events objectAtIndex: count];
      if (dayBasedView && [[event objectAtIndex: 7] boolValue])
	[self _fillBlocks: allDayBlocks withEvent: event];
      else
	[self _fillBlocks: blocks withEvent: event];
    }

  max = [blocks count];
  for (count = 0; count < max; count++)
    {
      currentDay = [blocks objectAtIndex: count];
      [currentDay sortUsingSelector: @selector (compareEventByStart:)];
      [self _addBlocksWidth: currentDay];
    }

  return [self _responseWithData: eventsBlocks];
//   timeIntervalSinceDate:
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
  NSArray *task;
  int statusCode;
  unsigned int endDateStamp;
  NSString *statusFlag;

  filteredTasks = [NSMutableArray array];

  [self _setupContext];

  tasks = [[self _fetchFields: tasksFields
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
