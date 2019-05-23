/* UIxCalMainView.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2018 Inverse inc.
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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WORequest.h>

#import <NGCards/iCalPerson.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserSettings.h>

#import <Appointments/SOGoAppointmentFolders.h>

#import "UIxCalMainView.h"

@implementation UIxCalMainView

- (NSString *) modulePath
{
  return @"Calendar";
}

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

- (NSArray *) tasksFilters
{
  return [NSArray arrayWithObjects: @"view_all", @"view_today", @"view_next7",
                                    @"view_next14", @"view_next31", @"view_thismonth", @"view_thisyear",
                                    @"view_not_started", @"view_overdue", @"view_incomplete", nil];
}

- (NSString *) tasksFilterLabel
{
  return [self labelForKey: [self valueForKey: @"taskFilter"]];
}

- (NSString *) selectedTasksFilter
{
  NSString *selectedFilter;
  
  selectedFilter = [self queryParameterForKey: @"tasksFilterpopup"];

  if (![selectedFilter length])
    selectedFilter = @"view_today";
  
  return selectedFilter;
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

- (BOOL) showCompletedTasks
{
  [self _setupContext];

  return [[us objectForKey: @"ShowCompletedTasks"] boolValue];
}

- (WOResponse *) saveSelectedListAction
{
  WORequest *request;
  NSDictionary *params;
  NSString *selectedList;
  
  [self _setupContext];
  request = [context request];
  params = [[request contentAsString] objectFromJSONString];

  selectedList = [params objectForKey: @"list"];
  [moduleSettings setObject: selectedList
                     forKey: @"SelectedList"];
  [us synchronize];
  
  return [self responseWithStatus: 204];
}

- (WOResponse *) saveListStateAction
{
  WORequest *request;
  NSDictionary *params;
  NSString *state;

  [self _setupContext];
  request = [context request];
  params = [[request contentAsString] objectFromJSONString];

  state = [params objectForKey: @"state"];
  [moduleSettings setObject: state
                     forKey: @"ListState"];
  [us synchronize];

  return [self responseWithStatus: 204];
}

- (BOOL) listIsCollapsed
{
  NSString *state;

  [self _setupContext];
  state = [moduleSettings objectForKey: @"ListState"];

  return (state && [state compare: @"collapse"] == NSOrderedSame);
}

- (WOResponse *) saveFoldersOrderAction
{
  WORequest *request;
  NSDictionary *params;
  NSArray *list;

  [self _setupContext];
  request = [context request];
  params = [[request contentAsString] objectFromJSONString];

  list = [params objectForKey: @"folders"];
  if (list)
    [moduleSettings setObject: list
                       forKey: @"FoldersOrder"];
  else
    [moduleSettings removeObjectForKey: @"FoldersOrder"];
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

/* Component Viewer, parent class of Appointment Viewer and Task Viewer */

@interface UIxComponentViewTemplate : UIxComponent
{
  id item;
}
@end

@implementation UIxComponentViewTemplate

- (id) init
{
  if ((self = [super init]))
    {
      item = nil;
    }

  return self;
}

- (void) dealloc
{
  [item release];
  [super dealloc];
}

- (void) setItem: (id) _item
{
  ASSIGN (item, _item);
}

- (id) item
{
  return item;
}

- (NSArray *) replyList
{
  return [NSArray arrayWithObjects:
                    [NSNumber numberWithInt: iCalPersonPartStatAccepted],
	   [NSNumber numberWithInt: iCalPersonPartStatDeclined],
	   [NSNumber numberWithInt: iCalPersonPartStatNeedsAction],
	   [NSNumber numberWithInt: iCalPersonPartStatTentative],
	   [NSNumber numberWithInt: iCalPersonPartStatDelegated],
		  nil];
}

- (NSString *) itemReplyText
{
  NSString *word;

  word = [iCalPerson descriptionForParticipationStatus: [item intValue]];

  return [self labelForKey: [NSString stringWithFormat: @"partStat_%@", word]];
}

@end

/* Appointment Viewer */

@interface UIxAppointmentViewTemplate : UIxComponentViewTemplate
@end

@implementation UIxAppointmentViewTemplate
@end

/* Task Viewer */

@interface UIxTaskViewTemplate : UIxComponentViewTemplate
@end

@implementation UIxTaskViewTemplate
@end

/* Component Editor, parent class of Appointment Editor and Task Editor */

@interface UIxComponentEditorTemplate : UIxComponent
{
  id item;
}
@end

@implementation UIxComponentEditorTemplate

- (id) init
{
  if ((self = [super init]))
    {
      item = nil;
    }

  return self;
}

- (void) dealloc
{
  [item release];
  [super dealloc];
}

- (void) setItem: (id) _item
{
  ASSIGN (item, _item);
}

- (id) item
{
  return item;
}

- (NSArray *) repeatList
{
  static NSArray *repeatItems = nil;

  if (!repeatItems)
    {
      repeatItems = [NSArray arrayWithObjects: @"never",
                             @"daily",
                             @"weekly",
                             @"monthly",
                             @"yearly",
                             @"custom",
                             nil];
      [repeatItems retain];
    }

  return repeatItems;
}

- (NSString *) itemRepeatText
{
  return [self labelForKey: [NSString stringWithFormat: @"repeat_%@", [item uppercaseString]]];
}

@end

/* Appointment Editor */

@interface UIxAppointmentEditorTemplate : UIxComponentEditorTemplate
@end

@implementation UIxAppointmentEditorTemplate
@end

/* Task Editor */

@interface UIxTaskEditorTemplate : UIxComponentEditorTemplate
@end

@implementation UIxTaskEditorTemplate

- (NSArray *) statusList
{
  static NSArray *statusItems = nil;

  if (!statusItems)
    {
      statusItems = [NSArray arrayWithObjects: @"not-specified",
                             @"needs-action",
                             @"in-process",
                             @"completed",
                             @"cancelled",
                             nil];
      [statusItems retain];
    }

  return statusItems;
}

- (NSString *) itemStatusText
{
  return [self labelForKey: [NSString stringWithFormat: @"status_%@", [item uppercaseString]]];
}

@end
