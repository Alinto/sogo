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

  // if (newTicket)
  //   {
  //     newSession = [self new];
  //     [newSession autorelease];
  //     [newSession setTicket: newTicket
  //                 fromProxy: fromProxy];
  //   }
  // else
  //   newSession = nil;

  return newSession;
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

- (NSString*) getToken
{
  return self->accessToken;
}

- (NSMutableDictionary *) fetchToken: (NSString * ) code redirect: (NSString *) oldLocation
{
  NSString *location, *form, *content;
  NSMutableDictionary *result;
  NSDictionary *tokenRet;
  NSURL *url;

  result = [NSMutableDictionary dictionary];

  // Prepare HTTPS post using libcurl
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
  NSString *location, *content, *auth;
  NSMutableDictionary *result;
  NSMutableData *buffer;
  NSDictionary *profile;
  NSURL *url;
  CURL *curl;

  NSUInteger status;
  char error[CURL_ERROR_SIZE];
  struct curl_slist *chunk = NULL;
  CURLcode rc;

  result = [NSMutableDictionary dictionary];

  // Prepare HTTPS post using libcurl
  location = self->userinfoEndpoint;
  [result setObject: location forKey: @"url"];

  url = [NSURL URLWithString: location];
  if (url)
  {
    curl_global_init(CURL_GLOBAL_SSL);
    curl = curl_easy_init();
    if (curl)
    {
      curl_easy_setopt(curl, CURLOPT_URL, [location UTF8String]);
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
      curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);
      curl_easy_setopt(curl, CURLOPT_TIMEOUT, 60L);
      curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);

      /* buffering ivar, no need to retain/release */
      auth = @"Authorization: Bearer ";
      auth = [auth stringByAppendingString: self->accessToken];
      chunk = curl_slist_append(chunk, [auth UTF8String]);
      curl_easy_setopt(curl, CURLOPT_HTTPHEADER, chunk);

      buffer = [NSMutableData data];

      curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_body_function);
      curl_easy_setopt(curl, CURLOPT_WRITEDATA, buffer);

      error[0] = 0;
      curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, &error);
  
      // Perform SOAP request
      rc = curl_easy_perform(curl);
      if (rc == CURLE_OK)
      {
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &status);
        [result setObject: [NSNumber numberWithUnsignedInt: status] forKey: @"status"];

        if (status == 200)
        {
          content = [[NSString alloc] initWithData: buffer
                                          encoding: NSUTF8StringEncoding];
          if (!content)
            content = [[NSString alloc] initWithData: buffer
                                            encoding: NSISOLatin1StringEncoding];
          profile = [content objectFromJSONString];

          /*profile = {"sub":"70a3e6a1-37cf-4cf6-b114-6973aabca86a",
                      "email_verified":false,"address":{},
                      "name":"Foo Bar",
                      "preferred_username":"myuser",
                      "given_name":"Foo",
                      "family_name":"Bar",
                      "email":"myuser@user.com"}*/

          //TODO
          [content autorelease];
        }
        else
          [result setObject: @"http-error" forKey: @"error"];
      }
      else
      {
        [self errorWithFormat: @"CURL error while accessing %@ (%d): %@", location, rc,
              [NSString stringWithCString: strlen(error) ? error : curl_easy_strerror(rc)]];
        [result setObject: @"bad-url" forKey: @"error"];
      }
      curl_easy_cleanup (curl);
    }
  }
  else
    [result setObject: @"invalid-url" forKey: @"error"];
  
  return result;
}

- (NSString *) login
{
  NSMutableDictionary *resultUserInfo;
  resultUserInfo = [self fetchUserInfo];
  if ([resultUserInfo objectForKey: @"status"] == 200)
  {
    return [resultUserInfo objectForKey: @"login"];
  }
  return nil;
}

@end
