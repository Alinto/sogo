/* UIxCalListingActions.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2009 Inverse inc.
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
#import <NGExtensions/NGCalendarDateRange.h>

#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoDateFormatter.h>
#import <SoObjects/SOGo/NSCalendarDate+SOGo.h>
#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/NSObject+Utilities.h>
#import <SoObjects/Appointments/SOGoAppointmentFolder.h>
#import <SoObjects/Appointments/SOGoAppointmentFolders.h>
#import <SoObjects/Appointments/SOGoAppointmentObject.h>
#import <Appointments/SOGoFreeBusyObject.h>

#import <UI/Common/WODirectAction+SOGo.h>

#import "NSArray+Scheduler.h"

#import "UIxCalListingActions.h"

static NSArray *eventsFields = nil;
static NSArray *tasksFields = nil;

#define dayLength 86400
#define quarterLength 900

#define intervalSeconds 900
#define offsetHours     24 * 5
#define offsetSeconds   offsetHours * 60 * 60
#define offsetBlocks    offsetHours * 4
#define maxBlocks       offsetBlocks * 2

@implementation UIxCalListingActions

+ (void) initialize
{
  if (!eventsFields)
    {
      eventsFields = [NSArray arrayWithObjects: @"c_name", @"c_folder",
			      @"c_status", @"c_title", @"c_startdate",
			      @"c_enddate", @"c_location", @"c_isallday",
			      @"c_classification", @"c_partmails",
			      @"c_partstates", @"c_owner", @"c_iscycle", @"c_nextalarm",
			      @"c_recurrence_id", nil];
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
      ASSIGN (dateFormatter, [user dateFormatterInContext: context]);
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
      endDate = nil;
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

- (void) _fixDates: (NSMutableDictionary *) aRecord
{
  NSCalendarDate *aDate, *aStartDate;
  NSNumber *aDateValue;
  NSString *aDateField;
  signed int daylightOffset;
  unsigned int count;
  static NSString *fields[] = { @"startDate", @"c_startdate",
				@"endDate", @"c_enddate" };
  
  for (count = 0; count < 2; count++)
    {
      aDateField = fields[count * 2];
      aDate = [aRecord objectForKey: aDateField];
      if ([userTimeZone isDaylightSavingTimeForDate: aDate] != 
	  [userTimeZone isDaylightSavingTimeForDate: startDate])
	{
	  daylightOffset = (signed int)[userTimeZone secondsFromGMTForDate: aDate]
	    - (signed int)[userTimeZone secondsFromGMTForDate: startDate];
	  aDate = [aDate dateByAddingYears:0 months:0 days:0 hours:0 minutes:0 seconds:daylightOffset];
	  [aRecord setObject: aDate forKey: aDateField];	  
	  aDateValue = [NSNumber numberWithInt: [aDate timeIntervalSince1970]];
	  [aRecord setObject: aDateValue forKey: fields[count * 2 + 1]];
	}
    }
  
  aDateValue = [aRecord objectForKey: @"c_recurrence_id"];
  aDate = [aRecord objectForKey: @"cycleStartDate"];
  aStartDate = [aRecord objectForKey: @"startDate"];
  if (aDateValue && aDate)
    {
      if ([userTimeZone isDaylightSavingTimeForDate: aStartDate] != 
	  [userTimeZone isDaylightSavingTimeForDate: aDate])
	{
	  // For the event's recurrence id, compute the daylight saving time
	  // offset with respect to the first occurrence of the recurring event.
	  daylightOffset = (signed int)[userTimeZone secondsFromGMTForDate: aStartDate]
	    - (signed int)[userTimeZone secondsFromGMTForDate: aDate];
	  aDateValue = [NSNumber numberWithInt: [aDateValue intValue] + daylightOffset];
	  [aRecord setObject: aDateValue forKey: @"c_recurrence_id"];
	}
    }
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

  infos = [NSMutableArray array];

  marker = [NSNull null];

  clientObject = [self clientObject];

  folders = [[clientObject subFolders] objectEnumerator];
  while ((currentFolder = [folders nextObject]))
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
	      // Possible improvement: only call _fixDates if event is recurrent
	      // or the view range span a daylight saving time change
	      [self _fixDates: newInfo];
	      [infos addObject: [newInfo objectsForKeys: fields
					 notFoundMarker: marker]];
	    }
	}
    }

  return infos;
}

- (WOResponse *) _responseWithData: (NSArray *) data
{
  WOResponse *response;

  response = [self responseWithStatus: 200];
  [response appendContentString: [data jsonRepresentation]];

  return response;
}

- (NSString *) _formattedDateForSeconds: (unsigned int) seconds
			      forAllDay: (BOOL) forAllDay
{
  NSCalendarDate *date;
  NSString *formattedDate;

  date = [NSCalendarDate dateWithTimeIntervalSince1970: seconds];
  // Adjust for daylight saving time? (wrt to startDate)
  [date setTimeZone: userTimeZone];
  if (forAllDay)
    formattedDate = [dateFormatter formattedDate: date];
  else
    formattedDate = [dateFormatter formattedDateAndTime: date];

  return formattedDate;    
}

//
// We return:
// 
// [[calendar name (full path), complete Event ID (full path), Fire date (UTC)], ..]
//
// Called when each module is loaded or whenever a calendar component is created, modified, deleted
// or whenever there's a {un}subscribe to a calendar.
//
// Workflow :
//
// - for ALL subscribed and ACTIVE calendars
//  - returns alarms that will occur in the next 48 hours or the non-triggered alarms
//    for non-completed events
//  - recurring events are currently ignored
//
- (WOResponse *) alarmsListAction
{
  SOGoAppointmentFolder *currentFolder;
  SOGoAppointmentFolders *clientObject;
  NSMutableArray *allAlarms;
  NSEnumerator *folders;
  WOResponse *response;
  unsigned int browserTime, laterTime;

  // We look for alarms in the next 48 hours
  browserTime = [[[context request] formValueForKey: @"browserTime"] intValue];
  laterTime = browserTime + 60*60*48;
  clientObject = [self clientObject];
  allAlarms = [NSMutableArray array];

  folders = [[clientObject subFolders] objectEnumerator];
  while ((currentFolder = [folders nextObject]))
    {
      if ([currentFolder isActive])
	{
	  NSDictionary *entry;
	  NSArray *alarms;
	  BOOL isCycle;
	  int i;

	  alarms = [currentFolder fetchAlarmInfosFrom: [NSNumber numberWithInt: browserTime]
				  to: [NSNumber numberWithInt: laterTime]];
	  
	  for (i = 0; i < [alarms count]; i++)
	    {
	      entry = [alarms objectAtIndex: i];
	      isCycle = [[entry objectForKey: @"c_iscycle"] boolValue];
	      
	      if (!isCycle)
		{
		  [allAlarms addObject: [NSArray arrayWithObjects:
						 [currentFolder nameInContainer],
						 [entry objectForKey: @"c_name"],
						 [entry objectForKey: @"c_nextalarm"],
						 nil]];
		}
	    }
	}
    }
  
  
  response = [self responseWithStatus: 200];
  [response appendContentString: [allAlarms jsonRepresentation]];
  
  return response;
}

- (WOResponse *) eventsListAction
{
  NSArray *oldEvent;
  NSEnumerator *events;
  NSMutableArray *newEvents, *newEvent;
  unsigned int interval;
  BOOL isAllDay;
  NSString *sort, *ascending;

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
  unsigned int delta, quarterStart, length, swap;
  
  if (start > end)
    {
      swap = end;
      end = start;
      start = swap;
    }
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
					number: (NSNumber *) number
					 onDay: (unsigned int) dayStart
				recurrenceTime: (unsigned int) recurrenceTime
				     userState: (iCalPersonPartStat) userState
{
  NSMutableDictionary *block;

  block = [NSMutableDictionary dictionary];

  if (dayBasedView)
    _feedBlockWithDayBasedData (block, start, end, dayStart);
  else
    _feedBlockWithMonthBasedData (block, start, userTimeZone, dateFormatter);
  [block setObject: number forKey: @"nbr"];
  if (recurrenceTime)
    [block setObject: [NSNumber numberWithInt: recurrenceTime]
	   forKey: @"recurrenceTime"];
  if (userState != iCalPersonPartStatOther)
    [block setObject: [NSNumber numberWithInt: userState]
	   forKey: @"userState"];

  return block;
}

static inline iCalPersonPartStat
_userStateInEvent (NSArray *event)
{
  unsigned int count, max;
  iCalPersonPartStat state;
  NSString *partList, *stateList;
  NSArray *participants, *states;
  SOGoUser *user;

  participants = nil;
  state = iCalPersonPartStatOther;

  partList = [event objectAtIndex: 9];
  stateList = [event objectAtIndex: 10];
  if ([partList length] && [stateList length])
    {
      participants = [partList componentsSeparatedByString: @"\n"];
      states = [stateList componentsSeparatedByString: @"\n"];
      count = 0;
      max = [participants count];
      while (state == iCalPersonPartStatOther && count < max)
	{
	  user = [SOGoUser userWithLogin: [event objectAtIndex: 11]
			   roles: nil];
	  if ([user hasEmail: [participants objectAtIndex: count]])
	    state = [[states objectAtIndex: count] intValue];
	  else
	    count++;
	}
    }

  return state;
}

- (void) _fillBlocks: (NSArray *) blocks
	   withEvent: (NSArray *) event
	  withNumber: (NSNumber *) number
{
  unsigned int currentDayStart, startSecs, endsSecs, currentStart, eventStart,
    eventEnd, offset, recurrenceTime;
  NSMutableArray *currentDay;
  NSMutableDictionary *eventBlock;
  iCalPersonPartStat userState;

  startSecs = (unsigned int) [startDate timeIntervalSince1970];
  endsSecs = (unsigned int) [endDate timeIntervalSince1970];
  eventStart = [[event objectAtIndex: 4] unsignedIntValue];
  eventEnd = [[event objectAtIndex: 5] unsignedIntValue];

  if ([[event objectAtIndex: 12] boolValue]) // c_iscycle
    recurrenceTime = [[event objectAtIndex: 14] unsignedIntValue]; // c_recurrence_id
  else
    recurrenceTime = 0;

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

  userState = _userStateInEvent (event);
  while (currentDayStart + dayLength < eventEnd)
    {
      eventBlock = [self _eventBlockWithStart: currentStart
			 end: currentDayStart + dayLength - 1
			 number: number
			 onDay: currentDayStart
			 recurrenceTime: recurrenceTime
			 userState: userState];
      [currentDay addObject: eventBlock];
      currentDayStart += dayLength;
      currentStart = currentDayStart;
      offset++;
      currentDay = [blocks objectAtIndex: offset];
    }
  eventBlock = [self _eventBlockWithStart: currentStart
		     end: eventEnd
		     number: number
		     onDay: currentDayStart
		     recurrenceTime: recurrenceTime
		     userState: userState];
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
  positions = NSZoneCalloc (NULL, siblings, sizeof (NSMutableDictionary *));

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

  NSZoneFree (NULL, positions);
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
//       NSZoneFree (NULL, positions);
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
  NSNumber *eventNbr;

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
      eventNbr = [NSNumber numberWithUnsignedInt: count];
      if (dayBasedView && [[event objectAtIndex: 7] boolValue])
	[self _fillBlocks: allDayBlocks withEvent: event withNumber: eventNbr];
      else
	[self _fillBlocks: blocks withEvent: event withNumber: eventNbr];
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


- (void) _fillFreeBusy: (unsigned int *) fb
                forUid: (NSString *) uid
              fromDate: (NSCalendarDate *) start
{
  SOGoUser *user;
  SOGoFreeBusyObject *fbObject;
  NSCalendarDate *end;
  NSTimeInterval interval;
  NSArray *records;
  NSDictionary *record;
  NSArray *emails, *partstates;
  NSCalendarDate *currentDate;
  unsigned int intervals, recordCount, recordMax;
  int count, startInterval, endInterval, i, type;
  int itemCount = (offsetBlocks + maxBlocks) * 15 * 60;

  user = [SOGoUser userWithLogin: uid roles: nil];
  fbObject = [[user homeFolderInContext: context] 
              freeBusyObject: @"freebusy.ifb" 
              inContext: context];

  end = [start addTimeInterval: itemCount];

  interval = [end timeIntervalSinceDate: start];// + 60;
  intervals = interval / intervalSeconds; /* slices of 15 minutes */

  records = [fbObject fetchFreeBusyInfosFrom: start to: end];
  recordMax = [records count];

  for (recordCount = 0; recordCount < recordMax; recordCount++)
    {
      record = [records objectAtIndex: recordCount];
      if ([[record objectForKey: @"c_isopaque"] boolValue])
        {
          type = 0;

          // If the event has NO organizer (which means it's the user that has created it) OR
          // If we are the organizer of the event THEN we are automatically busy
          if ([[record objectForKey: @"c_orgmail"] length] == 0 ||
              [user hasEmail: [record objectForKey: @"c_orgmail"]])
            {
              type = 1;
            }
          else
            {
              // We check if the user has accepted/declined or needs action
              // on the current event.
              emails = [[record objectForKey: @"c_partmails"] componentsSeparatedByString: @"\n"];

              for (i = 0; i < [emails count]; i++)
                {
                  if ([user hasEmail: [emails objectAtIndex: i]])
                    {
                      // We now fetch the c_partstates array and get the participation
                      // status of the user for the event
                      partstates = [[record objectForKey: @"c_partstates"] componentsSeparatedByString: @"\n"];

                      if (i < [partstates count])
                        {
                          type = ([[partstates objectAtIndex: i] intValue] < 2 ? 1 : 0);
                        }
                      break;
                    }
                }
            }

          currentDate = [record objectForKey: @"startDate"];
          if ([currentDate earlierDate: start] == currentDate)
            startInterval = 0;
          else
            startInterval = ([currentDate timeIntervalSinceDate: start]
                             / intervalSeconds);

          currentDate = [record objectForKey: @"endDate"];
          if ([currentDate earlierDate: end] == end)
            endInterval = itemCount - 1;
          else
            endInterval = ([currentDate timeIntervalSinceDate: start]
                           / intervalSeconds);

          if (type == 1)
            for (count = startInterval; count < endInterval; count++)
              *(fb + count) = 1;
        }
    }

}

