/* iCalEvent+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2016 Inverse inc.
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
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalRecurrenceRule.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/iCalTimeZonePeriod.h>
#import <NGCards/NSString+NGCards.h>

#import <SoObjects/SOGo/CardElement+SOGo.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoUserDefaults.h>
#import <SoObjects/SOGo/WOContext+SOGo.h>

#import <SOGo/NSCalendarDate+SOGo.h>

#import "iCalRepeatableEntityObject+SOGo.h"

#import "iCalEvent+SOGo.h"

@implementation iCalEvent (SOGoExtensions)

- (BOOL) isStillRelevant
{
  NSCalendarDate *now, *lastRecurrence;
  BOOL isStillRelevent;

  now = [NSCalendarDate calendarDate];

  if ([self isRecurrent])
    {
      lastRecurrence = [self lastPossibleRecurrenceStartDate];
      isStillRelevent = (lastRecurrence == nil || [lastRecurrence earlierDate: now] == now);
    }
  else
    isStillRelevent = ([[self endDate] earlierDate: now] == now);

  return isStillRelevent;
}

//
//
//
- (NSMutableDictionary *) quickRecordFromContent: (NSString *) theContent
                                       container: (id) theContainer
                                 nameInContainer: (NSString *) nameInContainer
{
  NSMutableDictionary *row;
  NSCalendarDate *startDate, *endDate;
  NSArray *attendees, *categories;
  NSString *uid, *title, *location, *status;
  NSNumber *sequence;
  id organizer;
  id participants, partmails;
  NSMutableString *partstates;
  unsigned int i, count, boolTmp;
  BOOL isAllDay;
  iCalAccessClass accessClass;
  iCalDateTime *date;
  iCalTimeZone *timeZone;

  /* extract values */

  startDate = [self startDate];
  endDate = [self endDate];
  uid = [self uid];
  if ([uid length] > 255)
    uid = [uid substringToIndex: 255];

  title = [self summary];
  if (![title isNotNull])
    title = @"";

  if ([title length] > 1000)
    title = [title substringToIndex: 1000];

  location = [self location];

  if ([location length] > 255)
    location = [location substringToIndex: 255];

  sequence = [self sequence];
  accessClass = [self symbolicAccessClass];
  isAllDay = [self isAllDay];
  status = [[self status] uppercaseString];

  attendees = [self attendees];
  partmails = [attendees valueForKey: @"rfc822Email"];
  partmails = [partmails componentsJoinedByString: @"\n"];
  participants = [attendees valueForKey: @"cn"];
  participants = [participants componentsJoinedByString: @"\n"];

  /* build row */

  row = [NSMutableDictionary dictionaryWithCapacity:8];

  [row setObject: @"vevent" forKey: @"c_component"];

  if ([uid isNotNull])
    [row setObject:uid forKey: @"c_uid"];
  else
    [self logWithFormat: @"WARNING: could not extract a uid from event!"];

  boolTmp = ((isAllDay) ? 1 : 0);
  [row setObject: [NSNumber numberWithInt: boolTmp]
          forKey: @"c_isallday"];
  boolTmp = ((([self isRecurrent] || [self recurrenceId])) ? 1 : 0);
  [row setObject: [NSNumber numberWithInt: boolTmp]
          forKey: @"c_iscycle"];
  boolTmp = (([self isOpaque]) ? 1 : 0);
  [row setObject: [NSNumber numberWithInt: boolTmp]
          forKey: @"c_isopaque"];
  [row setObject: [NSNumber numberWithInt: [self priorityNumber]]
          forKey: @"c_priority"];

  [row setObject: title forKey: @"c_title"];
  if ([location isNotNull]) [row setObject: location forKey: @"c_location"];
  if ([sequence isNotNull]) [row setObject: sequence forKey: @"c_sequence"];

  if ([startDate isNotNull])
    {
      if (isAllDay)
	{
	  // An all-day event usually doesn't have a timezone associated to its
	  // start date; however, if it does, we convert it to GMT.
	  date = (iCalDateTime*) [self uniqueChildWithTag: @"dtstart"];
	  timeZone = [(iCalDateTime*) date timeZone];
	  if (timeZone)
	    startDate = [timeZone computedDateForDate: startDate];
	}
      [row setObject: [self quickRecordDateAsNumber: startDate
                                         withOffset: 0
                                          forAllDay: isAllDay]
	      forKey: @"c_startdate"];
    }
  if ([endDate isNotNull])
    {
      if (isAllDay)
	{
	  // An all-day event usually doesn't have a timezone associated to its
	  // end date; however, if it does, we convert it to GMT.
	  date = (iCalDateTime*) [self uniqueChildWithTag: @"dtend"];
	  timeZone = [(iCalDateTime*) date timeZone];
	  if (timeZone)
	    endDate = [timeZone computedDateForDate: endDate];
	}
      [row setObject: [self quickRecordDateAsNumber: endDate
                                         withOffset: ((isAllDay) ? -1 : 0)
                                          forAllDay: isAllDay]
	      forKey: @"c_enddate"];
    }

  if ([self isRecurrent])
    {
      NSCalendarDate *date;
      NSArray *events;
      iCalEvent *e;

      date = [self lastPossibleRecurrenceStartDate];
      if (date)
        date = [date addTimeInterval: [self durationAsTimeInterval]];
      else
        /* this could also be *nil*, but in the end it makes the fetchspecs
           more complex - thus we set it to a "reasonable" distant future */
        date = iCalDistantFuture;

      // We have to make sure that we don't have occurrences that are after
      // our -lastPossibleRecurrenceStartDate. We do that by walking through
      // the events list from the calendar component
      events = [[self parent] events];

      for (i = 0; i < [events count]; i++)
        {
          e = [events objectAtIndex: i];
          if ([e recurrenceId] && [[e startDate] compare: date] == NSOrderedDescending)
            {
              date = [e startDate];
              date = [date addTimeInterval: [e durationAsTimeInterval]];
            }
        }

      [row setObject: [self quickRecordDateAsNumber: date
                                         withOffset: 0 forAllDay: NO]
              forKey: @"c_cycleenddate"];
      [row setObject: [self cycleInfo] forKey: @"c_cycleinfo"];
    }

  if ([participants length] > 0)
    [row setObject: participants forKey: @"c_participants"];
  if ([partmails length] > 0)
    [row setObject: partmails forKey: @"c_partmails"];

  if ([status isNotNull])
    {
      int code = 1;

      if ([status isEqualToString: @"TENTATIVE"])
	code = 2;
      else if ([status isEqualToString: @"CANCELLED"])
	code = 0;
      [row setObject:[NSNumber numberWithInt:code] forKey: @"c_status"];
    }
  else
    {
      /* confirmed by default */
      [row setObject: [NSNumber numberWithInt: 1] forKey: @"c_status"];
    }

  [row setObject: [NSNumber numberWithUnsignedInt: accessClass]
          forKey: @"c_classification"];

  organizer = [self organizer];
  if (organizer)
    {
      NSString *email;

      email = [organizer valueForKey: @"rfc822Email"];
      if (email)
	[row setObject:email forKey: @"c_orgmail"];
    }

  /* construct partstates */
  count = [attendees count];
  partstates = [[NSMutableString alloc] initWithCapacity:count * 2];
  for (i = 0; i < count; i++)
    {
      iCalPerson *p;
      iCalPersonPartStat stat;

      p = [attendees objectAtIndex:i];
      stat = [p participationStatus];
      if (i)
	[partstates appendString: @"\n"];
      [partstates appendFormat: @"%d", stat];
    }
  [row setObject:partstates forKey: @"c_partstates"];
  [partstates release];

  /* handle alarms */
  [self updateNextAlarmDateInRow: row  forContainer: theContainer  nameInContainer: nameInContainer];

  /* handle categories */
  categories = [self categories];
  if ([categories count] > 0)
    [row setObject: [categories componentsJoinedByString: @","]
            forKey: @"c_category"];
  else
    [row setObject: [NSNull null] forKey: @"c_category"];

  /* handle description */
  if ([self comment])
    [row setObject: [self comment]  forKey: @"c_description"];
  else
    [row setObject: [NSNull null] forKey: @"c_description"];

  return row;
}

