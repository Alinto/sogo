/* UIxRecurrenceEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2015 Inverse inc.
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
#import <Foundation/NSUserDefaults.h> /* for locale string constants */

#import <Common/UIxPageFrame.h>

#import <SOPE/NGCards/iCalRecurrenceRule.h>

#import "UIxRecurrenceEditor.h"

@implementation UIxRecurrenceEditor

- (NSArray *) shortWeekDaysList
{
  static NSArray *shortWeekDaysList = nil;

  if (!shortWeekDaysList)
    {
      shortWeekDaysList = [locale objectForKey: NSShortWeekDayNameArray];
      [shortWeekDaysList retain];
    }

  return shortWeekDaysList;
}

- (NSArray *) monthlyRepeatList
{
  static NSArray *monthlyRepeatList = nil;

  if (!monthlyRepeatList)
    {
      monthlyRepeatList = [NSArray arrayWithObjects: @"First", @"Second", @"Third",
				   @"Fourth", @"Fift", @"Last", nil];
      [monthlyRepeatList retain];
    }

  return monthlyRepeatList;
}

- (NSArray *) monthlyDayList
{
  static NSMutableArray *monthlyDayList = nil;

  if (!monthlyDayList)
    {
      monthlyDayList = [NSMutableArray arrayWithArray: [locale objectForKey: NSWeekDayNameArray]];
      [monthlyDayList addObject: [self labelForKey: @"DayOfTheMonth"]];
      [monthlyDayList retain];
    }
  
  return monthlyDayList;
}

- (NSArray *) yearlyMonthList
{
  static NSArray *yearlyMonthList = nil;

  if (!yearlyMonthList)
    {
      yearlyMonthList = [locale objectForKey: NSShortMonthNameArray];
      [yearlyMonthList retain];
    }
  
  return yearlyMonthList;
}

- (NSArray *) yearlyDayList
{
  static NSArray *yearlyDayList = nil;

  if (!yearlyDayList)
    {
      yearlyDayList = [locale objectForKey: NSWeekDayNameArray];
      [yearlyDayList retain];
    }
  
  return yearlyDayList;
}

//
// Items used to specify what kind of recurrence we want
//
- (NSArray *) repeatList
{
  static NSArray *repeatItems = nil;

  if (!repeatItems)
    {
      repeatItems = [NSArray arrayWithObjects: @"daily",
                             @"weekly",
                             @"bi-weekly",
                             @"every_weekday",
                             @"monthly",
                             @"yearly",
                             nil];
      [repeatItems retain];
    }

  return repeatItems;
}

- (NSString *) itemRepeatText
{
  return [self labelForKey: [NSString stringWithFormat: @"repeat_%@", [item uppercaseString]]];
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

  text = [self labelForKey: item];

  return text;
}

- (NSString *) labelForWeekDay
{
  return item;
}

- (NSString *) valueForWeekDay
{
  unsigned int i;

  i = [[self shortWeekDaysList] indexOfObject: item];

  return iCalWeekDayString[i];
}

- (NSString *) valueForMonthlyRepeat
{
  static NSArray *monthlyRepeatValues = nil;
  unsigned int i;

  if (!monthlyRepeatValues)
    {
      monthlyRepeatValues = [NSArray arrayWithObjects: @"1", @"2", @"3",
                                     @"4", @"5", @"-1", nil];
      [monthlyRepeatValues retain];
    }
  i = [[self monthlyRepeatList] indexOfObject: item];

  return [monthlyRepeatValues objectAtIndex: i];
}

- (NSString *) valueForMonthlyDay
{
  unsigned int i;

  i = [[self monthlyDayList] indexOfObject: item];
  if (i % 7 != i)
    return @"relative";
  else
    return iCalWeekDayString[i];
}

- (unsigned int) valueForYearlyMonth
{
  return [[self yearlyMonthList] indexOfObject: item] + 1;
}

- (NSString *) valueForYearlyDay
{
  unsigned int i;

  i = [[self yearlyDayList] indexOfObject: item];

  return iCalWeekDayString[i];
}

@end
