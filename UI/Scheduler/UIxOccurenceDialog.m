/* UIxOccurenceDialog.m - this file is part of SOGo
 *
 * Copyright (C) 2008-2014 Inverse inc.
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

#import <SoObjects/Appointments/SOGoCalendarComponent.h>

#import "UIxOccurenceDialog.h"

@implementation UIxOccurenceDialog

- (id) init
{
  if ((self = [super init]))
    action = nil;

  return self;
}

- (void) dealloc
{
  [action release];
  [super dealloc];
}

- (NSString *) action
{
  return action;
}

- (NSString *) calendarFolder
{
  SOGoCalendarComponent *component;

  component = [[self clientObject] container];

  return [[component container] nameInContainer];
}

- (NSString *) componentName
{
  SOGoCalendarComponent *component;

  component = [[self clientObject] container];

  return [component nameInContainer];
}

- (NSString *) recurrenceName
{
  return [[self clientObject] nameInContainer];
}

- (id <WOActionResults>) defaultAction
{
  ASSIGN (action, @"edit");

  return self;
}

- (id <WOActionResults>) confirmDeletionAction
{
  ASSIGN (action, @"delete");

  return self;
}

- (id <WOActionResults>) confirmAdjustmentAction
{
  ASSIGN (action, @"adjust");

  return self;
}

- (WOResponse *) deleteAction
{
  SOGoCalendarComponent *component;
  WOResponse *response;

  component = [self clientObject];
  response = (WOResponse *) [component prepareDelete];
  if (!response)
    response = [self responseWithStatus: 204];

  return response;
}

@end