- (NSTimeInterval) occurenceInterval
{
  return (NSTimeInterval) [[self endDate] timeIntervalSinceDate: [self startDate]];
}

/**
 * Shift the "until dates" of the recurrence rules of the event
 * with respect to the previous end date of the event.
 * @param previousEndDate the previous end date of the event
 */
- (void) updateRecurrenceRulesUntilDate: (NSCalendarDate *) previousEndDate
{
  iCalRecurrenceRule *rule;
  NSEnumerator *rules;
  NSCalendarDate *untilDate;
  int offset;

  // Recurrence rules
  rules = [[self recurrenceRules] objectEnumerator];
  while ((rule = [rules nextObject]))
    {
      untilDate = [rule untilDate];
      if (untilDate)
	{
	  // The until date must match the time of the end date
	  offset = [[self endDate] timeIntervalSinceDate: previousEndDate];
	  untilDate = [untilDate dateByAddingYears:0
                                            months:0
                                              days:0
                                             hours:0
                                           minutes:0
                                           seconds:offset];
	  [rule setUntilDate: untilDate];
	}
    }

  // Exception rules
  rules = [[self exceptionRules] objectEnumerator];
  while ((rule = [rules nextObject]))
    {
      untilDate = [rule untilDate];
      if (untilDate)
	{
	  // The until date must match the time of the end date
	  offset = [[self endDate] timeIntervalSinceDate: previousEndDate];
	  untilDate = [untilDate dateByAddingYears:0
                                            months:0
                                              days:0
                                             hours:0
                                           minutes:0
                                           seconds:offset];
	  [rule setUntilDate: untilDate];
	}
    }
}

