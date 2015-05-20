/* iCalByDayMask.m - this file is part of SOPE
 *
 * Copyright (C) 2010-2015 Inverse inc.
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
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import "iCalByDayMask.h"

#import <ctype.h>
#import <math.h>

@interface iCalByDayMask (PrivateAPI)

- (int) _iCalWeekOccurrenceIntValue: (iCalWeekOccurrence) weekOccurrence;

@end

@implementation iCalByDayMask

+ (id) byDayMaskWithDays: (iCalWeekOccurrences) theDays
{
  id o;

  o = [[self alloc] initWithDays: theDays];
  AUTORELEASE(o);

  return o;
}

- (id) initWithDays: (iCalWeekOccurrences) theDays
{
  self = [super init];

  if (self)
    {
      memcpy (days, theDays, sizeof(iCalWeekOccurrences));
    }

  return self;
}

+ (id) byDayMaskWithWeekDays
{
  id o;
  iCalWeekOccurrences d;

  d[iCalWeekDaySunday] = 0;
  d[iCalWeekDayMonday] = iCalWeekOccurrenceAll;
  d[iCalWeekDayTuesday] = iCalWeekOccurrenceAll;
  d[iCalWeekDayWednesday] = iCalWeekOccurrenceAll;
  d[iCalWeekDayThursday] = iCalWeekOccurrenceAll;
  d[iCalWeekDayFriday] = iCalWeekOccurrenceAll;
  d[iCalWeekDaySaturday] = 0;
  o = [[self alloc] initWithDays: d];
  AUTORELEASE(o);

  return o;
}

+ (id) byDayMaskWithRuleString: (NSString *) byDayRule
{
  id o;

  o = [[self alloc] initWithRuleString: byDayRule];
  AUTORELEASE(o);

  return o;
}

- (id) initWithRuleString: (NSString *) byDayRule
{
  NSArray *values;

  unsigned int count, max;
  NSString *value;
  unichar c, chars[2];
  unsigned int valueLength, i, digitStart, order;
  iCalWeekDay day;
  BOOL reverse;

  self = [super init];

  if (self)
    {
      memset(days, 0, 7 * sizeof(iCalWeekOccurrence));

      if ([byDayRule length] > 0)
	{
	  values = [byDayRule componentsSeparatedByString: @","];
	  max = [values count];
	  for (count = 0; count < max; count++)
	    {
	      value = [[values objectAtIndex: count] uppercaseString];
	      valueLength = [value length];
	      if (valueLength > 1)
		{
		  day = iCalWeekDayUnknown;
		  reverse = NO;
		  digitStart = 0;
		  order = 0;

		  [value getCharacters: chars
				 range: NSMakeRange(valueLength - 2, 2)];

		  switch (chars[0])
		    {
		    case 'M': day = iCalWeekDayMonday;
		      break;
		    case 'W': day = iCalWeekDayWednesday;
		      break;
		    case 'F': day = iCalWeekDayFriday;
		      break;
		    case 'T':
		      if (chars[1] == 'U')
			day = iCalWeekDayTuesday;
		      else if (chars[1] == 'H')
			day = iCalWeekDayThursday;
		      break;
		    case 'S':
		      if (chars[1] == 'A')
			day = iCalWeekDaySaturday;
		      else if (chars[1] == 'U')
			day = iCalWeekDaySunday;
		      break;
		    }

		  if (day != iCalWeekDayUnknown)
		    {
		      c = [value characterAtIndex: 0];
		      if (c == '-')
			{
			  digitStart = 1;
			  reverse = YES;
			  c = [value characterAtIndex: 1];
			}
		      else if (c == '+')
			{
			  digitStart = 1;
			  c = [value characterAtIndex: 1];
			}

		      i = digitStart;

		      while (i < valueLength && isdigit(c))
			{
			  i++;
			  c = [value characterAtIndex: i];
			}

		      if (i != digitStart)
			order = [[value substringWithRange: NSMakeRange(digitStart, (i - digitStart))] intValue];

		      if (order > 0 && order < 6)
			{
			  order = pow (2, order - 1);
			  if (reverse)
			    order = order << 5;
			  days[day] |= order;
			  //NSLog(@"*** iCalByDayMask [%i] %@ : day = %i, order = %i, result = %i", count, byDayRule, day, order, days[day]);
			}
		      else
			{
			  days[day] = iCalWeekOccurrenceAll;
			}
		    }
		}
	    }
	}
    }

  return self;
}

+ (id) byDayMaskWithDaysAndOccurrences: (NSArray *) values
{
  id o;

  o = [[self alloc] initWithDaysAndOccurrences: values];
  AUTORELEASE(o);

  return o;
}

- (id) initWithDaysAndOccurrences: (NSArray *) values
{
  unsigned int count, max;
  NSString *value;
  unichar c, chars[2];
  unsigned int valueLength, i, digitStart, order;
  iCalWeekDay day;
  id mask;
  BOOL reverse;

  self = [super init];

  if (self)
    {
      memset(days, 0, 7 * sizeof(iCalWeekOccurrence));

      max = [values count];
      for (count = 0; count < max; count++)
        {
          mask = [values objectAtIndex: count];
          if (![mask isKindOfClass: [NSDictionary class]])
            continue;
          value = [[mask objectForKey: @"day"] uppercaseString];
          valueLength = [value length];
          if (valueLength > 1)
            {
              day = iCalWeekDayUnknown;
              reverse = NO;
              digitStart = 0;
              order = 0;

              [value getCharacters: chars
                             range: NSMakeRange(0, valueLength)];

              switch (chars[0])
                {
                case 'M': day = iCalWeekDayMonday;
                  break;
                case 'W': day = iCalWeekDayWednesday;
                  break;
                case 'F': day = iCalWeekDayFriday;
                  break;
                case 'T':
                  if (chars[1] == 'U')
                    day = iCalWeekDayTuesday;
                  else if (chars[1] == 'H')
                    day = iCalWeekDayThursday;
                  break;
                case 'S':
                  if (chars[1] == 'A')
                    day = iCalWeekDaySaturday;
                  else if (chars[1] == 'U')
                    day = iCalWeekDaySunday;
                  break;
                }

              if (day != iCalWeekDayUnknown)
                {
                  value = [mask objectForKey: @"occurrence"];
                  valueLength = [value length];
                  if (valueLength > 0)
                    {
                      c = [value characterAtIndex: 0];
                      if (c == '-')
                        {
                          digitStart = 1;
                          reverse = YES;
                        }
                      else if (c == '+')
                        {
                          digitStart = 1;
                        }

                      i = digitStart;
                      while (i < valueLength)
                        {
                          c = [value characterAtIndex: i];
                          i++;
                          if (!isdigit(c))
                            break;
                        }

                      if (i != digitStart)
                        order = [[value substringWithRange: NSMakeRange(digitStart, (i - digitStart))] intValue];
                    }

                  if (order > 0 && order < 6)
                    {
                      order = pow (2, order - 1);
                      if (reverse)
                        order = order << 5;
                      days[day] |= order;
                      //NSLog(@"*** iCalByDayMask [%i] %@ : day = %i, order = %i, result = %i", count, byDayRule, day, order, days[day]);
                    }
                  else
                    {
                      days[day] = iCalWeekOccurrenceAll;
                    }
                }
	    }
	}
    }

  return self;
}

- (void) dealloc
{
  [super dealloc];
}

/**
 * The week occurrence has no meaning for a DAILY or WEEKLY frequency;
 * therefore, this method ignores the week occurrence.
 */
