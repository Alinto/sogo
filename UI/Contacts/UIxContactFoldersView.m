/* UIxContactFoldersView.m - this file is part of SOGo
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

#import <Foundation/NSString.h>
#import <SoObjects/Contacts/SOGoContactFolders.h>

#import <SOGo/NSString+URL.h>

#import "common.h"

#import "UIxContactFoldersView.h"

@implementation UIxContactFoldersView

- (id) _selectActionForApplication: (NSString *) actionName
{
  SOGoContactFolders *folders;
  NSString *url, *action;
  WORequest *request;

  folders = [self clientObject];
  action = [NSString stringWithFormat: @"../%@/%@",
                     [folders defaultSourceName],
                     actionName];

  request = [[self context] request];

  url = [[request uri] composeURLWithAction: action
                       parameters: [self queryParameters]
                       andHash: NO];

  return [self redirectToLocation: url];
}

- (id) defaultAction
{
  return [self _selectActionForApplication: @"view"];
}

- (id) newAction
{
  return [self _selectActionForApplication: @"new"];
}

- (id) selectForSchedulerAction
{
  return [self _selectActionForApplication: @"scheduler-contacts"];
}

- (id) selectForMailerAction
{
  return [self _selectActionForApplication: @"mailer-contacts"];
}

- (id) selectForCalendarsAction
{
  return [self _selectActionForApplication: @"calendars-contacts"];
}

@end