/**
 * @see [iCalRepeatableEntityObject+SOGo attributes]
 * @see [iCalEntityObject+SOGo attributes]
 * @see [UIxAppointmentEditor viewAction]
 */
- (NSDictionary *) attributesInContext: (WOContext *) context
{
  NSMutableDictionary *data;

  data = [NSMutableDictionary dictionaryWithDictionary: [super attributesInContext: context]];

  [data setObject: [NSNumber numberWithBool: ![self isOpaque]] forKey: @"isTransparent"];

  return data;
}

/**
 * @see [iCalRepeatableEntityObject+SOGo setAttributes:inContext:]
 * @see [iCalEntityObject+SOGo setAttributes:inContext:]
 * @see [UIxAppointmentEditor saveAction]
 */
- (void) setAttributes: (NSDictionary *) data
             inContext: (WOContext *) context
{
  NSCalendarDate *aptStartDate, *aptEndDate, *allDayStartDate;
  NSInteger offset, nbrDays;
  NSTimeZone *timeZone;
  iCalDateTime *startDate;
  iCalTimeZone *tz;
  SOGoUserDefaults *ud;
  BOOL isAllDay;
  id o;

  [super setAttributes: data inContext: context];

  aptStartDate = aptEndDate = nil;

  // Handle start/end dates
  o = [data objectForKey: @"startDate"];
  if ([o isKindOfClass: [NSString class]] && [o length])
    aptStartDate = [self dateFromString: o inContext: context];

  o = [data objectForKey: @"endDate"];
  if ([o isKindOfClass: [NSString class]] && [o length])
    aptEndDate = [self dateFromString: o inContext: context];

  o = [data objectForKey: @"isTransparent"];
  if ([o isKindOfClass: [NSNumber class]] && [o boolValue])
    [self setTransparency: @"TRANSPARENT"];
  else
    [self setTransparency: @"OPAQUE"];

  isAllDay = [[data objectForKey: @"isAllDay"] boolValue];

  if (aptStartDate && aptEndDate && [aptStartDate earlierDate: aptEndDate] == aptStartDate)
    {
      if (isAllDay)
        {
          // Remove the vTimeZone when dealing with an all-day event.
          startDate = (iCalDateTime *)[self uniqueChildWithTag: @"dtstart"];
          tz = [startDate timeZone];
          if (tz)
            {
              [startDate setTimeZone: nil];
              [(iCalDateTime *)[self uniqueChildWithTag: @"dtend"] setTimeZone: nil];
              [[self parent] removeChild: tz];
            }

          nbrDays = round ([aptEndDate timeIntervalSinceDate: aptStartDate] / 86400) + 1;
          timeZone = [aptStartDate timeZone];
          offset = [timeZone secondsFromGMTForDate: aptStartDate];
          allDayStartDate = [aptStartDate dateByAddingYears: 0 months: 0 days: 0
                                                      hours: 0 minutes: 0
                                                    seconds: offset];
          [self setAllDayWithStartDate: allDayStartDate
                              duration: nbrDays];
        }
      else
        {
          o = [data objectForKey: @"startTime"];
          if ([o isKindOfClass: [NSString class]] && [o length])
            [self adjustDate: &aptStartDate withTimeString: o inContext: context];

          o = [data objectForKey: @"endTime"];
          if ([o isKindOfClass: [NSString class]] && [o length])
            [self adjustDate: &aptEndDate withTimeString: o inContext: context];

          [self setStartDate: aptStartDate];
          [self setEndDate: aptEndDate];
        }
    }

  if (!isAllDay)
    {
      // Make sure there's a vTimeZone associated to the event unless it
      // is an all-day event.
      startDate = (iCalDateTime *)[self uniqueChildWithTag: @"dtstart"];
      if (![startDate timeZone])
        {
          ud = [[context activeUser] userDefaults];
          tz = [iCalTimeZone timeZoneForName: [ud timeZoneName]];
          if ([[self parent] addTimeZone: tz])
            {
              [startDate setTimeZone: tz];
              [(iCalDateTime *)[self uniqueChildWithTag: @"dtend"] setTimeZone: tz];
            }
        }
    }
}

