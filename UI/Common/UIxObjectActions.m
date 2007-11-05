/* UIxObjectActions.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
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
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <SoObjects/SOGo/LDAPUserManager.h>
#import <SoObjects/SOGo/SOGoObject.h>
#import <SoObjects/SOGo/SOGoPermissions.h>

#import "UIxObjectActions.h"

static BOOL sendACLAdvisories = NO;

@implementation UIxObjectActions

+ (void) initialize
{
  NSUserDefaults *ud;

  ud = [NSUserDefaults standardUserDefaults];
  sendACLAdvisories = [ud boolForKey: @"SOGoACLsSendEMailNotifications"];
}

- (WOResponse *) addUserInAclsAction
{
  WOResponse *response;
  WORequest *request;
  NSString *uid;
  unsigned int code;
  LDAPUserManager *um;
  SOGoObject *clientObject;

  code = 403;
  request = [context request];
  uid = [request formValueForKey: @"uid"];
  if ([uid length] > 0)
    {
      um = [LDAPUserManager sharedUserManager];
      if ([um contactInfosForUserWithUIDorEmail: uid])
        {
	  clientObject = [self clientObject];
	  [clientObject setRoles: [clientObject aclsForUser: uid]
			forUser: uid];
	  if (sendACLAdvisories)
	    [clientObject sendACLAdditionAdvisoryToUser: uid];
          code = 204;
        }
    }

  response = [context response];
  [response setStatus: code];

  return response;
}

- (WOResponse *) removeUserFromAclsAction
{
  WOResponse *response;
  WORequest *request;
  NSString *uid;
  unsigned int code;
  LDAPUserManager *um;
  SOGoObject *co;

  code = 403;
  request = [context request];
  uid = [request formValueForKey: @"uid"];
  if ([uid length] > 0)
    {
      um = [LDAPUserManager sharedUserManager];
      if ([um contactInfosForUserWithUIDorEmail: uid])
	{
	  co = [self clientObject];
	  [co removeAclsForUsers: [NSArray arrayWithObject: uid]];
	  if (sendACLAdvisories)
	    [co sendACLRemovalAdvisoryToUser: uid];
          code = 204;
        }
    }

  response = [context response];
  [response setStatus: code];

  return response;
}

@end
