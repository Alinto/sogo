/* SOGoCASSession.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2014 Inverse inc.
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

#import <NGObjWeb/WOHTTPConnection.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSObject+Logs.h>

#import <GDLContentStore/GCSOpenIdFolder.h>
#import <GDLContentStore/GCSFolderManager.h>

#import "NSDictionary+Utilities.h"
#import "NSString+Utilities.h"
#import "SOGoCache.h"
#import "SOGoSystemDefaults.h"

#import "SOGoOpenIdSession.h"

static BOOL SOGoOpenIDDebugEnabled = YES;

@implementation SOGoOpenIdSession

/// Check if all required parameters to set up a OpenIdSession are in sogo.conf

+ (BOOL) checkUserConfig
{
  SOGoSystemDefaults *sd;

  if(nil == [[GCSFolderManager defaultFolderManager] openIdFolder])
  {
    [self errorWithFormat: @"Something wrong with the table defined by OCSOpenIdURL"];
    return NO;
  }
  sd = [SOGoSystemDefaults sharedSystemDefaults];
  return ([sd openIdConfigUrl] && [sd openIdScope]  && [sd openIdClient]  && [sd openIdClientSecret]);
}

- (void) initialize
{
  SOGoSystemDefaults *sd;

  // //From sogo.conf
  // openIdConfigUrl = nil;
  // openIdScope = nil;
  // openIdClient = nil;
  // openIdClientSecret = nil;

  // //From request to well-known/configuration
  // //SHoud be ste in sogo.cong in case of oauth
  // authorizationEndpoint = nil;
  // tokenEndpoint = nil;
  // introspectionEndpoint = nil;
  // userinfoEndpoint = nil;
  // endSessionEndpoint = nil;
  // revocationEndpoint = nil;

  // //Access token
  // accessToken = nil;

  sd = [SOGoSystemDefaults sharedSystemDefaults];
  SOGoOpenIDDebugEnabled = [sd openIdDebugEnabled];
  openIdSessionIsOK = NO;
  if ([[self class] checkUserConfig])
  {
    openIdConfigUrl          = [sd openIdConfigUrl];
    openIdScope              = [sd openIdScope];
    openIdClient             = [sd openIdClient];
    openIdClientSecret       = [sd openIdClientSecret];
    openIdEmailParam         = [sd openIdEmailParam];
    openIdEnableRefreshToken = [sd openIdEnableRefreshToken];
    userTokenInterval        = [sd openIdTokenCheckInterval];

    [self _loadSessionFromCache];

    if(cacheUpdateNeeded)
    {
      [self fecthConfiguration];
    }
      
  }
  else
  {
    [self errorWithFormat: @"Missing parameters from sogo.conf"];
  }
}

- (WOResponse *) _performOpenIdRequest: (NSString *) endpoint
                        method: (NSString *) method
                       headers: (NSDictionary *) headers
                          body: (NSData *) body
{
  NSURL *url;
  NSUInteger status;
  WORequest *request;
  WOResponse *response;
  WOHTTPConnection *httpConnection;
  

  url = [NSURL URLWithString: endpoint];
  if (url)
  {
    if(SOGoOpenIDDebugEnabled)
    {
      NSLog(@"OpenId perform request: %@ %@", method, [endpoint hostlessURL]);
      NSLog(@"OpenId perform request, headers %@", headers);
      if(body)
        NSLog(@"OpenId perform request: content %@", [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding]);
    }
      
    httpConnection = [[WOHTTPConnection alloc] initWithURL: url];
    [httpConnection autorelease];

    request = [[WORequest alloc] initWithMethod: method
                                            uri: [endpoint hostlessURL]
                                    httpVersion: @"HTTP/1.1"
                                        headers: headers content: body
                                        userInfo: nil];
    [request autorelease];
    [httpConnection sendRequest: request];
    response = [httpConnection readResponse];
    status = [response status];
    if(status >= 200 && status <500 && status != 404)
      return response;
    else if (status == 404)
    {
      [self errorWithFormat: @"OpenID endpoint not found (404): %@", endpoint];
      return nil; 
    }
    else
    {
      [self errorWithFormat: @"OpenID server internal error during %@: %@", endpoint, response];
      return nil;
    }
  }
  else
  {
    [self errorWithFormat: @"OpenID can't handle endpoint (not a url): '%@'", endpoint];
    return nil;
  }
}

- (NSMutableDictionary *) fecthConfiguration
{
  NSString *location, *content;
  WOResponse * response;
  NSUInteger status;
  NSMutableDictionary *result;
  NSDictionary *config;
  NSURL *url;

  result = [NSMutableDictionary dictionary];
  [result setObject: self->openIdConfigUrl  forKey: @"url"];

  url = [NSURL URLWithString: self->openIdConfigUrl ];
  if (url)
  {
    response = [self _performOpenIdRequest: self->openIdConfigUrl 
                      method: @"GET"
                      headers: nil
                        body: nil];

    if (response)
    {
      status = [response status];
      if(status >= 200 && status <300)
      {
        content = [response contentString];
        config = [content objectFromJSONString];
        self->authorizationEndpoint = [config objectForKey: @"authorization_endpoint"];
        self->tokenEndpoint         = [config objectForKey: @"token_endpoint"];
        self->introspectionEndpoint = [config objectForKey: @"introspection_endpoint"];
        self->userinfoEndpoint      = [config objectForKey: @"userinfo_endpoint"];
        self->endSessionEndpoint    = [config objectForKey: @"end_session_endpoint"];
        self->revocationEndpoint    = [config objectForKey: @"revocation_endpoint"];
        openIdSessionIsOK = YES;
        [self _saveSessionToCache];
      }
      else
      {
        [self logWithFormat: @"Error during fetching the configuration (status %d), response: %@", status, response];
      }
    }
    else
      [result setObject: @"http-error" forKey: @"error"];
  }
  else
    [result setObject: @"invalid-url" forKey: @"error"];
  
  return result;
}

+ (SOGoOpenIdSession *) OpenIdSession
{
  SOGoOpenIdSession *newSession;

  newSession = [self new];
  [newSession autorelease];
  [newSession initialize];

  return newSession;
}

+ (SOGoOpenIdSession *) OpenIdSessionWithToken: (NSString *) token
{
  SOGoOpenIdSession *newSession;

  if (token)
    {
      newSession = [self new];
      [newSession autorelease];
      [newSession initialize];
      
      [newSession setAccessToken: token];
    }
  else
    newSession = nil;

  return newSession;
}

- (BOOL) sessionIsOk
{
  return self->openIdSessionIsOK;
}

- (void) _loadSessionFromCache
{
  SOGoCache *cache;
  NSString *jsonSession;
  NSDictionary *sessionDict;

  cache = [SOGoCache sharedCache];
  jsonSession = [cache openIdSessionFromServer: self->openIdConfigUrl];
  if ([jsonSession length])
  {
    sessionDict = [jsonSession objectFromJSONString];
    ASSIGN (authorizationEndpoint, [sessionDict objectForKey: @"authorization_endpoint"]);
    ASSIGN (tokenEndpoint, [sessionDict objectForKey: @"token_endpoint"]);
    ASSIGN (introspectionEndpoint, [sessionDict objectForKey: @"introspection_endpoint"]);
    ASSIGN (userinfoEndpoint, [sessionDict objectForKey: @"userinfo_endpoint"]);
    ASSIGN (endSessionEndpoint, [sessionDict objectForKey: @"end_session_endpoint"]);
    ASSIGN (revocationEndpoint, [sessionDict objectForKey: @"revocation_endpoint"]);
    openIdSessionIsOK = YES;
  }
  else
    cacheUpdateNeeded = YES;
}

- (void) _saveSessionToCache
{
  SOGoCache *cache;
  NSString *jsonSession;
  NSMutableDictionary *sessionDict;

  cache = [SOGoCache sharedCache];
  sessionDict = [NSMutableDictionary dictionary];
  [sessionDict setObject: authorizationEndpoint forKey: @"authorization_endpoint"];
  [sessionDict setObject: tokenEndpoint forKey: @"token_endpoint"];
  [sessionDict setObject: introspectionEndpoint forKey: @"introspection_endpoint"];
  [sessionDict setObject: userinfoEndpoint forKey: @"userinfo_endpoint"];
  [sessionDict setObject: endSessionEndpoint forKey: @"end_session_endpoint"];
  [sessionDict setObject: revocationEndpoint forKey: @"revocation_endpoint"];

  jsonSession = [sessionDict jsonRepresentation];
  [cache setOpenIdSession: jsonSession
         forServer: self->openIdConfigUrl];
}


- (BOOL) _loadUserFromCache: (NSString *) email
{
  /*
  Return NO if the user token must be check again, YES the user is valid for now
  */
  SOGoCache *cache;
  NSString *identifier, *nextCheck;
  NSTimeInterval nextCheckTime, timeNow;

  identifier = [self->openIdClient stringByAppendingString: email];

  cache = [SOGoCache sharedCache];
  nextCheck = [cache userOpendIdSessionFromServer: identifier];
  if ([nextCheck length])
  {
    timeNow = [[NSDate date] timeIntervalSince1970];
    nextCheckTime = [nextCheck doubleValue];
    if(timeNow > nextCheckTime)
      return NO;
    else
      return YES;
  }
  else
    return NO;
}

