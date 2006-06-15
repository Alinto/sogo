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

#include "SOGoAuthenticator.h"
#include "SOGoUser.h"
#include "common.h"

@implementation SOGoAuthenticator

static SOGoAuthenticator *auth = nil; // THREAD

+ (id)sharedSOGoAuthenticator {
  if (auth == nil)
    auth = [[self alloc] init];
  return auth;
}

/* check credentials */

- (BOOL)checkLogin:(NSString *)_login password:(NSString *)_pwd {
  if ([_login length] == 0)
    return NO;
  
  /* we accept any password since it is checked by Apache in front */
  return YES;
}

/* create SOGoUser */

- (SoUser *)userInContext:(WOContext *)_ctx {
  static SoUser *anonymous = nil;
  NSString  *login;
  NSArray   *uroles;
  
  if (anonymous == nil) {
    NSArray *ar = [NSArray arrayWithObject:SoRole_Anonymous];
    anonymous = [[SOGoUser alloc] initWithLogin:@"anonymous" roles:ar];
  }
  
  if ((login = [self checkCredentialsInContext:_ctx]) == nil)
    /* some error (otherwise result would have been anonymous */
    return nil;
  
  if ([login isEqualToString:@"anonymous"])
    return anonymous;
  
  uroles = [self rolesForLogin:login];
  return [[[SOGoUser alloc] initWithLogin:login roles:uroles] autorelease];
}

@end /* SOGoAuthenticator */
