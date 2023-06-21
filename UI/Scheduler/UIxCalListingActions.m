/* UIxCalListingActions.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2016 Inverse inc.
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSUserDefaults.h> /* for locale string constants */
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>

#import <NGCards/iCalPerson.h>
#import <NGCards/iCalCalendar.h>

#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>

#import <SOPE/NGCards/iCalRecurrenceRule.h>

#import <SOGo/SOGoDateFormatter.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/WOResourceManager+SOGo.h>
#import <Appointments/iCalToDo+SOGo.h>
#import <Appointments/SOGoAppointmentFolders.h>
#import <Appointments/SOGoWebAppointmentFolder.h>

#import "NSArray+Scheduler.h"

#import "UIxCalListingActions.h"

static NSArray *eventsFields = nil;
static NSArray *tasksFields = nil;

#define dayLength     86400
#define quarterLength 900                     // number of seconds in 15 minutes
#define offsetHours   (24 * 5)                // number of hours in invitation window
#define offsetSeconds (offsetHours * 60 * 60) // number of seconds in
                                              // invitation window
/* 1 block = 15 minutes */
#define offsetBlocks  (offsetHours * 4)       // number of 15-minute blocks in invitation window
#define maxBlocks     (offsetBlocks * 2)      // maximum number of blocks to search
                                              // for a free slot (10 days)

@class SOGoAppointment;

@implementation UIxCalListingActions

+ (void) initialize
{
  // NOTE: Modifying one of those two static arrays requires to modify NSArray+Scheduler.h
  if (!eventsFields)
  {
    eventsFields = [NSArray arrayWithObjects: @"c_name", @"c_folder",
                    @"calendarName",
                    @"c_status", @"c_isopaque", @"c_title", @"c_startdate", @"startHour",
                    @"c_enddate", @"c_location", @"c_isallday",
                    @"c_classification", @"c_category", @"c_priority",
                    @"c_partmails", @"c_partstates", @"c_owner",
                    @"c_iscycle", @"c_nextalarm",
                    @"c_recurrence_id", @"isException", @"viewable", @"editable",
                    @"erasable", @"ownerIsOrganizer", @"c_description", nil];
    [eventsFields retain];
  }
  if (!tasksFields)
  {
    tasksFields = [NSArray arrayWithObjects: @"c_name", @"c_folder",
                   @"calendarName",
                   @"c_status", @"c_title", @"c_startdate", @"c_enddate",
                   @"c_classification", @"c_location", @"c_category",
                   @"viewable", @"editable", @"erasable",
                   @"c_priority", @"c_owner",
                   @"c_iscycle", @"c_nextalarm",
                   @"c_recurrence_id", @"isException", @"c_description", nil];
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
    ASSIGN (now, [NSCalendarDate calendarDate]);
    ASSIGN (request, newRequest);
    user = [[self context] activeUser];
    ASSIGN (dateFormatter, [user dateFormatterInContext: context]);
    ASSIGN (userTimeZone, [[user userDefaults] timeZone]);
    [now setTimeZone: userTimeZone];
    dayBasedView = NO;
    currentView = nil;
    ASSIGN (enabledWeekDays, [[user userDefaults] calendarWeekdays]);
  }

  return self;
}

- (void) dealloc
{
  [dateFormatter release];
  [request release];
  [componentsData release];
  [userTimeZone release];
  [enabledWeekDays release];
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
    startDate = [NSCalendarDate calendarDate];
    [startDate setTimeZone: userTZ];
    endDate = [[startDate dateByAddingYears: 0 months: 0 days: 6] endOfDay];
  }
  else if ([popupValue isEqualToString: @"view_next14"])
  {
    startDate = [NSCalendarDate calendarDate];
    [startDate setTimeZone: userTZ];
    endDate = [[startDate dateByAddingYears: 0 months: 0 days: 13] endOfDay];
  }
  else if ([popupValue isEqualToString: @"view_next31"])
  {
    startDate = [NSCalendarDate calendarDate];
    [startDate setTimeZone: userTZ];
    endDate = [[startDate dateByAddingYears: 0 months: 0 days: 30] endOfDay];
  }
  else if ([popupValue isEqualToString: @"view_thismonth"])
    {
      newDate = [NSCalendarDate calendarDate];
      [newDate setTimeZone: userTZ];
      startDate = [[newDate firstDayOfMonth] beginOfDay];
      endDate = [[newDate lastDayOfMonth] endOfDay];
    }
  else if ([popupValue isEqualToString: @"view_thisyear"])
  {
    newDate = [NSCalendarDate dateWithYear: [[NSCalendarDate calendarDate] yearOfCommonEra]
                                     month: 1
                                       day: 1
                                      hour: 0 minute: 0 second: 0
                                  timeZone: userTZ];
    startDate = [[newDate firstDayOfMonth] beginOfDay];

    newDate = [NSCalendarDate dateWithYear: [[NSCalendarDate calendarDate] yearOfCommonEra]
                                     month: 12
                                       day: 31
                                      hour: 0 minute: 0 second: 0
                                  timeZone: userTZ];
    endDate = [[newDate lastDayOfMonth] endOfDay];
  }
  else if ([popupValue isEqualToString: @"view_future"])
  {
    startDate = [NSCalendarDate calendarDate];
    [startDate setTimeZone: userTZ];
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
  else if ([popupValue isEqualToString: @"view_last7"])
  {
    endDate = [NSCalendarDate calendarDate];
    [endDate setTimeZone: userTZ];
    startDate = [[endDate dateByAddingYears: 0 months: 0 days: -6] beginOfDay];
  }
  else if ([popupValue isEqualToString: @"view_last14"])
  {
    endDate = [NSCalendarDate calendarDate];
    [endDate setTimeZone: userTZ];
    startDate = [[endDate dateByAddingYears: 0 months: 0 days: -13] beginOfDay];
  }
  else if ([popupValue isEqualToString: @"view_last31"])
  {
    endDate = [NSCalendarDate calendarDate];
    [endDate setTimeZone: userTZ];
    startDate = [[endDate dateByAddingYears: 0 months: 0 days: -30] beginOfDay];
  }
  else if ([popupValue isEqualToString: @"view_lastmonth"])
    {
      newDate = [NSCalendarDate calendarDate];
      [newDate setTimeZone: userTZ];
      endDate = [[[newDate firstDayOfMonth] dateByAddingYears:0 months:0 days:-1 hours:0 minutes:0 seconds:0] endOfDay];
      startDate = [[endDate firstDayOfMonth] beginOfDay];
    }
  else if ([popupValue isEqualToString: @"view_lastyear"])
  {
    newDate = [NSCalendarDate dateWithYear: [[NSCalendarDate calendarDate] yearOfCommonEra] - 1
                                     month: 1
                                       day: 1
                                      hour: 0 minute: 0 second: 0
                                  timeZone: userTZ];
    startDate = [[newDate firstDayOfMonth] beginOfDay];

    newDate = [NSCalendarDate dateWithYear: [[NSCalendarDate calendarDate] yearOfCommonEra] - 1
                                     month: 12
                                       day: 31
                                      hour: 0 minute: 0 second: 0
                                  timeZone: userTZ];
    endDate = [[newDate lastDayOfMonth] endOfDay];
  }
}

