/* SOGoWebAuthenticator.h - this file is part of SOGo
 *
 * Copyright (C) 2007-2013 Inverse inc.
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

#ifndef _SOGOWEBAUTHENTICATOR_H_
#define _SOGOWEBAUTHENTICATOR_H_

#import <NGObjWeb/SoCookieAuthenticator.h>

#import "SOGoAuthenticator.h"
#import "SOGoConstants.h"

@class NSString;

@class WOContext;
@class WOCookie;

@class SOGoUser;

@interface SOGoWebAuthenticator : SoCookieAuthenticator <SOGoAuthenticator>

+ (id) sharedSOGoWebAuthenticator;

- (BOOL)checkLogin:(NSString *)_login
          password:(NSString *)_pwd
            domain:(NSString **)_domain
              perr:(SOGoPasswordPolicyError *)_perr
            expire:(int *)_expire
             grace:(int *)_grace
    additionalInfo:(NSMutableDictionary **)_additionalInfo;

- (BOOL)checkLogin:(NSString *)_login
          password:(NSString *)_pwd
            domain:(NSString **)_domain
              perr:(SOGoPasswordPolicyError *)_perr
            expire:(int *)_expire
             grace:(int *)_grace
    additionalInfo:(NSMutableDictionary **)_additionalInfo
          useCache:(BOOL)useCache;

- (WOCookie *) cookieWithUsername: (NSString *) username
                      andPassword: (NSString *) password
                        inContext: (WOContext *) context;

- (NSArray *)getCookiesIfNeeded: (WOContext *)_ctx;

@end

#endif /* _SOGOWEBAUTHENTICATOR_H_ */
