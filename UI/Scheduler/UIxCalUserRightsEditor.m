/* UIxCalUserRightsEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2015 Inverse inc.
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
#import <Foundation/NSValue.h>
#import <SoObjects/SOGo/SOGoPermissions.h>

#import "UIxCalUserRightsEditor.h"

@implementation UIxCalUserRightsEditor

- (id) init
{
  if ((self = [super init]))
    {
      currentRight = nil;
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
  [rights release];
  [super dealloc];
}

- (void) prepareRightsForm
{
  NSEnumerator *roles, *types;
  NSString *role, *type;

  types = [[self rightTypes] objectEnumerator];
  type = [types nextObject];
  while (type)
    {
      roles = [userRights objectEnumerator];
      role = [roles nextObject];
      while (role)
        {
          if ([role hasPrefix: type])
            {
              [rights setObject: [role substringFromIndex: [type length]]
                         forKey: type];
              break;
            }
          role = [roles nextObject];
        }
      type = [types nextObject];
    }
}

- (NSArray *) _rightsForType: (NSString *) type
{
  NSMutableArray *rightsForType;
  NSEnumerator *commonRights;
  NSString *currentCommonRight;

  rightsForType = [NSMutableArray arrayWithCapacity: 5];
  commonRights = [[self objectRights] objectEnumerator];
  while ((currentCommonRight = [commonRights nextObject]))
    [rightsForType addObject: [NSString stringWithFormat: @"%@%@",
                                        type, currentCommonRight]];

  return rightsForType;
}

/**
 * @see [UIxUserRightsEditor userRightsAction]
 */
- (NSDictionary *) userRightsForObject
{
  NSMutableDictionary *d;
  
  [self prepareRightsForm];

  d = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                               [NSNumber numberWithBool:[self userCanCreateObjects]], @"canCreateObjects",
                               [NSNumber numberWithBool:[self userCanEraseObjects]], @"canEraseObjects",
                           nil];

  [d addEntriesFromDictionary: rights];

  return d;
}

/**
 * @see [UIxUserRightsEditor saveUserRightsAction]
 */
- (void) updateRights: (NSDictionary *) newRights
{
  NSEnumerator *types;
  NSString *currentType, *currentValue;
  NSArray *rightsForType;

  types = [[self rightTypes] objectEnumerator];
  currentType = [types nextObject];
  while (currentType)
    {
      rightsForType = [self _rightsForType: currentType];
      currentValue = [newRights objectForKey: currentType];
	
      if ([currentValue isEqualToString: @"None"])
	[self removeAllRightsFromList: rightsForType];
      else
        {
          currentValue = [NSString stringWithFormat: @"%@%@", currentType, currentValue];
          if ([rightsForType containsObject: currentValue])
            [self appendExclusiveRight: currentValue
                              fromList: rightsForType];
        }
      currentType = [types nextObject];
    }

  if ([[newRights objectForKey: @"canCreateObjects"] boolValue])
    [self appendRight: SOGoRole_ObjectCreator];
  else
    [self removeRight: SOGoRole_ObjectCreator];

  if ([[newRights objectForKey: @"canEraseObjects"] boolValue])
    [self appendRight: SOGoRole_ObjectEraser];
  else
    [self removeRight: SOGoRole_ObjectEraser];
}

- (NSArray *) objectRights
{
  return ([uid isEqualToString: @"anonymous"]
          ? [NSArray arrayWithObjects: @"None", @"DAndTViewer", @"Viewer",
                     nil]
          : [NSArray arrayWithObjects: @"None", @"DAndTViewer", @"Viewer",
		     @"Responder", @"Modifier", nil]);
}

- (NSArray *) rightTypes
{
  return [NSArray arrayWithObjects: @"Public", @"Confidential", @"Private", nil];
}

- (void) setCurrentRight: (NSString *) newCurrentRight
{
  ASSIGN (currentRight, newCurrentRight);
}

- (NSString *) currentRight
{
  return currentRight;
}

- (NSString *) currentRightLabel
{
  return [self labelForKey:
		 [NSString stringWithFormat: @"label_%@", currentRight]];
}

- (BOOL) userCanCreateObjects
{
  return [userRights containsObject: SOGoRole_ObjectCreator];
}

- (BOOL) userCanEraseObjects
{
  return [userRights containsObject: SOGoRole_ObjectEraser];
}

@end
