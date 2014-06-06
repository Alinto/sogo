/* iCalEvent+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2013 Inverse inc.
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
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGCards/iCalAlarm.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalRecurrenceRule.h>
#import <NGCards/iCalTrigger.h>
#import <NGCards/NSString+NGCards.h>

#import "iCalRepeatableEntityObject+SOGo.h"
#import "iCalEvent+SOGo.h"
#import "SOGoAppointmentFolder.h"

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
- (NSMutableDictionary *) quickRecord
{
  NSMutableDictionary *row;
  NSCalendarDate *startDate, *endDate, *nextAlarmDate;
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
  boolTmp = (([self isRecurrent]) ? 1 : 0);
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
    
    date = [self lastPossibleRecurrenceStartDate];
    if (!date)
    {
      /* this could also be *nil*, but in the end it makes the fetchspecs
	     more complex - thus we set it to a "reasonable" distant future */
      date = iCalDistantFuture;
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
    [row setObject: [NSNumber numberWithInt:1] forKey: @"c_status"];
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
  
  nextAlarmDate = nil;
  
  if (![self isRecurrent] && [self hasAlarms])
  {
    iCalAlarm *anAlarm;
    NSString *webstatus;
    
    anAlarm = [[self alarms] objectAtIndex: 0];
    if ([[anAlarm action] caseInsensitiveCompare: @"DISPLAY"] == NSOrderedSame)
    {
      webstatus = [[anAlarm trigger] value: 0 ofAttribute: @"x-webstatus"];
      if (!webstatus || ([webstatus caseInsensitiveCompare: @"TRIGGERED"] != NSOrderedSame))
        nextAlarmDate = [anAlarm nextAlarmDate];
    }
  }
  else if ([self isRecurrent])
  {
    id *obj_content;
    BOOL hasOccurrenceAlarms = NO;
    int max, occurrenceCountAlarms = 0;
    NSArray *content;
    NSMutableDictionary *theRecord;
    NSCalendarDate *_rangeStartDate, *_rangeEndDate,
                   *_vEventStartDate, *_vEventEndDate,
                   *_startDate, *_endDate, *theRange, *today;
    NSNumber *masterEvent, *occurrenceEvent, *todaySecs;
    NSMutableArray *theRecords;
    iCalEvent *vevent;
    iCalAlarm *anAlarm;
    NSString *webstatus, *rowStartDate, *rowEndDate;
    
    obj_content = [self parent]; // Contains the VCALENDAR and all the VEVENT
    max = [[obj_content events] count] - 1;
    
    if ([[obj_content events] count] >= 1) { // Is there any occurrence(s) other than the master event ?
      for (i = max; i > 0; i--) {            // If so, is there alarms associated with it ?
        if ([[[obj_content events] objectAtIndex:i] hasAlarms])
        {
          hasOccurrenceAlarms = YES;
          occurrenceCountAlarms ++;
        }
        else
          [[obj_content events] removeObjectAtIndex:i];
      }
    }
    
    
    if ([[[[self parent] events] objectAtIndex:0] hasAlarms] || hasOccurrenceAlarms)
    // The master event or occurrence(s) have alarms
    {
      content = [NSArray arrayWithObject:obj_content];
      theRecord = [NSMutableDictionary dictionaryWithDictionary:row];
      [theRecord setObject:content forKey:@"c_content"];  // Add the "c_content" column
      [theRecord setObject:@"YES" forKey:@"c_fromiCalEvent"]; // Gives information for the flattenCycleRecord
      
      // Range from today + 1 year
      today = [NSCalendarDate date];
      _rangeStartDate = today;
      _rangeEndDate = [_rangeStartDate addYear:1 month:0 day: 0 hour: 0 minute: 0 second:0];
      theRange = [NGCalendarDateRange calendarDateRangeWithStartDate: _rangeStartDate
                                                             endDate: _rangeEndDate];
      
      // Return all the reccurences of the current event in an array. Each cell contains a dictionnary
      theRecords = [[NSMutableArray alloc] init];
      [SOGoAppointmentFolder flattenCycleRecord:theRecord forRange:theRange intoArray:theRecords];

      if ([[[[self parent] events] objectAtIndex:0] hasAlarms] && hasOccurrenceAlarms)
      {
        masterEvent = [NSNumber numberWithInt: [[[theRecords objectAtIndex:0] objectForKey:@"startDate"] timeIntervalSince1970]];
        todaySecs = [NSNumber numberWithInt:[today timeIntervalSince1970]];
        for (i=1; i <= occurrenceCountAlarms; i++) {
          occurrenceEvent = [NSNumber numberWithInt:
                             [[[[[[[theRecords objectAtIndex:i] objectForKey:@"c_content"] objectAtIndex:0] events] objectAtIndex:i] startDate] timeIntervalSince1970]];
          if (([occurrenceEvent intValue] < [masterEvent intValue]) && [occurrenceEvent intValue] > [todaySecs intValue]){
            vevent = [[[[[theRecords objectAtIndex:i] objectForKey:@"c_content"] objectAtIndex:0] events] objectAtIndex:i];
            // Set the value of the quicktable to the current occurrence so the alert display the associated date
            rowStartDate = [NSString stringWithFormat:@"%f",[[vevent startDate] timeIntervalSince1970]];
            rowEndDate = [NSString stringWithFormat:@"%f",[[vevent endDate] timeIntervalSince1970]];
          }
          else
          {
            vevent = [[[[[theRecords objectAtIndex:0] objectForKey:@"c_content"] objectAtIndex:0] events] lastObject];
            _startDate = [[theRecords objectAtIndex:0] objectForKey:@"startDate"];
            _endDate = [[theRecords objectAtIndex:0] objectForKey:@"endDate"];
            [vevent setStartDate:_startDate];
            [vevent setEndDate:_endDate];
            // Set the value of the quicktable to the current occurrence so the alert display the associated date
            rowStartDate = [NSString stringWithFormat:@"%f",[_startDate timeIntervalSince1970]];
            rowEndDate = [NSString stringWithFormat:@"%f",[_endDate timeIntervalSince1970]];
          }
          [row setObject:rowStartDate forKey:@"c_enddate"];
          [row setObject:rowEndDate forKey:@"c_startdate"];
        }
      }
      else
      {
        if (hasOccurrenceAlarms)
        // The startDate and endDate inside the occurrence are good for the computation of the next alarm
        {
          vevent = [[[[[theRecords objectAtIndex:0] objectForKey:@"c_content"] objectAtIndex:0] events] lastObject];
          // Set the value of the quicktable to the current occurrence so the alert display the associated date
          rowStartDate = [NSString stringWithFormat:@"%f",[[vevent startDate] timeIntervalSince1970]];
          rowEndDate = [NSString stringWithFormat:@"%f",[[vevent endDate] timeIntervalSince1970]];
          
        }
        else
        // Need to reajust the dates since the vevent is recurrent and there is only one entry in the quickTable
        {
          vevent = [[[[[theRecords objectAtIndex:0] objectForKey:@"c_content"] objectAtIndex:0] events] lastObject];
          _startDate = [[theRecords objectAtIndex:0] objectForKey:@"startDate"];
          _endDate = [[theRecords objectAtIndex:0] objectForKey:@"endDate"];
          [vevent setStartDate:_startDate];
          [vevent setEndDate:_endDate];
          // Set the value of the quicktable to the current occurrence so the alert display the associated date
          rowStartDate = [NSString stringWithFormat:@"%f",[_startDate timeIntervalSince1970]];
          rowEndDate = [NSString stringWithFormat:@"%f",[_endDate timeIntervalSince1970]];
        }
        [row setObject:rowStartDate forKey:@"c_enddate"];
        [row setObject:rowEndDate forKey:@"c_startdate"];
      }
      
      anAlarm = [[vevent alarms] lastObject];
      if ([[anAlarm action] caseInsensitiveCompare: @"DISPLAY"] == NSOrderedSame)
      {
        webstatus = [[anAlarm trigger] value: 0 ofAttribute: @"x-webstatus"];
        if (!webstatus || ([webstatus caseInsensitiveCompare: @"TRIGGERED"] != NSOrderedSame))
          nextAlarmDate = [anAlarm nextAlarmDate];
      }
      [theRecords release];
    }
  }
  
  if ([nextAlarmDate isNotNull])
    [row setObject: [NSNumber numberWithInt: [nextAlarmDate timeIntervalSince1970]] forKey: @"c_nextalarm"];
  else
    [row setObject: [NSNumber numberWithInt: 0] forKey: @"c_nextalarm"];
  
  categories = [self categories];
  if ([categories count] > 0)
    [row setObject: [categories componentsJoinedByString: @","] forKey: @"c_category"];
  else
    [row setObject: [NSNull null] forKey: @"c_category"];
  
  return row;
}

/**
 * Extract the start and end dates from the event, from which all recurrence
 * calculations will be based on.
 * @return the range of the first occurrence.
 */
- (NGCalendarDateRange *) firstOccurenceRange
{
  NSCalendarDate *start, *end;
  NGCalendarDateRange *firstRange;
  NSArray *dates;

  firstRange = nil;

  dates = [[[self uniqueChildWithTag: @"dtstart"] valuesForKey: @""] lastObject];
  if ([dates count] > 0)
    {
      start = [[dates lastObject] asCalendarDate]; // ignores timezone
      end = [start addTimeInterval: [self occurenceInterval]];

      firstRange = [NGCalendarDateRange calendarDateRangeWithStartDate: start
                                                               endDate: end];
    }
  
  return firstRange;
}

- (unsigned int) occurenceInterval
{
  return [[self endDate] timeIntervalSinceDate: [self startDate]];
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
  
@end
