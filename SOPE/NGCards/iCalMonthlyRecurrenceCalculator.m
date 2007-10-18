/*
  Copyright (C) 2004-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess
  
  This file is part of SOPE.
  
  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.
  
  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.
  
  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <NGExtensions/NSCalendarDate+misc.h>

#import "iCalRecurrenceCalculator.h"

@interface iCalMonthlyRecurrenceCalculator : iCalRecurrenceCalculator
@end

#import <NGExtensions/NGCalendarDateRange.h>
#import "iCalRecurrenceRule.h"
#import "NSCalendarDate+ICal.h"
#import <string.h>

@interface iCalRecurrenceCalculator(PrivateAPI)
- (NSCalendarDate *)lastInstanceStartDate;
@end

// #define HEAVY_DEBUG 1

@implementation iCalMonthlyRecurrenceCalculator

typedef BOOL NGMonthSet[12];
typedef BOOL NGMonthDaySet[32]; // 0 is unused

static void NGMonthDaySet_clear(NGMonthDaySet *daySet) {
  register unsigned i;
  
  for (i = 1; i <= 31; i++)
    (*daySet)[i] = NO;
}

static void NGMonthDaySet_copyOrUnion(NGMonthDaySet *base, NGMonthDaySet *new,
                                      BOOL doCopy)
{
  register unsigned i;
  
  if (doCopy)
    memcpy(base, new, sizeof(NGMonthDaySet));
  else {
    for (i = 1; i <= 31; i++) {
      if (!(*new)[i])
        (*base)[i] = NO;
    }
  }
}

static BOOL NGMonthDaySet_fillWithByMonthDay(NGMonthDaySet *daySet, 
                                             NSArray *byMonthDay)
{
  /* list of days in the month */
  unsigned i, count;
  BOOL ok;
  
  NGMonthDaySet_clear(daySet);

  for (i = 0, count = [byMonthDay count], ok = YES; i < count; i++) {
    int dayInMonth; /* -31..-1 and 1..31 */
        
    if ((dayInMonth = [[byMonthDay objectAtIndex:i] intValue]) == 0) {
      ok = NO;
      continue; /* invalid value */
    }
    if (dayInMonth > 31) {
      ok = NO;
      continue; /* error, value to large */
    }
    if (dayInMonth < -31) {
      ok = NO;
      continue; /* error, value to large */
    }
    
    /* adjust negative days */
        
    if (dayInMonth < 0) {
      /* eg: -1 == last day in month, 30 days => 30 */
      dayInMonth = 32 - dayInMonth /* because we count from 1 */;
    }
    
    (*daySet)[dayInMonth] = YES;
  }
  return ok;
}

static inline unsigned iCalDoWForNSDoW(int dow) {
  switch (dow) {
  case 0: return iCalWeekDaySunday;
  case 1: return iCalWeekDayMonday;
  case 2: return iCalWeekDayTuesday;
  case 3: return iCalWeekDayWednesday;
  case 4: return iCalWeekDayThursday;
  case 5: return iCalWeekDayFriday;
  case 6: return iCalWeekDaySaturday;
  case 7: return iCalWeekDaySunday;
  default: return 0;
  }
}

#if HEAVY_DEBUG
static NSString *dowEN[8] = { 
  @"SU", @"MO", @"TU", @"WE", @"TH", @"FR", @"SA", @"SU-"
};
#endif