- (void) _setupContext
{
  SOGoUser *user;
  NSString *param;

  user = [context activeUser];
  userLogin = [user login];

  criteria = [request formValueForKey: @"search"];
  value = [request formValueForKey: @"value"];
  param = [request formValueForKey: @"filterpopup"];
  if ([param length])
    {
      [self _setupDatesWithPopup: param andUserTZ: userTimeZone];
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
      currentView = param;
      dayBasedView = ![param isEqualToString: @"monthview"];
    }
}

- (void) _fixComponentTitle: (NSMutableDictionary *) component
                   withType: (NSString *) type
{
  NSString *labelKey;

  labelKey = [NSString stringWithFormat: @"%@_class%@",
              type, [component objectForKey: @"c_classification"]];
  [component setObject: [self labelForKey: labelKey  inContext: context]
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

  static NSString *fields[] = { @"startDate", @"c_startdate", @"endDate", @"c_enddate" };

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
  if (currentView && (dayBasedView || [[theRecord objectForKey: @"c_isallday"] boolValue]))
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

/**
 * Split participants information into arrays and return the string representation of
 * their states (0: needs-action, 1: accepted, etc).
 *
 * @see [iCalPerson descriptionForParticipationStatus:]
 */
- (void) _fixParticipants: (NSMutableDictionary *) theRecord
{
  NSArray *mails, *states;
  NSMutableArray *statesDescription;
  NSString *description;
  iCalPersonPartStat stat;
  NSUInteger count, max;

  states = nil;

  if ([[theRecord objectForKey: @"c_partmails"] length] > 0)
    {
      mails = [[theRecord objectForKey: @"c_partmails"] componentsSeparatedByString: @"\n"];

      // We add some robustness here, in case the quick table had c_partmails defined but
      // no corresponding c_partstates entries. This can happen if folks toy around the database
      // or if Funambol was used in the past, with a broken connector.
      if ([[theRecord objectForKey: @"c_partstates"] length] > 0)
        states = [[theRecord objectForKey: @"c_partstates"] componentsSeparatedByString: @"\n"];

      max = [mails count];
      statesDescription = [NSMutableArray arrayWithCapacity: max];

      for (count = 0; count < max; count++)
        {
          stat = (states ? [[states objectAtIndex: count] intValue] : 0);
          description = [iCalPerson descriptionForParticipationStatus: stat];
          if (description == nil) description = @"";
          [statesDescription addObject: [description lowercaseString]];
        }

      if (max > 0)
        {
          [theRecord setObject: mails forKey: @"c_partmails"];
          [theRecord setObject: statesDescription forKey: @"c_partstates"];
        }
    }
}

- (NSArray *) _fetchFields: (NSArray *) fields
        forComponentOfType: (NSString *) component
{
  NSCalendarDate *currentStartDate, *currentEndDate;
  NSEnumerator *folders, *currentInfos;
  NSMutableDictionary *newInfo;
  NSMutableArray *infos, *quickInfos, *allInfos, *quickInfosName;
  NSNull *marker;
  NSString *owner, *role, *calendarName, *iCalString, *recurrenceTime, *categories, *weekDay;
  NSRange match;
  iCalCalendar *calendar;
  iCalEntityObject *master;
  SOGoAppointmentFolder *currentFolder;
  SOGoAppointmentFolders *clientObject;
  SOGoUser *ownerUser;

  BOOL isErasable, folderIsRemote, quickInfosFlag, searchByTitleOrContent;
  int i;

  infos = [NSMutableArray array];
  marker = [NSNull null];
  clientObject = [self clientObject];
  quickInfosFlag = searchByTitleOrContent = NO;

  folders = [[clientObject subFolders] objectEnumerator];
  while ((currentFolder = [folders nextObject]))
    {
      if ([currentFolder isActive])
        {
          folderIsRemote = [currentFolder isKindOfClass: [SOGoWebAppointmentFolder class]];

          //
          // criteria can have the following values: "title", "title_Category_Location" and "entireContent"
          //
          if ([criteria isEqualToString:@"title_Category_Location"])
            {
              currentInfos = [[currentFolder fetchCoreInfosFrom: startDate
                                                             to: endDate
                                                          title: value
                                                      component: component
                                              additionalFilters: criteria] objectEnumerator];
              searchByTitleOrContent = ([value length] > 0);
            }
          else if ([criteria isEqualToString:@"entireContent"])
            {
              // First search : Through the quick table inside the location, category and title columns
              quickInfos = (NSMutableArray *)[currentFolder fetchCoreInfosFrom: startDate
                                                                            to: endDate
                                                                         title: value
                                                                     component: component
                                                             additionalFilters: criteria];

              searchByTitleOrContent = ([value length] > 0);

              // Save the c_name in another array to compare with
              if ([quickInfos count] > 0)
                {
                  quickInfosFlag = YES;
                  quickInfosName = [NSMutableArray arrayWithCapacity:[quickInfos count]];
                  for (i = 0; i < [quickInfos count]; i++)
                    [quickInfosName addObject:[[quickInfos objectAtIndex:i] objectForKey:@"c_name"]];
                }

              // Second research : Every objects except for those already in the quickInfos array
              allInfos = (NSMutableArray *)[currentFolder fetchCoreInfosFrom: startDate
                                                                          to: endDate
                                                                       title: nil
                                                                   component: component];
              if (quickInfosFlag == YES)
                {
                  for (i = ([allInfos count] - 1); i >= 0 ; i--) {
                    if ([quickInfosName containsObject:[[allInfos objectAtIndex:i] objectForKey:@"c_name"]])
                      [allInfos removeObjectAtIndex:i];
                  }
                }

              for (i = 0; i < [allInfos count]; i++)
                {
                  iCalString = [[allInfos objectAtIndex:i] objectForKey:@"c_content"];
                  calendar = [iCalCalendar parseSingleFromSource: iCalString];
                  master = (iCalEntityObject *)[calendar firstChildWithTag:component];
                  if (master) {
                    if ([[master comment] length] > 0)
                      {
                        match = [[master comment] rangeOfString:value options:NSCaseInsensitiveSearch];
                        if (match.length > 0) {
                          [quickInfos addObject:[allInfos objectAtIndex:i]];
                        }
                      }
                  }
                }

              currentInfos = [quickInfos objectEnumerator];
            } // else if ([criteria isEqualToString:@"entireContent"])
          else
            {
              currentInfos = [[currentFolder fetchCoreInfosFrom: startDate
                                                             to: endDate
                                                          title: value
                                                      component: component]
                               objectEnumerator];
            }

          owner = [currentFolder ownerInContext: context];
          ownerUser = [SOGoUser userWithLogin: owner];
          isErasable = ([owner isEqualToString: userLogin] || [[currentFolder aclsForUser: userLogin] containsObject: SOGoRole_ObjectEraser]);

          while ((newInfo = [currentInfos nextObject]))
            {
              if ([enabledWeekDays count] &&
                  [newInfo objectForKey: @"startDate"])
                {
                  currentStartDate = [newInfo objectForKey: @"startDate"];
                  currentEndDate = [newInfo objectForKey: @"endDate"];
                  if (!currentEndDate || [currentStartDate isDateOnSameDay: currentEndDate])
                    {
                      weekDay = iCalWeekDayString[[[newInfo objectForKey: @"startDate"] dayOfWeek]];
                      if (![enabledWeekDays containsObject: weekDay])
                        // Skip components that appear on disabled weekdays
                        continue;
                    }
                }

              if ([fields containsObject: @"viewable"])
                {
                  if ([owner isEqualToString: userLogin])
                    [newInfo setObject: [NSNumber numberWithInt: 1]  forKey: @"viewable"];
                  else
                    {
                      role = [currentFolder roleForComponentsWithAccessClass: [[newInfo objectForKey: @"c_classification"] intValue]
                                                                    forUser : userLogin];

                      if ([role isEqualToString: @"ComponentDAndTViewer"])
                        {
                          // We skip results that could lead to information "exposure".
                          // See http://sogo.nu/bugs/view.php?id=3619
                          if (searchByTitleOrContent)
                            continue;

                          [newInfo setObject: [NSNumber numberWithInt: 0]  forKey: @"viewable"];
                        }
                      else
                        [newInfo setObject: [NSNumber numberWithInt: 1]  forKey: @"viewable"];
                    }
                }

              if ([fields containsObject: @"editable"])
                {
                  if (folderIsRemote)
                    // .ics subscriptions are not editable
                    [newInfo setObject: [NSNumber numberWithInt: 0]
                                forKey: @"editable"];
                  else
                    {
                      // Identifies whether the active user can edit the event.
                      role = [currentFolder roleForComponentsWithAccessClass:[[newInfo objectForKey: @"c_classification"] intValue]
                                                                     forUser: userLogin];
                      if ([role isEqualToString: @"ComponentModifier"] || [role length] == 0)
                        [newInfo setObject: [NSNumber numberWithInt: 1]
                                    forKey: @"editable"];
                      else
                        [newInfo setObject: [NSNumber numberWithInt: 0]
                                    forKey: @"editable"];
                    }
                }
	      if ([fields containsObject: @"ownerIsOrganizer"])
                {
                  // Identifies whether the owner is the organizer of this event.
                  NSString *c_orgmail;
                  c_orgmail = [newInfo objectForKey: @"c_orgmail"];

                  if ([c_orgmail isKindOfClass: [NSString class]] && [ownerUser hasEmail: c_orgmail])
                    [newInfo setObject: [NSNumber numberWithInt: 1]
                                forKey: @"ownerIsOrganizer"];
                  else
                    [newInfo setObject: [NSNumber numberWithInt: 0]
                                forKey: @"ownerIsOrganizer"];
                }
              [newInfo setObject: [NSNumber numberWithBool: isErasable]
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

              // Split comma-delimited categories
              categories = [newInfo objectForKey: @"c_category"];
              if ([categories length])
                [newInfo setObject: [categories componentsSeparatedByString: @","] forKey: @"c_category"];

              // Fix empty title
              if (![[newInfo objectForKey: @"c_title"] length])
                [self _fixComponentTitle: newInfo withType: component];

              // Add prefix to recurrence id
              if ((recurrenceTime = [newInfo objectForKey: @"c_recurrence_id"]))
                [newInfo setObject: [NSString stringWithFormat: @"occurence%@", recurrenceTime]
                            forKey: @"c_recurrence_id"];

              // Add the formatted starting hour
              [self _addStartHour: newInfo];

              // Possible improvement: only call _fixDates if event is recurrent
	      // or the view range span a daylight saving time change
              [self _fixDates: newInfo];

              // Split linefeed-delimited list of participants emails and statuses
              if ([fields containsObject: @"c_partmails"])
                [self _fixParticipants: newInfo];

              [infos addObject: [newInfo objectsForKeys: fields
                                         notFoundMarker: marker]];
            }
        }
    }

  [infos sortUsingSelector: @selector(compareEventsStartDateAscending:)];

  return infos;
}

- (WOResponse *) _responseWithData: (id) data
{
  return [self responseWithStatus: 200 andJSONRepresentation: data];
}

- (NSString *) _formattedDateForSeconds: (unsigned int) seconds
                              forAllDay: (BOOL) forAllDay
{
  NSCalendarDate *date;
  NSUInteger delta;

  date = [NSCalendarDate dateWithTimeIntervalSince1970: seconds];
  // Adjust for daylight saving time? (wrt to startDate)
  //NSLog(@"***[UIxCalListingActions _formattedDateForSeconds] user timezone is %@", userTimeZone);
  [date setTimeZone: userTimeZone];

  if ([now dayOfCommonEra] == [date dayOfCommonEra])
    {
      // Same day
      if (forAllDay)
        return [self labelForKey: @"Today" inContext: context];
      else
        return [dateFormatter formattedTime: date];
    }
  else if ([now dayOfCommonEra] - [date dayOfCommonEra] == 1)
    {
      // Yesterday
      return [self labelForKey: @"Yesterday" inContext: context];
    }
  else if ([date dayOfCommonEra] - [now dayOfCommonEra] == 1)
    {
      // Tomorrow
      return [self labelForKey: @"Tomorrow" inContext: context];
    }
  else if (abs(delta = [date dayOfCommonEra] - [now dayOfCommonEra]) < 7)
    {
      NSString *dayOfWeek = [[locale objectForKey: NSWeekDayNameArray] objectAtIndex: [date dayOfWeek]];
      if (delta < 7)
        // Wihtin the next 7 days
        return dayOfWeek;
      else
        // With the past 7 days
        return [NSString stringWithFormat: [self labelForKey: @"Last %@" inContext: context], dayOfWeek];
    }
  else
    {
      return [dateFormatter shortFormattedDate: date];
    }
}

/**
 * @api {get} /so/:username/Calendar/alarmslist Get alarms
 * @apiVersion 1.0.0
 * @apiName GetAlarmsList
 * @apiGroup Calendar
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/alarmslist?browserTime=1286668800
 * @apiDescription Called when each module is loaded or whenever a calendar component is created, modified, deleted
 * or whenever there's a {un}subscribe to a calendar.
 *
 * Workflow :
 *
 * - for ALL subscribed and ACTIVE calendars
 *  - returns alarms that will occur in the next 48 hours or the non-triggered alarms
 *    for non-completed events
 *
 * @apiParam {Number} [browserTime] Epoch time of browser
 *
 * @apiSuccess (Success 200) {String[]} fields                   List of fields for each event definition
 * @apiSuccess (Success 200) {String[]} alarms                   List of events
 * @apiSuccess (Success 200) {String} alarms.c_folder            Calendar ID
 * @apiSuccess (Success 200) {String} alarms.c_name              Event UID
 * @apiSuccess (Success 200) {String} alarms.c_nextalarm         Epoch time of event's next alarm
 */
- (WOResponse *) alarmsListAction
{
  SOGoAppointmentFolder *currentFolder;
  SOGoAppointmentFolders *clientObject;
  NSMutableArray *allAlarms;
  NSDictionary *data;
  NSEnumerator *folders;
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
          int i;

          alarms = [currentFolder fetchAlarmInfosFrom: [NSNumber numberWithInt: browserTime]
                                                   to: [NSNumber numberWithInt: laterTime]];

          for (i = 0; i < [alarms count]; i++)
            {
              entry = [alarms objectAtIndex: i];

              [allAlarms addObject: [NSArray arrayWithObjects:
                                               [currentFolder nameInContainer],
                                          [entry objectForKey: @"c_name"],
                                          [entry objectForKey: @"c_nextalarm"],
                                             nil]];
            }
        }
    }

  data = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSArray arrayWithObjects: @"c_folder", @"c_name", @"c_nextalarm", nil], @"fields",
                       allAlarms, @"alarms", nil];

  return [self _responseWithData: data];
}

