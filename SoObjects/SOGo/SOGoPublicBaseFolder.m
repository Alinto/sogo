/* SOGoPublicBaseFolder.m - this file is part of SOGo
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

#import <Foundation/NSString.h>

#import "SOGoUser.h"
#import "SOGoUserFolder.h"

#import "SOGoPublicBaseFolder.h"

@implementation SOGoPublicBaseFolder

- (id) lookupName: (NSString *) key
        inContext: (id) localContext
          acquire: (BOOL) acquire
{
  id userFolder;

  if ([key length] > 0 && [SOGoUser userWithLogin: key roles: nil])
    userFolder = [SOGoUserFolder objectWithName: key inContainer: self];
  else
    userFolder = nil;

  return userFolder;
}

- (BOOL) isInPublicZone
{
  return YES;
}

@end
