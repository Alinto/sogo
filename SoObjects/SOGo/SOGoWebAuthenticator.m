/* SOGoWebAuthenticator.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2010 Inverse inc.
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

#import <NGObjWeb/SoDefaultRenderer.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOCookie.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGLdap/NGLdapConnection.h>

#import <MainUI/SOGoRootPage.h>

#import "SOGoCASSession.h"
#import "SOGoConstants.h"
#import "SOGoPermissions.h"
#import "SOGoSystemDefaults.h"
#import "SOGoUser.h"
#import "SOGoUserManager.h"

#import "SOGoWebAuthenticator.h"

@implementation SOGoWebAuthenticator

+ (id) sharedSOGoWebAuthenticator
{
  static SOGoWebAuthenticator *auth = nil;
 
  if (!auth)
    auth = [self new];

  return auth;
}

- (BOOL) checkLogin: (NSString *) _login
	   password: (NSString *) _pwd
{
  SOGoPasswordPolicyError perr;
  int expire, grace;

  return [self checkLogin: _login
	       password: _pwd
	       perr: &perr
	       expire: &expire
	       grace: &grace];
}

- (BOOL) checkLogin: (NSString *) _login
	   password: (NSString *) _pwd
	       perr: (SOGoPasswordPolicyError *) _perr
	     expire: (int *) _expire
	      grace: (int *) _grace
{
  SOGoCASSession *session;
  SOGoSystemDefaults *sd;
  BOOL rc;

  sd = [SOGoSystemDefaults sharedSystemDefaults];

  if ([[sd authenticationType] isEqualToString: @"cas"])
    {
      session = [SOGoCASSession CASSessionWithIdentifier: _pwd];
      if (session)
        rc = [[session login] isEqualToString: _login];
      else
        rc = NO;
    }
  else
    rc = [[SOGoUserManager sharedUserManager] checkLogin: _login
					      password: _pwd
					      perr: _perr
					      expire: _expire
					      grace: _grace];
  
  //  [self logWithFormat: @"Checked login with ppolicy enabled: %d %d %d", *_perr, *_expire, *_grace];
  
  // It's important to return the real value here. The callee will handle
  // the return code and check for the _perr value.
  return rc;
}

- (SOGoUser *) userInContext: (WOContext *)_ctx
{
  static SOGoUser *anonymous = nil;
  SOGoUser *user;

  user = (SOGoUser *) [super userInContext: _ctx];
  if (!user)
    {
      if (!anonymous)
        anonymous = [[SOGoUser alloc]
                      initWithLogin: @"anonymous"
                              roles: [NSArray arrayWithObject: SoRole_Anonymous]];
      user = anonymous;
    }

  return user;
}

- (NSString *) passwordInContext: (WOContext *) context
{
  NSArray *creds;
  NSString *auth, *password;

  auth = [[context request]
           cookieValueForKey: [self cookieNameInContext: context]];
  creds = [self parseCredentials: auth];
  if ([creds count] > 1)
    password = [creds objectAtIndex: 1];
  else
    password = nil;

  return password;
}

- (NSString *) imapPasswordInContext: (WOContext *) context
                           forServer: (NSString *) imapServer
                          forceRenew: (BOOL) renew
{
  SOGoSystemDefaults *sd;
  SOGoCASSession *session;
  NSString *password, *service;

  password = [self passwordInContext: context];
  if ([password length])
    {
      sd = [SOGoSystemDefaults sharedSystemDefaults];
      if ([[sd authenticationType] isEqualToString: @"cas"])
        {
          session = [SOGoCASSession CASSessionWithIdentifier: password];
          service = [NSString stringWithFormat: @"imap://%@", imapServer];
          if (renew)
            [session invalidateTicketForService: service];
          password = [session ticketForService: service];
          if ([password length] || renew)
            [session updateCache];
        }
    }

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
  WORequest *request;
  WOCookie *authCookie;
  NSCalendarDate *date;
  NSString *appName;

  request = [context request];
  page = [[WOApplication application] pageWithName: @"SOGoRootPage"
                                        forRequest: request];
  [[SoDefaultRenderer sharedRenderer] renderObject: [page defaultAction]
                                         inContext: context];
  authCookie = [WOCookie cookieWithName: [self cookieNameInContext: context]
                                  value: @"discard"];
  appName = [request applicationName];
  [authCookie setPath: [NSString stringWithFormat: @"/%@/", appName]];
  date = [NSCalendarDate calendarDate];
  [authCookie setExpires: [date yesterday]];
  [response addCookie: authCookie];
}

@end /* SOGoWebAuthenticator */