- (void) saveFilterValue: (NSString *) submodule
{
  NSString *filter;
  SOGoUserSettings *us;
  NSMutableDictionary *calendarSettings;

  filter = [[context request] formValueForKey: @"filterpopup"];
  if ([filter length]
      && ![filter isEqualToString: @"view_all"]
      && ![filter isEqualToString: @"view_future"])
  {
    us = [[context activeUser] userSettings];
    calendarSettings = [us objectForKey: @"Calendar"];
    // Must create if it doesn't exist
    if (!calendarSettings)
    {
      calendarSettings = [NSMutableDictionary dictionary];
      [us setObject: calendarSettings forKey: @"Calendar"];
    }
    //[us setObject: filter forKey: submodule];
    [calendarSettings setObject: filter forKey: submodule];
    [us synchronize];
  }
}

- (void) saveSortValue: (NSString *) submodule
{
  NSString *sort, *ascending;
  SOGoUserSettings *us;
  NSMutableDictionary *calendarSettings;

  sort = [[context request] formValueForKey: @"sort"];
  ascending = [[context request] formValueForKey: @"asc"];
  if ([sort length])
  {
    us = [[context activeUser] userSettings];
    calendarSettings = [us objectForKey: @"Calendar"];
    // Must create if it doesn't exist
    if (!calendarSettings)
    {
      calendarSettings = [NSMutableDictionary dictionary];
      [us setObject: calendarSettings forKey: @"Calendar"];
    }
    [calendarSettings setObject: [NSArray arrayWithObjects: [sort lowercaseString], [NSString stringWithFormat: @"%d", [ascending intValue]], nil]
                         forKey: submodule];
    [us synchronize];
  }
}

