/* UIxContactsUserRightsEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse inc.
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
#import <NGObjWeb/WORequest.h>
#import <SoObjects/SOGo/SOGoPermissions.h>

#import "UIxContactsUserRightsEditor.h"

@implementation UIxContactsUserRightsEditor

- (void) setUserCanCreateObjects: (BOOL) userCanCreateObjects
{
  if (userCanCreateObjects)
    [self appendRight: SOGoRole_ObjectCreator];
  else
    [self removeRight: SOGoRole_ObjectCreator];
}

- (BOOL) userCanCreateObjects
{
  return [userRights containsObject: SOGoRole_ObjectCreator];
}

- (void) setUserCanEraseObjects: (BOOL) userCanEraseObjects
{
  if (userCanEraseObjects)
    [self appendRight: SOGoRole_ObjectEraser];
  else
    [self removeRight: SOGoRole_ObjectEraser];
}

- (BOOL) userCanEraseObjects
{
  return [userRights containsObject: SOGoRole_ObjectEraser];
}

- (void) setUserCanEditObjects: (BOOL) userCanEditObjects
{
  if (userCanEditObjects)
    [self appendRight: SOGoRole_ObjectEditor];
  else
    [self removeRight: SOGoRole_ObjectEditor];
}

- (BOOL) userCanEditObjects
{
  return [userRights containsObject: SOGoRole_ObjectEditor];
}

- (void) setUserCanViewObjects: (BOOL) userCanViewObjects
{
  if (userCanViewObjects)
    [self appendRight: SOGoRole_ObjectViewer];
  else
    [self removeRight: SOGoRole_ObjectViewer];
}

- (BOOL) userCanViewObjects
{
  return [userRights containsObject: SOGoRole_ObjectViewer];
}

- (void) updateRights
{
  WORequest *request;

  request = [context request];

  if ([[request formValueForKey: @"ObjectCreator"] length] > 0)
    [self appendRight: SOGoRole_ObjectCreator];
  else
    [self removeRight: SOGoRole_ObjectCreator];

  if ([[request formValueForKey: @"ObjectEditor"] length] > 0)
    [self appendRight: SOGoRole_ObjectEditor];
  else
    [self removeRight: SOGoRole_ObjectEditor];

  if ([[request formValueForKey: @"ObjectViewer"] length] > 0)
    [self appendRight: SOGoRole_ObjectViewer];
  else
    [self removeRight: SOGoRole_ObjectViewer];

  if ([[request formValueForKey: @"ObjectEraser"] length] > 0)
    [self appendRight: SOGoRole_ObjectEraser];
  else
    [self removeRight: SOGoRole_ObjectEraser];
}

@end
