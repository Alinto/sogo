/*
  Copyright (C) 2007-2011 Inverse inc.
  Copyright (C) 2004 SKYRIX Software AG

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSArray.h>
#import <Foundation/NSURL.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>
#import <NGExtensions/NSObject+Logs.h>

#import "SOGoCASSession.h"
#import "SOGoPermissions.h"
#import "SOGoSystemDefaults.h"
#import "SOGoUser.h"
#import "SOGoUserManager.h"

#import "SOGoDAVAuthenticator.h"

@implementation SOGoDAVAuthenticator

+ (id) sharedSOGoDAVAuthenticator
{
  static SOGoDAVAuthenticator *auth = nil;
 
  auth = [self new];

  return auth;
}

- (BOOL) checkLogin: (NSString *) _login
           password: (NSString *) _pwd
{
  NSString *domain;
  SOGoSystemDefaults *sd;
  SOGoCASSession *session;
  SOGoPasswordPolicyError perr;
  int expire, grace;
  BOOL rc;

  domain = nil;
  perr = PolicyNoError;
  rc = ([[SOGoUserManager sharedUserManager]
          checkLogin: [_login stringByReplacingString: @"%40"
                                           withString: @"@"]
            password: _pwd
              domain: &domain
                perr: &perr
              expire: &expire
               grace: &grace
      additionalInfo: nil]
        && perr == PolicyNoError);
        
  if (!rc)
    {
      sd = [SOGoSystemDefaults sharedSystemDefaults];
      if ([[sd davAuthenticationType] isEqualToString: @"cas"])
        {
          /* CAS authentication for DAV requires using a proxy */
          session = [SOGoCASSession CASSessionWithTicket: _pwd
                                               fromProxy: YES];
          rc = [[session login] isEqualToString: _login];
          if (rc)
            [session updateCache];
        }
    }

  return rc;
}

- (NSString *) passwordInContext: (WOContext *) context
{
  NSString *auth, *password;
  NSArray *creds;

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
      if ([[sd davAuthenticationType] isEqualToString: @"cas"])
        {
          session = [SOGoCASSession CASSessionWithTicket: password
                                               fromProxy: YES];

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

- (SOGoUser *) userInContext: (WOContext *)_ctx
{
  static SOGoUser *anonymous = nil;
  SOGoUser *user;
  NSString *login;

  login = [self checkCredentialsInContext:_ctx];
  if ([login isEqualToString: @"anonymous"])
    {
      if (!anonymous)
        anonymous
          = [[SOGoUser alloc]
                  initWithLogin: @"anonymous"
                          roles: [NSArray arrayWithObject: SoRole_Anonymous]];
      user = anonymous;
    }
  else if ([login length])
    {
      user = [SOGoUser userWithLogin: login
                               roles: [self rolesForLogin: login]];
      [user setCurrentPassword: [self passwordInContext: _ctx]];
    }
  else
    user = nil;

  return user;
}

@end /* SOGoDAVAuthenticator */
