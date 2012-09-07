/* UIxCalMainView.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2009 Inverse inc.
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserSettings.h>

#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoAppointmentFolders.h>

#import "UIxCalMainView.h"

@implementation UIxCalMainView

- (void) checkDefaultModulePreference
{
  SOGoUserDefaults *ud;

  ud = [[context activeUser] userDefaults];
  if ([ud rememberLastModule])
    {
      [ud setLoginModule: @"Calendar"];
      [ud synchronize];
    }
}

- (void) _setupContext
{
  SOGoUser *activeUser;
  NSString *module;
  SOGoAppointmentFolders *clientObject;

  contextIsSetup = YES;
  [self checkDefaultModulePreference];

  activeUser = [context activeUser];
  clientObject = [self clientObject];

  module = [clientObject nameInContainer];

  us = [activeUser userSettings];
  moduleSettings = [us objectForKey: module];
  if (!moduleSettings)
    {
      moduleSettings = [NSMutableDictionary dictionary];
      [us setObject: moduleSettings forKey: module];
    }
}

- (NSArray *) monthMenuItems
{
  static NSMutableArray *monthMenuItems = nil;
  unsigned int count;

  if (!monthMenuItems)
    {
      monthMenuItems = [[NSMutableArray alloc] initWithCapacity: 12];
      for (count = 1; count < 13; count++)
        [monthMenuItems addObject:
                          [NSString stringWithFormat: @"%.2d", count]];
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
  static NSMutableArray *yearMenuItems = nil;
  int count, year;
 
  if (!yearMenuItems)
    {
      year = [[NSCalendarDate date] yearOfCommonEra];
      yearMenuItems = [[NSMutableArray alloc] initWithCapacity: 11];
      for (count = -5; count < 6; count++)
        [yearMenuItems addObject: [NSNumber numberWithInt: year + count]];
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

- (NSString *) verticalDragHandleStyle
{
  NSString *vertical;
  
  if (!contextIsSetup)
    [self _setupContext];
  vertical = [moduleSettings objectForKey: @"DragHandleVertical"];

  return ((vertical && [vertical intValue] > 0) ? (id)[vertical stringByAppendingFormat: @"px"] : nil);
}

- (NSString *) horizontalDragHandleStyle
{
  NSString *horizontal;

  if (!contextIsSetup)
    [self _setupContext];
  horizontal = [moduleSettings objectForKey: @"DragHandleHorizontal"];

  return ((horizontal && [horizontal intValue] > 0) ? (id)[horizontal stringByAppendingFormat: @"px"] : nil);
}

- (NSString *) eventsListViewStyle
{
  NSString *height;

  if (!contextIsSetup)
    [self _setupContext];
  height = [moduleSettings objectForKey: @"DragHandleVertical"];

  return ((height && [height intValue] > 0) ? [NSString stringWithFormat: @"%ipx", [height intValue]] : nil);
}

- (WOResponse *) saveDragHandleStateAction
{
  WORequest *request;
  NSString *dragHandle;
  
  if (!contextIsSetup)
    [self _setupContext];
  request = [context request];

  if ((dragHandle = [request formValueForKey: @"vertical"]) != nil)
    [moduleSettings setObject: dragHandle
		    forKey: @"DragHandleVertical"];
  else if ((dragHandle = [request formValueForKey: @"horizontal"]) != nil)
    [moduleSettings setObject: dragHandle
		    forKey: @"DragHandleHorizontal"];
  else
    return [self responseWithStatus: 400];

  [us synchronize];

  return [self responseWithStatus: 204];
}

- (NSString *) eventsTabClass
{
   NSString *list;

   [self _setupContext];
   list = [moduleSettings objectForKey: @"SelectedList"];
   
   return (list && [list compare: @"eventsListView"] == NSOrderedSame)? @"active" : @"";
}

- (NSString *) tasksTabClass
{
   NSString *list;

   [self _setupContext];
   list = [moduleSettings objectForKey: @"SelectedList"];
   
   return (list && [list compare: @"tasksListView"] == NSOrderedSame)? @"active" : @"";
}

- (WOResponse *) saveSelectedListAction
{
  WORequest *request;
  NSString *selectedList;
  
  [self _setupContext];
  request = [context request];

  selectedList = [request formValueForKey: @"list"];
  [moduleSettings setObject: selectedList
                     forKey: @"SelectedList"];
  [us synchronize];
  
  return [self responseWithStatus: 204];
}

- (unsigned int) firstDayOfWeek
{
  SOGoUserDefaults *ud;

  ud = [[context activeUser] userDefaults];

  return [ud firstDayOfWeek];
}

- (unsigned int) dayStartHour
{
  SOGoUserDefaults *ud;

  ud = [[context activeUser] userDefaults];

  return [ud dayStartHour];
}

- (NSString *) currentView
{
  NSString *view;
  
  if (!contextIsSetup)
    [self _setupContext];
  view = [moduleSettings objectForKey: @"View"];

  return (view ? view : @"weekview");
}

@end