static inline NSString* _userStateInEvent (NSArray *event)
{
  unsigned int count, max;
  NSString *state;
  NSArray *participants, *states;
  SOGoUser *user;

  participants = nil;
  state = nil;

  participants = [event objectAtIndex: eventPartMailsIndex];

  // We guard ourself against bogus value coming from the quick tables
  if ([participants isKindOfClass: [NSArray class]])
    {
      states = [event objectAtIndex: eventPartStatesIndex];
      count = 0;
      max = [participants count];
      user = [SOGoUser userWithLogin: [event objectAtIndex: eventOwnerIndex]
                               roles: nil];
      while (state == nil && count < max)
        {
          if ([user hasEmail: [participants objectAtIndex: count]])
            state = [states objectAtIndex: count];
          else
            count++;
        }
    }

  return state;
}

/**
 * @api {get} /so/:username/Calendar/eventslist List events
 * @apiVersion 1.0.0
 * @apiName GetEventsList
 * @apiGroup Calendar
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/eventslist?day=20141201\&filterpopup=view_selectedday
 *
 * @apiParam {Boolean} [asc]         Descending sort when false. Defaults to true (ascending).
 * @apiParam {String} [sort]         Sort field. Either title, start, end, location, or calendarName.
 * @apiParam {Number} [day]          Selected day (YYYYMMDD)
 * @apiParam {String} [filterpopup]  Time period. Either view_today, view_next7, view_next14, view_next31, view_thismonth, view_thisyear, view_future, view_selectedday, or view_all
 * @apiParam {String} [search]       Search field criteria. Either title_Category_Location or entireContent.
 * @apiParam {String} [value]        String to match
 *
 * @apiSuccess (Success 200) {String[]} fields                                              List of fields for each event definition
 * @apiSuccess (Success 200) {String} events.<month>.month                                  Full month and year
 * @apiSuccess (Success 200) {Object} events.<month>.days                                   List of days
 * @apiSuccess (Success 200) {String[]} events.<month>.days.<date>.month                    Abbreviated month name
 * @apiSuccess (Success 200) {String[]} events.<month>.days.<date>.monthDay                 Day of month
 * @apiSuccess (Success 200) {String[]} events.<month>.days.<date>.weekDay                  Abbreviated weeday name
 * @apiSuccess (Success 200) {String[]} events.<month>.days.<date>.events                   List of events
 * @apiSuccess (Success 200) {String} events.<month>.days.<date>.events.c_name              Event UID
 * @apiSuccess (Success 200) {String} events.<month>.days.<date>.events.c_folder            Calendar ID
 * @apiSuccess (Success 200) {String} events.<month>.days.<date>.events.calendarName        Human readable name of calendar
 * @apiSuccess (Success 200) {Number} events.<month>.days.<date>.events.c_status            0: Cancelled, 1: Normal, 2: Tentative
 * @apiSuccess (Success 200) {Number} events.<month>.days.<date>.events.c_isopaque          1 if event is opaque (not transparent)
 * @apiSuccess (Success 200) {String} events.<month>.days.<date>.events.c_title             Title
 * @apiSuccess (Success 200) {String} events.<month>.days.<date>.events.c_startdate         Epoch time of start date
 * @apiSuccess (Success 200) {String} events.<month>.days.<date>.events.c_enddate           Epoch time of end date
 * @apiSuccess (Success 200) {String} events.<month>.days.<date>.events.c_location          Event's location
 * @apiSuccess (Success 200) {Number} events.<month>.days.<date>.events.c_isallday          1 if event lasts all day
 * @apiSuccess (Success 200) {Number} events.<month>.days.<date>.events.c_classification    0: Public, 1: Private, 2: Confidential
 * @apiSuccess (Success 200) {String} events.<month>.days.<date>.events.c_category          Category
 * @apiSuccess (Success 200) {Number} events.<month>.days.<date>.events.c_priority          Priority (0 to 9)
 * @apiSuccess (Success 200) {String[]} events.<month>.days.<date>.events.c_partmails       Participants email addresses
 * @apiSuccess (Success 200) {String[]} events.<month>.days.<date>.events.c_partstates      Participants states
 * @apiSuccess (Success 200) {String} events.<month>.days.<date>.events.c_owner             Event's owner
 * @apiSuccess (Success 200) {Number} events.<month>.days.<date>.events.c_iscycle           1 if the event is cyclic/recurring
 * @apiSuccess (Success 200) {Number} events.<month>.days.<date>.events.c_nextalarm         Epoch time of next alarm
 * @apiSuccess (Success 200) {String} [events.<month>.days.<date>.events.c_recurrence_id]   Recurrence ID if event is cyclic
 * @apiSuccess (Success 200) {Number} events.<month>.days.<date>.events.isException         1 if recurrence is an exception
 * @apiSuccess (Success 200) {Number} events.<month>.days.<date>.events.viewable            1 if active user can view the event
 * @apiSuccess (Success 200) {Number} events.<month>.days.<date>.events.editable            1 if active user can edit the event
 * @apiSuccess (Success 200) {Number} events.<month>.days.<date>.events.erasable            1 if active user can erase the event
 * @apiSuccess (Success 200) {Number} events.<month>.days.<date>.events.ownerIsOrganizer    1 if owner is also the organizer
 * @apiSuccess (Success 200) {String} events.<month>.days.<date>.events.formatted_startdate Localized start date
 * @apiSuccess (Success 200) {String} events.<month>.days.<date>.events.formatted_enddate   Localized end date
 */
