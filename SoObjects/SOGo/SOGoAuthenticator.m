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

#import <NGLdap/NGLdapConnection.h>
#import "SOGoPermissions.h"

#include "SOGoAuthenticator.h"
#include "SOGoUser.h"
#include "common.h"

@implementation SOGoAuthenticator

static SOGoAuthenticator *auth = nil;

+ (id) sharedSOGoAuthenticator
{
  if (auth == nil)
    auth = [[self alloc] init];
  return auth;
}

- (id) init
{
  if ((self = [super init]))
    {
      ud = [NSUserDefaults standardUserDefaults];

      LDAPBaseDN = nil;
      LDAPHost = nil;
      LDAPPort = -1;

      authMethod = [[ud stringForKey:@"AuthentificationMethod"] retain];
      if ([authMethod isEqualToString: @"LDAP"])
	{
	  LDAPBaseDN = [[ud stringForKey:@"LDAPRootDN"] retain];
	  LDAPHost = [[ud stringForKey:@"LDAPHost"] retain];
	  LDAPPort = [ud integerForKey:@"LDAPPort"];
	}
    }

  return self;
}

- (void) dealloc
{
  if (LDAPBaseDN)
    [LDAPBaseDN release];
  if (LDAPHost)
    [LDAPHost release];
  [authMethod release];
  [super dealloc];
}

- (BOOL) checkLogin: (NSString *) _login
	   password: (NSString *) _pwd
{
  return (([_login isEqualToString: @"freebusy"]
           && [_pwd isEqualToString: @"freebusy"])
          || ([authMethod isEqualToString: @"LDAP"]
              && [self LDAPCheckLogin: _login password: _pwd])
          || [_login length] > 0);
}

- (BOOL) LDAPCheckLogin: (NSString *) _login
	       password: (NSString *) _pwd
{
  return [NGLdapConnection checkPassword: _pwd
			   ofLogin: _login
			   atBaseDN: LDAPBaseDN
			   onHost: LDAPHost
			   port: LDAPPort];
}

/* create SOGoUser */

- (SoUser *) userInContext:(WOContext *)_ctx
{
  static SoUser *anonymous = nil, *freebusy;
  NSString  *login;
  
  if (!anonymous)
    anonymous
      = [[SOGoUser alloc] initWithLogin:@"anonymous"
			  roles: [NSArray arrayWithObject: SoRole_Anonymous]];

  if (!freebusy)
    freebusy
      = [[SOGoUser alloc] initWithLogin: @"freebusy"
                          roles: [NSArray arrayWithObject: SOGoRole_FreeBusy]];

  if ((login = [self checkCredentialsInContext:_ctx]) == nil)
    /* some error (otherwise result would have been anonymous */
    return nil;
  
  if ([login isEqualToString: @"anonymous"])
    return anonymous;
  else if ([login isEqualToString: @"freebusy"])
    return freebusy;

//   uroles = [NSMutableArray arrayWithArray: ];

  return [[[SOGoUser alloc] initWithLogin: login
                            roles: [self rolesForLogin: login]]
	   autorelease];
}

// - (BOOL) renderException: (NSException *) exception
//                inContext: (WOContext *) context
// {
//   id renderedException;
//   WOComponent *tmpComponent;
//   WOResponse *response;
//   BOOL rc;

//   rc = [super renderException: exception inContext: context];
//   if (!rc)
//     {
//       tmpComponent = [WOComponent new];
//       renderedException = [tmpComponent pageWithName: @"UIxException"];
//       if (renderedException)
//         {
//           rc = YES;
//           response = [context response];
//           [response setHeader: @"text/html" forKey: @"content-type"];
//           [renderedException setClientObject: exception];
//           [context setPage: renderedException];
//           [renderedException appendToResponse: response
//                              inContext: context];
//         }
//       [tmpComponent release];
//     }

//   return rc;
// }

@end /* SOGoAuthenticator */
