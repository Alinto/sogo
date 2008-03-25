/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  
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
#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import "iCalRecurrenceRule.h"
#import "NSCalendarDate+ICal.h"


#import "iCalRecurrenceCalculator.h"

/* class cluster */


/* Private */

@interface iCalRecurrenceCalculator (PrivateAPI)
- (NSCalendarDate *)lastInstanceStartDate;

- (unsigned)offsetFromSundayForJulianNumber:(long)_jn;
- (unsigned)offsetFromSundayForWeekDay:(iCalWeekDay)_weekDay;
- (unsigned)offsetFromSundayForCurrentWeekStart;
  
- (iCalWeekDay)weekDayForJulianNumber:(long)_jn;
@end

@implementation iCalRecurrenceCalculator

static Class NSCalendarDateClass     = Nil;
static Class iCalRecurrenceRuleClass = Nil;
static Class dailyCalcClass   = Nil;
static Class weeklyCalcClass  = Nil;
static Class monthlyCalcClass = Nil;
static Class yearlyCalcClass  = Nil;

+ (void)initialize {
  static BOOL didInit = NO;
  
  if (didInit) return;
  didInit = YES;

  NSCalendarDateClass     = [NSCalendarDate class];
  iCalRecurrenceRuleClass = [iCalRecurrenceRule class];

  dailyCalcClass   = NSClassFromString(@"iCalDailyRecurrenceCalculator");
  weeklyCalcClass  = NSClassFromString(@"iCalWeeklyRecurrenceCalculator");
  monthlyCalcClass = NSClassFromString(@"iCalMonthlyRecurrenceCalculator");
  yearlyCalcClass  = NSClassFromString(@"iCalYearlyRecurrenceCalculator");
}

/* factory */

+ (id)  recurrenceCalculatorForRecurrenceRule: (iCalRecurrenceRule *) _rrule
	   withFirstInstanceCalendarDateRange: (NGCalendarDateRange *) _range
{
  iCalRecurrenceFrequency freq;
  Class calcClass;
  id calc;

  freq = [_rrule frequency];
  if (freq == iCalRecurrenceFrequenceDaily)
    calcClass = dailyCalcClass;
  else if (freq == iCalRecurrenceFrequenceWeekly)
    calcClass = weeklyCalcClass;
  else if (freq == iCalRecurrenceFrequenceMonthly)
    calcClass = monthlyCalcClass;
  else if (freq == iCalRecurrenceFrequenceYearly)
    calcClass = yearlyCalcClass;
  else
    calcClass = Nil;

  if (calcClass)
    {
      calc = [[calcClass alloc] initWithRecurrenceRule:_rrule
				firstInstanceCalendarDateRange: _range];
      [calc autorelease];
    }
  else
    {
      [self errorWithFormat: @"unsupported rrule frequency: %@", _rrule];
      calc = nil;
    }

  return calc;
}

/* complex calculation convenience */

+ (NSArray *)recurrenceRangesWithinCalendarDateRange:(NGCalendarDateRange *)_r
  firstInstanceCalendarDateRange:(NGCalendarDateRange *)_fir
  recurrenceRules:(NSArray *)_rRules
  exceptionRules:(NSArray *)_exRules
  exceptionDates:(NSArray *)_exDates
{
  id                       rule;
  iCalRecurrenceCalculator *calc;
  NSMutableArray           *ranges;
  NSMutableArray           *exDates;
  unsigned                 i, count, rCount;
  
  ranges = [NSMutableArray arrayWithCapacity:64];
  
  for (i = 0, count  = [_rRules count]; i < count; i++) {
    NSArray *rs;

    rule = [_rRules objectAtIndex:i];
    if (![rule isKindOfClass:iCalRecurrenceRuleClass])
      rule = [iCalRecurrenceRule recurrenceRuleWithICalRepresentation:rule];
        
    calc = [self recurrenceCalculatorForRecurrenceRule:rule
                 withFirstInstanceCalendarDateRange:_fir];

    rs   = [calc recurrenceRangesWithinCalendarDateRange:_r];
    [ranges addObjectsFromArray:rs];
  }
  
  if ([ranges count] == 0)
    return nil;
  
  /* test if any exceptions do match */
  
  for (i = 0, count = [_exRules count]; i < count; i++) {
    NSArray *rs;

    rule = [_exRules objectAtIndex:i];
    if (![rule isKindOfClass:iCalRecurrenceRuleClass])
      rule = [iCalRecurrenceRule recurrenceRuleWithICalRepresentation:rule];

    calc = [self recurrenceCalculatorForRecurrenceRule:rule
                 withFirstInstanceCalendarDateRange:_fir];
    rs   = [calc recurrenceRangesWithinCalendarDateRange:_r];
    [ranges removeObjectsInArray:rs];
  }
  
  if (![ranges isNotEmpty])
    return nil;
  
  /* exception dates */

  if ((count = [_exDates count]) == 0)
    return ranges;
  
  /* sort out exDates not within range */

  exDates = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    id exDate;

    exDate = [_exDates objectAtIndex:i];
    if (![exDate isKindOfClass:NSCalendarDateClass])
      exDate = [NSCalendarDate calendarDateWithICalRepresentation:exDate];
    
    if ([_r containsDate:exDate])
      [exDates addObject:exDate];
  }

  /* remove matching exDates from ranges */

  if ((count = [exDates count]) == 0)
    return ranges;
  
  for (i = 0, rCount = [ranges count]; i < count; i++) {
    NSCalendarDate      *exDate;
    NGCalendarDateRange *r;
    unsigned            k;

    exDate = [exDates objectAtIndex:i];
    
    for (k = 0; k < rCount; k++) {
      unsigned rIdx;
      
      rIdx = (rCount - k) - 1;
      r    = [ranges objectAtIndex:rIdx];
      if ([r containsDate:exDate]) {
        [ranges removeObjectAtIndex:rIdx];
        rCount--;
        break; /* this is safe because we know that ranges don't overlap */
      }
    }
  }
  return ranges;
}


