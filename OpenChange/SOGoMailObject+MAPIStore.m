/* SOGoMailObject+MAPIStore.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
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

#import <NGExtensions/NSObject+Logs.h>

#import "MAPIStoreTypes.h"

#import "SOGoMailObject+MAPIStore.h"

@implementation SOGoMailObject (MAPIStoreMessage)

- (void) setMAPIProperties: (NSDictionary *) properties
{
  id value;

  value = [properties objectForKey: MAPIPropertyKey (PR_FLAG_STATUS)];
  if (value)
    {
      /* We don't handle the concept of "Follow Up" */
      if ([value intValue] == 2)
        [self addFlags: @"\\Flagged"];
      else /* 0: unflagged, 1: follow up complete */
        [self removeFlags: @"\\Flagged"];
    }
}

- (void) MAPISave
{
  /* stub */
}

@end