- (void) _saveUserToCache: (NSString *) email
{
  SOGoCache *cache;
  NSString *identifier, *nextCheck;
  NSTimeInterval nextCheckTime;

  identifier    = [self->openIdClient stringByAppendingString: email];
  nextCheckTime = [[NSDate date] timeIntervalSince1970] + self->userTokenInterval;
  nextCheck     = [NSString stringWithFormat:@"%f", nextCheckTime];

  cache = [SOGoCache sharedCache];
  [cache setUserOpendIdSessionFromServer: identifier
         nextCheckAfter: nextCheck];
}

- (NSString*) loginUrl: (NSString *) oldLocation
{
  NSString* logUrl;
  logUrl = [self->authorizationEndpoint stringByAppendingFormat: @"?scope=%@", self->openIdScope];
  logUrl = [logUrl stringByAppendingString: @"&response_type=code"];
  logUrl = [logUrl stringByAppendingFormat: @"&client_id=%@", self->openIdClient];
  logUrl = [logUrl stringByAppendingFormat: @"&redirect_uri=%@", oldLocation];
  // logurl = [self->logurl stringByAppendingFormat: @"&state=%@", state];

  return logUrl;
}

- (NSString *) logoutUrl
{
  return self->endSessionEndpoint;
}

- (NSString*) getRefreshToken
{
  return self->refreshToken;
}

