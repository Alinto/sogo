/* UIxAdministrationFilterPanel.m - this file is part of SOGo
 *
 * Copyright (C) 2009 Inverse inc.
 *
 * Author: Francis Lachapelle <flachapelle@inverse.ca>
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

#import <SOGoUI/UIxComponent.h>

@interface UIxAdministrationFilterPanel : UIxComponent
{
  NSString *searchText;
  NSString *searchCriteria;
}

@end

@implementation UIxAdministrationFilterPanel

static NSArray      *filters           = nil;

+ (void) initialize
{
  NSMutableDictionary *md;
  NSMutableArray *ma;
  
  md = [[NSMutableDictionary alloc] initWithCapacity:8];
  ma = [[NSMutableArray alloc] initWithCapacity:4];

  filters           = [ma copy];
  [md release]; md = nil;
  [ma release]; ma = nil;
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
  ASSIGNCOPY(searchText, _txt);
}

- (void) setSearchCriteria: (NSString *)_txt
{
  ASSIGNCOPY(searchText, _txt);
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
#if 1
  return [[[self context] page] labelForKey: @"filter"];
#else
  return [self valueForKey: @"filter"];
#endif
}

- (NSString *) selectedFilter
{
  return [self queryParameterForKey: @"filterpopup"];
}

@end /* UIxAdministrationFilterPanel */
