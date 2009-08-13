/* UIxAdministration.m - this file is part of SOGo
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

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>

#import <SoObjects/SOGo/SOGoUser.h>
//#import "../../Main/SOGo.h"

#import "UIxAdministration.h"

@implementation UIxAdministration

- (id) init
{
  if ((self = [super init]))
    {
      ASSIGN (user, [context activeUser]);
    }

  return self;
}

- (void) dealloc
{
  [user release];
  [super dealloc];
}

- (BOOL) shouldTakeValuesFromRequest: (WORequest *) request
                           inContext: (WOContext*) context
{
  return [[request method] isEqualToString: @"POST"];
}

@end
