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


size_t curl_body_function(void *ptr, size_t size, size_t nmemb, void *buffer)
{
  size_t total;
  
  total = size * nmemb;
  [(NSMutableData *)buffer appendBytes: ptr length: total];
  
  return total;
}

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

- (NSString *) _performOpenIdRequest: (NSString *) endpoint
                        method: (NSString *) method
                       headers: (NSDictionary *) headers
                          body: (NSData *) body
{
  NSURL *url;
  NSMutableDictionary* trueHeaders;
  NSUInteger* status;
  WORequest *request;
  WOResponse *response;
  WOHTTPConnection *httpConnection;
  

  url = [NSURL URLWithString: endpoint];
  if (url)
  {
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
    if(status >= 200 && status <400)
      return [response contentString];
    else
    {
      [self errorWithFormat: @"OpenID failed request to %@: %@", endpoint, response];
      return nil;
    }
  }
  else
  {
    [self errorWithFormat: @"OpenID can't handle endpoint: '%@'", endpoint];
    return nil;
  }
}

- (NSMutableDictionary *) fecthConfiguration
{
  NSString *location, *content;
  NSMutableDictionary *result;
  NSDictionary *config;
  NSURL *url;

  result = [NSMutableDictionary dictionary];

  location = [self->openIdUrl stringByAppendingString: @"/.well-known/openid-configuration"];
  [result setObject: location forKey: @"url"];

  url = [NSURL URLWithString: location];
  if (url)
  {
      content = [self _performOpenIdRequest: location
                        method: @"GET"
                       headers: nil
                          body: nil];
      if (content)
      {
          config = [content objectFromJSONString];
          self->authorizationEndpoint = [config objectForKey: @"authorization_endpoint"];
          self->tokenEndpoint         = [config objectForKey: @"token_endpoint"];
          self->introspectionEndpoint = [config objectForKey: @"introspection_endpoint"];
          self->userinfoEndpoint      = [config objectForKey: @"userinfo_endpoint"];
          self->endSessionEndpoint    = [config objectForKey: @"end_session_endpoint"];
          self->revocationEndpoint    = [config objectForKey: @"revocation_endpoint"];
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
      
      [self setAccessToken: token];
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
  NSMutableDictionary *result;
  NSDictionary *tokenRet;
  NSURL *url;

  result = [NSMutableDictionary dictionary];
  
  location = self->tokenEndpoint;
  url = [NSURL URLWithString: location];
  if (url)
  {
    form = @"grant_type=authorization_code";
    form = [form stringByAppendingFormat: @"&code=%@", code];
    form = [form stringByAppendingFormat: @"&redirect_uri=%@", oldLocation];
    form = [form stringByAppendingFormat: @"&client_id=%@", self->openIdClient];
    form = [form stringByAppendingFormat: @"&client_secret=%@", self->openIdClientSecret];

    content = [self _performOpenIdRequest: location
                      method: @"GET"
                      headers: nil
                        body: [form dataUsingEncoding:NSUTF8StringEncoding]];
    if (content)
    {
        tokenRet = [content objectFromJSONString];
        self->accessToken = [tokenRet objectForKey: @"access_token"];
        self->refreshToken = [tokenRet objectForKey: @"refresh_token"];
        self->idToken = [tokenRet objectForKey: @"id_token"];
        self->tokenType = [tokenRet objectForKey: @"token_type"];
        [content autorelease];
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
    auth = [NSString initWithString: @"Bearer "];
    auth = [auth stringByAppendingString: self->accessToken];
    headers = [NSDictionary dictionaryWithObject: auth forKey: @"Authorization"];

    content = [self _performOpenIdRequest: location
                       method: @"GET"
                      headers: headers
                         body: nil];
    if (content)
    {
        profile = [content objectFromJSONString];
        [self errorWithFormat: @"Profile is %@", profile];

          /*profile = {"sub":"70a3e6a1-37cf-4cf6-b114-6973aabca86a",
                      "email_verified":false,"address":{},
                      "name":"Foo Bar",
                      "preferred_username":"myuser",
                      "given_name":"Foo",
                      "family_name":"Bar",
                      "email":"myuser@user.com"}*/
        if (email = [profile objectForKey: @"email"])
          [result setObject: email forKey: @"login"];
        else
          [result setObject: @"no mail found"  forKey: @"error"];
        [content autorelease];
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
