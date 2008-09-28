/* SOGoWebAuthenticator.m - this file is part of SOGo
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
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/SoDefaultRenderer.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOCookie.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGLdap/NGLdapConnection.h>

#import <UI/MainUI/SOGoRootPage.h>

#import "LDAPUserManager.h"
#import "SOGoPermissions.h"
#import "SOGoUser.h"

#import "SOGoWebAuthenticator.h"

@implementation SOGoWebAuthenticator

+ (id) sharedSOGoWebAuthenticator
{
  static SOGoWebAuthenticator *auth = nil;
 
  if (!auth)
    auth = [self new];

  return auth;
}

- (id) init
{
  NSUserDefaults *ud;

  if ((self = [super init]))
    {
      ud = [NSUserDefaults standardUserDefaults];
      authMethod = [ud stringForKey: @"SOGoAuthenticationMethod"];
      if (!authMethod)
	authMethod = [ud stringForKey: @"SOGoAuthentificationMethod"];
      if (!authMethod)
	{
	  authMethod = @"LDAP";
	  [self warnWithFormat:
		  @"authentication method automatically set to '%@'",
		authMethod];
	}
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
    accept = NO;
//   else
//     accept = ([authMethod isEqualToString: @"bypass"]
// 	      && [_login length] > 0);

  return accept;
// 	  || ([_login isEqualToString: @"freebusy"]
// 	      && [_pwd isEqualToString: @"freebusy"]));
}

- (SOGoUser *) userInContext: (WOContext *)_ctx
{
  static SOGoUser *anonymous = nil;
  SOGoUser *user;

  if (!anonymous)
    anonymous
      = [[SOGoUser alloc] initWithLogin: @"anonymous"
			  roles: [NSArray arrayWithObject: SoRole_Anonymous]];

  user = (SOGoUser *) [super userInContext: _ctx];
  if (!user)
    user = anonymous;

  return user;
}

- (NSString *) passwordInContext: (WOContext *) context
{
  NSArray *creds;
  NSString *auth, *password;
  
  auth = [[context request] cookieValueForKey:
			      [self cookieNameInContext: context]];
  creds = [self parseCredentials: auth];
  if ([creds count] > 1)
    password = [creds objectAtIndex: 1];
  else
    password = nil;

  return password;
}

/* create SOGoUser */

- (SOGoUser *) userWithLogin: (NSString *) login
		    andRoles: (NSArray *) roles
		   inContext: (WOContext *) ctx
{
  /* the actual factory method */
  return [SOGoUser userWithLogin: login roles: roles];
}

- (WOResponse *) preprocessCredentialsInContext: (WOContext *) context
{
  /*
    This is called by SoObjectRequestHandler prior doing any significant
    processing to allow the authenticator to reject invalid requests.
  */
  WOResponse *response;
  NSString *auth;
  
  auth = [[context request]
	   cookieValueForKey: [self cookieNameInContext:context]];
  if ([auth isEqualToString: @"discard"])
    {
      [context setObject: [NSArray arrayWithObject: SoRole_Anonymous]
	       forKey: @"SoAuthenticatedRoles"];
      response = nil;
    }
  else
    response = [super preprocessCredentialsInContext: context];

  return response;
}

- (void) setupAuthFailResponse: (WOResponse *) response
		    withReason: (NSString *) reason
		     inContext: (WOContext *) context
{
  WOComponent *page;
  WOCookie *authCookie;
  NSCalendarDate *date;

  page = [[WOApplication application] pageWithName: @"SOGoRootPage"
				      forRequest: [context request]];
  [[SoDefaultRenderer sharedRenderer] renderObject: page
				      inContext: context];
  authCookie = [WOCookie cookieWithName: [self cookieNameInContext: context]
                         value: @"discard"];
  [authCookie setPath: @"/"];
  date = [NSCalendarDate calendarDate];
  [authCookie setExpires: [date yesterday]];
  [response addCookie: authCookie];
}

@end /* SOGoWebAuthenticator */
