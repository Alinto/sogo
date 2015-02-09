/* SOGoSAML2Session.h - this file is part of SOGo
 *
 * Copyright (C) 2012-2014 Inverse inc.
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

#ifndef SOGOSAML2SESSION_H
#define SOGOSAML2SESSION_H

/* implementation of the SAML2 protocol as required for a client:
   https://www.oasis-open.org/standards#samlv2.0 */

#import <Foundation/NSObject.h>

#include <lasso/lasso.h>

@class NSString;

@interface SOGoSAML2Session : NSObject
{
  LassoLogin *lassoLogin;

  NSString *login;
  NSString *identifier;
  NSString *assertion;
  NSString *identity;
  NSString *session;
}

+ (LassoServer *) lassoServerInContext: (WOContext *) context;

+ (NSString *) metadataInContext: (WOContext *) context
                     certificate: (NSString *) certificate;

+ (NSString *) authenticationURLInContext: (WOContext *) context;

+ (SOGoSAML2Session *) SAML2SessionInContext: (WOContext *) context;

+ (SOGoSAML2Session *) SAML2SessionWithIdentifier: (NSString *) newIdentifier
                                        inContext: (WOContext *) context;

- (void) processAuthnResponse: (NSString *) authnResponse;

- (NSString *) login;
- (NSString *) identifier;
- (NSString *) assertion;
- (NSString *) identity;
- (NSString *) session;

@end

#endif /* SOGOSAML2SESSION_H */
