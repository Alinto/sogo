/* SOGoProxyAuthenticator.h - this file is part of SOGo
 *
 * Copyright (C) 2009-2013 Inverse inc.
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

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSObject+Logs.h>

#import "SOGoPermissions.h"
#import "SOGoSystemDefaults.h"
#import "SOGoUser.h"

#import "SOGoProxyAuthenticator.h"

@implementation SOGoProxyAuthenticator

+ (id) sharedSOGoProxyAuthenticator
{
  static SOGoProxyAuthenticator *auth = nil;
 
  if (!auth)
    auth = [self new];

  return auth;
}

- (BOOL) checkLogin: (NSString *) _login
           password: (NSString *) _pwd
{
  return YES;
}

/* create SOGoUser */

- (NSString *) checkCredentialsInContext: (WOContext *) context
{
  NSString *remoteUser;


  /* If such a header is not provided by the proxy, SOPE will attempt to
     deduce it from the "Authorization" header. */
  remoteUser = [[context request] headerForKey: @"x-webobjects-remote-user"];
   
  if ([remoteUser length] == 0 && [[SOGoSystemDefaults sharedSystemDefaults] trustProxyAuthentication])
    {
      remoteUser = @"anonymous";
    }
  
  return remoteUser;
}

- (WOResponse *) unauthorized: (NSString *) reason
                    inContext: (WOContext *) context
{
  WOResponse *r;

  if (![reason length])
    reason = @"Unauthorized";
  
  r = [context response];
  [r setStatus: 403 /* unauthorized */];
  [r setHeader: @"text/plain; charset=utf-8" forKey: @"content-type"];
  [r appendContentString: reason];

  return r;
}

- (SOGoUser *) userInContext: (WOContext *) context
{
  SOGoUser *user;
  NSString *login;

  login = [self checkCredentialsInContext: context];
  if ([login length])
    user = [SOGoUser userWithLogin: login
                             roles: [NSArray arrayWithObject:
                                               SoRole_Authenticated]];
  else
    user = nil;

  return user;
}

- (NSArray *)getCookiesIfNeeded: (WOContext *)_ctx
{
  //Needs to be override by children if needed
  return nil;
}

#warning the DAV authenticator is pretty similar to this one. We should enable \
  the use of the former for Basic auth type through some defaults.
- (NSString *) passwordInContext: (WOContext *) context
{
  NSString *password, *authType, *authorization, *pair, *pairStart;
  WORequest *rq;

  password = @"";

  rq = [context request];
  authType = [rq headerForKey: @"x-webobjects-auth-type"];
  if ([authType isEqualToString: @"Basic"])
    {
      authorization = [rq headerForKey: @"authorization"];
      if ([authorization hasPrefix: @"Basic "])
        {
          pair = [[authorization substringFromIndex: 6]
                   stringByDecodingBase64];
          pairStart = [NSString stringWithFormat: @"%@:",
                                [self checkCredentialsInContext: context]];
          if ([pair hasPrefix: pairStart])
            password = [pair substringFromIndex: [pairStart length]];
          else
            [self errorWithFormat: @"the username in the 'authorization'"
                  @" header does not have the expected value"];
        }
      else
        [self errorWithFormat:
                @"'authorization' header does not have the expected value"];
    }
  else if (authType)
    [self errorWithFormat: @"unrecognized authentication type: '%@'",
          authType];
  else
    [self warnWithFormat: @"no authentication type found, skipped"];

  return password;
}

- (NSString *) imapPasswordInContext: (WOContext *) context
                              forURL: (NSURL *) server
                          forceRenew: (BOOL) renew
{
  return (renew ? nil : [self passwordInContext: context]);
}

- (WOResponse *) preprocessCredentialsInContext: (WOContext *) context
{
  WOResponse *r;

  if ([self userInContext: context])
    {
      [context setObject: [NSArray arrayWithObject: SoRole_Authenticated]
                  forKey: @"SoAuthenticatedRoles"];
      r = nil;
    }
  else
    r = [self unauthorized: nil inContext: context];

  return r;
}

- (BOOL) renderException: (NSException *) e
               inContext: (WOContext *) context
{
  BOOL rc;

  if ([e httpStatus] == 401)
    {
      [self unauthorized: [e reason] inContext: context];
      rc = YES;
    }
  else
    rc = NO;

  return rc;
}

@end /* SOGoProxyAuthenticator */
