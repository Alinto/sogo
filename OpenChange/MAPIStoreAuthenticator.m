/* MAPIStoreAuthenticator.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2012 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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
#import <Foundation/NSURL.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoPermissions.h>

#import "MAPIStoreAuthenticator.h"

@implementation MAPIStoreAuthenticator

- (void) dealloc
{
        [username release];
        [password release];
        [super dealloc];
}

- (void) setUsername: (NSString *) newUsername
{
        ASSIGN (username, newUsername);
}

- (NSString *) username
{
  return username;
}

- (void) setPassword: (NSString *) newPassword
{
        ASSIGN (password, newPassword);
}

- (SOGoUser *) userInContext: (WOContext *)_ctx
{
        return [SOGoUser userWithLogin: username
                                 roles: [NSArray arrayWithObject: SoRole_Authenticated]];
}

- (NSString *) imapPasswordInContext: (WOContext *) context
                              forURL: (NSURL *) server
                          forceRenew: (BOOL) renew
{
        NSString *imapPassword;

        if (renew)
                imapPassword = nil;
        else
                imapPassword = password;

        return imapPassword;
}

@end
