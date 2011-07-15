/* SOGoWebAuthenticator.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2011 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Francis Lachapelle <flachapelle@inverse.ca>
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
#import <Foundation/NSURL.h>

#import <NGObjWeb/SoDefaultRenderer.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOCookie.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGLdap/NGLdapConnection.h>

#import <MainUI/SOGoRootPage.h>

#import "SOGoCache.h"
#import "SOGoCASSession.h"
#import "SOGoConstants.h"
#import "SOGoPermissions.h"
#import "SOGoSession.h"
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
  NSString *username, *password, *domain, *value;
  SOGoPasswordPolicyError perr;
  int expire, grace;
 

  // We check for the existence of the session in the database/memcache
  // and we extract the real password from it. Here,
  //
  // _login == userKey
  // _pwd == sessionKey
  //
  // If the session isn't present in the database, we fail the login process.
  //
  value = [SOGoSession valueForSessionKey: _pwd];

  if (!value)
    return NO;

  domain = nil;
  [SOGoSession decodeValue: value
                  usingKey: _login
                     login: &username
                    domain: &domain
                  password: &password];

  return [self checkLogin: username
                 password: password
                   domain: &domain
                     perr: &perr
                   expire: &expire
                    grace: &grace];
}

- (BOOL) checkLogin: (NSString *) _login
	   password: (NSString *) _pwd
             domain: (NSString **) _domain
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
      session = [SOGoCASSession CASSessionWithIdentifier: _pwd fromProxy: NO];
      if (session)
        rc = [[session login] isEqualToString: _login];
      else
        rc = NO;
    }
  else
    rc = [[SOGoUserManager sharedUserManager] checkLogin: _login
                                                password: _pwd
                                                  domain: _domain
                                                    perr: _perr
                                                  expire: _expire
                                                   grace: _grace];
  
  //[self logWithFormat: @"Checked login with ppolicy enabled: %d %d %d", *_perr, *_expire, *_grace];
  
  // It's important to return the real value here. The callee will handle
  // the return code and check for the _perr value.
  return rc;
}

//
//
//
- (SOGoUser *) userInContext: (WOContext *)_ctx
{
  static SOGoUser *anonymous = nil;
  SOGoUser *user;

  user = (SOGoUser *) [super userInContext: _ctx];
  if (!user || [[user login] isEqualToString: @"anonymous"])
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
  NSString *auth, *password;
  NSArray *creds;

  auth = [[context request]
           cookieValueForKey: [self cookieNameInContext: context]];
  creds = [self parseCredentials: auth];
  if ([creds count] > 1)
    {
      NSString *login, *domain;
      
      [SOGoSession decodeValue: [SOGoSession valueForSessionKey: [creds objectAtIndex: 1]]
                      usingKey: [creds objectAtIndex: 0]
                         login: &login
                        domain: &domain
                      password: &password];
    }
  else
    password = nil;

  return password;
}

//
// We overwrite SOPE's method in order to proper retrieve
// the username from the cookie.
//
- (NSString *) checkCredentials: (NSString *)_creds
{
  NSString *login, *domain, *pwd, *userKey, *sessionKey;
  NSArray *creds;

  SOGoPasswordPolicyError perr;
  int expire, grace;
  
  if (![(creds = [self parseCredentials:_creds]) isNotEmpty])
    return nil;

  userKey = [creds objectAtIndex:0];
  if ([userKey isEqualToString:@"anonymous"])
    return @"anonymous";
  
  sessionKey = [creds objectAtIndex:1];
  
  [SOGoSession decodeValue: [SOGoSession valueForSessionKey: sessionKey]
                  usingKey: userKey
                     login: &login
                    domain: &domain
                  password: &pwd];
  
  if (![self checkLogin: login
               password: pwd
                 domain: &domain
                   perr: &perr
                 expire: &expire
                  grace: &grace])
    return nil;
  
  if (domain)
    login = [NSString stringWithFormat: @"%@@%@", login, domain];

  return login;
}


- (NSString *) imapPasswordInContext: (WOContext *) context
                              forURL: (NSURL *) server
                          forceRenew: (BOOL) renew
{
  NSString *password, *service, *scheme;
  SOGoCASSession *session;
  SOGoSystemDefaults *sd;
 
  password = [self passwordInContext: context];
  if ([password length])
    {
      sd = [SOGoSystemDefaults sharedSystemDefaults];
      if ([[sd authenticationType] isEqualToString: @"cas"])
        {
          session = [SOGoCASSession CASSessionWithIdentifier: password
                                                   fromProxy: NO];

	  // We must NOT assume the scheme exists
	  scheme = [server scheme];

	  if (!scheme)
	    scheme = @"imap";

	  service = [NSString stringWithFormat: @"%@://%@", scheme, [server host]];

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

//
// This is called by SoObjectRequestHandler prior doing any significant
// processing to allow the authenticator to reject invalid requests.
//
- (WOResponse *) preprocessCredentialsInContext: (WOContext *) context
{
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
