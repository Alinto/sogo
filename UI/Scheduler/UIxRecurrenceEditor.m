/* UIxRecurrenceEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2008 Inverse inc.
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
  static NSArray *monthlyDayList = nil;

  if (!monthlyDayList)
    {
      monthlyDayList = [NSArray arrayWithObjects: @"Sunday", @"Monday", @"Tuesday",
				@"Wednesday", @"Thursday", @"Friday",
				@"Saturday", @"DayOfTheMonth", nil];
      [monthlyDayList retain];
    }
  
  return monthlyDayList;
}

- (NSArray *) yearlyMonthList
{
  static NSArray *yearlyMonthList = nil;

  if (!yearlyMonthList)
    {
      yearlyMonthList = [NSArray arrayWithObjects: @"January", @"February", @"March",
				 @"April", @"May", @"June", @"July", @"August",
				 @"September", @"October", @"November", @"December", nil];
      [yearlyMonthList retain];
    }
  
  return yearlyMonthList;
}

- (NSArray *) yearlyDayList
{
  static NSArray *yearlyDayList = nil;

  if (!yearlyDayList)
    {
      yearlyDayList = [NSArray arrayWithObjects: @"Sunday", @"Monday", @"Tuesday",
			       @"Wednesday", @"Thursday", @"Friday",
			       @"Saturday", nil];
      [yearlyDayList retain];
    }
  
  return yearlyDayList;
}

//
// Items used to specify what kind of recurrence we want
//
- (NSArray *) repeatList
{
  static NSArray *repeatList = nil;

  if (!repeatList)
    {
      repeatList = [NSArray arrayWithObjects: @"Daily", @"Weekly",
			    @"Monthly", @"Yearly", nil];
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

  text = [self labelForKey: item];

  return text;
}

@end
