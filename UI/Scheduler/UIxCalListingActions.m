/* UIxCalListingActions.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2011 Inverse inc.
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

#import <NGCards/iCalPerson.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/iCalDateTime.h>

#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <SOGo/SOGoDateFormatter.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSObject+Utilities.h>
#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoAppointmentFolders.h>
#import <Appointments/SOGoAppointmentObject.h>
#import <Appointments/SOGoWebAppointmentFolder.h>
#import <Appointments/SOGoFreeBusyObject.h>

#import <UI/Common/WODirectAction+SOGo.h>

#import "NSArray+Scheduler.h"

#import "UIxCalListingActions.h"

static NSArray *eventsFields = nil;
static NSArray *tasksFields = nil;

#define dayLength       86400
#define quarterLength   900             // number of seconds in 15 minutes
#define offsetHours (24 * 5)            // number of hours in invitation window
#define offsetSeconds (offsetHours * 60 * 60)  // number of seconds in
                                               // invitation window
/* 1 block = 15 minutes */
#define offsetBlocks (offsetHours * 4)  // number of 15-minute blocks in invitation window
#define maxBlocks (offsetBlocks * 2)    // maximum number of blocks to search
                                        // for a free slot (10 days)

@implementation UIxCalListingActions

+ (void) initialize
{
  if (!eventsFields)
    {
      eventsFields = [NSArray arrayWithObjects: @"c_name", @"c_folder",
			      @"calendarName",
			      @"c_status", @"c_title", @"c_startdate",
			      @"c_enddate", @"c_location", @"c_isallday",
			      @"c_classification", @"c_category",
                              @"c_partmails", @"c_partstates", @"c_owner",
                              @"c_iscycle", @"c_nextalarm",
                              @"c_recurrence_id", @"isException", @"editable",
                              @"erasable", @"ownerIsOrganizer", nil];
      [eventsFields retain];
    }
  if (!tasksFields)
    {
      tasksFields = [NSArray arrayWithObjects: @"c_name", @"c_folder",
			     @"c_status", @"c_title", @"c_enddate",
			     @"c_classification", @"editable", @"erasable",
                             @"c_priority", nil];
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
      ASSIGN (userTimeZone, [[user userDefaults] timeZone]);
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
  NSString *param;

  user = [context activeUser];
  userLogin = [user login];

  param = [request formValueForKey: @"filterpopup"];
  if ([param length])
    {
      [self _setupDatesWithPopup: param andUserTZ: userTimeZone];
      title = [request formValueForKey: @"search"];
    }
  else
    {
      param = [request formValueForKey: @"sd"];
      if ([param length] > 0)
	startDate = [[NSCalendarDate dateFromShortDateString: param
				     andShortTimeString: nil
				     inTimeZone: userTimeZone] beginOfDay];
      else
	startDate = nil;

      param = [request formValueForKey: @"ed"];
      if ([param length] > 0)
	endDate = [[NSCalendarDate dateFromShortDateString: param
				   andShortTimeString: nil
				   inTimeZone: userTimeZone] endOfDay];
      else
	endDate = nil;

      param = [request formValueForKey: @"view"];
      dayBasedView = ![param isEqualToString: @"monthview"];
    }
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

/*
 * Adjust the event start and end dates when there's a time change
 * in the period covering the view for the user's timezone.
 * @param theRecord the attributes of the event.
 */
- (void) _fixDates: (NSMutableDictionary *) theRecord
{
  NSCalendarDate *aDate;
  NSNumber *aDateValue;
  NSString *aDateField;
  int daylightOffset;
  unsigned int count;
  static NSString *fields[] = { @"startDate", @"c_startdate",
				@"endDate", @"c_enddate" };
  
  /* WARNING: This condition has been put and removed many times, please leave
     it. Here is the story...
     If _fixDates: is conditional to dayBasedView, the recurrences are computed
     properly but the display time is wrong.
     If _fixDates: is non-conditional, the reverse occurs.
     If only this part of _fixDates: is conditional, both are right.

     Regarding all day events, we need to execute this code no matter what the
     date and the view are, otherwise the event will span on two days.
     
     ref bugs:
     http://www.sogo.nu/bugs/view.php?id=909
     http://www.sogo.nu/bugs/view.php?id=678
     ...
  */
  
  //NSLog(@"***[UIxCalListingActions _fixDates:] %@", [theRecord objectForKey: @"c_title"]);
  if (dayBasedView || [[theRecord objectForKey: @"c_isallday"] boolValue])
    {
      for (count = 0; count < 2; count++)
        {
          aDateField = fields[count * 2];
          aDate = [theRecord objectForKey: aDateField];
	  daylightOffset = (int) ([userTimeZone secondsFromGMTForDate: aDate]
				  - [userTimeZone secondsFromGMTForDate: startDate]);
	  //NSLog(@"***[UIxCalListingActions _fixDates:] %@ = %@ (%i)", aDateField, aDate, daylightOffset);
          if (daylightOffset)
            {
              aDate = [aDate dateByAddingYears: 0 months: 0 days: 0 hours: 0
                                       minutes: 0 seconds: daylightOffset];
              [theRecord setObject: aDate forKey: aDateField];
              aDateValue = [NSNumber numberWithInt: [aDate timeIntervalSince1970]];
              [theRecord setObject: aDateValue forKey: fields[count * 2 + 1]];
            }
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
  SOGoUser *ownerUser;
  NSString *owner, *role, *calendarName;
  BOOL isErasable, folderIsRemote;

  infos = [NSMutableArray array];
  marker = [NSNull null];
  clientObject = [self clientObject];

  folders = [[clientObject subFolders] objectEnumerator];
  while ((currentFolder = [folders nextObject]))
    {
      if ([currentFolder isActive]
          && (![component isEqualToString: @"vtodo"] || [currentFolder showCalendarTasks]))
        {
          folderIsRemote
            = [currentFolder isKindOfClass: [SOGoWebAppointmentFolder class]];
          currentInfos
            = [[currentFolder fetchCoreInfosFrom: startDate
                                              to: endDate
                                           title: title
                                       component: component] objectEnumerator];
	  owner = [currentFolder ownerInContext: context];
	  ownerUser = [SOGoUser userWithLogin: owner];
	  isErasable = ([owner isEqualToString: userLogin]
			|| [[currentFolder aclsForUser: userLogin] containsObject: SOGoRole_ObjectEraser]);
          while ((newInfo = [currentInfos nextObject]))
            {
              if ([fields containsObject: @"editable"])
                {
                  if (folderIsRemote)
		    // .ics subscriptions are not editable
                    [newInfo setObject: [NSNumber numberWithInt: 0]
                                forKey: @"editable"];
                  else
                    {
		      // Identifies whether the active user can edit the event.
                      role =
                        [currentFolder roleForComponentsWithAccessClass:
                                                 [[newInfo objectForKey: @"c_classification"] intValue]
                                                                forUser: userLogin];
                      if ([role isEqualToString: @"ComponentModifier"] 
                          || [role length] == 0)
                        [newInfo setObject: [NSNumber numberWithInt: 1]
                                    forKey: @"editable"];
                      else
                        [newInfo setObject: [NSNumber numberWithInt: 0]
                                    forKey: @"editable"];
                    }
                }
	      if ([fields containsObject: @"ownerIsOrganizer"])
		{
		  // Identifies whether the active user is the organizer
		  // of this event.
		  NSString *c_orgmail;
		  c_orgmail = [newInfo objectForKey: @"c_orgmail"];

		  if ([c_orgmail isKindOfClass: [NSString class]] && [ownerUser hasEmail: c_orgmail])
                    [newInfo setObject: [NSNumber numberWithInt: 1]
                                forKey: @"ownerIsOrganizer"];
                  else
                    [newInfo setObject: [NSNumber numberWithInt: 0]
                                forKey: @"ownerIsOrganizer"];
		}
	      if (isErasable)
		[newInfo setObject: [NSNumber numberWithInt: 1]
			    forKey: @"erasable"];
	      else
		[newInfo setObject: [NSNumber numberWithInt: 0]
			    forKey: @"erasable"];
	      [newInfo setObject: [currentFolder nameInContainer]
                          forKey: @"c_folder"];
              [newInfo setObject: [currentFolder ownerInContext: context]
                          forKey: @"c_owner"];
              calendarName = [currentFolder displayName];
              if (calendarName == nil)
                calendarName = @"";
              [newInfo setObject: calendarName
                          forKey: @"calendarName"];
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
  //NSLog(@"***[UIxCalListingActions _formattedDateForSeconds] user timezone is %@", userTimeZone);
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
      if ([currentFolder isActive] && [currentFolder showCalendarAlarms])
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

- (void) checkFilterValue
{
  NSString *filter;
  SOGoUserSettings *us;

  filter = [[context request] formValueForKey: @"filterpopup"];
  if ([filter length]
      && ![filter isEqualToString: @"view_all"]
      && ![filter isEqualToString: @"view_future"])
    {
      us = [[context activeUser] userSettings];
      [us setObject: filter forKey: @"CalendarDefaultFilter"];
      [us synchronize];
    }
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
  [self checkFilterValue];

  newEvents = [NSMutableArray array];
  events = [[self _fetchFields: eventsFields
		  forComponentOfType: @"vevent"] objectEnumerator];
  while ((oldEvent = [events nextObject]))
    {
      newEvent = [NSMutableArray arrayWithArray: oldEvent];
      isAllDay = [[oldEvent objectAtIndex: eventIsAllDayIndex] boolValue];
      interval = [[oldEvent objectAtIndex: eventStartDateIndex] intValue];
      [newEvent addObject: [self _formattedDateForSeconds: interval
						forAllDay: isAllDay]];
      interval = [[oldEvent objectAtIndex: eventEndDateIndex] intValue];
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
  else if ([sort isEqualToString: @"calendarName"])
    [newEvents sortUsingSelector: @selector (compareEventsCalendarNameAscending:)];
  else
    [newEvents sortUsingSelector: @selector (compareEventsStartDateAscending:)];

  ascending = [[context request] formValueForKey: @"asc"];
  if (![ascending boolValue])
    [newEvents reverseArray];

  return [self _responseWithData: newEvents];
}

static inline void
_feedBlockWithDayBasedData (NSMutableDictionary *block, unsigned int start,
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
_feedBlockWithMonthBasedData (NSMutableDictionary *block, unsigned int start,
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

  partList = [event objectAtIndex: eventPartMailsIndex];
  stateList = [event objectAtIndex: eventPartStatesIndex];
  if ([partList length] && [stateList length])
    {
      participants = [partList componentsSeparatedByString: @"\n"];
      states = [stateList componentsSeparatedByString: @"\n"];
      count = 0;
      max = [participants count];
      while (state == iCalPersonPartStatOther && count < max)
	{
	  user = [SOGoUser userWithLogin: [event objectAtIndex: eventOwnerIndex]
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
  int currentDayStart, startSecs, endsSecs, currentStart, eventStart,
    eventEnd, offset, recurrenceTime, swap;
  NSMutableArray *currentDay;
  NSMutableDictionary *eventBlock;
  iCalPersonPartStat userState;

  eventStart = [[event objectAtIndex: eventStartDateIndex] intValue];
  if (eventStart < 0)
    [self errorWithFormat: @"event '%@' has negative start: %d (skipped)",
          [event objectAtIndex: eventNameIndex], eventStart];
  else
    {
      eventEnd = [[event objectAtIndex: eventEndDateIndex] intValue];
      if (eventEnd < 0)
        [self errorWithFormat: @"event '%@' has negative end: %d (skipped)",
              [event objectAtIndex: eventNameIndex], eventEnd];
      else
        {
          if (eventEnd < eventStart)
            {
              swap = eventStart;
              eventStart = eventEnd;
              eventEnd = swap;
              [self warnWithFormat: @"event '%@' has end < start: %d < %d",
                    [event objectAtIndex: eventNameIndex], eventEnd, eventStart];
            }

          startSecs = (unsigned int) [startDate timeIntervalSince1970];
          endsSecs = (unsigned int) [endDate timeIntervalSince1970];

          if ([[event objectAtIndex: eventIsCycleIndex] boolValue])
            recurrenceTime = [[event objectAtIndex: eventRecurrenceIdIndex] unsignedIntValue];
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
          if (offset >= [blocks count])
            [self errorWithFormat: @"event '%@' has a computed offset that"
                  @" overflows the amount of blocks (skipped)",
                  [event objectAtIndex: eventNameIndex]];
          else
            {
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
	      if (eventEnd > currentStart)
		{
		  eventBlock = [self _eventBlockWithStart: currentStart
						      end: eventEnd
						   number: number
						    onDay: currentDayStart
					   recurrenceTime: recurrenceTime
						userState: userState];
		  [currentDay addObject: eventBlock];
		}
	      else
		[self warnWithFormat: @"event '%@' has end <= start: %d < %d",
		      [event objectAtIndex: eventNameIndex], eventEnd, currentStart];
	    }
        }
    }
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
  BOOL isAllDay;

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
//      NSLog(@"***[UIxCalListingActions eventsBlocksAction] %i = %@ : %@ / %@ / %@", count,
//	    [event objectAtIndex: eventTitleIndex],
//	    [event objectAtIndex: eventStartDateIndex],
//	    [event objectAtIndex: eventEndDateIndex],
//	    [event objectAtIndex: eventRecurrenceIdIndex]);
      eventNbr = [NSNumber numberWithUnsignedInt: count];
      isAllDay = [[event objectAtIndex: eventIsAllDayIndex] boolValue];
      if (dayBasedView && isAllDay)
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
  SOGoUserSettings *us;
  NSEnumerator *tasks;
  NSMutableArray *filteredTasks, *filteredTask;
  BOOL showCompleted;
  NSArray *task;
  int statusCode;
  unsigned int endDateStamp;
  NSString *statusFlag;

  filteredTasks = [NSMutableArray array];

  [self _setupContext];

#warning see TODO in SchedulerUI.js about "setud"
  showCompleted = [[request formValueForKey: @"show-completed"] intValue];
  if ([request formValueForKey: @"setud"])
    {
      us = [[context activeUser] userSettings];
      [us setBool: showCompleted forKey: @"ShowCompletedTasks"];
      [us synchronize];
    }

  tasks = [[self _fetchFields: tasksFields
		 forComponentOfType: @"vtodo"] objectEnumerator];
  while ((task = [tasks nextObject]))
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
    }
  [filteredTasks sortUsingSelector: @selector (compareTasksAscending:)];

  return [self _responseWithData: filteredTasks];
}

@end
