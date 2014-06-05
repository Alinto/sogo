/*

Copyright (c) 2014, Inverse inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Inverse inc. nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

#import "iCalRecurrenceRule+ActiveSync.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGCards/iCalEvent.h>
#import <NGCards/iCalByDayMask.h>

#import "NSCalendarDate+ActiveSync.h"
#import "NSDate+ActiveSync.h"

@implementation iCalRecurrenceRule (ActiveSync)

- (NSString *) activeSyncRepresentationInContext: (WOContext *) context
{
  NSMutableString *s;
  int type;

  s = [NSMutableString string];
  
  [s appendString: @"<Recurrence xmlns=\"Calendar:\">"];

  // 0 -> daily, 1 -> weekly, 2 -> montly, 5 -> yearly
  type = 0;

  if ([self frequency] == iCalRecurrenceFrequenceDaily)
    {
      type = 0;

      // 1 -> sunday, 2 -> monday, 4 -> tuesday, 8 -> wednesday, 16 -> thursday, 32 -> friday, 64 -> saturday, 127 -> last day of month (montly or yearl recurrences only)
      if ([[self byDayMask] isWeekDays])
        {
          [s appendFormat: @"<Recurrence_DayOfWeek xmlns=\"Calendar:\">%d</Recurrence_DayOfWeek>", (2|4|8|16|32)];
        }
      else
        {
          [s appendFormat: @"<Recurrence_Interval xmlns=\"Calendar:\">%d</Recurrence_Interval>", [self repeatInterval]]; 
        }
    }
  else if ([self frequency] == iCalRecurrenceFrequenceWeekly)
    {
      iCalWeekOccurrences *occurrences;
      int i, v;

      type = 1;

      occurrences = [[self byDayMask] weekDayOccurrences];
      v = 0;

      if (occurrences)
        {
          for (i = 0; i < 7; i++)
            {
              if (occurrences[0][i])
                v += (1 << i);
            }
        }
      else
        {
          // No byDayMask, we take the event's start date to compute the DayOfWeek
          // 0 == Sunday, 6 == Saturday
          v = (1 << [[[self parent] startDate] dayOfWeek]);
        }

      [s appendFormat: @"<Recurrence_DayOfWeek xmlns=\"Calendar:\">%d</Recurrence_DayOfWeek>", v];
      [s appendFormat: @"<Recurrence_Interval xmlns=\"Calendar:\">%d</Recurrence_Interval>", [self repeatInterval]]; 
    }
  else if ([self frequency] == iCalRecurrenceFrequenceMonthly)
    {
      if ([[self byDay] length])
        {
          int firstOccurrence;
          iCalByDayMask *dm;
          
          type = 3; // recurs monthly on the nth day
          dm = [self byDayMask];
          firstOccurrence = [dayMask firstOccurrence];

          // Handle the case for "Last day of the month"
          if (firstOccurrence < 0)
            firstOccurrence = 5;

          [s appendFormat: @"<Recurrence_DayOfWeek xmlns=\"Calendar:\">%d</Recurrence_DayOfWeek>", (1 << [dm firstDay])];          
          [s appendFormat: @"<Recurrence_WeekOfMonth xmlns=\"Calendar:\">%d</Recurrence_WeekOfMonth>", firstOccurrence];
        }
      else if ([[self byMonthDay] count])
        {
          NSArray *days;
          
          type = 2; // recurs monthly
          days = [self byMonthDay];
          if ([days count] > 0 && [[days objectAtIndex: 0] intValue] < 0)
            {
              // Last day of the month
              iCalByDayMask *dm;
          
              dm = [self byDayMask];
              [s appendFormat: @"<Recurrence_DayOfWeek xmlns=\"Calendar:\">%d</Recurrence_DayOfWeek>", (1 << [dm firstDay])];
              [s appendFormat: @"<Recurrence_WeekOfMonth xmlns=\"Calendar:\">%d</Recurrence_WeekOfMonth>", 5];
            }
          else
            {
              // Unsupported rule in ActiveSync/Outlook. Rule that says "Repeat on the 7th and 8th of each month".
              // FIXME
            }
        }
      else
        {
          // Simple reccurrence rule of type "Monthly"
          type = 2;
          [s appendFormat: @"<Recurrence_DayOfMonth xmlns=\"Calendar:\">%d</Recurrence_DayOfMonth>",
             [[[self parent] startDate] dayOfMonth]];
        }
    }
  else if ([self frequency] == iCalRecurrenceFrequenceYearly)
    {
      type = 6; // Yearly on the nth day
      
      if ([[self flattenedValuesForKey: @"bymonth"] length])
        {
          if ([[self byDay] length])
            {
              int firstOccurrence;
              iCalByDayMask *dm;
              
              dm = [self byDayMask];
              firstOccurrence = [dm firstOccurrence];
              if (firstOccurrence < 0)
                firstOccurrence = 5;
              
              [s appendFormat: @"<Recurrence_DayOfWeek xmlns=\"Calendar:\">%d</Recurrence_DayOfWeek>", (1 << [dm firstDay])];
              [s appendFormat: @"<Recurrence_WeekOfMonth xmlns=\"Calendar:\">%d</Recurrence_WeekOfMonth>", firstOccurrence];
              [s appendFormat: @"<Recurrence_MonthOfYear xmlns=\"Calendar:\">%@</Recurrence_MonthOfYear>",
                 [self flattenedValuesForKey: @"bymonth"]];
            }
          else
            {
              type = 5; // Yearly
              
              [s appendFormat: @"<Recurrence_DayOfMonth xmlns=\"Calendar:\">%@</Recurrence_DayOfMonth>",
                 [self flattenedValuesForKey: @"bymonthday"]];
              
              [s appendFormat: @"<Recurrence_MonthOfYear xmlns=\"Calendar:\">%@</Recurrence_MonthOfYear>",
                 [self flattenedValuesForKey: @"bymonth"]];
            }
        }
      else
        type = 5;
    }
  
  [s appendFormat: @"<Recurrence_Type xmlns=\"Calendar:\">%d</Recurrence_Type>", type];

  // Occurrences / Until
  //[s appendFormat: @"<Recurrence_Occurrences xmlns=\"Calendar:\">%d</Recurrence_Occurrences>", 5];
  if ([self repeatCount])
    {
      [s appendFormat: @"<Recurrence_Occurrences xmlns=\"Calendar:\">%@</Recurrence_Occurrences>",
         [self flattenedValuesForKey: @"count"]];
    }
  else if ([self untilDate])
    {
      NSCalendarDate *date;
      
      date = [self untilDate];
      //ud = [[context activeUser] userDefaults];
      //[date setTimeZone: [ud timeZone]];
      
      [s appendFormat: @"<Recurrence_Until xmlns=\"Calendar:\">%@</Recurrence_Until>",
         [date activeSyncRepresentationWithoutSeparatorsInContext: context]];
    }  


  [s appendString: @"</Recurrence>"];

  return s;
}

//
//
//
- (void) _setByDayFromValues: (NSDictionary *) theValues
{
  NSString *day;
  id o;
  
  unsigned int day_of_week;
  int i, week_of_month;
  
  o = [theValues objectForKey: @"Recurrence_DayOfWeek"];
  
  // The documentation says WeekOfMonth must be between 1 and 5. The value
  // 5 means "last week of month"
  week_of_month = [[theValues objectForKey: @"Recurrence_WeekOfMonth"] intValue];
  
  if (week_of_month > 4)
    week_of_month = -1;
  
  // We find the correct day of the week
  day_of_week = [o intValue];
  
  for (i = 0; i < 7; i++)
    {
      if ((1<<i) == day_of_week)
        {
          day_of_week = i;
          break;
        }
    }
  
  day = [self iCalRepresentationForWeekDay: i];
  
  [self setSingleValue: [NSString stringWithFormat: @"%d%@",
                                  week_of_month, day]
                forKey: @"byday"];
}

- (void) _setByMonthFromValues: (NSDictionary *) theValues
{
  unsigned int month_of_year;
  
  month_of_year = [[theValues objectForKey: @"Recurrence_MonthOfYear"] intValue];
  
  [self setSingleValue: [NSString stringWithFormat: @"%d", month_of_year]
                forKey: @"bymonth"];
}

//
//
//
- (void) takeActiveSyncValues: (NSDictionary *) theValues
                    inContext: (WOContext *) context
{
  id o;

  int recurrenceType;

  recurrenceType = [[theValues objectForKey: @"Recurrence_Type"] intValue];

  if ((o = [theValues objectForKey: @"Recurrence_Interval"]))
    {
      [self setRepeatInterval: [o intValue]];
    }
  else
    [self setRepeatInterval: 1];
  
  switch (recurrenceType)
    {                                          
      //
      // Daily
      //
    case 0:
      [self setFrequency: iCalRecurrenceFrequenceDaily];

      
      // Every weekday
      if ((o = [theValues objectForKey: @"Recurrence_DayOfWeek"]))
        {
          [self setByDayMask: [iCalByDayMask byDayMaskWithWeekDays]];
        }
      break;
      //
      // Weekly
      //
    case 1:
      [self setFrequency: iCalRecurrenceFrequenceWeekly];

      // 42 == Every Monday, Wednesday and Friday, for example 
      if ((o = [theValues objectForKey: @"Recurrence_DayOfWeek"]))
        {
          iCalWeekOccurrences days;
          unsigned int i, v;
          
          memset(days, 0, 7 * sizeof(iCalWeekOccurrence));
          v = [o intValue];
          
          for (i = 0; i < 7; i++)
            {
              if (v & (1<<i))
                days[i] = iCalWeekOccurrenceAll;
            }

          [self setByDayMask: [iCalByDayMask byDayMaskWithDays: days]];
        }
      break;
      //
      // Montly
      //
    case 2:
    case 3:
      [self setFrequency: iCalRecurrenceFrequenceMonthly];
      
      // The 5th of every X month(s)
      if ((o = [theValues objectForKey: @"Recurrence_DayOfMonth"]))
        {
          [self setValues: [NSArray arrayWithObject: o]
                  atIndex: 0 forKey: @"bymonthday"];
        }
      // The 3rd Thursay every X month(s)
      else if ((o = [theValues objectForKey: @"Recurrence_DayOfWeek"]))
        {
          [self _setByDayFromValues: theValues];
        }

      break;
      //
      // Yearly
      //
    case 5:
    case 6:
    default:
      [self setFrequency: iCalRecurrenceFrequenceYearly];

      // On April 19th 
      if ((o = [theValues objectForKey: @"Recurrence_DayOfMonth"]))
        {
          [self setValues: [NSArray arrayWithObject: o] atIndex: 0
                   forKey: @"bymonthday"];
          
          [self _setByMonthFromValues: theValues];
        }
      else
        {
          // On the Second Wednesday of April
          [self _setByDayFromValues: theValues];
          [self _setByMonthFromValues: theValues];
        }

      break;
    }

  if ((o = [theValues objectForKey: @"Recurrence_Occurrences"]))
    {
      [self setRepeatCount: [o intValue]];
    }
  else if ((o = [theValues objectForKey: @"Recurrence_Until"]))
    {
      [self setUntilDate: [o calendarDate]];
    }
}

@end