- (NSString*) getToken
{
  return self->accessToken;
}

- (void) setAccessToken: (NSString* ) token
{
  self->accessToken = token;
}


- (NSString *) getCurrentToken
{
  NSString *currentToken;

  //See if the current token has been refreshed
  currentToken = [[[GCSFolderManager defaultFolderManager] openIdFolder] getNewToken: self->accessToken];

  if(currentToken)
  {
    //be sure the old token has been cleaned
    [[[GCSFolderManager defaultFolderManager] openIdFolder] deleteOpenIdSessionFor: self->accessToken];
    return currentToken;
  }
  return self->accessToken;
}

- (NSMutableDictionary *) fetchToken: (NSString * ) code redirect: (NSString *) oldLocation
{
  NSString *location, *form, *content;
  WOResponse *response;
  NSUInteger status;
  NSMutableDictionary *result;
  NSDictionary *headers;
  NSDictionary *tokenRet;
  NSURL *url;

  result = [NSMutableDictionary dictionary];
  [result setObject: @"ok" forKey: @"error"];
  
  location = self->tokenEndpoint;
  url = [NSURL URLWithString: location];
  if (url)
  {
    form = @"grant_type=authorization_code";
    form = [form stringByAppendingFormat: @"&code=%@", code];
    form = [form stringByAppendingFormat: @"&redirect_uri=%@", [oldLocation stringByEscapingURL]];
    form = [form stringByAppendingFormat: @"&client_secret=%@", self->openIdClientSecret];
    form = [form stringByAppendingFormat: @"&client_id=%@", self->openIdClient];

    headers = [NSDictionary dictionaryWithObject: @"application/x-www-form-urlencoded"  forKey: @"content-type"];
    
    response = [self _performOpenIdRequest: location
                      method: @"POST"
                      headers: headers
                        body: [form dataUsingEncoding:NSUTF8StringEncoding]];

    if (response)
    {
      status = [response status];
      if(status >= 200 && status <300)
      {
        content = [response contentString];
        tokenRet = [content objectFromJSONString];
        if (SOGoOpenIDDebugEnabled)
        {
          NSLog(@"fetch token response: %@", tokenRet);
        }
        self->accessToken = [tokenRet objectForKey: @"access_token"];
        self->refreshToken = [tokenRet objectForKey: @"refresh_token"];
        self->refreshExpiresIn = [tokenRet objectForKey: @"refresh_expires_in"];
        self->idToken = [tokenRet objectForKey: @"id_token"];
        self->tokenType = [tokenRet objectForKey: @"token_type"];
        self->expiresIn = [tokenRet objectForKey: @"expires_in"];
      }
      else
      {
        [self logWithFormat: @"Error during fetching the token (status %d), response: %@", status, response];
      }
    }
    else
    {
        [result setObject: @"http-error" forKey: @"error"];
    }
  }
  else
    [result setObject: @"invalid-url" forKey: @"error"];
  
  return result;
}

