/* UIxAclEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2006, 2007 Inverse groupe conseil
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSKeyValueCoding.h>
#import <NGObjWeb/SoUser.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGCards/iCalPerson.h>
#import <SoObjects/SOGo/LDAPUserManager.h>
#import <SoObjects/SOGo/SOGoContentObject.h>
#import <SoObjects/SOGo/SOGoPermissions.h>
#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>

#import "UIxAclEditor.h"

@implementation UIxAclEditor

- (id) init
{
  if ((self = [super init]))
    {
      aclUsers = nil;
      prepared = NO;
      publishInFreeBusy = NO;
      users = [NSMutableArray new];
      currentUser = nil;
      defaultUserID = nil;
      savedUIDs = nil;
    }

  return self;
}

- (void) dealloc
{
  [savedUIDs release];
  [users release];
  [currentUser release];
  [defaultUserID release];
  [super dealloc];
}

- (NSArray *) aclsForObject
{
  if (!aclUsers)
    aclUsers = [[self clientObject] aclUsers];

  return aclUsers;
}

- (NSString *) _displayNameForUID: (NSString *) uid
{
  LDAPUserManager *um;
  
  um = [LDAPUserManager sharedUserManager];

  return [NSString stringWithFormat: @"%@ <%@>",
		   [um getCNForUID: uid], [um getEmailForUID: uid]];
}

- (NSString *) ownerName
{
  NSString *ownerLogin;

  ownerLogin = [[self clientObject] ownerInContext: context];

  return [self _displayNameForUID: ownerLogin];
}

- (BOOL) hasOwner
{
  NSString *ownerLogin;

  ownerLogin = [[self clientObject] ownerInContext: context];

  return (![ownerLogin isEqualToString: @"nobody"]);
}

- (NSString *) defaultUserID
{
  if (!defaultUserID)
    ASSIGN (defaultUserID, [[self clientObject] defaultUserID]);

  return defaultUserID;
}

- (void) _prepareUsers
{
  NSEnumerator *aclsEnum;
  NSString *currentUID, *ownerLogin;

  ownerLogin = [[self clientObject] ownerInContext: context];
  if (!defaultUserID)
    ASSIGN (defaultUserID, [[self clientObject] defaultUserID]);

  aclsEnum = [[self aclsForObject] objectEnumerator];
  currentUID = [aclsEnum nextObject];
  while (currentUID)
    {
      if (!([currentUID isEqualToString: ownerLogin]
	    || [currentUID isEqualToString: defaultUserID]))
	[users addObjectUniquely: currentUID];
      currentUID = [aclsEnum nextObject];
    }

  prepared = YES;
}

- (NSArray *) usersForObject
{
  if (!prepared)
    [self _prepareUsers];

  return users;
}

- (void) setCurrentUser: (NSString *) newCurrentUser
{
  ASSIGN (currentUser, newCurrentUser);
}

- (NSString *) currentUser
{
  return currentUser;
}

- (NSString *) currentUserDisplayName
{
  return [self _displayNameForUID: currentUser];
}

- (void) setUserUIDS: (NSString *) retainedUsers
{
  if ([retainedUsers length] > 0)
    savedUIDs = [retainedUsers componentsSeparatedByString: @","];
  else
    savedUIDs = [NSArray new];
}

- (BOOL) shouldTakeValuesFromRequest: (WORequest *) request
                           inContext: (WOContext *) context
{
  return ([[request method] isEqualToString: @"POST"]);
}

- (id <WOActionResults>) saveAclsAction
{
  NSEnumerator *aclsEnum;
  SOGoObject *clientObject;
  NSString *currentUID, *ownerLogin;

  clientObject = [self clientObject];
  ownerLogin = [clientObject ownerInContext: context];
  aclsEnum = [[self aclsForObject] objectEnumerator];
  currentUID = [[aclsEnum nextObject] objectForKey: @"c_uid"];
  while (currentUID)
    {
      if ([currentUID isEqualToString: ownerLogin]
	  || [savedUIDs containsObject: currentUID])
        [users removeObject: currentUID];
      currentUID = [[aclsEnum nextObject] objectForKey: @"c_uid"];
    }
  [clientObject removeAclsForUsers: users];

  return [self jsCloseWithRefreshMethod: nil];
}

- (BOOL) canModifyAcls
{
  SoSecurityManager *mgr;

  mgr = [SoSecurityManager sharedSecurityManager];

  return (![mgr validatePermission: SOGoPerm_SaveAcls
		onObject: [self clientObject]
		inContext: context]);
}

// - (id <WOActionResults>) addUserInAcls
// {
//   SOGoObject *clientObject;
//   NSString *uid;

//   uid = [self queryParameterForKey: @"uid"];

//   clientObject = [self clientObject];
// }

@end
