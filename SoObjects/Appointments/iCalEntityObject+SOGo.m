/* iCalEntityObject+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
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
#import <Foundation/NSEnumerator.h>

#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>

#import "iCalEntityObject+SOGo.h"

@implementation iCalEntityObject (SOGoExtensions)

- (BOOL) userIsParticipant: (SOGoUser *) user
{
  NSEnumerator *emails;
  NSArray *identities;
  NSString *currentEmail;
  BOOL response;

  response = NO;

  identities = [user allIdentities];
  emails = [[identities objectsForKey: @"email"] objectEnumerator];
  currentEmail = [emails nextObject];
  while (!response && currentEmail)
    if ([self isParticipant: currentEmail])
      response = YES;
    else
      currentEmail = [emails nextObject];

  return response;
}

- (BOOL) userIsOrganizer: (SOGoUser *) user
{
  NSEnumerator *emails;
  NSArray *identities;
  NSString *currentEmail;
  BOOL response;

  response = NO;

  identities = [user allIdentities];
  emails = [[identities objectsForKey: @"email"] objectEnumerator];
  currentEmail = [emails nextObject];
  while (!response && currentEmail)
    if ([self isOrganizer: currentEmail])
      response = YES;
    else
      currentEmail = [emails nextObject];

  return response;
}

@end
