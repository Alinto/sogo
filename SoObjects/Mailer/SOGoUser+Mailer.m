/* SOGoUser+Mailer.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoUserSettings.h>

#import "SOGoUser+Mailer.h"

@implementation SOGoUser (SOGoMailExtensions)

- (NSArray *) mailDelegators
{
  NSDictionary *mailSettings;
  NSArray *mailDelegators;

  mailSettings = [[self userSettings] objectForKey: @"Mail"];
  mailDelegators = [mailSettings objectForKey: @"DelegateFrom"];
  if (!mailDelegators)
    mailDelegators = [NSArray array];

  return mailDelegators;
}

- (void) _setMailDelegators: (NSArray *) newDelegators
{
  SOGoUserSettings *settings;

  settings = [self userSettings];
  [[settings objectForKey: @"Mail"] setObject: newDelegators
                                       forKey: @"DelegateFrom"];
  [settings synchronize];
}

- (void) addMailDelegator: (NSString *) newDelegator
{
  NSMutableArray *delegators;

  delegators = [[self mailDelegators] mutableCopy];
  [delegators autorelease];
  [delegators addObjectUniquely: newDelegator];

  [self _setMailDelegators: delegators];
}

- (void) removeMailDelegator: (NSString *) oldDelegator
{
  NSMutableArray *delegators;

  delegators = [[self mailDelegators] mutableCopy];
  [delegators autorelease];
  [delegators removeObject: oldDelegator];

  [self _setMailDelegators: delegators];
}

@end
