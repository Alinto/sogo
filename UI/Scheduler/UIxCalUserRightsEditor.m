/* UIxCalUserRightsEditor.m - this file is part of SOGo
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

#import "UIxCalUserRightsEditor.h"

@implementation UIxCalUserRightsEditor

- (id) init
{
  if ((self = [super init]))
    {
      currentRight = nil;
      currentRightType = nil;
      rights = [NSMutableDictionary new];
      [rights setObject: @"None" forKey: @"Public"];
      [rights setObject: @"None" forKey: @"Private"];
      [rights setObject: @"None" forKey: @"Confidential"];
    }

  return self;
}

- (void) dealloc
{
  [currentRight release];
  [currentRightType release];
  [rights release];
  [super dealloc];
}

- (void) prepareRightsForm
{
  NSEnumerator *roles, *types;
  NSString *role, *type;
  unsigned int length;

  roles = [userRights objectEnumerator];
  role = [roles nextObject];
  while (role)
    {
      types = [[self rightTypes] objectEnumerator];
      type = [types nextObject];
      while (type)
	{
	  if ([role hasPrefix: type])
	    {
	      length = [type length];
	      [rights setObject: [role substringFromIndex: length]
		      forKey: type];
	    }
	  type = [types nextObject];
	}
      role = [roles nextObject];
    }
}

- (NSArray *) _rightsForType: (NSString *) type
{
  NSMutableArray *rightsForType;
  NSEnumerator *commonRights;
  NSString *currentCommonRight;

  rightsForType = [NSMutableArray new];
  [rightsForType autorelease];
  commonRights = [[self objectRights] objectEnumerator];
  currentCommonRight = [commonRights nextObject];
  while (currentCommonRight)
    {
      [rightsForType addObject: [NSString stringWithFormat: @"%@%@",
					  type, currentCommonRight]];
      currentCommonRight = [commonRights nextObject];
    }

  return rightsForType;
}

- (void) updateRights
{
  NSEnumerator *types;
  NSString *currentType, *currentValue;
  NSArray *rightsForType;
  WORequest *request;

  request = [context request];
  types = [[self rightTypes] objectEnumerator];
  currentType = [types nextObject];
  while (currentType)
    {
      rightsForType = [self _rightsForType: currentType];
      currentValue
	= [request formValueForKey:
		     [NSString stringWithFormat: @"%@Right", currentType]];
      if ([currentValue isEqualToString: @"None"])
	[self removeAllRightsFromList: rightsForType];
      else
	[self appendExclusiveRight: [NSString stringWithFormat: @"%@%@",
					      currentType, currentValue]
	      fromList: rightsForType];
      currentType = [types nextObject];
    }

  if ([[request formValueForKey: @"ObjectCreator"] length] > 0)
    [self appendRight: SOGoRole_ObjectCreator];
  else
    [self removeRight: SOGoRole_ObjectCreator];

  if ([[request formValueForKey: @"ObjectEraser"] length] > 0)
    [self appendRight: SOGoRole_ObjectEraser];
  else
    [self removeRight: SOGoRole_ObjectEraser];
}

- (NSArray *) objectRights
{
  return
    [NSArray arrayWithObjects:
	       @"Viewer", @"DAndTViewer", @"Modifier", @"Responder", @"None", nil];
}

- (void) setCurrentRight: (NSString *) newCurrentRight
{
  ASSIGN (currentRight, newCurrentRight);
}

- (NSString *) currentRight
{
  return currentRight;
}

- (NSArray *) rightTypes
{
  return
    [NSArray arrayWithObjects: @"Public", @"Confidential", @"Private", nil];
}

- (void) setCurrentRightType: (NSString *) newCurrentRightType
{
  ASSIGN (currentRightType, newCurrentRightType);
}

- (NSString *) currentRightType
{
  return currentRightType;
}

- (NSString *) currentRightTypeLabel
{
  return [self labelForKey:
		 [NSString stringWithFormat: @"label_%@", currentRightType]];
}

- (NSString *) currentRightTypeName
{
  return [NSString stringWithFormat: @"%@Right", currentRightType];
}

- (NSString *) currentRightSelection
{
  return [rights objectForKey: currentRightType];
}

- (void) setUserCanCreateObjects: (BOOL) userCanCreateObjects
{
  [self appendRight: SOGoRole_ObjectCreator];
}

- (BOOL) userCanCreateObjects
{
  return [userRights containsObject: SOGoRole_ObjectCreator];
}

- (void) setUserCanEraseObjects: (BOOL) userCanEraseObjects
{
  [self appendRight: SOGoRole_ObjectEraser];
}

- (BOOL) userCanEraseObjects
{
  return [userRights containsObject: SOGoRole_ObjectEraser];
}

@end