- (WOResponse *) eventsListAction
{
  BOOL isAllDay;
  NSArray *oldEvent;
  NSCalendarDate *date;
  NSDictionary *data;
  NSEnumerator *events;
  NSMutableArray *fields, *dayEvents, *newEvent, *allDayEvents;
  NSMutableDictionary *allEvents, *monthData, *monthEvents, *dayData;
  NSString *sort, *ascending, *day, *weekDay, *month, *userState;
  unsigned int interval, count, max;
  SEL sortSelector;

  [self _setupContext];
  [self saveFilterValue: @"EventsFilterState"];
  [self saveSortValue: @"EventsSortingState"];

  allEvents = [NSMutableDictionary dictionary];
  allDayEvents = [NSMutableArray array];
  events = [[self _fetchFields: eventsFields
            forComponentOfType: @"vevent"] objectEnumerator];
  while ((oldEvent = [events nextObject]))
  {
    interval = [[oldEvent objectAtIndex: eventStartDateIndex] intValue];
    date = [NSCalendarDate dateWithTimeIntervalSince1970: interval];
    [date setTimeZone: userTimeZone];

    // Skip components that appear on disabled weekdays
    weekDay = iCalWeekDayString[[date dayOfWeek]];
    if ([enabledWeekDays count] && ![enabledWeekDays containsObject: weekDay])
        continue;

    month = [date descriptionWithCalendarFormat: @"%Y%m" locale: locale];
    day = [date shortDateString];
    if (!(monthData = [allEvents objectForKey: month]))
      {
        monthEvents = [NSMutableDictionary dictionary];
        monthData = [NSMutableDictionary
                      dictionaryWithObjectsAndKeys:
                        [date descriptionWithCalendarFormat: @"%B %Y" locale: locale], @"month",
                      monthEvents, @"days",
                      nil];
        [allEvents setObject: monthData forKey: month];
      }
    monthEvents = [monthData objectForKey: @"days"];
    if (!(dayData = [monthEvents objectForKey: day]))
      {
        dayEvents = [NSMutableArray array];
        [allDayEvents addObject: dayEvents];
        dayData = [NSMutableDictionary
                    dictionaryWithObjectsAndKeys:
                      [date descriptionWithCalendarFormat: @"%b" locale: locale], @"month",
                      [date descriptionWithCalendarFormat: @"%e" locale: locale], @"monthDay",
                      [date descriptionWithCalendarFormat: @"%a" locale: locale], @"weekDay",
                      dayEvents, @"events",
                      nil];
        [monthEvents setObject: dayData forKey: day];
      }
    dayEvents = [dayData objectForKey: @"events"];
    newEvent = [NSMutableArray arrayWithArray: oldEvent];
    isAllDay = [[oldEvent objectAtIndex: eventIsAllDayIndex] boolValue];
    [newEvent addObject: [self _formattedDateForSeconds: interval
                                              forAllDay: isAllDay]];
    interval = [[oldEvent objectAtIndex: eventEndDateIndex] intValue];
    [newEvent addObject: [self _formattedDateForSeconds: interval
                                              forAllDay: isAllDay]];
    userState = _userStateInEvent(oldEvent);
    if (userState != nil) [newEvent addObject: userState];
    [dayEvents addObject: newEvent];
  }

  // Sort affects events of each day (but not the days)
  sort = [[context request] formValueForKey: @"sort"];
  if ([sort isEqualToString: @"title"])
    sortSelector = @selector (compareEventsTitleAscending:);
  else if ([sort isEqualToString: @"end"])
    sortSelector =  @selector (compareEventsEndDateAscending:);
  else if ([sort isEqualToString: @"location"])
    sortSelector = @selector (compareEventsLocationAscending:);
  else if ([sort isEqualToString: @"calendarName"])
    sortSelector = @selector (compareEventsCalendarNameAscending:);
  else
    sortSelector = @selector (compareEventsStartDateAscending:);
  ascending = [[context request] formValueForKey: @"asc"];
  max = [allDayEvents count];
  for (count = 0; count < max; count++)
    {
      dayEvents = [allDayEvents objectAtIndex: count];
      [dayEvents sortUsingSelector: sortSelector];
      if (![ascending boolValue])
        [dayEvents reverseArray];
    }

  // Fields names
  fields = [NSMutableArray arrayWithArray: eventsFields];
  [fields addObject: @"formatted_startdate"];
  [fields addObject: @"formatted_enddate"];
  [fields addObject: @"userState"];

  data = [NSDictionary dictionaryWithObjectsAndKeys: fields, @"fields", allEvents, @"events", nil];

  return [self _responseWithData: data];
}

