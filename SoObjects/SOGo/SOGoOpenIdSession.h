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
#import <SOGo/SOGoObject.h>


@class NSString;
@class NSMutableDictionary;
@class NSURL;
@class NSJSONSerialization;

size_t curl_body_function(void *ptr, size_t size, size_t nmemb, void *buffer);

@interface SimpleOpenIdResponse: NSObject
{
  unsigned int status;
  NSString    *content;
}

- (id)initWithResponse: (NSString *)_data andStatus:(unsigned int )_status;

- (void)setStatus:(unsigned int)_status;
- (unsigned int)status;
- (void)setContent:(NSString *)_data;
- (NSString *)contentString;

@end

@interface SOGoOpenIdSession : SOGoObject
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
  NSString *openIdHttpVersion;
  BOOL openIdEnableRefreshToken;
  BOOL sendDomainInfo;

  NSString *forDomain;


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
+ (SOGoOpenIdSession *) OpenIdSession: (NSString *) _domain;
+ (SOGoOpenIdSession *) OpenIdSessionWithConfig: (NSDictionary *) _config;
+ (SOGoOpenIdSession *) OpenIdSessionWithToken: (NSString *) token domain: (NSString *) _domain;
+ (SOGoOpenIdSession *) OpenIdSessionWithTokenAndConfig: (NSString *) token config: (NSDictionary *) _config;
+ (void) deleteValueForSessionKey: (NSString *) theSessionKey;

- (void) initialize;
- (void) initializeWithConfig: (NSDictionary *) _config;
- (BOOL) sessionIsOK;
- (SimpleOpenIdResponse *) _performOpenIdRequest: (NSString *) endpoint
                        method: (NSString *) method
                       headers: (NSDictionary *) headers
                          body: (NSData *) body;
- (NSMutableDictionary *) fecthConfiguration: (NSString *) _domain;
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
