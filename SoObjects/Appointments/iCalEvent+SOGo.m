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
    BOOL hasAnotherOccurrenceAlarm = NO, hasAnotherRecord = NO;
    int max, occurrenceCountAlarms = 0;
    NSArray *content;
    NSMutableDictionary *theRecord;
    NSCalendarDate *_rangeStartDate, *_rangeEndDate,
    *_vEventStartDate, *_vEventEndDate,
    *_startDate, *_endDate, *_nextStartDate, *_nextEndDate, *theRange, *today;
    NSMutableArray *theRecords;
    NSArray *vEventDates;
    iCalEvent *vEvent, *vNextEvent;
    iCalAlarm *anAlarm, *anotherAlarm;
    NSString *webstatus, *rowStartDate, *rowEndDate, *rowNextStartDate, *rowNextEndDate;
    NSNumber *masterEvent, *occurrenceEvent, *intToday;
    int intervalStartDate, intervalEndDate, intervalNextStartDate, intervalNextEndDate;
    
    obj_content = [self parent];            // Contains the VCALENDAR and all the VEVENT
    max = [[obj_content events] count] - 1; // Number of occurrences (Substract one; the master event)
    
    // Is there any occurrence(s) other than the master event ? If so, is there alarms associated with it ?
    for (i = max; i > 0; i--)
      if ([[[obj_content events] objectAtIndex:i] hasAlarms])
        occurrenceCountAlarms ++;
    
    if ([[[[self parent] events] objectAtIndex:0] hasAlarms] || occurrenceCountAlarms > 0)
      // The master event or occurrence(s) have alarms
    {
      content = [NSArray arrayWithObject:obj_content];
      theRecord = [NSMutableDictionary dictionaryWithDictionary:row]; // Make a copy of row inside theRecord
      [theRecord setObject:content forKey:@"c_content"];              // Add the "c_content" column
      [theRecord setObject:@"YES" forKey:@"c_fromiCalEvent"];         // Gives information for the flattenCycleRecord
      
      today = [NSCalendarDate date];
      _rangeStartDate = today;
      _rangeEndDate = [_rangeStartDate addYear:1 month:0 day: 0 hour: 0 minute: 0 second:0];
      theRange = [NGCalendarDateRange calendarDateRangeWithStartDate: _rangeStartDate
                                                             endDate: _rangeEndDate];
      
      // Return all the reccurences of the current event in an array. Each cell contains a dictionnary
      theRecords = [[NSMutableArray alloc] init];
      [SOGoAppointmentFolder flattenCycleRecord:theRecord forRange:theRange intoArray:theRecords];
      
      if ([[[[self parent] events] objectAtIndex:0] hasAlarms] && occurrenceCountAlarms > 0)
        // Case 1 : Both the master event and occurrences event(s) have alarms;
      {
        masterEvent = [NSNumber numberWithInt:[[[theRecords objectAtIndex:0] objectForKey:@"startDate"] timeIntervalSince1970]];
        intToday = [NSNumber numberWithInt:[today timeIntervalSince1970]];
        for (i=1; i <= occurrenceCountAlarms; i++)
        {
          occurrenceEvent = [NSNumber numberWithInt:[[[[[[[theRecords objectAtIndex:0] objectForKey:@"c_content"] objectAtIndex:0] events] objectAtIndex:i] startDate] timeIntervalSince1970]];
          if (([occurrenceEvent intValue] < [masterEvent intValue]) && ([occurrenceEvent intValue] > [intToday intValue]))
            // The next alarm is inside an occurrence
          {
            if ([vEvent isNotNull])
            {
              if ([occurrenceEvent intValue] < [[vEvent startDate] timeIntervalSince1970]) {
                vNextEvent = vEvent;
                vEvent = [[[[[theRecords objectAtIndex:i] objectForKey:@"c_content"] objectAtIndex:0] events] objectAtIndex:i];
              }
            }
            else
            {
              vEvent = [[[[[theRecords objectAtIndex:i] objectForKey:@"c_content"] objectAtIndex:0] events] objectAtIndex:i];
            }
          }
        }
        if ([vEvent isNotNull]) {
          if ([vNextEvent isNotNull]) {
            // Start the alarm code
          }
          else
          {
            if ([theRecords count] > 1) {
              _nextStartDate = [[theRecords objectAtIndex:1] objectForKey:@"startDate"];
              _nextEndDate = [[theRecords objectAtIndex:1] objectForKey:@"endDate"];
              intervalNextStartDate = [_nextStartDate timeIntervalSince1970];
              intervalNextEndDate = [_nextEndDate timeIntervalSince1970];
              rowNextStartDate = [NSString stringWithFormat:@"%d", intervalNextStartDate];
              rowNextEndDate = [NSString stringWithFormat:@"%d", intervalNextEndDate];
              hasAnotherRecord = YES;
            }
            anAlarm = [[vEvent alarms] lastObject];
            if ([[anAlarm action] caseInsensitiveCompare: @"DISPLAY"] == NSOrderedSame)
            {
              webstatus = [[anAlarm trigger] value: 0 ofAttribute: @"x-webstatus"];
              if ([webstatus caseInsensitiveCompare: @"ACTIVE"] == NSOrderedSame){
                if (hasAnotherRecord)
                {
                  [vEvent setStartDate:_nextStartDate];
                  [vEvent setEndDate:_nextEndDate];
                  [row setObject:rowNextStartDate forKey:@"c_enddate"];
                  [row setObject:rowNextEndDate forKey:@"c_startdate"];
                  nextAlarmDate = [anAlarm nextAlarmDate];
                }
              }
              else if (!webstatus || ([webstatus caseInsensitiveCompare: @"TRIGGERED"] != NSOrderedSame)){
                [vEvent setStartDate:_startDate];
                [vEvent setEndDate:_endDate];
                [row setObject:rowStartDate forKey:@"c_enddate"];
                [row setObject:rowEndDate forKey:@"c_startdate"];
                nextAlarmDate = [anAlarm nextAlarmDate];
              }
            }

          }
        }
        else
          // The next alarm is inside the master event
        {
          vEvent = [[[[[theRecords objectAtIndex:0] objectForKey:@"c_content"] objectAtIndex:0] events] lastObject];
          _startDate = [[theRecords objectAtIndex:0] objectForKey:@"startDate"];
          _endDate = [[theRecords objectAtIndex:0] objectForKey:@"endDate"];
          intervalStartDate = [[vEvent startDate] timeIntervalSince1970];
          intervalEndDate = [[vEvent endDate] timeIntervalSince1970];
          rowStartDate = [NSString stringWithFormat:@"%d", intervalStartDate];
          rowEndDate = [NSString stringWithFormat:@"%d", intervalEndDate];
          [vEvent setStartDate:_startDate];
          [vEvent setEndDate:_endDate];
          
          if ([theRecords count] > 1) {
            vNextEvent = [[[[[theRecords objectAtIndex:1] objectForKey:@"c_content"] objectAtIndex:0] events] lastObject];
            _nextStartDate = [[theRecords objectAtIndex:1] objectForKey:@"startDate"];
            _nextEndDate = [[theRecords objectAtIndex:1] objectForKey:@"endDate"];
            intervalNextStartDate = [_nextStartDate timeIntervalSince1970];
            intervalNextEndDate = [_nextEndDate timeIntervalSince1970];
            rowNextStartDate = [NSString stringWithFormat:@"%d", intervalStartDate];
            rowNextEndDate = [NSString stringWithFormat:@"%d", intervalEndDate];
            anotherAlarm = [[vNextEvent alarms] lastObject];
            if ([[anotherAlarm action] caseInsensitiveCompare: @"DISPLAY"] == NSOrderedSame)
            {
              webstatus = [[anotherAlarm trigger] value: 0 ofAttribute: @"x-webstatus"];
              if (!webstatus || ([webstatus caseInsensitiveCompare: @"TRIGGERED"] != NSOrderedSame))
                hasAnotherRecord = YES;
            }
          }
          anAlarm = [[vEvent alarms] lastObject];
          if ([[anAlarm action] caseInsensitiveCompare: @"DISPLAY"] == NSOrderedSame)
          {
            webstatus = [[anAlarm trigger] value: 0 ofAttribute: @"x-webstatus"];
            if ([webstatus caseInsensitiveCompare: @"ACTIVE"] == NSOrderedSame){
              if (hasAnotherRecord)
              {
                [vEvent setStartDate:_nextStartDate];
                [vEvent setEndDate:_nextEndDate];
                [row setObject:rowNextStartDate forKey:@"c_enddate"];
                [row setObject:rowNextEndDate forKey:@"c_startdate"];
                nextAlarmDate = [anAlarm nextAlarmDate];
              }
            }
            else if (!webstatus || ([webstatus caseInsensitiveCompare: @"TRIGGERED"] != NSOrderedSame)){
              [vEvent setStartDate:_startDate];
              [vEvent setEndDate:_endDate];
              [row setObject:rowStartDate forKey:@"c_enddate"];
              [row setObject:rowEndDate forKey:@"c_startdate"];
              nextAlarmDate = [anAlarm nextAlarmDate];
            }
          }
          
        }
      }
      else if (occurrenceCountAlarms > 0)
        // Case 2: Alarms on occurences events only;
        // Since there is no alarms on the master, the array(theRecords) only contains occurrences with alarms
      {
        if (occurrenceCountAlarms > 1) {
          vNextEvent = [[[[[theRecords objectAtIndex:1] objectForKey:@"c_content"] objectAtIndex:0] events] lastObject];
          _nextStartDate = [[theRecords objectAtIndex:1] objectForKey:@"startDate"];
          _nextEndDate = [[theRecords objectAtIndex:1] objectForKey:@"endDate"];
          intervalNextStartDate = [_nextStartDate timeIntervalSince1970];
          intervalNextEndDate = [_nextEndDate timeIntervalSince1970];
          rowNextStartDate = [NSString stringWithFormat:@"%d", intervalStartDate];
          rowNextEndDate = [NSString stringWithFormat:@"%d", intervalEndDate];
          anotherAlarm = [[vNextEvent alarms] lastObject];
          if ([[anotherAlarm action] caseInsensitiveCompare: @"DISPLAY"] == NSOrderedSame)
          {
            webstatus = [[anotherAlarm trigger] value: 0 ofAttribute: @"x-webstatus"];
            if (!webstatus || ([webstatus caseInsensitiveCompare: @"TRIGGERED"] != NSOrderedSame))
              hasAnotherOccurrenceAlarm = YES;
          }
        }
        vEvent = [[[[[theRecords objectAtIndex:0] objectForKey:@"c_content"] objectAtIndex:0] events] lastObject];
        _startDate = [[theRecords objectAtIndex:0] objectForKey:@"startDate"];
        _endDate = [[theRecords objectAtIndex:0] objectForKey:@"endDate"];
        intervalStartDate = [_startDate timeIntervalSince1970];
        intervalEndDate = [_endDate timeIntervalSince1970];
        rowStartDate = [NSString stringWithFormat:@"%d", intervalStartDate];
        rowEndDate = [NSString stringWithFormat:@"%d", intervalEndDate];
        
        anAlarm = [[vEvent alarms] lastObject];
        if ([[anAlarm action] caseInsensitiveCompare: @"DISPLAY"] == NSOrderedSame)
        {
          webstatus = [[anAlarm trigger] value: 0 ofAttribute: @"x-webstatus"];
          if ([webstatus caseInsensitiveCompare: @"ACTIVE"] == NSOrderedSame){
            if (hasAnotherOccurrenceAlarm) {
              [row setObject:rowNextStartDate forKey:@"c_enddate"];
              [row setObject:rowNextEndDate forKey:@"c_startdate"];
              nextAlarmDate = [anAlarm nextAlarmDate];
            }
          }
          else if (!webstatus || ([webstatus caseInsensitiveCompare: @"TRIGGERED"] != NSOrderedSame)){
            [row setObject:rowStartDate forKey:@"c_enddate"];
            [row setObject:rowEndDate forKey:@"c_startdate"];
            nextAlarmDate = [anAlarm nextAlarmDate];
          }
        }
      }
      else
        // Case 3 : Alarms on master event only;
        // Need to reajust the dates since the vevent is recurrent and there is only one entry in the quickTable
      {
        vEvent = [[[[[theRecords objectAtIndex:0] objectForKey:@"c_content"] objectAtIndex:0] events] lastObject];
        
        // Get the StartDate, EndDate in both local time and epoch time
        // 1- startDate, 2- endDate, 3- epoch startDate, 4- epoch endDate
        vEventDates = [self _vEventDates:[theRecords objectAtIndex:0]]
        _startDate = [[theRecords objectAtIndex:0] objectForKey:@"startDate"];
        _endDate = [[theRecords objectAtIndex:0] objectForKey:@"endDate"];
        
        // Set the value of the quicktable to the current occurrence so the alert display the associated date
        intervalStartDate = [_startDate timeIntervalSince1970];
        intervalEndDate = [_endDate timeIntervalSince1970];
        rowStartDate = [NSString stringWithFormat:@"%d", intervalStartDate];
        rowEndDate = [NSString stringWithFormat:@"%d", intervalEndDate];
        
        if ([theRecords count] > 1)
        {
          _nextStartDate = [[theRecords objectAtIndex:1] objectForKey:@"startDate"];
          _nextEndDate = [[theRecords objectAtIndex:1] objectForKey:@"endDate"];
          intervalNextStartDate = [_nextStartDate timeIntervalSince1970];
          intervalNextEndDate = [_nextEndDate timeIntervalSince1970];
          rowNextStartDate = [NSString stringWithFormat:@"%d", intervalNextStartDate];
          rowNextEndDate = [NSString stringWithFormat:@"%d", intervalNextEndDate];
          hasAnotherRecord = YES;
        }
        
        anAlarm = [[vEvent alarms] lastObject];
        if ([[anAlarm action] caseInsensitiveCompare: @"DISPLAY"] == NSOrderedSame)
        {
          webstatus = [[anAlarm trigger] value: 0 ofAttribute: @"x-webstatus"];
          if (([webstatus caseInsensitiveCompare: @"ACTIVE"] == NSOrderedSame) && hasAnotherRecord)
          {
            [vEvent setStartDate:_nextStartDate];
            [vEvent setEndDate:_nextEndDate];
            [row setObject:rowNextStartDate forKey:@"c_enddate"];
            [row setObject:rowNextEndDate forKey:@"c_startdate"];
            nextAlarmDate = [anAlarm nextAlarmDate];
          }
          else if (!webstatus || ([webstatus caseInsensitiveCompare: @"TRIGGERED"] != NSOrderedSame))
          {
            [vEvent setStartDate:_startDate];
            [vEvent setEndDate:_endDate];
            [row setObject:rowStartDate forKey:@"c_enddate"];
            [row setObject:rowEndDate forKey:@"c_startdate"];
            nextAlarmDate = [anAlarm nextAlarmDate];
          }
        }
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

- (NSArray *) _vEventDates
{
  // TO BE CONTINUED
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
