/* UIxContactsFilterPanel.m - this file is part of SOGo
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSKeyValueCoding.h>

#import <NGObjWeb/WOContext.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>

#import "UIxCalFilterPanel.h"

static NSArray *filters = nil;

@implementation UIxCalFilterPanel

+ (void) initialize
{
  static NSString *quals[]
    = {@"view_all",
       @"view_today", @"view_next7", @"view_next14",
       @"view_next31", @"view_thismonth", @"view_future",
       @"view_selectedday" };

  if (!filters)
    {
      filters = [NSArray arrayWithObjects: quals count: 8];
      [filters retain];
    }
}

- (id) init
{
  if ((self = [super init]))
    {
      searchText = nil;
      searchCriteria = nil;
    }

  return self;
}

- (void) dealloc
{
  [searchCriteria release];
  [searchText release];
  [super dealloc];
}

/* accessors */

- (void) setSearchText: (NSString *)_txt
{
  ASSIGN (searchText, _txt);
}

- (void) setSearchCriteria: (NSString *)_txt
{
  ASSIGN (searchText, _txt);
}

- (NSString *) searchText
{
  if (!searchText)
    searchText = [[self queryParameterForKey: @"search"] copy];

  return searchText;
}

- (NSString *) searchCriteria
{
  if (!searchCriteria)
    searchCriteria = [[self queryParameterForKey: @"criteria"] copy];

  return searchCriteria;
}

/* filters */

- (NSArray *) filters
{
  return filters;
}

/* qualifiers */

- (NSString *) filterLabel
{
  return [self labelForKey: [self valueForKey:@"filter"]];
}

- (NSString *) selectedFilter
{
  NSString *selectedFilter;
  SOGoUserSettings *us;

  selectedFilter = [self queryParameterForKey: @"filterpopup"];
  if (![selectedFilter length])
    {
      us = [[context activeUser] userSettings];
      selectedFilter = [us objectForKey: @"CalendarDefaultFilter"];
    }
  if (![selectedFilter length])
    selectedFilter = @"view_today";

  return selectedFilter;
}

@end /* UIxCalFilterPanel */
