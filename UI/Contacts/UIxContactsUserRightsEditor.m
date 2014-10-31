/* UIxContactsUserRightsEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2014 Inverse inc.
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WORequest.h>

#import <SoObjects/SOGo/SOGoPermissions.h>

#import "UIxContactsUserRightsEditor.h"

@implementation UIxContactsUserRightsEditor

- (BOOL) userCanCreateObjects
{
  return [userRights containsObject: SOGoRole_ObjectCreator];
}

- (BOOL) userCanEraseObjects
{
  return [userRights containsObject: SOGoRole_ObjectEraser];
}

- (BOOL) userCanEditObjects
{
  return [userRights containsObject: SOGoRole_ObjectEditor];
}

- (BOOL) userCanViewObjects
{
  return [userRights containsObject: SOGoRole_ObjectViewer];
}

- (NSDictionary *) userRightsForObject
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSNumber numberWithBool:[self userCanCreateObjects]], @"canCreateObjects",
                           [NSNumber numberWithBool:[self userCanEraseObjects]], @"canEraseObjects",
                           [NSNumber numberWithBool:[self userCanEditObjects]], @"canEditObjects",
                           [NSNumber numberWithBool:[self userCanViewObjects]], @"canViewObjects",
                       nil];
}

- (void) updateRights: (NSDictionary *) newRights
{
  if ([[newRights objectForKey: @"canCreateObjects"] boolValue])
    [self appendRight: SOGoRole_ObjectCreator];
  else
    [self removeRight: SOGoRole_ObjectCreator];

  if ([[newRights objectForKey: @"canEditObjects"] boolValue])
    [self appendRight: SOGoRole_ObjectEditor];
  else
    [self removeRight: SOGoRole_ObjectEditor];

  if ([[newRights objectForKey: @"canViewObjects"] boolValue])
    [self appendRight: SOGoRole_ObjectViewer];
  else
    [self removeRight: SOGoRole_ObjectViewer];

  if ([[newRights objectForKey: @"canEraseObjects"] boolValue])
    [self appendRight: SOGoRole_ObjectEraser];
  else
    [self removeRight: SOGoRole_ObjectEraser];
}

@end
