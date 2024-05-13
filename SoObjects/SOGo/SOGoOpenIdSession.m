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

#import <curl/curl.h>

#import <DOM/DOMElement.h>
#import <DOM/DOMDocument.h>
#import <DOM/DOMText.h>

#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOHTTPConnection.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSObject+Logs.h>

#import <SaxObjC/SaxObjectDecoder.h>
#import <SaxObjC/SaxXMLReaderFactory.h>

#import "NSDictionary+Utilities.h"
#import "NSString+Utilities.h"
#import "SOGoCache.h"
#import "SOGoObject.h"
#import "SOGoSystemDefaults.h"

#import "SOGoOpenIdSession.h"

static BOOL SOGoOpenIDDebugEnabled = YES;

@implementation SOGoOpenIdSession

/// Check if all required parameters to set up a OpenIdSession are in sogo.conf
+ (BOOL) checkUserConfig
{
  SOGoSystemDefaults *sd;

  sd = [SOGoSystemDefaults sharedSystemDefaults];
  return ([sd openIdUrl] && [sd openIdScope]  && [sd openIdClient]  && [sd openIdClientSecret]);
}

- (void) initialize
{
  SOGoSystemDefaults *sd;

  // //From sogo.conf
  // openIdUrl = nil;
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
  if ([[self class] checkUserConfig])
  {
    openIdUrl = [sd openIdUrl];
    openIdScope = [sd openIdScope];
    openIdClient = [sd openIdClient];
    openIdClientSecret = [sd openIdClientSecret];

    [self fecthConfiguration];
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
  NSMutableDictionary* trueHeaders;
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

  location = [self->openIdUrl stringByAppendingString: @"/.well-known/openid-configuration"];
  [result setObject: location forKey: @"url"];

  url = [NSURL URLWithString: location];
  if (url)
  {
      response = [self _performOpenIdRequest: location
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

// - (NSString*) endSessionUrl
// {

// }

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

- (NSString*) getToken
{
  return self->accessToken;
}

- (void) setAccessToken: (NSString* ) token
{
  self->accessToken = token;
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
        self->accessToken = [tokenRet objectForKey: @"access_token"];
        self->refreshToken = [tokenRet objectForKey: @"refresh_token"];
        self->idToken = [tokenRet objectForKey: @"id_token"];
        self->tokenType = [tokenRet objectForKey: @"token_type"];
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
          if (email = [profile objectForKey: @"email"])
            [result setObject: email forKey: @"login"];
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

- (NSString *) login
{
  NSMutableDictionary *resultUserInfo;
  NSString *error;

  resultUserInfo = [self fetchUserInfo];
  if ([[resultUserInfo objectForKey: @"error"] isEqualToString: @"ok"])
  {
    return [resultUserInfo objectForKey: @"login"];
  }
  else
  {
    [self errorWithFormat: @"Can't get user email from profile because: %@", [resultUserInfo objectForKey: @"error"]];
  }
  return nil;
}

@end