- (BOOL) occursOnDay: (iCalWeekDay) weekDay
{
  return days[weekDay] > 0;
}

- (BOOL) occursOnDay: (iCalWeekDay) weekDay
  withWeekOccurrence: (iCalWeekOccurrence) occurrence
{
  return (days[weekDay] & occurrence) > 0;
}

- (BOOL) occursOnDay: (iCalWeekDay) weekDay
      withWeekNumber: (int) week
{
  unsigned int absWeek, order;

  absWeek = abs (week);
  order = 0;
  if (absWeek > 0 && absWeek < 6)
    {
      order = pow (2, absWeek - 1);
      if (week < 0)
	order = order << 5;
    }

  return ((days[weekDay] & order) > 0);
}

- (BOOL) isWeekDays
{
  return (days[iCalWeekDaySunday]    == 0 &&
	  days[iCalWeekDayMonday]    == iCalWeekOccurrenceAll &&
	  days[iCalWeekDayTuesday]   == iCalWeekOccurrenceAll &&
	  days[iCalWeekDayWednesday] == iCalWeekOccurrenceAll &&
	  days[iCalWeekDayThursday]  == iCalWeekOccurrenceAll &&
	  days[iCalWeekDayFriday]    == iCalWeekOccurrenceAll &&
	  days[iCalWeekDaySaturday]  == 0);
}