- (unsigned int **) _loadFreeBusyForUsers: (NSArray *) uids 
                      fromDate: (NSCalendarDate *) start
{
  unsigned int **fbData, **node, count;

  fbData = calloc ([uids count], sizeof (unsigned int *));
  for (count = 0; count < [uids count]; count++)
    {
      fbData[count] = calloc (offsetBlocks + maxBlocks, sizeof (unsigned int *));
      node = fbData + count;
      [self _fillFreeBusy: *node
                   forUid: [uids objectAtIndex: count]
                 fromDate: start];
    }

  return fbData;
}

- (BOOL) _possibleBlock: (int) block
               forUsers: (int) users
               freeBusy: (unsigned int **) fbData
               interval: (int) blocks
{
  unsigned int *node;
  int bCount, uCount;
  BOOL rc = YES;

  for (uCount = 0; uCount < users; uCount++)
    {
      node = *(fbData + uCount);
      for (bCount = block; bCount < block + blocks; bCount++)
        {
          if (*(node+bCount) != 0)
            {
              rc = NO;
              break;
            }
        }
    }

  return rc;
}

- (NSCalendarDate *) _parseDateField: (NSString *) dateF
                           timeField: (NSString *) timeF
{
  NSString *buffer;
  NSCalendarDate *rc;

  buffer = [NSString stringWithFormat: @"%@ %@", 
                [[context request] formValueForKey: dateF],
                [[context request] formValueForKey: timeF]];
  rc = [NSCalendarDate dateWithString: buffer
                       calendarFormat: @"%Y%m%d %H:%M"];

  return rc;
}

