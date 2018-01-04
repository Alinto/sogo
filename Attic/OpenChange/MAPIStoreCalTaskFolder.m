/* MAPIStoreCalTaskFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2016 Enrique J. Hernandez
 *
 * Author: Enrique J. Hernandez <ejhernandez@zentyal.com>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>

#import <SOGo/SOGoPermissions.h>

#import "MAPIStoreCalTaskFolder.h"

@implementation MAPIStoreCalTaskFolder

- (NSArray *) expandRoles: (NSArray *) roles
{
  static NSDictionary *rolesMap = nil;
  NSArray *subRoles;
  NSMutableSet *expandedRoles;
  NSString *role, *subRole;
  NSUInteger i, max, j;

  if (!rolesMap)
    {
      /* Build the map of array permissions */
      rolesMap = [[NSDictionary alloc] initWithObjects: [NSArray arrayWithObjects:
                                                                   [NSArray arrayWithObjects: SOGoCalendarRole_PublicDAndTViewer,
                                                                                              SOGoCalendarRole_PublicViewer,
                                                                                              SOGoCalendarRole_PublicResponder,
                                                                                              SOGoCalendarRole_PublicModifier, nil],
                                                                   [NSArray arrayWithObjects: SOGoCalendarRole_ConfidentialDAndTViewer,
                                                                                              SOGoCalendarRole_ConfidentialViewer,
                                                                                              SOGoCalendarRole_ConfidentialResponder,
                                                                                              SOGoCalendarRole_ConfidentialModifier, nil],
                                                                   [NSArray arrayWithObjects: SOGoCalendarRole_PrivateDAndTViewer,
                                                                                              SOGoCalendarRole_PrivateViewer,
                                                                                              SOGoCalendarRole_PrivateResponder,
                                                                                              SOGoCalendarRole_PrivateModifier, nil],
                                                                   [NSArray arrayWithObjects: SOGoCalendarRole_ComponentDAndTViewer,
                                                                                              SOGoCalendarRole_ComponentViewer,
                                                                                              SOGoCalendarRole_ComponentResponder,
                                                                                              SOGoCalendarRole_ComponentModifier, nil],
                                                                   nil]
                                               forKeys: [NSArray arrayWithObjects: @"Public", @"Confidential", @"Private",
                                                                                   @"Component", nil]];
    }

  max = [roles count];
  expandedRoles = [NSMutableSet set];
  for (i = 0; i < max; i++)
    {
      role = [roles objectAtIndex: i];
      subRoles = nil;
      if ([role hasPrefix: @"Public"])
          subRoles = [rolesMap objectForKey: @"Public"];
      else if ([role hasPrefix: @"Confidential"])
          subRoles = [rolesMap objectForKey: @"Confidential"];
      else if ([role hasPrefix: @"Private"])
          subRoles = [rolesMap objectForKey: @"Private"];
      else if ([role hasPrefix: @"Component"])
          subRoles = [rolesMap objectForKey: @"Component"];

      if (subRoles)
        {
          for (j = 0; j < [subRoles count]; j++)
            {
              subRole = [subRoles objectAtIndex: j];
              [expandedRoles addObject: subRole];

              if ([subRole isEqualToString: role])
                break;
            }
        }
      else
        {
          [expandedRoles addObject: role];
        }
    }

  return [expandedRoles allObjects];
}

@end