static void NGMonthDaySet_fillWithByDayX(NGMonthDaySet *daySet, 
                                         unsigned dayMask,
					 unsigned firstDoWInMonth,
					 unsigned numberOfDaysInMonth,
                                         int occurrence1)
{
  // TODO: this is called 'X' because the API doesn't allow for full iCalendar
  //       functionality. The daymask must be a list of occurence+dow
  register unsigned dayInMonth;
  register int dow; /* current day of the week */
  int occurrences[7] = { 0, 0, 0, 0, 0, 0, 0 } ;
  
  NGMonthDaySet_clear(daySet);
  
  if (occurrence1 >= 0) {
    for (dayInMonth = 1, dow = firstDoWInMonth; dayInMonth<=31; dayInMonth++) {
      // TODO: complete me
      
      if (dayMask & iCalDoWForNSDoW(dow)) {
        if (occurrence1 == 0)
	  (*daySet)[dayInMonth] = YES;
        else { /* occurrence1 > 0 */
	  occurrences[dow] = occurrences[dow] + 1;
	  
	  if (occurrences[dow] == occurrence1) 
	    (*daySet)[dayInMonth] = YES;
        }
      }
      
      dow = (dow == 6 /* Sat */) ? 0 /* Sun */ : (dow + 1);
    }
  }
  else {
    int lastDoWInMonthSet;
    
    /* get the last dow in the set (not necessarily the month!) */
    for (dayInMonth = 1, dow = firstDoWInMonth; 
	 dayInMonth < numberOfDaysInMonth;dayInMonth++)
      dow = (dow == 6 /* Sat */) ? 0 /* Sun */ : (dow + 1);
    lastDoWInMonthSet = dow;
    
#if HEAVY_DEBUG
    NSLog(@"LAST DOW IN SET: %i / %@", 
	  lastDoWInMonthSet, dowEN[lastDoWInMonthSet]);
#endif
    /* start at the end of the set */
    for (dayInMonth = numberOfDaysInMonth, dow = lastDoWInMonthSet; 
	 dayInMonth >= 1; dayInMonth--) {
      // TODO: complete me
      
#if HEAVY_DEBUG
      NSLog(@"  CHECK day-of-month %02i, "
	    @" dow=%i/%@ (first=%i/%@, last=%i/%@)",
	    dayInMonth, 
	    dow, dowEN[dow],
	    firstDoWInMonth, dowEN[firstDoWInMonth],
	    lastDoWInMonthSet, dowEN[lastDoWInMonthSet]
	    );
#endif
      
      if (dayMask & iCalDoWForNSDoW(dow)) {
	occurrences[dow] = occurrences[dow] + 1;
#if HEAVY_DEBUG
	NSLog(@"    MATCH %i/%@ count: %i occurences=%i",
	      dow, dowEN[dow], occurrences[dow], occurrence1);
#endif
	  
	if (occurrences[dow] == -occurrence1) {
#if HEAVY_DEBUG
	  NSLog(@"    COUNT MATCH");
#endif
	  (*daySet)[dayInMonth] = YES;
	}
      }
      
      dow = (dow == 0 /* Sun */) ? 6 /* Sat */ : (dow - 1);
    }
  }
}

- (BOOL)_addInstanceWithStartDate:(NSCalendarDate *)_startDate
  limitDate:(NSCalendarDate *)_until
  limitRange:(NGCalendarDateRange *)_r
  toArray:(NSMutableArray *)_ranges
{
  NGCalendarDateRange *r;
  NSCalendarDate *end;
  
  /* check whether we are still in the limits */

  // TODO: I think we should check in here whether we succeeded the
  //       repeatCount. Currently we precalculate that info in the
  //       -lastInstanceStartDate method.
  if (_until != nil) {
    /* Note: the 'until' in the rrule is inclusive as per spec */
    if ([_until compare:_startDate] == NSOrderedAscending)
      /* start after until */
      return NO; /* Note: we assume that the algorithm is sequential */
  }

  /* create end date */

  end = [_startDate addTimeInterval:[self->firstRange duration]];
  [end setTimeZone:[_startDate timeZone]];
    
  /* create range and check whether its in the requested range */
  
  r = [[NGCalendarDateRange alloc] initWithStartDate:_startDate endDate:end];
  if ([_r containsDateRange:r])
    [_ranges addObject:r];
  [r release]; r = nil;
  
  return YES;
}