- (iCalWeekDay) firstDay
{
  int i;
  iCalWeekDay day;

  day = -1;
  for (i = 0; day == -1 && i < 7; i++)
    {
      if (days[i])
        day = i;
    }

  return day;
}

- (int) firstOccurrence
{
  int occurrence;
  iCalWeekDay day;

  occurrence = 0;
  day = [self firstDay];

  if (day > -1 && days[day] != iCalWeekOccurrenceAll)
    occurrence = [self _iCalWeekOccurrenceIntValue: days[day]];

  return occurrence;
}

- (iCalWeekOccurrences *) weekDayOccurrences
{
  return &days;
}

- (int) _iCalWeekOccurrenceIntValue: (iCalWeekOccurrence) weekOccurrence
{
  int i = 0;

  switch (weekOccurrence)
    {
    case iCalWeekOccurrenceFirst:        i = 1;
      break;
    case iCalWeekOccurrenceSecond:       i = 2;
      break;
    case iCalWeekOccurrenceThird:        i = 3;
      break;
    case iCalWeekOccurrenceFourth:       i = 4;
      break;
    case iCalWeekOccurrenceFifth:        i = 5;
      break;
    case iCalWeekOccurrenceLast:         i = -1;
      break;
    case iCalWeekOccurrenceSecondLast:   i = -2;
      break;
    case iCalWeekOccurrenceThirdLast:    i = -3;
      break;
    case iCalWeekOccurrenceFourthLast:   i = -4;
      break;
    case iCalWeekOccurrenceFifthLast:    i = -5;
      break;
    case iCalWeekOccurrenceAll:          i = 0;
      break;
    }

  return i;
}

- (NSString *) asRuleString
{
  NSMutableArray *rules;
  NSMutableString *rule;
  int i;

  rules = [NSMutableArray array];
  for (i = 0; i < 7; i++)
    {
      if (days[i])
	{
	  rule = [NSMutableString string];
	  if (days[i] != iCalWeekOccurrenceAll)
	      [rule appendFormat: @"%i", [self _iCalWeekOccurrenceIntValue: days[i]]];
	  [rule appendString: iCalWeekDayString[i]];
	  [rules addObject: rule];
	}
    }

  return [rules componentsJoinedByString: @","];
}

- (NSString *) asRuleStringWithIntegers
{
  unsigned int i;
  NSMutableString *s;

  s = [NSMutableString string];

  for (i = 0; i < 7; i++)
    if (days[i] > 0)
      {
	[s appendFormat: @"%d,", i];
      }
  [s deleteSuffix: @","];

  return s;
}

- (NSArray *) asRuleArray
{
  NSMutableArray *rules;
  NSMutableDictionary *rule;
  int i;

  rules = [NSMutableArray array];
  for (i = 0; i < 7; i++)
    {
      if (days[i])
	{
	  rule = [NSMutableDictionary dictionary];
	  if (days[i] != iCalWeekOccurrenceAll)
            [rule setObject: [NSNumber numberWithInt: [self _iCalWeekOccurrenceIntValue: days[i]]]
                     forKey: @"occurrence"];
	  [rule setObject: iCalWeekDayString[i]
                   forKey: @"day"];
	  [rules addObject: rule];
	}
    }
  return rules;
}

@end /* iCalByDayMask */
