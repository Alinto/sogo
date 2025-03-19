/* SOGoStaticAuthenticator.m - this file is part of SOGo
 *
 * Copyright (C) 2013 Inverse inc.
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

#import <Foundation/NSString.h>

#import "SOGoStaticAuthenticator.h"

@implementation SOGoStaticAuthenticator

+ (id) authenticatorWithUser: (NSString *) user
                 andPassword: (NSString *) password
{
  SOGoStaticAuthenticator *newAuthenticator;
  newAuthenticator = [[self alloc] initWithUser: user
                                    andPassword: password];
  [newAuthenticator autorelease];
  return newAuthenticator;
}

- (id) init
{
  if ((self = [super init]))
    {
      _username = nil;
      _password = nil;
    }
  return self;
}

- (void) dealloc
{
  [_username release];
  [_password release];
  [super dealloc];
}

- (id) initWithUser: (NSString *) user
        andPassword: (NSString *) password;
{
  if ((self = [self init]))
    {
      _username = [user retain];
      _password = [password retain];
    }
  return self;
}

- (NSString *) passwordInContext: (WOContext *) context
{
  return _password;
}

- (SOGoUser *) userInContext: (WOContext *) context
{
  return nil;
}

- (NSArray *)getCookiesIfNeeded: (WOContext *)_ctx
{
  //Needs to be override by children if needed
  return nil;
}

- (NSString *) username
{
  return _username;
}

- (NSString *) imapPasswordInContext: (WOContext *) context
                              forURL: (NSURL *) server
                          forceRenew: (BOOL) renew
{
  return _password;
}

@end
