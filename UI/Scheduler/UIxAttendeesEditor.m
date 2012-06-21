/* UIxAttendeesEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2012 Inverse inc.
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
#import <Foundation/NSString.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/NSDictionary+Utilities.h>

#import <Common/UIxPageFrame.h>

#import "UIxAttendeesEditor.h"

@implementation UIxAttendeesEditor

- (id) defaultAction
{
  [[self parent] setToolbar: @""];

  return self;
}

- (void) setItem: (NSString *) newItem
{
  item = newItem;
}

- (NSString *) item
{
  return item;
}

- (NSArray *) zoomList
{
  static NSArray *zoomItems = nil;

  if (!zoomItems)
    {
      zoomItems = [NSArray arrayWithObjects: @"400", @"200", @"100",
			   @"50", @"25", nil];
      [zoomItems retain];
    }

  return zoomItems;
}

- (void) setZoom: (NSString *) zoom
{
//   ASSIGN (zoom, _zoom);
}

- (NSString *) zoom
{
  return @"100";
//   return zoom;
}

- (NSString *) itemZoomText
{
  return [self labelForKey: [NSString stringWithFormat: @"zoom_%@", item]];
}

- (unsigned int) dayStartHour
{
  SOGoUserDefaults *ud;

  ud = [[context activeUser] userDefaults];

  return [ud dayStartHour];
}

- (unsigned int) dayEndHour
{
  SOGoUserDefaults *ud;

  ud = [[context activeUser] userDefaults];

  return [ud dayEndHour];
}

@end