- (NSMutableDictionary *) _makeValidResponseFrom: (NSCalendarDate *) nStart 
                                              to: (NSCalendarDate *) nEnd
{
  NSMutableDictionary *rc;

  rc = [NSMutableDictionary dictionaryWithCapacity: 512];
  [rc setObject: [nStart descriptionWithCalendarFormat: @"%Y%m%d"]
         forKey: @"startDate"];
  [rc setObject: [nStart descriptionWithCalendarFormat: @"%H"]
         forKey: @"startHour"];
  [rc setObject: [nStart descriptionWithCalendarFormat: @"%M"]
         forKey: @"startMinute"];

  [rc setObject: [nEnd descriptionWithCalendarFormat: @"%Y%m%d"]
         forKey: @"endDate"];
  [rc setObject: [nEnd descriptionWithCalendarFormat: @"%H"]
         forKey: @"endHour"];
  [rc setObject: [nEnd descriptionWithCalendarFormat: @"%M"]
         forKey: @"endMinute"];

  return rc;
}

- (BOOL) _validateStart: (NSCalendarDate *) start 
                 andEnd: (NSCalendarDate *) end 
                against: (NSArray *) limits
{
  NSCalendarDate *sFrom, *sTo, *eFrom, *eTo;
  BOOL rc = YES;

  sFrom = [NSCalendarDate dateWithYear: [start yearOfCommonEra]
                                 month: [start monthOfYear]
                                   day: [start dayOfMonth]
                                  hour: [[limits objectAtIndex: 0] hourOfDay]
                                minute: [[limits objectAtIndex: 0] minuteOfHour]
                                second: 0
                              timeZone: [start timeZone]];
  sTo = [NSCalendarDate dateWithYear: [start yearOfCommonEra]
                               month: [start monthOfYear]
                                 day: [start dayOfMonth]
                                hour: [[limits objectAtIndex: 1] hourOfDay]
                              minute: [[limits objectAtIndex: 1] minuteOfHour]
                              second: 0
                            timeZone: [start timeZone]];

  eFrom = [NSCalendarDate dateWithYear: [end yearOfCommonEra]
                                 month: [end monthOfYear]
                                   day: [end dayOfMonth]
                                  hour: [[limits objectAtIndex: 0] hourOfDay]
                                minute: [[limits objectAtIndex: 0] minuteOfHour]
                                second: 0
                              timeZone: [end timeZone]];
  eTo = [NSCalendarDate dateWithYear: [end yearOfCommonEra]
                               month: [end monthOfYear]
                                 day: [end dayOfMonth]
                                hour: [[limits objectAtIndex: 1] hourOfDay]
                              minute: [[limits objectAtIndex: 1] minuteOfHour]
                              second: 0
                            timeZone: [end timeZone]];

  // start < sFrom
  if ([sFrom compare: start] == NSOrderedDescending)
    rc = NO;
  // start > sTo
  if ([sTo compare: start] == NSOrderedAscending)
    rc = NO;

  // end > eTo
  if ([eTo compare: end] == NSOrderedAscending)
    rc = NO;
  // end < eFrom
  if ([eFrom compare: end] == NSOrderedDescending)
    rc = NO;

  return rc;
}

