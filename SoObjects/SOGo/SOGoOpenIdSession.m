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


#import <Foundation/NSProcessInfo.h>

#import <curl/curl.h>

#import <NGObjWeb/WOHTTPConnection.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSObject+Logs.h>

#import <SOGo/SOGoUser.h>

#import <GDLContentStore/GCSOpenIdFolder.h>
#import <GDLContentStore/GCSFolderManager.h>

#import "NSDictionary+Utilities.h"
#import <SOGo/NSString+Utilities.h>
#import <SOGo/NSString+Crypto.h>
#import "SOGoCache.h"
#import "SOGoSystemDefaults.h"

#import "SOGoOpenIdSession.h"

static BOOL SOGoOpenIDDebugEnabled = YES;


size_t curl_body_function(void *ptr, size_t size, size_t nmemb, void *buffer)
{
  size_t total;
  
  total = size * nmemb;
  [(NSMutableData *)buffer appendBytes: ptr length: total];
  
  return total;
}


@implementation SimpleOpenIdResponse

- (id)init {
  if ((self = [super init])) {
  }
  return self;
}

- (id)initWithResponse: (NSString *)_data andHeaders: (NSString *)_headers andStatus:(unsigned int )_status{
  if ((self = [self init])) {
    [self setStatus: _status];
    [self setContent: _data];
    [self setHeaders: _headers];
  }
  return self;
}

- (void)setStatus:(unsigned int)_status
{
  self->status = _status;
}

- (unsigned int)status
{
  if(self->status)
    return self->status;
  return 0;
}

- (void)setContent:(NSString *)_data
{
  self->content = _data;
}

- (NSString *)contentString
{
  if(self->content)
    return self->content;
  return nil;
}

- (void)setHeaders:(NSString *)_data
{
  self->headers = _data;
}

- (NSString *)headers
{
  if(self->headers)
    return self->headers;
  return nil;
}

- (NSString*)description {
    NSString *co, *hd;
    unsigned int st;
    st = 0;
    co = @"nil";
    hd = @"nil";
    if(self->status)
      st = self->status;
    if(self->headers)
      hd = self->headers;
    if(self->content)
      co = self->content;
    return [NSString stringWithFormat: @"<SimpleOpenIdResponse> <status: %d>, <headers: %@>, <content: %@>", st, hd, co];
}

@end

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

- (void) initializeWithConfig: (NSDictionary *) _config
{
  SOGoSystemDefaults *sd;
  id refreshTokenBool, domainInfo;

  if([_config objectForKey: @"SOGoOpenIdConfigUrl"] &&
      [_config objectForKey: @"SOGoOpenIdScope"] &&
      [_config objectForKey: @"SOGoOpenIdClient"] &&
      [_config objectForKey: @"SOGoOpenIdClientSecret"])
  {
    openIdConfigUrl          = [_config objectForKey: @"SOGoOpenIdConfigUrl"];
    openIdScope              = [_config objectForKey: @"SOGoOpenIdScope"];
    openIdClient             = [_config objectForKey: @"SOGoOpenIdClient"];
    openIdClientSecret       = [_config objectForKey: @"SOGoOpenIdClientSecret"];
    openIdEmailParam         = [_config objectForKey: @"SOGoOpenIdEmailParam"];
    openIdHttpVersion        = [_config objectForKey: @"SOGoOpenIdHttpVersion"];

    openIdEnableRefreshToken = NO;
    refreshTokenBool = [_config objectForKey: @"SOGoOpenIdEnableRefreshToken"];
    if (refreshTokenBool && [refreshTokenBool respondsToSelector: @selector (boolValue)])
        openIdEnableRefreshToken = [refreshTokenBool boolValue];

    sendDomainInfo = NO;
    domainInfo = [_config objectForKey: @"SOGoOpenIdSendDomainInfo"];
    if (domainInfo && [domainInfo respondsToSelector: @selector (boolValue)])
        sendDomainInfo = [domainInfo boolValue];

      
    userTokenInterval        = [_config objectForKey: @"SOGoOpenIdTokenCheckInterval"];
    [self _loadSessionFromCache: forDomain];

    if(cacheUpdateNeeded)
    {
      [self fecthConfiguration: forDomain];
    }
  }
  else
  {
    [self errorWithFormat: @"Missing parameters from sogo.conf"];
  }
}