- (NSMutableDictionary *) refreshToken: (NSString * ) userRefreshToken
{
  NSString *location, *form, *content;
  WOResponse *response;
  NSUInteger status;
  NSMutableDictionary *result;
  NSDictionary *headers;
  NSDictionary *refreshTokenRet;
  NSURL *url;

  result = [NSMutableDictionary dictionary];
  [result setObject: @"ok" forKey: @"error"];
  
  if(!userRefreshToken || [userRefreshToken length] == 0)
  {
    [result setObject: @"invalid-token" forKey: @"error"];
    return result;
  }

  location = self->tokenEndpoint;
  url = [NSURL URLWithString: location];
  if (url)
  {
    form = @"grant_type=refresh_token";
    form = [form stringByAppendingFormat: @"&scope=%@", self->openIdScope];
    form = [form stringByAppendingFormat: @"&refresh_token=%@", userRefreshToken];
    form = [form stringByAppendingFormat: @"&client_secret=%@", self->openIdClientSecret];
    form = [form stringByAppendingFormat: @"&client_id=%@", self->openIdClient];

    headers = [NSDictionary dictionaryWithObject: @"application/x-www-form-urlencoded"  forKey: @"content-type"];
    
    response = [self _performOpenIdRequest: location
                      method: @"POST"
                      headers: headers
                        body: [form dataUsingEncoding:NSUTF8StringEncoding]];

    if (response)
    {
      status = [response status];
      if(status >= 200 && status <300)
      {
        content = [response contentString];
        refreshTokenRet = [content objectFromJSONString];
        if (SOGoOpenIDDebugEnabled)
        {
          NSLog(@"refresh token response: %@", refreshTokenRet);
        }
        self->accessToken = [refreshTokenRet objectForKey: @"access_token"];
        self->refreshToken = [refreshTokenRet objectForKey: @"refresh_token"];
        self->refreshExpiresIn = [refreshTokenRet objectForKey: @"refresh_expires_in"];
        self->tokenType = [refreshTokenRet objectForKey: @"token_type"];
        self->expiresIn = [refreshTokenRet objectForKey: @"expires_in"];
      }
      else
      {
        [self logWithFormat: @"Error during refreshing the token (status %d), response: %@", status, response];
      }
    }
    else
    {
        [result setObject: @"http-error" forKey: @"error"];
    }
  }
  else
    [result setObject: @"invalid-url" forKey: @"error"];
  
  return result;
}

