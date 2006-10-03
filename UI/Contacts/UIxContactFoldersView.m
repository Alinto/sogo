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

#import <SOGoUI/NSDictionary+URL.h>

#import "common.h"

#import "UIxContactFoldersView.h"

@implementation UIxContactFoldersView

- (id) defaultAction
{
  SOGoContactFolders *folders;
  NSString *url;

  folders = [self clientObject];
  url = [NSString stringWithFormat: @"%@/view%@",
                  [folders defaultSourceName],
                  [[self queryParameters] asURLParameters]];

  return [self redirectToLocation: url];
}

- (id) newAction
{
  SOGoContactFolders *folders;
  NSString *url;

  folders = [self clientObject];
  url = [NSString stringWithFormat: @"%@/new%@",
                  [folders defaultSourceName],
                  [[self queryParameters] asURLParameters]];
  
  return [self redirectToLocation: url];
}

- (id) _selectActionForApplication: (NSString *) actionName
{
  SOGoContactFolders *folders;
  NSString *url, *selectorId;

  folders = [self clientObject];
  selectorId = [self queryParameterForKey: @"selectorId"];

  url = [NSString stringWithFormat: @"%@/%@?selectorId=%@",
                  [folders defaultSourceName],
                  actionName, selectorId];

  return [self redirectToLocation: url];
}

- (id) selectForSchedulerAction
{
  return [self _selectActionForApplication: @"scheduler-contacts"];
}

- (id) selectForMailerAction
{
  return [self _selectActionForApplication: @"mailer-contacts"];
}

@end