- (void) initialize: (NSString*) _domain
{
  SOGoSystemDefaults *sd;
  NSDictionary *config;
  NSString *type;

  sd = [SOGoSystemDefaults sharedSystemDefaults];
  SOGoOpenIDDebugEnabled = [sd openIdDebugEnabled];
  openIdSessionIsOK = NO;

  //Check if there is a root config or config per domain
  if(_domain != nil && [sd doesLoginTypeByDomain])
  {
    forDomain = _domain;
    type = [sd getLoginTypeForDomain: _domain];
    if(type != nil && [type isEqualToString: @"openid"])
    {
      config = [sd getLoginConfigForDomain: _domain];
      [self initializeWithConfig: config];
    }
    else
    {
      [self errorWithFormat: @"Missing parameters from sogo.conf"];
    }
  }
  else if ([[self class] checkUserConfig])
  {
    openIdConfigUrl          = [sd openIdConfigUrl];
    openIdScope              = [sd openIdScope];
    openIdClient             = [sd openIdClient];
    openIdClientSecret       = [sd openIdClientSecret];
    openIdEmailParam         = [sd openIdEmailParam];
    openIdHttpVersion        = [sd openIdHttpVersion];
    openIdEnableRefreshToken = [sd openIdEnableRefreshToken];
    userTokenInterval        = [sd openIdTokenCheckInterval];
    sendDomainInfo           = [sd openIdSendDomainInfo];
    forDomain = _domain;

    [self _loadSessionFromCache: _domain];

    if(cacheUpdateNeeded)
    {
      [self fecthConfiguration: _domain];
    }
      
  }
  else
  {
    [self errorWithFormat: @"Missing parameters from sogo.conf"];
  }
}

- (SimpleOpenIdResponse *) _performOpenIdRequest: (NSString *) endpoint
                        method: (NSString *) method
                       headers: (NSDictionary *) headers
                          body: (NSData *) body
{
  NSURL *url;
  NSMutableData *buffer, *buffHeaders;
  SimpleOpenIdResponse *response;
  
  CURL *curl;
  struct curl_slist *headerlist=NULL;
  NSUInteger status;
  NSString *content, *headerResp;
  CURLcode rc;
  char error[CURL_ERROR_SIZE];

  url = [NSURL URLWithString: endpoint];
  if(!url)
  {
    [self errorWithFormat: @"OpenID can't handle endpoint (not a url): '%@'", endpoint];
    return nil;
  }

  if(SOGoOpenIDDebugEnabled)
  {
    NSLog(@"OpenId perform request: %@ %@", method, endpoint);
    NSLog(@"OpenId perform request, headers %@", headers);
  }
  if(SOGoOpenIDDebugEnabled)
    NSLog(@"OpenId perform request, body raw %@", body);

  curl_global_init(CURL_GLOBAL_SSL);
  curl = curl_easy_init();

  if (curl)
  {
    error[0] = 0;
    curl_easy_setopt(curl, CURLOPT_URL, [endpoint UTF8String]);

    //add form
    if(body)
    {
      //Trick because sometimes NSData bytes don't add the \0 at the end and junk character may be added
      const char *myBodyTmp = (const char*)[body bytes];
      char myBody[[body length]+1];
      strncpy(myBody, myBodyTmp, [body length]);
      myBody[[body length]]='\0';

      if(SOGoOpenIDDebugEnabled)
        NSLog(@"OpenId perform request, myBodyTmp %s", myBodyTmp);

      if(SOGoOpenIDDebugEnabled)
        NSLog(@"OpenId perform request, myBody %s", myBody);

      curl_easy_setopt(curl, CURLOPT_POST, 1);
      curl_easy_setopt(curl, CURLOPT_POSTFIELDS, myBody);
    }
    
    //add headers
    if(headers)
    {
      NSEnumerator *enumerator = [headers keyEnumerator];
      NSString *key, *header;
      while((key = [enumerator nextObject]))
      {
        header = [NSString stringWithFormat: @"%@: %@", key, [headers objectForKey: key]];
        headerlist = curl_slist_append(headerlist, [header UTF8String]);
      }
    }
    if(headerlist != NULL)
      curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headerlist);
    

    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 60L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);

    buffer = [NSMutableData data];
    buffHeaders = [NSMutableData data];
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_body_function);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, buffer);
    curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, curl_body_function);
    curl_easy_setopt(curl, CURLOPT_HEADERDATA, buffHeaders);
    curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, &error);

    // Perform SOAP request
    rc = curl_easy_perform(curl);
    if (rc == CURLE_OK)
    {
      curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &status);

      response = [SimpleOpenIdResponse alloc];
      headerResp = [[NSString alloc] initWithData: buffHeaders
                                        encoding: NSUTF8StringEncoding];

      response = [response initWithResponse: nil andHeaders: headerResp andStatus: status];

      if(status >= 200 && status <500 && status != 404)
      {
        content = [[NSString alloc] initWithData: buffer
                                        encoding: NSUTF8StringEncoding];
        if (!content)
          content = [[NSString alloc] initWithData: buffer
                                          encoding: NSISOLatin1StringEncoding];
        [response setContent: content];

        if(SOGoOpenIDDebugEnabled)
          NSLog(@"OpenId perform request: response is: %@", response);

        return [response autorelease];
      }
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
      [self errorWithFormat: @"CURL error while accessing %@ (%d): %@", endpoint, rc,
            [NSString stringWithCString: strlen(error) ? error : curl_easy_strerror(rc)]];
    }
    curl_easy_cleanup (curl);
  }
  else
  {
    [self errorWithFormat: @"OpenID error when setting curl request for: %@", endpoint];
    return nil; 
  }
}

