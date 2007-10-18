/*
  Copyright (C) 2004 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOResponse.h>
#import <NGLdap/NGLdapConnection.h>

#import "LDAPUserManager.h"
#import "SOGoPermissions.h"
#import "SOGoUser.h"

#import "SOGoDAVAuthenticator.h"

@implementation SOGoDAVAuthenticator

+ (id) sharedSOGoDAVAuthenticator
{
  static SOGoDAVAuthenticator *auth = nil;
 
  if (!auth)
    auth = [self new];

  return auth;
}

- (id) init
{
  if ((self = [super init]))
    {
      authMethod = [[NSUserDefaults standardUserDefaults]
		     stringForKey: @"SOGoAuthentificationMethod"];
      [authMethod retain];
    }

  return self;
}

- (void) dealloc
{
  [authMethod release];
  [super dealloc];
}

- (BOOL) checkLogin: (NSString *) _login
	   password: (NSString *) _pwd
{
  BOOL accept;
  LDAPUserManager *um;

  if ([authMethod isEqualToString: @"LDAP"])
    {
      um = [LDAPUserManager sharedUserManager];
      accept = [um checkLogin: _login andPassword: _pwd];
    }
  else
    accept = ([authMethod isEqualToString: @"bypass"]
	      && [_login length] > 0);

  return accept;
// 	  || ([_login isEqualToString: @"freebusy"]
// 	      && [_pwd isEqualToString: @"freebusy"]));
}

- (NSString *) passwordInContext: (WOContext *) context
{
  NSString  *auth, *password;
  NSArray   *creds;

  password = nil;
  auth = [[context request] headerForKey: @"authorization"];
  if (auth)
    {
      creds = [self parseCredentials: auth];
      if ([creds count] > 1)
	password = [creds objectAtIndex: 1];
    }

  return password;
}

/* create SOGoUser */

- (SOGoUser *) userInContext: (WOContext *)_ctx
{
  static SOGoUser *anonymous = nil;
  SOGoUser *user;
  NSArray *traversalPath;
  NSString *login;

  if (!anonymous)
    anonymous
      = [[SOGoUser alloc] initWithLogin: @"anonymous"
			  roles: [NSArray arrayWithObject: SoRole_Anonymous]];

  login = [self checkCredentialsInContext:_ctx];
  if (login)
    {
      if ([login isEqualToString: @"anonymous"])
        {
          traversalPath = [_ctx objectForKey: @"SoRequestTraversalPath"];
	  user = anonymous;
        }
      else
	{
	  user = [SOGoUser userWithLogin: login
			   roles: [self rolesForLogin: login]];
	  [user setCurrentPassword: [self passwordInContext: _ctx]];
	}
    }
  else
    user = nil;

  return user;
}

@end /* SOGoDAVAuthenticator */
