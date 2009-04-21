/* UIxReminderEditor.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import <Common/UIxPageFrame.h>

#import "UIxReminderEditor.h"

@implementation UIxReminderEditor

- (NSArray *) unitsList
{
  static NSArray *unitsList = nil;

  if (!unitsList)
    {
      unitsList = [NSArray arrayWithObjects: @"MINUTES", @"HOURS", @"DAYS", nil];
      [unitsList retain];
    }

  return unitsList;
}

- (NSArray *) referencesList
{
  static NSArray *referencesList = nil;

  if (!referencesList)
    {
      referencesList = [NSArray arrayWithObjects: @"BEFORE", @"AFTER", nil];
      [referencesList retain];
    }
  
  return referencesList;
}

- (NSArray *) relationsList
{
  static NSArray *relationsList = nil;

  if (!relationsList)
    {
      relationsList = [NSArray arrayWithObjects: @"START", @"END", nil];
      [relationsList retain];
    }
  
  return relationsList;
}

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

  if ([item isEqualToString: @"-"])
    text = item;
  else
    text = [self labelForKey: [NSString stringWithFormat: @"reminder_%@", item]];

  return text;
}

@end
