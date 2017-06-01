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
  BOOL dirty;
  NSDictionary *mailSettings, *delegatorSettings;
  NSArray *mailDelegators, *delegates;
  NSMutableArray *validMailDelegators;
  NSString *delegatorLogin;
  SOGoUser *delegatorUser;
  unsigned int max, count;

  dirty = NO;
  validMailDelegators = [NSMutableArray array];
  mailSettings = [[self userSettings] objectForKey: @"Mail"];
  mailDelegators = [mailSettings objectForKey: @"DelegateFrom"];
  if (mailDelegators)
    {
      max = [mailDelegators count];
      for (count = 0; count < max; count++)
        {
          // 1. Verify if delegator is valid
          delegatorLogin = [mailDelegators objectAtIndex: count];
          delegatorUser = [SOGoUser userWithLogin: delegatorLogin];
          if (delegatorUser)
            {
              // 2. Verify if delegator still delegates to user
              delegatorSettings = [[delegatorUser userSettings] objectForKey: @"Mail"];
              delegates = [delegatorSettings objectForKey: @"DelegateTo"];
              if ([delegates containsObject: [self login]])
                [validMailDelegators addObject: delegatorLogin];
              else
                dirty = YES;
            }
          else
            dirty = YES;
        }
    }

  if (dirty)
    [self _setMailDelegators: validMailDelegators];

  return validMailDelegators;
}

- (void) _setMailDelegators: (NSArray *) newDelegators
{
  NSMutableDictionary *mailSettings;
  SOGoUserSettings *settings;

  settings = [self userSettings];
  mailSettings = [settings objectForKey: @"Mail"];
  if (!mailSettings)
    {
      mailSettings = [NSMutableDictionary dictionaryWithCapacity: 1];
      [settings setObject: mailSettings forKey: @"Mail"];
    }
  [mailSettings setObject: newDelegators
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