- (NSMutableDictionary *) fecthConfiguration: (NSString*) _domain
{
  NSString *content;
  SimpleOpenIdResponse *response;
  // WOResponse * response;
  NSUInteger status;
  NSMutableDictionary *result;
  NSDictionary *config, *headers;
  NSURL *url;

  result = [NSMutableDictionary dictionary];
  [result setObject: self->openIdConfigUrl  forKey: @"url"];

  url = [NSURL URLWithString: self->openIdConfigUrl ];
  if (url)
  {
    if(self->sendDomainInfo && _domain != nil && [_domain length] > 0)
      headers = [NSDictionary dictionaryWithObject: _domain forKey: @"sogo-user-domain"];
    else
      headers = nil;

    response = [self _performOpenIdRequest: self->openIdConfigUrl 
                      method: @"GET"
                      headers: headers
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
        self->userinfoEndpoint      = [config objectForKey: @"userinfo_endpoint"];

        if([config objectForKey: @"end_session_endpoint"]) 
          self->endSessionEndpoint    = [config objectForKey: @"end_session_endpoint"];

        //Optionnals?
        if([config objectForKey: @"introspection_endpoint"])
          self->introspectionEndpoint = [config objectForKey: @"introspection_endpoint"];
        if([config objectForKey: @"revocation_endpoint"])
          self->revocationEndpoint    = [config objectForKey: @"revocation_endpoint"];

        openIdSessionIsOK = YES;
        [self _saveSessionToCache: _domain];
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

+ (SOGoOpenIdSession *) OpenIdSession: (NSString *) _domain
{
  SOGoOpenIdSession *newSession;

  newSession = [self new];
  [newSession autorelease];
  [newSession initialize: _domain];

  return newSession;
}

+ (SOGoOpenIdSession *) OpenIdSessionWithConfig: (NSDictionary *) _config
{
  SOGoOpenIdSession *newSession;

  newSession = [self new];
  [newSession autorelease];
  [newSession initializeWithConfig: _config];

  return newSession;
}

+ (SOGoOpenIdSession *) OpenIdSessionWithToken: (NSString *) token domain: (NSString *) _domain
{
  SOGoOpenIdSession *newSession;

  if (token)
    {
      newSession = [self new];
      [newSession autorelease];
      [newSession initialize: _domain];
      
      [newSession setAccessToken: token];
    }
  else
    newSession = nil;

  return newSession;
}

+ (SOGoOpenIdSession *) OpenIdSessionWithTokenAndConfig: (NSString *) token config: (NSDictionary *) _config
{
  SOGoOpenIdSession *newSession;

  if (token)
    {
      newSession = [self new];
      [newSession autorelease];
      [newSession initializeWithConfig: _config];
      
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

- (void) _loadSessionFromCache: (NSString*) _domain
{
  SOGoCache *cache;
  NSString *jsonSession, *cacheKey;
  NSDictionary *sessionDict;

  if(_domain != nil && [_domain length] > 0)
    cacheKey = [self->openIdConfigUrl stringByAppendingFormat: @":%@", _domain];
  else
    cacheKey = self->openIdConfigUrl;

  cache = [SOGoCache sharedCache];
  jsonSession = [cache openIdSessionFromServer: cacheKey];
  if ([jsonSession length])
  {
    sessionDict = [jsonSession objectFromJSONString];
    ASSIGN (authorizationEndpoint, [sessionDict objectForKey: @"authorization_endpoint"]);
    ASSIGN (tokenEndpoint, [sessionDict objectForKey: @"token_endpoint"]);
    ASSIGN (userinfoEndpoint, [sessionDict objectForKey: @"userinfo_endpoint"]);
    if([sessionDict objectForKey: @"end_session_endpoint"])
      ASSIGN (endSessionEndpoint, [sessionDict objectForKey: @"end_session_endpoint"]);

    //Optionnals?
    if([sessionDict objectForKey: @"introspection_endpoint"])
      ASSIGN (introspectionEndpoint, [sessionDict objectForKey: @"introspection_endpoint"]);
    if([sessionDict objectForKey: @"revocation_endpoint"])
      ASSIGN (revocationEndpoint, [sessionDict objectForKey: @"revocation_endpoint"]);
    openIdSessionIsOK = YES;
  }
  else
    cacheUpdateNeeded = YES;
}

- (void) _saveSessionToCache: (NSString*) _domain
{
  SOGoCache *cache;
  NSString *jsonSession, *cacheKey;
  NSMutableDictionary *sessionDict;

  cache = [SOGoCache sharedCache];
  sessionDict = [NSMutableDictionary dictionary];
  [sessionDict setObject: authorizationEndpoint forKey: @"authorization_endpoint"];
  [sessionDict setObject: tokenEndpoint forKey: @"token_endpoint"];
  [sessionDict setObject: userinfoEndpoint forKey: @"userinfo_endpoint"];
  if(endSessionEndpoint)
    [sessionDict setObject: endSessionEndpoint forKey: @"end_session_endpoint"];

  //Optionnals?
  if(introspectionEndpoint)
    [sessionDict setObject: introspectionEndpoint forKey: @"introspection_endpoint"];
  if(revocationEndpoint)
    [sessionDict setObject: revocationEndpoint forKey: @"revocation_endpoint"];

  jsonSession = [sessionDict jsonRepresentation];

  if(_domain != nil && [_domain length] > 0)
    cacheKey = [self->openIdConfigUrl stringByAppendingFormat: @":%@", _domain];
  else
    cacheKey = self->openIdConfigUrl;

  [cache setOpenIdSession: jsonSession
                forServer: cacheKey];
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


-(NSString *) _random_state
{
    return [[[NSProcessInfo processInfo] globallyUniqueString] asSHA1String];;
}

- (NSString*) loginUrl: (NSString *) oldLocation
{
  NSString* logUrl;
  logUrl = [self->authorizationEndpoint stringByAppendingFormat: @"?scope=%@", self->openIdScope];
  logUrl = [logUrl stringByAppendingString: @"&response_type=code"];
  logUrl = [logUrl stringByAppendingFormat: @"&client_id=%@", self->openIdClient];
  logUrl = [logUrl stringByAppendingFormat: @"&redirect_uri=%@", oldLocation];
  logUrl = [logUrl stringByAppendingFormat: @"&state=%@", [self _random_state]];
  if(self->forDomain != nil && [self->forDomain length] > 0)
    logUrl = [logUrl stringByAppendingFormat: @"&sogo_domain=%@", forDomain];
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
  SimpleOpenIdResponse *response;
  // WOResponse *response;
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

    if(self->sendDomainInfo && self->forDomain != nil && [self->forDomain length] > 0)
      headers = [NSDictionary dictionaryWithObjectsAndKeys: @"application/x-www-form-urlencoded", @"content-type",
                                                                self->forDomain, @"sogo-user-domain", nil];
    else
      headers = [NSDictionary dictionaryWithObject: @"application/x-www-form-urlencoded"  forKey: @"content-type"];

    if(SOGoOpenIDDebugEnabled)
      NSLog(@"OpenId fetch token, form %@", form);

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
  SimpleOpenIdResponse *response;
  // WOResponse *response;
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

    if(self->sendDomainInfo && self->forDomain != nil && [self->forDomain length] > 0)
      headers = [NSDictionary dictionaryWithObjectsAndKeys: @"application/x-www-form-urlencoded", @"content-type",
                                                                self->forDomain, @"sogo-user-domain", nil];
    else
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
  SimpleOpenIdResponse *response;
  // WOResponse *response;
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
    if(self->sendDomainInfo && self->forDomain != nil && [self->forDomain length] > 0)
      headers = [NSDictionary dictionaryWithObjectsAndKeys: @"application/x-www-form-urlencoded", @"content-type",
                                                                self->forDomain, @"sogo-user-domain",
                                                                auth, @"authorization", nil];
    else
      headers = [NSDictionary dictionaryWithObjectsAndKeys: @"application/x-www-form-urlencoded", @"content-type",
                                                                auth, @"authorization", nil];

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
          [self logWithFormat: @"Error fetching userInfo (status %d), response: %@", status, response];
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

- (NSString *) login: (NSString *) email
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
