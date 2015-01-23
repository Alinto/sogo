/* SOGoWebDAVAclManager.m - this file is part of SOGo
 *
 * Copyright (C) 2008-2015 Inverse inc.
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
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/SoClass.h>
#import <NGObjWeb/SoClassSecurityInfo.h>
#import <NGExtensions/NSObject+Logs.h>

#import "NSDictionary+Utilities.h"
#import "NSObject+DAV.h"
#import "SOGoObject.h"
#import "SOGoUser.h"
#import "SOGoWebDAVValue.h"

#import "SOGoWebDAVAclManager.h"

static NSNumber *yesObject = nil;

@interface SoClass (SOGoDAVPermissions)

- (BOOL) userRoles: (NSArray *) userRoles
    havePermission: (NSString *) permission;

@end

@implementation SoClass (SOGoDAVPermissions)

- (BOOL) userRoles: (NSArray *) userRoles
    havePermission: (NSString *) permission
{
  BOOL result;
  SoClass *currentClass;
  NSArray *roles;

  result = NO;

  currentClass = self;
  while (!result && currentClass)
    {
      roles = [[currentClass soClassSecurityInfo]
		defaultRolesForPermission: permission];
      if ([roles firstObjectCommonWithArray: userRoles])
	{
 	  // NSLog (@"matched '%@': %@", permission, roles);
	  result = YES;
	}
      else
	currentClass = [currentClass soSuperClass];
    }

  return result;
}

@end

@implementation SOGoWebDAVAclManager

+ (void) initialize
{
  if (!yesObject)
    {
      yesObject = [NSNumber numberWithBool: YES];
      [yesObject retain];
    }
}

- (id) init
{
  if ((self = [super init]))
    {
      aclTree = [NSMutableDictionary new];
      [self registerDAVPermission: davElement (@"all", @"DAV:")
                         abstract: YES
                   withEquivalent: nil
                        asChildOf: nil];
    }

  return self;
}

- (void) dealloc
{
  [aclTree release];
  [super dealloc];
}

- (void) _registerChild: (NSMutableDictionary *) newEntry
		     of: (NSDictionary *) parentPermission
{
  NSString *identifier;
  NSMutableDictionary *parentEntry;
  NSMutableArray *children;

  identifier = [parentPermission keysWithFormat: @"{%{ns}}%{method}"];
  parentEntry = [aclTree objectForKey: identifier];
  if (parentEntry)
    {
      children = [parentEntry objectForKey: @"children"];
      if (!children)
        {
          children = [NSMutableArray array];
          [parentEntry setObject: children forKey: @"children"];
        }
      [children addObject: newEntry];
      [newEntry setObject: parentEntry forKey: @"parent"];
    }
  else
    [self errorWithFormat: @"parent entry '%@' does not exist in DAV"
	  @" permissions table", identifier];
}

- (void) registerDAVPermission: (NSDictionary *) davPermission
	 	      abstract: (BOOL) abstract
		withEquivalent: (NSString *) sogoPermission
		     asChildOf: (NSDictionary *) otherDAVPermission
{
  NSMutableDictionary *newEntry;
  NSString *identifier;

  newEntry = [NSMutableDictionary new];
  identifier = [davPermission keysWithFormat: @"{%{ns}}%{method}"];
  if ([aclTree objectForKey: identifier])
    [self warnWithFormat:
            @"entry '%@' already exists in DAV permissions table",
          identifier];
  [aclTree setObject: newEntry forKey: identifier];
  [newEntry setObject: davPermission forKey: @"permission"];
  if (abstract)
    [newEntry setObject: yesObject forKey: @"abstract"];
  if (sogoPermission)
    [newEntry setObject: sogoPermission forKey: @"equivalent"];

  if (otherDAVPermission)
    [self _registerChild: newEntry of: otherDAVPermission];

  [newEntry release];
}

#warning this method should be simplified!
/* We add the permissions that fill those conditions:
   - should match the sogo permissions implied by the user roles
   If all the child permissions of a permission are included, then this
   permission will be included too. Conversely, if a permission is included,
   all the child permissions will be included too. */

- (BOOL) _fillArray: (NSMutableArray *) davPermissions
     withPermission: (NSDictionary *) permission
       forUserRoles: (NSArray *) userRoles
	withSoClass: (SoClass *) soClass
     matchSOGoPerms: (BOOL) matchSOGoPerms
{
  NSString *sogoPermission;
  NSDictionary *childPermission;
  NSEnumerator *children;
  BOOL appended, childrenAppended;

  // NSLog (@"attempt to add permission: %@",
  //        [permission objectForKey: @"permission"]);
  appended = YES;
  if (matchSOGoPerms)
    {
      sogoPermission = [permission objectForKey: @"equivalent"];
      if (sogoPermission
	  && [soClass userRoles: userRoles havePermission: sogoPermission])
	[davPermissions addObject: [permission objectForKey: @"permission"]];
      else
	appended = NO;
      // NSLog (@"permission '%@' appended: %d", sogoPermission, appended);
    }
  else
    [davPermissions
      addObject: [permission objectForKey: @"permission"]];

  children = [[permission objectForKey: @"children"] objectEnumerator];
  if (children)
    {
      childrenAppended = YES;
      while ((childPermission = [children nextObject]))
	childrenAppended &= [self _fillArray: davPermissions
                              withPermission: childPermission
                                forUserRoles: userRoles
                                 withSoClass: soClass
                              matchSOGoPerms: (matchSOGoPerms
                                               && !appended)];
      if (childrenAppended && !appended)
	{
          // NSLog (@"  adding perm '%@' because children were appended",
          //        [permission objectForKey: @"permission"]);
	  [davPermissions
	    addObject: [permission objectForKey: @"permission"]];
	  appended = YES;
	}
    }

  return appended;
}

- (NSArray *) davPermissionsForRoles: (NSArray *) roles
			    onObject: (SOGoObject *) object
{
  NSMutableArray *davPermissions;
  SoClass *soClass;

  davPermissions = [NSMutableArray array];
  soClass = [[object class] soClass];
  [self _fillArray: davPermissions
	withPermission: [aclTree objectForKey: @"{DAV:}all"]
	forUserRoles: roles
	withSoClass: soClass
	matchSOGoPerms: YES];

  return davPermissions;
}

- (SOGoWebDAVValue *)
    _supportedPrivilegeSetFromPermission: (NSDictionary *) perm
{
  NSMutableArray *privilege;
  NSEnumerator *children;
  NSDictionary *currentPerm;

  privilege = [NSMutableArray array];
  [privilege addObject:
	       davElementWithContent (@"privilege",
				      @"DAV:",
				      [perm objectForKey: @"permission"])];
  if ([[perm objectForKey: @"abstract"] boolValue])
    [privilege addObject: davElement (@"abstract", @"DAV:")];
  children = [[perm objectForKey: @"children"] objectEnumerator];
  while ((currentPerm = [children nextObject]))
    [privilege addObject:
		 [self _supportedPrivilegeSetFromPermission: currentPerm]];

  return davElementWithContent (@"supported-privilege",
				@"DAV:", privilege);
}

- (SOGoWebDAVValue *) treeAsWebDAVValue
{
  return [self _supportedPrivilegeSetFromPermission:
		 [aclTree objectForKey: @"{DAV:}all"]];
}

- (id) copyWithZone: (NSZone *) aZone
{
  SOGoWebDAVAclManager *x;

  x = [[SOGoWebDAVAclManager allocWithZone: aZone] init];
  x->aclTree = [aclTree mutableCopyWithZone: aZone];

  return x;
}

@end