- (NSArray *) _loadScheduleLimitsForUsers: (NSArray *) users
{
  SOGoUserDefaults *ud;
  NSCalendarDate *from, *to, *maxFrom, *maxTo;
  int count;

  maxFrom = [NSCalendarDate dateWithString: @"00:01"
                            calendarFormat: @"%H:%M"];
  maxTo = [NSCalendarDate dateWithString: @"23:59"
                          calendarFormat: @"%H:%M"];

  for (count = 0; count < [users count]; count++)
    {
      ud = [[SOGoUser userWithLogin: [users objectAtIndex: count]
                              roles: nil] primaryUserDefaults];
      from = [NSCalendarDate dateWithString: [ud objectForKey: @"DayStartTime"]
                             calendarFormat: @"%H:%M"];
      to = [NSCalendarDate dateWithString: [ud objectForKey: @"DayEndTime"]
                             calendarFormat: @"%H:%M"];
      maxFrom = (NSCalendarDate *)[from laterDate: maxFrom];
      maxTo = (NSCalendarDate *)[to earlierDate: maxTo];
    }

  return [NSArray arrayWithObjects: maxFrom, maxTo, nil];
}

- (WOResponse *) findPossibleSlotAction
{
  WORequest *r;
  NSCalendarDate *nStart, *nEnd;
  NSArray *uids, *limits;
  NSMutableDictionary *rc;
  int direction, count, blockDuration, step;
  unsigned int **fbData;
  BOOL isAllDay = NO, onlyOfficeHours = YES;

  r = [context request];
  rc = nil;
  
  uids = [[r formValueForKey: @"uids"] componentsSeparatedByString: @","];
  if ([uids count] > 0)
    {
      isAllDay = [[r formValueForKey: @"isAllDay"] boolValue];
      onlyOfficeHours = [[r formValueForKey: @"onlyOfficeHours"] boolValue];
      direction = [[r formValueForKey: @"direction"] intValue];
      limits = [self _loadScheduleLimitsForUsers: uids];
      
      if (isAllDay)
        step = direction * 96;
      else
        step = direction;

      nStart = [[self _parseDateField: @"startDate" 
                            timeField: @"startTime"] 
                addTimeInterval: intervalSeconds * step];
      nEnd = [[self _parseDateField: @"endDate" 
                          timeField: @"endTime"] 
              addTimeInterval: intervalSeconds * step];
      blockDuration = [nEnd timeIntervalSinceDate: nStart] / intervalSeconds;

      fbData = [self _loadFreeBusyForUsers: uids 
                                  fromDate: [nStart addTimeInterval: -offsetSeconds]];

      for (count = offsetBlocks; 
           (count < offsetBlocks + maxBlocks) && count >= 0; 
           count += step)
        {
          //NSLog (@"Trying %@ -> %@", nStart, nEnd);
          if ((onlyOfficeHours && [self _validateStart: nStart 
                                                andEnd: nEnd 
                                               against: limits]) 
              || !onlyOfficeHours)
            {
              //NSLog (@"valid");
              if ([self _possibleBlock: count
                              forUsers: [uids count]
                              freeBusy: fbData
                              interval: blockDuration])
                {
                  //NSLog (@"possible");
                  rc = [self _makeValidResponseFrom: nStart 
                                                 to: nEnd];
                  break;
                }
            }
          nStart = [nStart addTimeInterval: intervalSeconds * step];
          nEnd = [nEnd addTimeInterval: intervalSeconds * step];
        }

      for (count = 0; count < [uids count]; count++)
        free (*(fbData+count));
      free (fbData);
    }

  return [self _responseWithData: [NSArray arrayWithObjects: rc, nil]];
}

@end