static inline void _feedBlockWithDayBasedData (NSMutableDictionary *block, unsigned int start,
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
  if (delta > dayLength)
    delta = dayLength;
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

// static inline void _feedBlockWithMonthBasedData (NSMutableDictionary *block, unsigned int start,
//                                                  NSTimeZone *userTimeZone,
//                                                  SOGoDateFormatter *dateFormatter)
// {
//   NSCalendarDate *eventStartDate;
//   NSString *startHour;

//   eventStartDate = [NSCalendarDate dateWithTimeIntervalSince1970: start];
//   [eventStartDate setTimeZone: userTimeZone];
//   startHour = [dateFormatter formattedTime: eventStartDate];
//   [block setObject: startHour forKey: @"starthour"];
//   [block setObject: [NSNumber numberWithUnsignedInt: start]
//             forKey: @"start"];
// }

- (void) _addStartHour: (NSMutableDictionary *) theRecord
{
  NSCalendarDate *eventStartDate;
  NSString *startHour;

  eventStartDate = [theRecord objectForKey: @"startDate"];
  if (eventStartDate)
    {
      startHour = [dateFormatter formattedTime: eventStartDate];
      [theRecord setObject: startHour forKey: @"startHour"];
    }
}

- (NSMutableDictionary *) _eventBlockWithStart: (unsigned int) start
                                           end: (unsigned int) end
                                        number: (NSNumber *) number
                                         onDay: (unsigned int) dayStart
                                recurrenceTime: (unsigned int) recurrenceTime
                                     userState: (NSString *) userState
{
  NSMutableDictionary *block;

  block = [NSMutableDictionary dictionary];

  if (dayBasedView)
    _feedBlockWithDayBasedData (block, start, end, dayStart);
  // else
  //   _feedBlockWithMonthBasedData (block, start, userTimeZone, dateFormatter);
  [block setObject: number forKey: @"nbr"];
  if (recurrenceTime)
    [block setObject: [NSNumber numberWithInt: recurrenceTime]
              forKey: @"recurrenceTime"];
  if (userState != nil)
    [block setObject: userState
              forKey: @"userState"];

  return block;
}

- (void) _fillBlocks: (NSArray *) blocks
           withEvent: (NSArray *) event
          withNumber: (NSNumber *) number
{
  int offset, recurrenceTime;
  long long startSecs, endsSecs, swap, currentDayStart, currentStart, eventStart,
  eventEnd, computedEventEnd;
  NSMutableArray *currentDay;
  NSMutableDictionary *eventBlock;
  NSString *userState;

  eventStart = [[event objectAtIndex: eventStartDateIndex] intValue];
  eventEnd = [[event objectAtIndex: eventEndDateIndex] intValue];

  if ((eventEnd < eventStart && eventEnd > 0)
      || (eventStart > 0 && eventEnd < 0)
      || (eventStart > eventEnd && eventStart < 0 && eventEnd < 0))
  {
    swap = eventStart;
    eventStart = eventEnd;
    eventEnd = swap;
    [self warnWithFormat: @"event '%@' has end < start: %d < %d",
          [event objectAtIndex: eventNameIndex], eventEnd, eventStart];
  }

  startSecs = (long long) [startDate timeIntervalSince1970];
  endsSecs = (long long) [endDate timeIntervalSince1970];

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
    offset = ((currentStart - startSecs) / dayLength);
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

    if (eventEnd < startSecs)
      // The event doesn't end in the covered period.
      // This special case occurs with a DST change.
      return;

    userState = _userStateInEvent(event);
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

    computedEventEnd = eventEnd;

    // We add 5 mins to the end date of an event if the end date
    // is equal or smaller than the event's start date.
    if (eventEnd <= currentStart)
      computedEventEnd = currentStart + (5*60);

    eventBlock = [self _eventBlockWithStart: currentStart
                                        end: computedEventEnd
                                      number: number
                                      onDay: currentDayStart
                              recurrenceTime: recurrenceTime
                                  userState: userState];
    [currentDay addObject: eventBlock];
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

static inline unsigned int _computeMaxBlockSiblings (NSArray *block)
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

static inline void _propagateBlockSiblings (NSArray *block, NSNumber *maxSiblings)
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
static inline void _computeBlocksSiblings (NSArray *blocks)
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

static inline void _computeBlockPosition (NSArray *block)
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

- (NSArray *) _selectedCalendars
{
  SOGoAppointmentFolders *co;
  SOGoAppointmentFolder *folder;
  NSMutableArray *selectedCalendars;
  NSArray *folders;
  NSString *fUID, *fName;
  NSNumber *isActive;
  unsigned int count, foldersCount;

  co = [self clientObject];
  folders = [co subFolders];
  foldersCount = [folders count];
  selectedCalendars = [[NSMutableArray alloc] initWithCapacity: foldersCount];
  for (count = 0; count < foldersCount; count++)
  {
    folder = [folders objectAtIndex: count];
    isActive = [NSNumber numberWithBool: [folder isActive]];
    if ([isActive intValue] != 0) {
      fUID = [folder nameInContainer];
      fName = [folder displayName];
      [selectedCalendars addObject: [NSDictionary dictionaryWithObjectsAndKeys:
                                                    fUID, @"id",
                                                  fName, @"name",
                                                  nil]];
    }
  }
  return selectedCalendars;
}

/**
 * @api {get} /so/:username/Calendar/eventsblocks Get events blocks
 * @apiVersion 1.0.0
 * @apiName GetEventsBlocks
 * @apiGroup Calendar
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/eventsblocks?day=20141201\&popupfilter=view_selectedday
 *
 * @apiParam {Number} [sd] Period start date (YYYYMMDD)
 * @apiParam {Number} [ed] Period end date (YYYYMMDD)
 * @apiParam {String} [view] Formatting view. Either dayview, multicolumndayview, weekview or monthview.
 *
 * @apiSuccess (Success 200) {Object[]} days
 * @apiSuccess (Success 200) {String} days.date
 * @apiSuccess (Success 200) {Number} days.number
 * @apiSuccess (Success 200) {String[]} eventsFields             List of fields for each event definition
 * @apiSuccess (Success 200) {String[]} events                   List of events
 * @apiSuccess (Success 200) {String} events.c_name              Event UID
 * @apiSuccess (Success 200) {String} events.c_folder            Calendar ID
 * @apiSuccess (Success 200) {String} events.calendarName        Human readable name of calendar
 * @apiSuccess (Success 200) {Number} events.c_status            0: Cancelled, 1: Normal, 2: Tentative
 * @apiSuccess (Success 200) {String} events.c_title             Title
 * @apiSuccess (Success 200) {String} events.c_startdate         Epoch time of start date
 * @apiSuccess (Success 200) {String} events.c_enddate           Epoch time of end date
 * @apiSuccess (Success 200) {String} events.c_location          Event's location
 * @apiSuccess (Success 200) {Number} events.c_isallday          1 if event lasts all day
 * @apiSuccess (Success 200) {Number} events.c_classification    0: Public, 1: Private, 2: Confidential
 * @apiSuccess (Success 200) {String} events.c_category          Category
 * @apiSuccess (Success 200) {String[]} events.c_partmails       Participants email addresses
 * @apiSuccess (Success 200) {String[]} events.c_partstates      Participants states
 * @apiSuccess (Success 200) {String} events.c_owner             Event's owner
 * @apiSuccess (Success 200) {Number} events.c_iscycle           1 if the event is cyclic
 * @apiSuccess (Success 200) {Number} events.c_nextalarm         Epoch time of next alarm
 * @apiSuccess (Success 200) {String} [events.c_recurrence_id]   Recurrence ID if event is cyclic
 * @apiSuccess (Success 200) {Number} events.isException         1 if recurrence is an exception
 * @apiSuccess (Success 200) {Number} events.viewable            1 if active user can view the event
 * @apiSuccess (Success 200) {Number} events.editable            1 if active user can edit the event
 * @apiSuccess (Success 200) {Number} events.erasable            1 if active user can erase the event
 * @apiSuccess (Success 200) {Number} events.ownerIsOrganizer    1 if owner is also the organizer
 * @apiSuccess (Success 200) {Object[]} blocks
 * @apiSuccess (Success 200) {Number} blocks.nbr
 * @apiSuccess (Success 200) {Number} [blocks.start]             Day-based views only
 * @apiSuccess (Success 200) {Number} [blocks.position]          Day-based views only
 * @apiSuccess (Success 200) {Number} [blocks.length]            Day-based views only
 * @apiSuccess (Success 200) {Number} [blocks.siblings]          Day-based views only
 * @apiSuccess (Success 200) {Number} [blocks.realSiblings]      Day-based views only
 * @apiSuccess (Success 200) {Object[]} allDayBlocks
 * @apiSuccess (Success 200) {Number} allDayBlocks.nbr
 * @apiSuccess (Success 200) {Number} allDayBlocks.start
 * @apiSuccess (Success 200) {Number} allDayBlocks.length
 */
- (WOResponse *) eventsBlocksAction
{
  int count, max;
  NSArray *events, *event, *calendars;
  NSCalendarDate *currentDate;
  NSDictionary *eventsBlocks, *calendar;
  NSMutableArray *allDayBlocks, *blocks, *days, *currentDay, *eventsForCalendar, *eventsByCalendars;
  NSNumber *eventNbr;
  NSString *calendarName, *calendarId;
  BOOL isAllDay;
  int i, j;

  [self _setupContext];

  events = [self _fetchFields: eventsFields forComponentOfType: @"vevent"];

  if ([currentView isEqualToString: @"multicolumndayview"])
  {
    calendars = (NSMutableArray *)[self _selectedCalendars];
    eventsByCalendars = [NSMutableArray arrayWithCapacity:[calendars count]];
    for (i = 0; i < [calendars count]; i++) // For each calendar
    {
      calendar = [calendars objectAtIndex:i];
      calendarName = [calendar objectForKey: @"name"];
      calendarId = [calendar objectForKey: @"id"];
      days = [NSMutableArray array];
      eventsForCalendar = [NSMutableArray array];
      [self _prepareEventBlocks: &blocks withAllDays: &allDayBlocks];
      for (j = 0; j < [events count]; j++) {
        if ([[[events objectAtIndex:j] objectAtIndex:eventFolderIndex] isEqualToString: calendarId]) {
          // Event is in current calendar
          [eventsForCalendar addObject: [events objectAtIndex:j]];
        }
      }
      eventsBlocks = [NSDictionary dictionaryWithObjectsAndKeys:
                                     calendarId , @"id",
                                   calendarName, @"calendarName",
                                   eventsFields, @"eventsFields",
                                   eventsForCalendar, @"events",
                                   allDayBlocks, @"allDayBlocks",
                                   blocks, @"blocks",
                                   days, @"days", nil];
      max = [eventsForCalendar count];
      for (count = 0; count < max; count++)
      {
        event = [eventsForCalendar objectAtIndex: count];
        eventNbr = [NSNumber numberWithUnsignedInt: count];
        isAllDay = [[event objectAtIndex: eventIsAllDayIndex] boolValue];
        if (dayBasedView && isAllDay)
          [self _fillBlocks: allDayBlocks withEvent: event withNumber: eventNbr];
        else
          [self _fillBlocks: blocks withEvent: event withNumber: eventNbr];
      }

      currentDate = [[startDate copy] autorelease];
      [currentDate setTimeZone: userTimeZone];
      max = [blocks count];
      for (count = 0; count < max; count++)
      {
        currentDay = [blocks objectAtIndex: count];
        [currentDay sortUsingSelector: @selector (compareEventByStart:)];
        [self _addBlocksWidth: currentDay];

        [days addObject: [NSDictionary dictionaryWithObjectsAndKeys:
                                         [currentDate shortDateString], @"date",
                                            [NSNumber numberWithInt: count], @"number", nil]];
        currentDate = [currentDate addYear:0 month:0 day:1 hour:0 minute:0 second:0];
      }
      [eventsByCalendars addObject: eventsBlocks];
    }
    return [self _responseWithData: eventsByCalendars];
  }
  else
  {
    days = [NSMutableArray array];
    [self _prepareEventBlocks: &blocks withAllDays: &allDayBlocks];
    eventsBlocks = [NSDictionary dictionaryWithObjectsAndKeys:
                                   eventsFields, @"eventsFields",
                                 events, @"events",
                                 allDayBlocks, @"allDayBlocks",
                                 blocks, @"blocks",
                                 days, @"days", nil];
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

    currentDate = [[startDate copy] autorelease];
    [currentDate setTimeZone: userTimeZone];
    max = [blocks count];
    for (count = 0; count < max; count++)
    {
      currentDay = [blocks objectAtIndex: count];
      [currentDay sortUsingSelector: @selector (compareEventByStart:)];
      [self _addBlocksWidth: currentDay];

      [days addObject: [NSDictionary dictionaryWithObjectsAndKeys:
                                       [currentDate shortDateString], @"date",
                                          [NSNumber numberWithInt: count], @"number", nil]];
      currentDate = [currentDate addYear:0 month:0 day:1 hour:0 minute:0 second:0];
    }

    if ([enabledWeekDays count] > 0 && [enabledWeekDays count] < 7)
      {
        // Remove the days that are disabled in the user's defaults
        int weekDay, weekDayCount;

        weekDayCount= [currentDate dayOfWeek];
        for (count = max - 1; count >= 0; count--)
          {
            weekDayCount--;
            if (weekDayCount < 0)
              weekDay = ((weekDayCount % 7) + 7) % 7;
            else
              weekDay = weekDayCount;
            if (![enabledWeekDays containsObject: iCalWeekDayString[weekDay]])
              {
                [allDayBlocks removeObjectAtIndex: count];
                [blocks removeObjectAtIndex: count];
                [days removeObjectAtIndex: count];
              }
          }
      }

    return [self _responseWithData: [NSArray arrayWithObject: eventsBlocks]];
  }
}

- (NSString *) _getStatusClassForStatusCode: (int) statusCode
                            andEndDateStamp: (unsigned int) endDateStamp
{
  NSCalendarDate *taskDate;
  NSString *statusClass;

  if (statusCode == 1)
    statusClass = @"completed";
  else
  {
    if (endDateStamp)
    {
      taskDate = [NSCalendarDate dateWithTimeIntervalSince1970: endDateStamp];
      [taskDate setTimeZone: userTimeZone];
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
      statusClass = @"noduedate";
  }

  return statusClass;
}

/**
 * @api {get} /so/:username/Calendar/taskslist List tasks
 * @apiVersion 1.0.0
 * @apiName GetTasksList
 * @apiGroup Calendar
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/taskslist?filterpopup=view_all
 *
 * @apiParam {Number} [show_completed] Show completed tasks when set to 1. Defaults to ignore completed tasks.
 * @apiParam {Boolean} [asc]           Descending sort when false. Defaults to true (ascending).
 * @apiParam {Boolean} [sort]          Sort field. Either title, priority, end, location, category, calendarname, or status.
 * @apiParam {Number} [day]            Selected day (YYYYMMDD)
 * @apiParam {String} [filterpopup]    Time period. Either view_today, view_next7, view_next14, view_next31, view_thismonth, view_thisyear, view_overdue, view_incomplete, view_not_started, or view_all
 * @apiParam {String} [search]         Search field criteria. Either title_Category_Location or entireContent.
 *
 * @apiSuccess (Success 200) {String[]} fields                List of fields for each event definition
 * @apiSuccess (Success 200) {String[]} tasks                 List of events
 * @apiSuccess (Success 200) {String} tasks.c_name            Todo UID
 * @apiSuccess (Success 200) {String} tasks.c_folder          Calendar ID
 * @apiSuccess (Success 200) {String} tasks.calendarName      Human readable name of calendar
 * @apiSuccess (Success 200) {Number} tasks.c_status          0: Needs-action, 1: Completed, 2: In-process, 3: Cancelled
 * @apiSuccess (Success 200) {String} tasks.c_title           Title
 * @apiSuccess (Success 200) {String} tasks.c_enddate         End date (epoch time)
 * @apiSuccess (Success 200) {Number} tasks.c_classification  0: Public, 1: Private, 2: Confidential
 * @apiSuccess (Success 200) {String} tasks.c_location        Location
 * @apiSuccess (Success 200) {String} tasks.c_category        Category
 * @apiSuccess (Success 200) {Number} tasks.viewable          1 if task is viewable by the active user
 * @apiSuccess (Success 200) {Number} tasks.editable          1 if task is editable by the active user
 * @apiSuccess (Success 200) {Number} tasks.erasable          1 if task is erasable by the active user
 * @apiSuccess (Success 200) {String} tasks.c_priority        Priority (0-9)
 * @apiSuccess (Success 200) {String} tasks.c_owner           Username of owner
 * @apiSuccess (Success 200) {String} [tasks.c_recurrence_id] Recurrence ID if task is cyclic
 * @apiSuccess (Success 200) {Number} tasks.isException       1 if task is cyclic and an exception
 * @apiSuccess (Success 200) {String} tasks.status            Either completed, overdue, duetoday, or duelater
 * @apiSuccess (Success 200) {String} tasks.formatted_enddate Localized end date
 */
- (WOResponse *) tasksListAction
{
  NSDictionary *data;
  NSMutableArray *filteredTasks, *filteredTask, *fields;
  NSString *sort, *ascending;
  NSString *statusFlag, *tasksView;
  SOGoUserSettings *us;
  NSEnumerator *tasks;
  NSArray *task;

  unsigned int endDateStamp;
  BOOL showCompleted;
  int statusCode;
  int startSecs;

  filteredTasks = [NSMutableArray array];

  [self _setupContext];
  [self saveFilterValue: @"TasksFilterState"];
  [self saveSortValue: @"TasksSortingState"];

  startSecs = (unsigned int) [startDate timeIntervalSince1970];
  tasksView = [request formValueForKey: @"filterpopup"];

  showCompleted = [[request formValueForKey: @"show_completed"] intValue];
  us = [[context activeUser] userSettings];
  [us setBool: showCompleted forKey: @"ShowCompletedTasks"];
  [us synchronize];

  tasks = [[self _fetchFields: tasksFields
           forComponentOfType: @"vtodo"] objectEnumerator];

  while ((task = [tasks nextObject]))
  {
    statusCode = [[task objectAtIndex: taskStatusIndex] intValue];
    if (statusCode != 1 || showCompleted)
    {
      filteredTask = [NSMutableArray arrayWithArray: task];
      endDateStamp = [[task objectAtIndex: taskEndDateIndex] intValue];
      statusFlag = [self _getStatusClassForStatusCode: statusCode
                                      andEndDateStamp: endDateStamp];
      [filteredTask addObject: statusFlag];
      statusFlag = [iCalToDo statusForCode: statusCode];
      [filteredTask replaceObjectAtIndex: taskStatusIndex withObject: statusFlag];
      if (endDateStamp > 0)
        [filteredTask addObject: [self _formattedDateForSeconds: endDateStamp
                                                      forAllDay: NO]];
      else
        [filteredTask addObject: [NSNull null]];
      if (([tasksView isEqualToString:@"view_today"]     ||
           [tasksView isEqualToString:@"view_next7"]     ||
           [tasksView isEqualToString:@"view_next14"]    ||
           [tasksView isEqualToString:@"view_next31"]    ||
           [tasksView isEqualToString:@"view_thismonth"] ||
           [tasksView isEqualToString:@"view_thisyear"]  ||
           [tasksView isEqualToString:@"view_last7"]     ||
           [tasksView isEqualToString:@"view_last14"]    ||
           [tasksView isEqualToString:@"view_last31"]    ||
           [tasksView isEqualToString:@"view_lastmonth"] ||
           [tasksView isEqualToString:@"view_lastyear"]) &&
          (endDateStamp == 0 || endDateStamp >= startSecs))
        [filteredTasks addObject: filteredTask];
      else if ([tasksView isEqualToString:@"view_all"])
        [filteredTasks addObject: filteredTask];
      else if (([tasksView isEqualToString:@"view_overdue"]) &&
               ([[filteredTask objectAtIndex:taskStatusFlagIndex] isEqualToString:@"overdue"]))
        [filteredTasks addObject: filteredTask];
      else if ([tasksView isEqualToString:@"view_incomplete"] &&
               (![[filteredTask objectAtIndex:taskStatusFlagIndex] isEqualToString:@"completed"]))
        [filteredTasks addObject: filteredTask];
      else if ([tasksView isEqualToString:@"view_not_started"] &&
               ([[[filteredTask objectAtIndex:taskStatusIndex] stringValue] isEqualToString:@"0"]))
        [filteredTasks addObject: filteredTask];
    }
  }
  sort = [[context request] formValueForKey: @"sort"];
  if ([sort isEqualToString: @"title"])
    [filteredTasks sortUsingSelector: @selector (compareTasksTitleAscending:)];
  else if ([sort isEqualToString: @"priority"])
    [filteredTasks sortUsingSelector: @selector (compareTasksPriorityAscending:)];
  else if ([sort isEqualToString: @"start"])
    [filteredTasks sortUsingSelector: @selector (compareTasksStartDateAscending:)];
  else if ([sort isEqualToString: @"end"])
    [filteredTasks sortUsingSelector: @selector (compareTasksEndDateAscending:)];
  else if ([sort isEqualToString: @"location"])
    [filteredTasks sortUsingSelector: @selector (compareTasksLocationAscending:)];
  else if ([sort isEqualToString: @"category"])
    [filteredTasks sortUsingSelector: @selector (compareTasksCategoryAscending:)];
  else if ([sort isEqualToString: @"calendarName"])
    [filteredTasks sortUsingSelector: @selector (compareTasksCalendarNameAscending:)];
  else
    [filteredTasks sortUsingSelector: @selector (compareTasksAscending:)];

  ascending = [[context request] formValueForKey: @"asc"];
  if (![ascending boolValue])
    [filteredTasks reverseArray];

  // Fields names
  fields = [NSMutableArray arrayWithArray: tasksFields];
  [fields addObject: @"status"];
  [fields addObject: @"formatted_enddate"];

  data = [NSDictionary dictionaryWithObjectsAndKeys: fields, @"fields", filteredTasks, @"tasks", nil];

  return [self _responseWithData: data];
}

- (WOResponse *) activeTasksAction
{
  NSMutableDictionary *activeTasksByCalendars;
  SOGoAppointmentFolder *folder;
  SOGoAppointmentFolders *co;
  NSArray *folders;
  int i;

  co = [self clientObject];
  folders = [co subFolders];
  activeTasksByCalendars = [NSMutableDictionary dictionaryWithCapacity: [folders count]];

  for (i = 0; i < [folders count]; i++)
    {
      folder = [folders objectAtIndex: i];

      [activeTasksByCalendars setObject: [folder activeTasks]
                                 forKey: [folder nameInContainer]];
  }

  return [self _responseWithData: activeTasksByCalendars];
}

@end