/* init */

- (id)    initWithRecurrenceRule: (iCalRecurrenceRule *) _rrule
  firstInstanceCalendarDateRange: (NGCalendarDateRange *) _range
{
  if ((self = [super init]))
    {
      rrule = [_rrule retain];
      firstRange = [_range retain];
    }

  return self;  
}

- (void) dealloc
{
  [firstRange release];
  [rrule release];
  [super dealloc];
}

/* helpers */

- (unsigned) offsetFromSundayForJulianNumber: (long) _jn
{
  return (unsigned)((int) (_jn + 1.5)) % 7;
}

- (unsigned) offsetFromSundayForWeekDay: (iCalWeekDay) _weekDay
{
  unsigned offset;
  
  switch (_weekDay)
    {
    case iCalWeekDaySunday:
      offset = 0; break;
    case iCalWeekDayMonday:
      offset = 1; break;
    case iCalWeekDayTuesday:
      offset = 2; break;
    case iCalWeekDayWednesday:
      offset = 3; break;
    case iCalWeekDayThursday:
      offset = 4; break;
    case iCalWeekDayFriday:
      offset = 5; break;
    case iCalWeekDaySaturday:
      offset = 6; break;
    default:
      offset = 0; break;
    }

  return offset;
}

- (unsigned) offsetFromSundayForCurrentWeekStart
{
  return [self offsetFromSundayForWeekDay: [rrule weekStart]];
}

- (iCalWeekDay) weekDayForJulianNumber: (long)_jn
{
  unsigned int day;
  iCalWeekDay weekDay;
  iCalWeekDay weekDays[] = {iCalWeekDaySunday, iCalWeekDayMonday,
			    iCalWeekDayTuesday, iCalWeekDayWednesday,
			    iCalWeekDayThursday, iCalWeekDayFriday,
			    iCalWeekDaySaturday};

  if (day < 7)
    weekDay = weekDays[day];
  else
    {
      [self errorWithFormat:
	      @"got unexpected weekday: %d (falling back on sunday)", day];
      weekDay = iCalWeekDaySunday;
    }

  return weekDay;
}

/* calculation */

- (NSArray *)
 recurrenceRangesWithinCalendarDateRange: (NGCalendarDateRange *) _r
{
  return nil; /* subclass responsibility */
}

- (BOOL) doesRecurrWithinCalendarDateRange: (NGCalendarDateRange *) _range
{
  return ([[self recurrenceRangesWithinCalendarDateRange: _range] count]
	  > 0);
}

- (NGCalendarDateRange *) firstInstanceCalendarDateRange
{
  return firstRange;
}

- (NGCalendarDateRange *) lastInstanceCalendarDateRange
{
  NSCalendarDate *start, *end;
  NGCalendarDateRange *range;

  range = nil;

  start = [self lastInstanceStartDate];
  if (start)
    {
      end = [start addTimeInterval: [firstRange duration]];
      range = [NGCalendarDateRange calendarDateRangeWithStartDate: start
				   endDate: end];
    }

  return range;
}

- (NSCalendarDate *) lastInstanceStartDate
{
  /* 
     NOTE: this is horribly inaccurate and doesn't even consider the use
           of repeatCount. It MUST be implemented by subclasses properly!
	   However, it does the trick for SOGo 1.0 - that's why it's left here.
  */
  return [rrule untilDate];
}

@end /* iCalRecurrenceCalculator */