- (iCalTimeZone *) adjustInContext: (WOContext *) context
                     withTimezones: (NSDictionary *) timezones
{
  iCalDateTime *dtstart, *dtend;
  iCalTimeZone *timezone;
  NSCalendarDate *date, *startDate, *endDate;
  NSString *startDateAsString, *timezoneId;
  SOGoUserDefaults *ud;
  int delta;

  delta = 0;
  timezone = nil;

  dtstart = (iCalDateTime *) [self uniqueChildWithTag: @"dtstart"];
  dtend = (iCalDateTime *) [self uniqueChildWithTag: @"dtend"];

  startDate = [dtstart dateTime];
  endDate = [dtend dateTime];

  if (!startDate)
    {
      if (endDate)
        {
          // End date but no start date
          delta = 60*60; // 1 hour
          [self setStartDate: [[self endDate] dateByAddingYears: 0  months: 0  days: 0  hours: 0  minutes: 0  seconds: -delta]];
        }
      else
        {
          // No start date, no end date; start the event at the first "working" hour
          date = [[NSCalendarDate calendarDate] beginOfDayForUser: [context activeUser]];
          [self setStartDate: date];
        }
      dtstart = (iCalDateTime *) [self uniqueChildWithTag: @"dtstart"];
      startDate = [dtstart dateTime];
      [self errorWithFormat: @"Event with no start date; setting start date to %@ for UID %@", startDate, [self uid]];
    }

  if (startDate)
    {
      timezoneId = [dtstart value: 0 ofAttribute: @"tzid"];
      if ([timezoneId length])
        {
          timezone = [iCalTimeZone timeZoneForName: timezoneId];
          // Fallback to tz (VTIMEZONE) found in the ics.
          if (!timezone)
            timezone = [timezones valueForKey: timezoneId];
        }
      else
        {
          startDateAsString = [[dtstart valuesAtIndex: 0 forKey: @""] objectAtIndex: 0];
          if (!([self isAllDay] ||
                [startDateAsString hasSuffix: @"Z"] ||
                [startDateAsString hasSuffix: @"z"]))
            {
              // The start date is a "floating time", let's use the user's timezone
              // for both the start and end dates.
              ud = [[context activeUser] userDefaults];
              timezone = [iCalTimeZone timeZoneForName: [ud timeZoneName]];
              delta = [[timezone periodForDate: startDate] secondsOffsetFromGMT];

              [self setStartDate: [[self startDate] dateByAddingYears: 0  months: 0  days: 0  hours: 0  minutes: 0  seconds: -delta]];
              [dtstart setTimeZone: timezone];
              startDate = [dtstart dateTime];
              [self errorWithFormat: @"Event with no timezone; setting timezone %@ to start date for UID %@", [timezone tzId], [self uid]];

              if (endDate)
                {
                  [self setEndDate: [[self endDate] dateByAddingYears: 0  months: 0  days: 0  hours: 0  minutes: 0  seconds: -delta]];
                  [dtend setTimeZone: timezone];
                  endDate = [dtend dateTime];
                  [self errorWithFormat: @"Event with no timezone; setting timezone %@ to end date for UID %@", [timezone tzId], [self uid]];
                }
            }
        }
      if (endDate && [startDate compare: endDate] == NSOrderedDescending)
        {
          [self errorWithFormat: @"Event with start date after end date; swapping dates for UID %@", [self uid]];
          [self setStartDate: endDate];
          [self setEndDate: startDate];
        }
    }

  if (!endDate && ![self hasDuration])
    {
      // No end date, no duration
      if ([self isAllDay])
        [self setDuration: @"P1D"];
      else
        [self setDuration: @"PT1H"];

      [self errorWithFormat: @"Event with no end date; setting duration to %@ for UID %@", [self duration], [self uid]];
    }

  //
  // We check for broken all-day events (like the ones coming from the "WebCalendar" tool) where
  // the start date is equal to the end date. This clearly violates the RFC:
  //
  // 3.8.2.2. Date-Time End
  // The value MUST be later in time than the value of the "DTSTART" property.
  //
  if ([self isAllDay] && [[self startDate] isEqual: [self endDate]])
    {
      [self setEndDate: [[self startDate] dateByAddingYears: 0  months: 0  days: 1  hours: 0  minutes: 0  seconds: 0]];
      [self errorWithFormat: @"Broken all-day event; setting end date to %@ for UID %@", [self endDate], [self uid]];
    }

  if ([self isRecurrent])
    {
      NSArray *rules;
      iCalRecurrenceRule *rule;

      rules = [self recurrenceRules];
      if ([rules count] > 0)
        {
          // Consider first rule only
          rule = [rules objectAtIndex: 0];
          if ([rule repeatCount] && [rule untilDate])
            {
              [self errorWithFormat: @"Recurrent event with both repeat count (%i) and until date (%@); dropping until date", [rule repeatCount], [rule untilDate]];
              [rule setUntil: nil];
            }
        }
    }

  return timezone;

}

@end
