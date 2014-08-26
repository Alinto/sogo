/* UIxCalViewPrint.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2014 Inverse inc.
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

#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>

#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoUser.h>

#import <UIxCalViewPrint.h>

static NSArray *layoutItems = nil;

@implementation UIxCalViewPrint

+ (void) initialize
{
  if (!layoutItems)
  {
    layoutItems = [NSArray arrayWithObjects: @"LIST", @"Daily", @"Multi-Columns", @"Weekly", nil];
    [layoutItems retain];
  }
}

- (id) init
{
  item = nil;
  
  return self;
}

- (void) dealloc
{
  [item release];
}

- (void) setItem: (NSString *) newItem
{
  ASSIGN(item, newItem);
}

- (NSString *) item
{
  return item;
}

- (NSArray *) printLayoutList
{
  return layoutItems;
}

- (NSString *) itemPrintLayoutText
{
  return [self labelForKey: [NSString stringWithFormat: item]];
}

//
// The objective here is to return the parent view layout and select the print
// layout corresponding. Default print view: list view
// 
- (NSString *) parentPrintLayout
{
  SOGoUser *activeUser;
  NSString *parentView;
  
  activeUser = [[self context] activeUser];
  us = [activeUser userSettings];
  parentView = [[us objectForKey:@"Calendar"] objectForKey:@"View" ];
  
  if ([parentView isEqualToString:@"dayview"])
    return @"Daily";
  
  else if ([parentView isEqualToString:@"weekview"])
    return @"Weekly";
  
  else if ([parentView isEqualToString:@"multicolumndayview"])
    return @"Multi-Columns";
  
  else
    return @"LIST";
}

@end
