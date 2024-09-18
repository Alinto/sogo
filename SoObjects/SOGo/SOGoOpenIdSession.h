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

#import <NGObjWeb/WOResponse.h>


@class NSString;
@class NSMutableDictionary;
@class NSURL;
@class NSJSONSerialization;


@interface SOGoOpenIdSession : NSObject
{
  //For cache
  BOOL cacheUpdateNeeded;
  int userTokenInterval;

  //From sogo.conf
  BOOL openIdSessionIsOK;
  NSString *openIdConfigUrl;
  NSString *openIdScope;
  NSString *openIdClient;
  NSString *openIdClientSecret;
  NSString *openIdEmailParam;
  BOOL openIdEnableRefreshToken;

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
  NSNumber *expiresIn;
  NSNumber *refreshExpiresIn;
}

+ (BOOL) checkUserConfig;
+ (SOGoOpenIdSession *) OpenIdSession;
+ (void) deleteValueForSessionKey: (NSString *) theSessionKey;

- (void) initialize;
- (BOOL) sessionIsOK;
- (WOResponse *) _performOpenIdRequest: (NSString *) endpoint
                        method: (NSString *) method
                       headers: (NSDictionary *) headers
                          body: (NSData *) body;
- (NSMutableDictionary *) fecthConfiguration;
- (void) setAccessToken;
- (NSString *) getRefreshToken; 
- (NSString *) getToken;
- (NSString *) getCurrentToken; 
- (NSString *) loginUrl: (NSString *) oldLocation;
- (NSMutableDictionary *) fetchToken: (NSString *) code redirect: (NSString *) oldLocation;

- (NSString *) logoutUrl;
- (NSMutableDictionary *) fetchUserInfo;
- (NSString *) _login;
- (NSString *) login: (NSString *) identifier;


@end


#endif /* SOGOOPENIDSESSION_H */