- (NSMutableDictionary *) fetchUserInfo
{
  NSString *location, *auth, *content;
  WOResponse *response;
  NSUInteger status;
  NSMutableDictionary *result;
  NSDictionary *profile, *headers;
  NSURL *url;
  NSString *email;

  result = [NSMutableDictionary dictionary];
  [result setObject: @"ok" forKey: @"error"];

  location = self->userinfoEndpoint;
  url = [NSURL URLWithString: location];
  if (url)
  {
    auth = [NSString stringWithFormat: @"Bearer %@", self->accessToken];
    headers = [NSDictionary dictionaryWithObject: auth forKey: @"authorization"];

    response = [self _performOpenIdRequest: location
                       method: @"GET"
                      headers: headers
                         body: nil];
    if (response)
    {
        status = [response status];
        if(status >= 200 && status <300)
        {
          content = [response contentString];
          profile = [content objectFromJSONString];
          if(SOGoOpenIDDebugEnabled && profile)
            NSLog(@"OpenId fetch user info, profile is %@", profile);

            /*profile = {"sub":"70a3e6a1-37cf-4cf6-b114-6973aabca86a",
                        "email_verified":false,
                        "address":{},
                        "name":"Foo Bar",
                        "preferred_username":"myuser",
                        "given_name":"Foo",
                        "family_name":"Bar",
                        "email":"myuser@user.com"}*/
          if (email = [profile objectForKey: self->openIdEmailParam])
          {
            if(self->userTokenInterval > 0)
              [self _saveUserToCache: email];
            [result setObject: email forKey: @"login"];
          }
          else
            [result setObject: @"no mail found"  forKey: @"error"];
        }
        else
        {
          [self logWithFormat: @"Error during fetching the token (status %d), response: %@", status, response];
          [result setObject: @"http-error" forKey: @"error"];
        }
    }
    else
    {
      [result setObject: @"http-error" forKey: @"error"];
    }
  }
  else
    [result setObject: @"invalid-url" forKey: @"error"];
  
  return result;
}



+ (void) deleteValueForSessionKey: (NSString *) theSessionKey
{
  GCSOpenIdFolder *folder;
  
  folder = [[GCSFolderManager defaultFolderManager] openIdFolder];
  [folder deleteOpenIdSessionFor: theSessionKey];
}

- (NSString *) _login
{
  NSMutableDictionary *resultUserInfo, *resultResfreh;
  NSString* _oldAccessToken;

  resultUserInfo = [self fetchUserInfo];
  if ([[resultUserInfo objectForKey: @"error"] isEqualToString: @"ok"])
  { 
    //Save some infos as the refresh token to the database
    [[[GCSFolderManager defaultFolderManager] openIdFolder] writeOpenIdSession: self->accessToken
                                                                withOldSession: nil
                                                              withRefreshToken: self->refreshToken
                                                                    withExpire: self->expiresIn
                                                             withRefreshExpire: self->refreshExpiresIn];
    return [resultUserInfo objectForKey: @"login"];
  }
  else if(openIdEnableRefreshToken)
  {
    //try to refresh
    if(self->accessToken)
    {
      self->refreshToken = [[[GCSFolderManager defaultFolderManager] openIdFolder] getRefreshToken: self->accessToken];
      //remove old session
      [[[GCSFolderManager defaultFolderManager] openIdFolder] deleteOpenIdSessionFor: self->accessToken];
    }
    if(self->refreshToken)
    {
      _oldAccessToken = self->accessToken;
      resultResfreh = [self refreshToken: self->refreshToken];
      if ([[resultResfreh objectForKey: @"error"] isEqualToString: @"ok"])
      {
        resultUserInfo = [self fetchUserInfo];
        if ([[resultUserInfo objectForKey: @"error"] isEqualToString: @"ok"])
        {
          [[[GCSFolderManager defaultFolderManager] openIdFolder] writeOpenIdSession: self->accessToken
                                                                      withOldSession: _oldAccessToken
                                                                    withRefreshToken: self->refreshToken
                                                                          withExpire: self->expiresIn
                                                                   withRefreshExpire: self->refreshExpiresIn];
          return [resultUserInfo objectForKey: @"login"];
        }
      }
    }

    //The acces token hasn't work, delete the session in database if needed
    if(self->accessToken)
    {
      [[[GCSFolderManager defaultFolderManager] openIdFolder] deleteOpenIdSessionFor: self->accessToken];
    }

    [self errorWithFormat: @"Can't get user email from profile because: %@", [resultUserInfo objectForKey: @"error"]];
  }
  else
  {
    //remove old session
    [[[GCSFolderManager defaultFolderManager] openIdFolder] deleteOpenIdSessionFor: self->accessToken];
  }

  return @"anonymous";
}

- (BOOL) login: (NSString *) email
{
  //Check if we need to fetch userinfo
  if(self->userTokenInterval > 0 && [self _loadUserFromCache: email])
  {
    return email;
  }
  else
  {
    return [self _login];
  }

}

@end
