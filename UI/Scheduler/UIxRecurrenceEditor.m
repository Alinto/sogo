/* UIxRecurrenceEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2008 Inverse groupe conseil
 *
 * Author: Ludovic Marcotte <ludovic@inverse.ca>
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
#import <Foundation/NSString.h>

#import <Common/UIxPageFrame.h>

#import "UIxRecurrenceEditor.h"

@implementation UIxRecurrenceEditor

- (id) defaultAction
{
  [[self parent] setToolbar: @""];

  return self;
}

//
// Items used for the "Daily" recurrences.
//
- (NSArray *) dailyRadioList
{
  static NSArray *dailyItems = nil;

  if (!dailyItems)
    {
      dailyItems = [NSArray arrayWithObjects: @"Every", @"Every weekday", nil];
      [dailyItems retain];
    }

  return dailyItems;
}


//
// Items used for the "Weekly" recurrences.
//
- (NSArray *) weeklyCheckBoxList
{
  static NSArray *dayItems = nil;

  if (!dayItems)
    {
      dayItems = [NSArray arrayWithObjects: @"Mon", @"Tue", @"Wed", 
			  @"Thu", @"Fri", @"Sat", @"Sun", nil];
      [dayItems retain];
    }
  
  return dayItems;
}


//
// Items used for the "Montly" recurrences".
//
- (NSArray *) dayMonthList
{
  static NSArray *dayMonthList = nil;

  if (!dayMonthList)
    {
      int i;
      
      dayMonthList = [[NSMutableArray alloc] init];

      for (i = 1; i <= 31; i++)
	{
	  [(NSMutableArray *)dayMonthList addObject: [NSString stringWithFormat: @"%d", i]];
	}
    }

  return dayMonthList;
}

- (NSArray *) monthlyRepeatList
{
  static NSArray *monthlyRepeatList = nil;

  if (!monthlyRepeatList)
    {
      monthlyRepeatList = [NSArray arrayWithObjects: @"FIRST", @"SECOND", @"THIRD",
				  @"FOURTH", @"FIFT", @"LAST", nil];
      [monthlyRepeatList retain];
    }

  return monthlyRepeatList;
}

- (NSArray *) monthlyDayList
{
  static NSArray *monthlyDayList = nil;

  if (!monthlyDayList)
    {
      monthlyDayList = [NSArray arrayWithObjects: @"SUNDAY", @"MONDAY", @"TUESDAY",
				@"WEDNESDAY", @"THURSDAY", @"FRIDAY",
				@"SATURDAY", @"DAYOFTHEMONTH", nil];
      [monthlyDayList retain];
    }
  
  return monthlyDayList;
}

- (NSArray *) monthlyRadioList
{
  static NSArray *monthlyRadioList = nil;

  if (!monthlyRadioList)
    {
      monthlyRadioList = [NSArray arrayWithObjects: @"The", @"Recur on day(s)", nil];
      [monthlyRadioList retain];
    }

  return monthlyRadioList;
}


//
// Items used for the "Yearly" recurrences".
//
- (NSArray *) yearlyRadioList
{
  static NSArray *yearlyRadioList = nil;

  if (!yearlyRadioList)
    {
      yearlyRadioList = [NSArray arrayWithObjects: @"Every", @"Every", nil];
      [yearlyRadioList retain];
    }

  return yearlyRadioList;
}

- (NSArray *) yearlyMonthList
{
  static NSArray *yearlyMonthList = nil;

  if (!yearlyMonthList)
    {
      yearlyMonthList = [NSArray arrayWithObjects: @"JANUARY", @"FEBRUARY", @"MARCH",
				 @"APRIL", @"MAY", @"JUNE", @"JULY", @"AUGUST",
				 @"SEPTEMBER", @"OCTOBER", @"NOVEMBER", @"DECEMBER", nil];
      [yearlyMonthList retain];
    }
  
  return yearlyMonthList;
}

- (NSArray *) yearlyDayList
{
  static NSArray *yearlyDayList = nil;

  if (!yearlyDayList)
    {
      yearlyDayList = [NSArray arrayWithObjects: @"SUNDAY", @"MONDAY", @"TUESDAY",
			       @"WEDNESDAY", @"THURSDAY", @"FRIDAY",
			       @"SATURDAY", nil];
      [yearlyDayList retain];
    }
  
  return yearlyDayList;
}


//
// Items used to specify the range.
//
- (NSArray *) rangeRadioList
{
  static NSArray *rangeRadioList = nil;
 
  if (!rangeRadioList)
    {
      rangeRadioList = [NSArray arrayWithObjects: @"No end date", @"Create", 
				@"Repeat until", nil];
      [rangeRadioList retain];
    }

  return rangeRadioList;
}


//
// Items used to specify what kind of recurrence we want
//
- (NSArray *) repeatList
{
  static NSArray *repeatList = nil;

  if (!repeatList)
    {
      repeatList = [NSArray arrayWithObjects: @"DAILY", @"WEEKLY",
			    @"MONTHLY", @"YEARLY", nil];
      [repeatList retain];
    }

  return repeatList;
}


//
// Accessors
//
- (void) setItem: (NSString *) theItem
{
  item = theItem;
}

- (NSString *) item
{
  return item;
}

- (NSString *) itemText
{
  NSString *text;

  text = [self labelForKey: [NSString stringWithFormat: @"repeat_%@", item]];

  return text;
}

@end
