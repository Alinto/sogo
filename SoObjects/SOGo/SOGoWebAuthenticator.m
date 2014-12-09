/* SOGoWebAuthenticator.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2014 Inverse inc.
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
#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSData+gzip.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSString+Ext.h>
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
#if defined(SAML2_CONFIG)
#import "SOGoSAML2Session.h"
#endif
#import "SOGoWebAuthenticator.h"

#define COOKIE_SESSIONKEY_LEN 16
/* the key b64 encoded key XORed with the cookie value
 * must fit in the database field which is 255 char long at the moment
 */
#define COOKIE_USERKEY_LEN    160

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
  return [self checkLogin: _login
                 password: _pwd
                   domain: _domain
                     perr: _perr
                   expire: _expire
                    grace: _grace
                 useCache: YES];
}

- (BOOL) checkLogin: (NSString *) _login
           password: (NSString *) _pwd
             domain: (NSString **) _domain
               perr: (SOGoPasswordPolicyError *) _perr
             expire: (int *) _expire
              grace: (int *) _grace
           useCache: (BOOL) _useCache
{
  SOGoCASSession *session;
  SOGoSystemDefaults *sd;
  NSString *authenticationType;
  BOOL rc;

  sd = [SOGoSystemDefaults sharedSystemDefaults];

  authenticationType = [sd authenticationType];
  if ([authenticationType isEqualToString: @"cas"])
    {
      session = [SOGoCASSession CASSessionWithIdentifier: _pwd fromProxy: NO];
      if (session)
        rc = [[session login] isEqualToString: _login];
      else
        rc = NO;
    }
#if defined(SAML2_CONFIG)
  else if ([authenticationType isEqualToString: @"saml2"])
    {
      SOGoSAML2Session *saml2Session;
      WOContext *context;

      context = [[WOApplication application] context];
      saml2Session = [SOGoSAML2Session SAML2SessionWithIdentifier: _pwd
                                                        inContext: context];
      rc = [[saml2Session login] isEqualToString: _login];
    }
#endif /* SAML2_CONFIG */
  else
    rc = [[SOGoUserManager sharedUserManager] checkLogin: _login
                                                password: _pwd
                                                  domain: _domain
                                                    perr: _perr
                                                  expire: _expire
                                                   grace: _grace
                                                useCache: _useCache];
  
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
  
  if (domain && [login rangeOfString: @"@"].location == NSNotFound)
    login = [NSString stringWithFormat: @"%@@%@", login, domain];

  return login;
}


- (NSString *) imapPasswordInContext: (WOContext *) context
                              forURL: (NSURL *) server
                          forceRenew: (BOOL) renew
{
  NSString *authType, *password;
  SOGoSystemDefaults *sd;
 
  password = [self passwordInContext: context];
  if ([password length])
    {
      sd = [SOGoSystemDefaults sharedSystemDefaults];
      authType = [sd authenticationType];
      if ([authType isEqualToString: @"cas"])
        {
          SOGoCASSession *session;
          SOGoUser *user;
          NSString *service, *scheme;

          session = [SOGoCASSession CASSessionWithIdentifier: password
                                                   fromProxy: NO];

          user = [self userInContext: context];
          // Try configured CAS service name first
          service = [[user domainDefaults] imapCASServiceName];
          if (!service)
            {
              // We must NOT assume the scheme exists
              scheme = [server scheme];

              if (!scheme)
                scheme = @"imap";

              service = [NSString stringWithFormat: @"%@://%@",
                         scheme, [server host]];
            }

          if (renew)
            [session invalidateTicketForService: service];

          password = [session ticketForService: service];

          if ([password length] || renew)
            [session updateCache];
        }
#if defined(SAML2_CONFIG)
      else if ([authType isEqualToString: @"saml2"])
        {
          SOGoSAML2Session *session;
          WOContext *context;
          NSData *assertion;

          context = [[WOApplication application] context];
          session = [SOGoSAML2Session SAML2SessionWithIdentifier: password
                                                       inContext: context];
          assertion = [[session assertion]
                        dataUsingEncoding: NSUTF8StringEncoding];
          password = [[[assertion compress] stringByEncodingBase64]
                       stringByReplacingString: @"\n"
                                    withString: @""];
        }
#endif
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

- (WOCookie *) cookieWithUsername: (NSString *) username
                      andPassword: (NSString *) password
                        inContext: (WOContext *) context
{
  WOCookie *authCookie;
  NSString *cookieValue, *cookieString, *appName, *sessionKey, *userKey, *securedPassword;

  //
  // We create a new cookie - thus we create a new session
  // associated to the user. For security, we generate:
  //
  // A- a session key
  // B- a user key
  //
  // In memcached, the session key will be associated to the user's password
  // which will be XOR'ed with the user key.
  //
  sessionKey = [SOGoSession generateKeyForLength: COOKIE_SESSIONKEY_LEN];
  userKey = [SOGoSession generateKeyForLength: COOKIE_USERKEY_LEN];

  NSString *value = [NSString stringWithFormat: @"%@:%@", username, password];
  securedPassword = [SOGoSession securedValue: value  usingKey: userKey];


  [SOGoSession setValue: securedPassword  forSessionKey: sessionKey];

  //cookieString = [NSString stringWithFormat: @"%@:%@",
  //                         username, password];
  cookieString = [NSString stringWithFormat: @"%@:%@",
                           userKey, sessionKey];
  cookieValue = [NSString stringWithFormat: @"basic %@",
                          [cookieString stringByEncodingBase64]];
  authCookie = [WOCookie cookieWithName: [self cookieNameInContext: context]
                                  value: cookieValue];
  appName = [[context request] applicationName];
  [authCookie setPath: [NSString stringWithFormat: @"/%@/", appName]];
  
  return authCookie;
}

@end /* SOGoWebAuthenticator */
