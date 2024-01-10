/* SOGoCASSession.h - this file is part of SOGo
 *
 * Copyright (C) 2000-2023 Alinto.
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

#ifndef SOGOOPENIDSESSION_H
#define SOGOOPENIDSESSION_H

/* implementation of the OpenId Connect as required for a client/proxy:
   https://openid.net/developers/how-connect-works/ */

#import <Foundation/NSURLSession.h>


@class NSString;
@class NSMutableDictionary;
@class NSURL;
@class NSJSONSerialization;

size_t curl_body_function(void *ptr, size_t size, size_t nmemb, void *buffer);

@interface SOGoOpenIdSession : NSObject
{
  //From sogo.conf
  NSString *openIdUrl;
  NSString *openIdScope;
  NSString *openIdClient;
  NSString *openIdClientSecret;

  //From request to well-known/configuration
  NSString *authorizationEndpoint;
  NSString *tokenEndpoint;
  NSString *introspectionEndpoint;
  NSString *userinfoEndpoint;
  NSString *endSessionEndpoint;
  NSString *revocationEndpoint;

  //Access token
  NSString *accessToken;
  NSString *refreshToken;
  NSString *idToken;
  NSString *tokenType;
}

+ (BOOL) checkUserConfig;
+ (SOGoOpenIdSession *) OpenIdSession;
// + (SOGoOpenIdSession *) OpenIdSessionWithToken: (NSString *) token;

- (void) initialize;
- (NSString *) _performOpenIdRequest: (NSString *) endpoint
                        method: (NSString *) method
                       headers: (NSDictionary *) headers
                          body: (NSData *) body;
- (NSMutableDictionary *) fecthConfiguration;
- (NSString*) getToken; 
- (NSString *) loginUrl: (NSString *) oldLocation;
- (NSMutableDictionary *) fetchToken: (NSString *) code redirect: (NSString *) oldLocation;
// - (void) refreshToken;
// - (void) revokeToken;
- (NSMutableDictionary *) fetchUserInfo;
- (NSString *) login;
// - (void) logoutUrl;
// - (void) updateCache;

@end


#endif /* SOGOOPENIDSESSION_H */
