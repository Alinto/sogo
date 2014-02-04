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

#import <NGCards/iCalByDayMask.h>

#import "NSCalendarDate+ActiveSync.h"
#import "NSDate+ActiveSync.h"

@implementation iCalRecurrenceRule (ActiveSync)

- (NSString *) activeSyncRepresentation
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

      for (i = 0; i < 7; i++)
        {
          if (occurrences[i])
            v += (1 << i);
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
         [date activeSyncRepresentationWithoutSeparators]];
    }  


  [s appendString: @"</Recurrence>"];

  return s;
}

//
//
//
- (void) takeActiveSyncValues: (NSDictionary *) theValues
{
  id o;

  int recurrenceType;

  recurrenceType = [[theValues objectForKey: @"Recurrence_Type"] intValue];

  [self setInterval: @"1"];

  switch (recurrenceType)
    {
      // Daily
    case 0:
      [self setFrequency: iCalRecurrenceFrequenceDaily];
      if ((o = [theValues objectForKey: @"Recurrence_Interval"]))
        {
          [self setRepeatInterval: [o intValue]];
        }
      break;
      // Weekly
    case 1:
      break;
      // Montly
    case 2:
    case 3:
      break;
      // Yearly
    case 5:
    case 6:
    default:
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