- (NSArray *)recurrenceRangesWithinCalendarDateRange:(NGCalendarDateRange *)_r{
  /* main entry */
  // TODO: check whether this is OK for multiday-events!
  NSMutableArray *ranges;
  NSTimeZone     *timeZone;
  NSCalendarDate *eventStartDate, *rStart, *rEnd, *until;
  int            eventDayOfMonth;
  unsigned       monthIdxInRange, numberOfMonthsInRange, interval;
  int            diff;
  NGMonthSet byMonthList = { // TODO: fill from rrule, this is the default
    /* enable all months of the year */
    YES, YES, YES, YES, YES, YES, 
    YES, YES, YES, YES, YES, YES
  };
  NSArray       *byMonthDay; // array of ints (-31..-1 and 1..31)
  NGMonthDaySet byMonthDaySet;
  
  eventStartDate  = [self->firstRange startDate];
  eventDayOfMonth = [eventStartDate dayOfMonth];
  timeZone        = [eventStartDate timeZone];
  rStart          = [_r startDate];
  rEnd            = [_r endDate];
  interval        = [self->rrule repeatInterval];
  until           = [self lastInstanceStartDate]; // TODO: maybe replace
  byMonthDay      = [self->rrule byMonthDay];


  /* check whether the range to be processed is beyond the 'until' date */  
  if (until != nil) {
    if ([until compare:rStart] == NSOrderedAscending) /* until before start */
      return nil;
    if ([until compare:rEnd] == NSOrderedDescending) /* end before until */
      rEnd = until; // TODO: why is that? end is _before_ until?
  }

  
  /* precalculate month days (same for all instances) */

  if (byMonthDay != nil) {
#if HEAVY_DEBUG
    NSLog(@"byMonthDay: %@", byMonthDay);
#endif
    NGMonthDaySet_fillWithByMonthDay(&byMonthDaySet, byMonthDay);
  }
  
  
  // TODO: I think the 'diff' is to skip recurrence which are before the
  //       requested range. Not sure whether this is actually possible, eg
  //       the repeatCount must be processed from the start.
  diff = [eventStartDate monthsBetweenDate:rStart];
  if ((diff != 0) && [rStart compare:eventStartDate] == NSOrderedAscending)
    diff = -diff;
  
  numberOfMonthsInRange  = [rStart monthsBetweenDate:rEnd] + 1;
  ranges = [NSMutableArray arrayWithCapacity:numberOfMonthsInRange];
  
  /* 
     Note: we do not add 'eventStartDate', this is intentional, the event date
           itself is _not_ necessarily part of the sequence, eg with monthly
           byday recurrences.
  */
  
  for (monthIdxInRange = 0; monthIdxInRange < numberOfMonthsInRange; 
       monthIdxInRange++) {
    NSCalendarDate *cursor;
    unsigned       numDaysInMonth;
    int            monthIdxInRecurrence, dom;
    NGMonthDaySet  monthDays;
    BOOL           didByFill, doCont;
    
    monthIdxInRecurrence = diff + monthIdxInRange;
    
    if (monthIdxInRecurrence < 0)
      continue;
    
    /* first check whether we are in the interval */

    if ((monthIdxInRecurrence % interval) != 0)
      continue;

    /*
      Then the sequence is:
      - check whether the month is in the BYMONTH list
    */
    
    /*
      Note: the function below adds exactly a month, eg:
            2007-01-30 + 1month => 2007-02-*28*!!
    */
    cursor = [eventStartDate dateByAddingYears:0
                             months:(diff + monthIdxInRange)
                             days:0];
    [cursor setTimeZone:timeZone];
    numDaysInMonth = [cursor numberOfDaysInMonth];
    

    /* check whether we match the bymonth specification */
    
    if (!byMonthList[[cursor monthOfYear] - 1])
      continue;
    
    
    /* check 'day level' byXYZ rules */
    
    didByFill = NO;
    
    if (byMonthDay != nil) { /* list of days in the month */
      NGMonthDaySet_copyOrUnion(&monthDays, &byMonthDaySet, !didByFill);
      didByFill = YES;
    }
    
    if ([self->rrule byDayMask] != 0) { // TODO: replace the mask with an array
      NGMonthDaySet ruleset;
      unsigned firstDoWInMonth;
      
      firstDoWInMonth = [[cursor firstDayOfMonth] dayOfWeek];
      
      NGMonthDaySet_fillWithByDayX(&ruleset, 
                                   [self->rrule byDayMask],
				   firstDoWInMonth,
				   [cursor numberOfDaysInMonth],
                                   [self->rrule byDayOccurence1]);
      NGMonthDaySet_copyOrUnion(&monthDays, &ruleset, !didByFill);
      didByFill = YES;
    }
    
    if (!didByFill) {
      /* no rules applied, take the dayOfMonth of the startDate */
      NGMonthDaySet_clear(&monthDays);
      monthDays[eventDayOfMonth] = YES;
    }
    
    // TODO: add processing of byhour/byminute/bysecond etc
    
    /* 
       Next step is to create NSCalendarDate instances from our 'monthDays'
       set. We walk over each day of the 'monthDays' set. If its flag isn't
       set, we continue.
       If its set, we add the date to the instance.
       
       The 'cursor' is the *startdate* of the event (not necessarily a
       component of the sequence!) plus the currently processed month.
       Eg:
         startdate: 2007-01-30
	 cursor[1]: 2007-01-30
	 cursor[2]: 2007-02-28 <== Note: we have February!
    */
    
    for (dom = 1, doCont = YES; dom <= numDaysInMonth && doCont; dom++) {
      NSCalendarDate *start;
      
      if (!monthDays[dom])
	continue;

      // TODO: what is this good for?
      /*
	Here we need to correct the date. Remember that the startdate given in
	the event is not necessarily a date of the sequence!

	The 'numDaysInMonth' localvar contains the number of days in the
	current month (eg 31 for Januar, 28 for most February's, etc)
	
	Eg: MONTHLY;BYDAY=-1WE (last wednesday, every month)
	
	  cursor:  2007-01-30 (eventDayOfMonth = 30)
	  =>start: 2007-01-31 (dom = 31)
	  cursor:  2007-02-28 (eventDayOfMonth = 30)
	  =>start: 2007-02-28 (dom = 28)
	
	Note: in case the cursor already had an event-day overflow, that is the
	      'eventDayOfMonth' is bigger than the 'numDaysInMonth', the cursor
	      will already be corrected!
	      Eg:
	        start was:      2007-01-30
		cursor will be: 2007-02-28
      */
      if (eventDayOfMonth == dom) {
	start = cursor;
      }
      else {
	int maxDay = 
	  eventDayOfMonth > numDaysInMonth ? numDaysInMonth : eventDayOfMonth;
	
	start = [cursor dateByAddingYears:0 months:0 days:(dom - maxDay)];
      }

      /*
	Setup for 2007-02-28, MONTHLY;BYDAY=-1WE.
	  dom:             28
	  eventDayOfMonth: 31
	  cursor:          2007-02-28
	  start:           2007-02-25 <== WRONG
      */

#if HEAVY_DEBUG
      NSLog(@"DOM %i EDOM %i NUMDAYS %i START: %@ CURSOR: %@", 
	    dom, eventDayOfMonth, numDaysInMonth,
	    start, cursor);
#endif
      doCont = [self _addInstanceWithStartDate:start
		     limitDate:until
		     limitRange:_r
		     toArray:ranges];
    }
    if (!doCont) break; /* reached some limit */
  }
  return ranges;
}

- (NSCalendarDate *)lastInstanceStartDate {
  if ([self->rrule repeatCount] > 0) {
    NSCalendarDate *until;
    unsigned       months, interval;
    
    interval = [self->rrule repeatInterval];
    months   = [self->rrule repeatCount] - 1 /* the first counts as one! */;
    
    if (interval > 0)
      months *= interval;
    
    until = [[self->firstRange startDate] dateByAddingYears:0
                                          months:months
                                          days:0];
    return until;
  }
  return [super lastInstanceStartDate];
}

@end /* iCalMonthlyRecurrenceCalculator */
