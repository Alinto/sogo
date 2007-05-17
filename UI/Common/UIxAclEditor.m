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
#import <NGCards/iCalPerson.h>
#import <SoObjects/SOGo/LDAPUserManager.h>
#import <SoObjects/SOGo/SOGoContentObject.h>
#import <SoObjects/SOGo/SOGoPermissions.h>

#import "UIxAclEditor.h"

@implementation UIxAclEditor

- (id) init
{
  if ((self = [super init]))
    {
      acls = nil;
      prepared = NO;
      publishInFreeBusy = NO;
      users = [NSMutableArray new];
      currentUser = nil;
      savedUIDs = nil;
    }

  return self;
}

- (void) dealloc
{
  [savedUIDs release];
  [users release];
  [currentUser release];
  [super dealloc];
}

- (NSArray *) aclsForObject
{
  if (!acls)
    acls = [[self clientObject] acls];

  return acls;
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

- (NSString *) defaultUserID
{
  return SOGoDefaultUserID;
}

- (void) _prepareUsers
{
  NSEnumerator *aclsEnum;
  NSDictionary *currentAcl;
  NSString *currentUID, *ownerLogin;

  ownerLogin = [[self clientObject] ownerInContext: context];

  aclsEnum = [[self aclsForObject] objectEnumerator];
  currentAcl = [aclsEnum nextObject];
  while (currentAcl)
    {
      currentUID = [currentAcl objectForKey: @"c_uid"];
      if (!([currentUID isEqualToString: ownerLogin]
	    || [currentUID isEqualToString: SOGoDefaultUserID]
	    || [users containsObject: currentUID]))
	  [users addObject: currentUID];
      currentAcl = [aclsEnum nextObject];

      prepared = YES;
    }
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

- (NSString *) toolbar
{
  NSString *currentLogin, *ownerLogin;

  currentLogin = [[context activeUser] login];
  ownerLogin = [[self clientObject] ownerInContext: context];

  return (([ownerLogin isEqualToString: currentLogin])
          ? @"SOGoAclOwner.toolbar" : @"SOGoAclAssistant.toolbar");
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

- (BOOL) currentUserIsOwner
{
  SOGoObject *clientObject;
  NSString *currentUserLogin, *ownerLogin;

  clientObject = [self clientObject];
  ownerLogin = [clientObject ownerInContext: context];
  currentUserLogin = [[context activeUser] login];

  return [ownerLogin isEqualToString: currentUserLogin];
}

// - (id <WOActionResults>) addUserInAcls
// {
//   SOGoObject *clientObject;
//   NSString *uid;

//   uid = [self queryParameterForKey: @"uid"];

//   clientObject = [self clientObject];
// }

@end
