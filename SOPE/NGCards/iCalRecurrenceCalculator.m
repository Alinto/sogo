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

#import <Foundation/NSEnumerator.h>

#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import "iCalRecurrenceRule.h"
#import "NSString+NGCards.h"

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
static Class NSStringClass     = Nil;
static Class iCalRecurrenceRuleClass = Nil;
static Class dailyCalcClass   = Nil;
static Class weeklyCalcClass  = Nil;
static Class monthlyCalcClass = Nil;
static Class yearlyCalcClass  = Nil;

+ (void) initialize
{
  static BOOL didInit = NO;
  
  if (didInit) return;
  didInit = YES;

  NSCalendarDateClass     = [NSCalendarDate class];
  NSStringClass = [NSString class];
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

+ (void)    _fillRanges: (NSMutableArray *) ranges
              fromRules: (NSArray *) rrules
	    withinRange: (NGCalendarDateRange *) limits
       startingWithDate: (NGCalendarDateRange *) first
{
  NSEnumerator *rules;
  iCalRecurrenceRule *currentRule;
  iCalRecurrenceCalculator *calc;

  rules = [rrules objectEnumerator];
  while ((currentRule = [rules nextObject]))
    {
      if ([currentRule isKindOfClass: NSStringClass])
	currentRule =
	  [iCalRecurrenceRule
	    recurrenceRuleWithICalRepresentation: (NSString *) currentRule];

      calc = [self recurrenceCalculatorForRecurrenceRule: currentRule
		   withFirstInstanceCalendarDateRange: first];
      [ranges addObjectsFromArray:
		[calc recurrenceRangesWithinCalendarDateRange: limits]];
    }
}

+ (void) _removeExceptionsFromRanges: (NSMutableArray *) ranges
			   withRules: (NSArray *) exrules
			 withinRange: (NGCalendarDateRange *) limits
		    startingWithDate: (NGCalendarDateRange *) first
{
  NSEnumerator *rules;
  iCalRecurrenceRule *currentRule;
  iCalRecurrenceCalculator *calc;

  rules = [exrules objectEnumerator];
  while ((currentRule = [rules nextObject]))
    {
      if ([currentRule isKindOfClass: NSStringClass])
	currentRule =
	  [iCalRecurrenceRule
	    recurrenceRuleWithICalRepresentation: (NSString *) currentRule];
	  
      calc = [self recurrenceCalculatorForRecurrenceRule: currentRule
		   withFirstInstanceCalendarDateRange: first];
      [ranges removeObjectsInArray:
		[calc recurrenceRangesWithinCalendarDateRange: limits]];
    }
}

+ (NSArray *) _dates: (NSArray *) dateList
	 withinRange: (NGCalendarDateRange *) limits
{
  NSMutableArray *newDates;
  NSEnumerator *dates;
  NSCalendarDate *currentDate;

  newDates = [NSMutableArray array];

  dates = [dateList objectEnumerator];
  while ((currentDate = [dates nextObject]))
    {
      if ([currentDate isKindOfClass: NSStringClass])
	currentDate = [(NSString *) currentDate asCalendarDate];
      if ([limits containsDate: currentDate])
	[newDates addObject: currentDate];
    }

  return newDates;
}

+ (void) _removeExceptionDatesFromRanges: (NSMutableArray *) ranges
			       withDates: (NSArray *) exdates
			     withinRange: (NGCalendarDateRange *) limits
			startingWithDate: (NGCalendarDateRange *) first
{
  NSEnumerator *dates;
  NSCalendarDate *currentDate;
  NGCalendarDateRange *currentRange;
  unsigned int count, maxRanges;
  NSComparisonResult compare;

  dates = [[self _dates: exdates withinRange: limits] objectEnumerator];
  while ((currentDate = [dates nextObject]))
    {
      maxRanges = [ranges count];
      for (count = maxRanges; count > 0; count--)
	{
	  currentRange = [ranges objectAtIndex: count - 1];
          compare = [[currentRange startDate] compare: currentDate];
          if ((compare == NSOrderedAscending || compare == NSOrderedSame) &&
              [[currentRange endDate] compare: currentDate] == NSOrderedDescending)
            {
              [ranges removeObjectAtIndex: count - 1];
            }
	}
    }
}

+ (NSArray *)
 recurrenceRangesWithinCalendarDateRange: (NGCalendarDateRange *) _r
	  firstInstanceCalendarDateRange: (NGCalendarDateRange *) _fir
			 recurrenceRules: (NSArray *) _rRules
			  exceptionRules: (NSArray *) _exRules
			  exceptionDates: (NSArray *) _exDates
{
  NSMutableArray *ranges;

  ranges = [NSMutableArray arrayWithCapacity: 64];

  if ([_rRules count] > 0)
    {
      [self _fillRanges: ranges fromRules: _rRules
	    withinRange: _r startingWithDate: _fir];
      [self _removeExceptionsFromRanges: ranges withRules: _exRules
	    withinRange: _r startingWithDate: _fir];
      [self _removeExceptionDatesFromRanges: ranges withDates: _exDates
	    withinRange: _r startingWithDate: _fir];
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
  iCalWeekDay weekDays[] = {iCalWeekDaySunday, iCalWeekDayMonday,
			    iCalWeekDayTuesday, iCalWeekDayWednesday,
			    iCalWeekDayThursday, iCalWeekDayFriday,
			    iCalWeekDaySaturday};

  return weekDays[[self offsetFromSundayForJulianNumber: _jn]];
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
  */
  return [rrule untilDate];
}

@end /* iCalRecurrenceCalculator */
