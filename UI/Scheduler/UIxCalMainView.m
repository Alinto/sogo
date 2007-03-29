/* UIxCalMainView.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse groupe conseil
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WOResponse.h>

#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>

#import "UIxCalMainView.h"

#import <Appointments/SOGoAppointmentFolder.h>

static NSMutableArray *monthMenuItems = nil;
static NSMutableArray *yearMenuItems = nil;

@implementation UIxCalMainView

- (NSArray *) monthMenuItems
{
  unsigned int count;
 
  if (!monthMenuItems)
    {
      monthMenuItems = [NSMutableArray arrayWithCapacity: 12];
      
      for (count = 1; count < 13; count++)
        [monthMenuItems addObject:
                          [NSString stringWithFormat: @"%.2d", count]];
      [monthMenuItems retain];
    }

  return monthMenuItems;
}

- (void) setMonthMenuItem: (NSString *) aMonthMenuItem
{
  monthMenuItem = aMonthMenuItem;
}

- (NSString *) monthMenuItem
{
  return monthMenuItem;
}

- (NSString *) monthMenuItemLabel
{
  return [self localizedNameForMonthOfYear: [monthMenuItem intValue]];
}

- (NSArray *) yearMenuItems
{
  int count, year;
 
  if (!yearMenuItems)
    {
      year = [[NSCalendarDate date] yearOfCommonEra];
      yearMenuItems = [NSMutableArray arrayWithCapacity: 11];
      for (count = -5; count < 6; count++)
        [yearMenuItems addObject: [NSNumber numberWithInt: year + count]];
      [yearMenuItems retain];
    }

  return yearMenuItems;
}

- (void) setYearMenuItem: (NSNumber *) aYearMenuItem
{
  yearMenuItem = aYearMenuItem;
}

- (NSNumber *) yearMenuItem
{
  return yearMenuItem;
}

- (id) batchDeleteAction
{
  NSArray *ids;
  SOGoAppointmentFolder *clientObject;

  ids = [[self queryParameterForKey: @"ids"] componentsSeparatedByString: @"/"];
  if (ids)
    {
      clientObject = [self clientObject];
      [clientObject deleteEntriesWithIds: ids];
    }

  return self;
}

@end
