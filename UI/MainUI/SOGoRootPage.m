/*

  Copyright (C) 2006-2021 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/


#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOCookie.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSObject+Values.h>

#import <SOGo/NSString+Crypto.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoBuild.h>
#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoCASSession.h>
#import <SOGo/SOGoOpenIdSession.h>
#if defined(SAML2_CONFIG)
#import <SOGo/SOGoSAML2Session.h>
#endif /* SAML2_ENABLE */
#import <SOGo/SOGoSession.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoWebAuthenticator.h>
#import <SOGo/SOGoEmptyAuthenticator.h>
#import <SOGo/SOGoMailer.h>
#import <SOGo/SOGoAdmin.h>

#if defined(MFA_CONFIG)
#include <liboath/oath.h>
#endif

#import "SOGoRootPage.h"

static const NSString *kJwtKey = @"jwt";

@implementation SOGoRootPage

- (id) init
{
  if ((self = [super init]))
    {
      cookieLogin = nil;
    }

  return self;
}

- (void) dealloc
{
  [cookieLogin release];
  [super dealloc];
}

/* accessors */

- (NSString *) modulePath
{
  return @"";
}

//- (NSString *) connectURL
//{
//  return [NSString stringWithFormat: @"%@/connect", [self applicationPath]];
//}

- (NSString *) cookieUsername
{
  NSString *value;

  if (cookieLogin == nil)
    {
      value = [[context request] cookieValueForKey: @"SOGoLogin"];
      cookieLogin = [value isNotNull]? [value stringByDecodingBase64] : @"";
      [cookieLogin retain];
    }

  return cookieLogin;
}

- (BOOL) rememberLogin
{
  return ([[self cookieUsername] length]);
}

- (WOCookie *) _cookieWithUsername: (NSString *) username
{
  WOCookie *loginCookie;
  NSString *appName;
  NSCalendarDate *date;

  appName = [[context request] applicationName];
  date = [NSCalendarDate calendarDate];
  [date setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];
  if (username)
    {
      // Cookie expires in one month
      loginCookie = [WOCookie cookieWithName: @"SOGoLogin"
                                       value: [username stringByEncodingBase64]
                                        path: nil
                                      domain: nil
                                     expires: [date dateByAddingYears:0 months:1 days:0
                                                                hours:0 minutes:0 seconds:0]
                                    isSecure: NO];
    }
  else
    {
      loginCookie = [WOCookie cookieWithName: @"SOGoLogin"
                                       value: nil];
      [loginCookie setExpires: [date yesterday]];
    }

  [loginCookie setPath: [NSString stringWithFormat: @"/%@/", appName]];

  return loginCookie;
}

- (WOCookie *) _authLocationCookie: (BOOL) cookieReset
                          withName: (NSString *) cookieName
                          withValue: (NSString *) _value
{
  WOCookie *locationCookie;
  NSString *appName;
  WORequest *rq;
  NSCalendarDate *date;

  rq = [context request];
  if(_value)
    locationCookie = [WOCookie cookieWithName: cookieName value: _value];
  else
    locationCookie = [WOCookie cookieWithName: cookieName value: [rq uri]];
  appName = [rq applicationName];
  [locationCookie setPath: [NSString stringWithFormat: @"/%@/", appName]];
  if (cookieReset)
    {
      date = [NSCalendarDate calendarDate];
      [date setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];
      [locationCookie setExpires: [date yesterday]];
    }

  return locationCookie;
}

- (WOCookie *) _domainCookie: (BOOL) cookieReset
                    withDomain: (NSString *) _domain
{
  WOCookie *domainCookie;
  NSString *appName;
  WORequest *rq;
  NSCalendarDate *date;

  rq = [context request];
  domainCookie = [WOCookie cookieWithName: @"sogo-user-domain" value: _domain];
  appName = [rq applicationName];
  [domainCookie setPath: [NSString stringWithFormat: @"/%@/", appName]];
  if (cookieReset)
    {
      date = [NSCalendarDate calendarDate];
      [date setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];
      [domainCookie setExpires: [date yesterday]];
    }

  return domainCookie;
}

//
//
//
- (WOResponse *) _responseWithLDAPPolicyError: (int) error
{
  NSDictionary *jsonError;

  jsonError = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: error]
                                          forKey: @"LDAPPasswordPolicyError"];
  return [self responseWithStatus: 403
            andJSONRepresentation: jsonError];
}

- (void) _checkAutoReloadWebCalendars: (SOGoUser *) loggedInUser
{
  NSDictionary *autoReloadedWebCalendars;
  NSMutableDictionary *moduleSettings;
  SOGoUserSettings *us;

  us = [loggedInUser userSettings];
  moduleSettings = [us objectForKey: @"Calendar"];

  if (moduleSettings)
    {
      autoReloadedWebCalendars = [moduleSettings objectForKey: @"AutoReloadedWebCalendars"];
      if ([[autoReloadedWebCalendars allValues] containsObject: [NSNumber numberWithInt: 1]])
        {
          [moduleSettings setObject: [NSNumber numberWithBool: YES] forKey: @"ReloadWebCalendars"];
          [us synchronize];
        }
    }
}

//
//
//
- (WOResponse *) connectAction
{
  WOResponse *response;
  WORequest *request;
  WOCookie *authCookie, *xsrfCookie;
  SOGoWebAuthenticator *auth;
  SOGoUserDefaults *ud;
  SOGoUserSettings *us;
  SOGoUser *loggedInUser;
  NSDictionary *params;
  NSString *username, *password, *language, *domain, *remoteHost;
  NSArray *supportedLanguages, *creds;

  SOGoPasswordPolicyError err;
  int expire, grace;
  BOOL rememberLogin, b;

  err = PolicyNoError;
  expire = grace = -1;

  auth = [[WOApplication application] authenticatorInContext: context];
  request = [context request];
  params = [[request contentAsString] objectFromJSONString];

  username = [params objectForKey: @"userName"];
  password = [params objectForKey: @"password"];
  language = [params objectForKey: @"language"];
  rememberLogin = [[params objectForKey: @"rememberLogin"] boolValue];
  domain = [params objectForKey: @"domain"];
  /* this will always be set to something more or less useful by
   * [WOHttpTransaction applyAdaptorHeadersWithHttpRequest] */
  remoteHost = [request headerForKey:@"x-webobjects-remote-host"];

  if ((b = [auth checkLogin: username password: password domain: &domain
		 perr: &err expire: &expire grace: &grace useCache: NO])
      && (err == PolicyNoError)
      // no password policy
      && ((expire < 0 && grace < 0)     // no password policy or everything is alright
      || (expire < 0 && grace > 0)      // password expired, grace still permits login
      || (expire >= 0 && grace == -1))) // password about to expire OR ppolicy activated and passwd never changed
    {
      NSMutableDictionary *json = [NSMutableDictionary dictionary];

      [self logWithFormat: @"successful login from '%@' for user '%@' - expire = %d  grace = %d", remoteHost, username, expire, grace];

      // We get the proper username for cookie creation. If we are using a multidomain
      // environment with SOGoEnableDomainBasedUID, we could have to append the domain
      // to the username. Also when SOGoEnableDomainBasedUID is enabled, we could be in
      // the DomainLessLogin situation, so we would NOT add the domain. -getUIDForEmail
      // has all the logic for this, so lets use it.
      if ([domain isNotNull])
        username = [[SOGoUserManager sharedUserManager] getUIDForEmail: username];

      loggedInUser = [SOGoUser userWithLogin: username];
      ud = [loggedInUser userDefaults];
      us = [loggedInUser userSettings];

#if defined(MFA_CONFIG)
      if ([ud totpEnabled])
        {
          NSString *verificationCode;

          verificationCode = [params objectForKey: @"verificationCode"];
          if ([verificationCode length] == 6 && [verificationCode unsignedIntValue] > 0)
            {
              unsigned int code;
              const char *real_secret;
              char *secret;

              size_t secret_len;

              const auto time_step = OATH_TOTP_DEFAULT_TIME_STEP_SIZE;
              const auto digits = 6;

              real_secret = [[loggedInUser totpKey] UTF8String];

              auto result = oath_init();
              auto t = time(NULL);
              auto left = time_step - (t % time_step);

              char otp[digits + 1];

              oath_base32_decode (real_secret,
                                  strlen(real_secret),
                                  &secret, &secret_len);

              result = oath_totp_generate2(secret,
                                           secret_len,
                                           t,
                                           time_step,
                                           OATH_TOTP_DEFAULT_START_TIME,
                                           digits,
                                           0,
                                           otp);

              sscanf(otp, "%u", &code);

              oath_done();
              free(secret);

              if (code != [verificationCode unsignedIntValue])
                {
                  [self logWithFormat: @"Invalid TOTP key for '%@'", username];
                  [json setObject: [NSNumber numberWithInt: 1]
                           forKey: @"totpInvalidKey"];
                  return [self responseWithStatus: 403
                            andJSONRepresentation: json];
                }
            } //  if ([verificationCode length] == 6 && [verificationCode unsignedIntValue] > 0)
          else
            {
              if ([us dictionaryForKey: @"General"] && ![[us dictionaryForKey: @"General"] objectForKey: @"PrivateSalt"])
                {
                  // Since v5.3.0, a new salt is used for TOTP. If it's missing, disable TOTP and alert the user.
                  [ud setTotpEnabled: NO];
                  [ud synchronize];

                  [self logWithFormat: @"New TOTP key for '%@' must be created", username];
                  [json setObject: [NSNumber numberWithInt: 1]
                           forKey: @"totpDisabled"];
                }
              else
                {
                  [self logWithFormat: @"Missing TOTP key for '%@', asking it..", username];
                  [json setObject: [NSNumber numberWithInt: 1]
                           forKey: @"totpMissingKey"];
                  return [self responseWithStatus: 202
                            andJSONRepresentation: json];
                }
            }
        }
#endif
      
      if ([us objectForKey: @"ForceResetPassword"]) {
        response = [self _responseWithLDAPPolicyError: PolicyPasswordExpired];
      } else {
        [self _checkAutoReloadWebCalendars: loggedInUser];

        [json setObject: [loggedInUser cn]
                forKey: @"cn"];
        [json setObject: [NSNumber numberWithInt: expire]
                forKey: @"expire"];
        [json setObject: [NSNumber numberWithInt: grace]
                forKey: @"grace"];
        [json setObject: [SOGoUser getEncryptedUsernameIfNeeded: username request: request]
                forKey: @"username"];

        response = [self responseWithStatus: 200
                      andJSONRepresentation: json];

        authCookie = [auth cookieWithUsername: username
                                  andPassword: password
                                    inContext: context];
        [response addCookie: authCookie];

        // We prepare the XSRF protection cookie
        creds = [auth parseCredentials: [authCookie value]];
        xsrfCookie = [WOCookie cookieWithName: @"XSRF-TOKEN"
                                        value: [[SOGoSession valueForSessionKey: [creds lastObject]] asSHA1String]];
        [xsrfCookie setPath: [NSString stringWithFormat: @"/%@/", [[context request] applicationName]]];
        [response addCookie: xsrfCookie];

        supportedLanguages = [[SOGoSystemDefaults sharedSystemDefaults]
                              supportedLanguages];
        [context setActiveUser: loggedInUser];
        if (language && [supportedLanguages containsObject: language])
        {
          [ud setLanguage: language];
          [ud synchronize];
        }
      }
    }
  else
    {
      [self logWithFormat: @"Login from '%@' for user '%@' might not have worked - password policy: %d  grace: %d  expire: %d  bound: %d",
            remoteHost, username, err, grace, expire, b];

      response = [self _responseWithLDAPPolicyError: err];
    }

  if (rememberLogin)
    [response addCookie: [self _cookieWithUsername: [params objectForKey: @"userName"]]];
  else
    [response addCookie: [self _cookieWithUsername: nil]];

  return response;
}


- (NSDictionary *) _casRedirectKeys
{
  NSDictionary *redirectKeys;
  NSURL *soURL;
  NSString *serviceURL;

  soURL = [[WOApplication application] soURL];
  // appending 'index' to /SOGo/so/. Matches serviceURL sent by _pgtUrlFromURL
  serviceURL = [NSString stringWithFormat: @"%@index", [soURL absoluteString]];

  redirectKeys = [NSDictionary dictionaryWithObject: serviceURL
                                             forKey: @"service"];

  return redirectKeys;
}

- (id <WOActionResults>) casProxyAction
{
  SOGoCache *cache;
  WORequest *request;
  NSString *pgtId, *pgtIou;

  request = [context request];
  pgtId = [request formValueForKey: @"pgtId"];
  pgtIou = [request formValueForKey: @"pgtIou"];
  if ([pgtId length] && [pgtIou length])
    {
      cache = [SOGoCache sharedCache];
      [cache setCASPGTId: pgtId forPGTIOU: pgtIou];
    }

  return [self responseWithStatus: 200];
}

- (id <WOActionResults>) _casDefaultAction
{
  WOResponse *response;
  NSString *login, *logoutRequest, *newLocation, *oldLocation, *ticket;
  SOGoCASSession *casSession;
  SOGoUser *loggedInUser;
  SOGoWebAuthenticator *auth;
  WOCookie *casCookie, *casLocationCookie;
  WORequest *rq;

  casCookie = nil;
  casLocationCookie = nil;

  newLocation = nil;

  login = [[context activeUser] login];
  if ([login isEqualToString: @"anonymous"])
    login = nil;
  if (!login)
  {
    rq = [context request];
    ticket = [rq formValueForKey: @"ticket"];
    if ([ticket length])
    {
      casSession = [SOGoCASSession CASSessionWithTicket: ticket
                                              fromProxy: NO];
      login = [casSession login];
      if ([login length])
      {
        auth = [[WOApplication application]
                  authenticatorInContext: context];
        casCookie = [auth cookieWithUsername: login
                                  andPassword: [casSession identifier]
                                    inContext: context];
        [casSession updateCache];
        newLocation = [rq cookieValueForKey: @"cas-location"];
        /* login callback, we expire the "cas-location" cookie, created
            below */
        casLocationCookie = [self _authLocationCookie: YES
                                              withName: @"cas-location"
                                              withValue: nil];
      }
    }
    else
      {
        /* anonymous and no ticket, possibly a logout request from CAS
          * See: https://wiki.jasig.org/display/CASUM/Single+Sign+Out
          */
        logoutRequest = [rq formValueForKey: @"logoutRequest"];
        if ([logoutRequest length])
          {
            [SOGoCASSession handleLogoutRequest: logoutRequest];
            return [self responseWithStatus: 200];
          }
      }
  }
  else
    ticket = nil;

  if (login)
    {
      /* We redirect the user to their "homepage" when newLocation could not be
         deduced from the "cas-location" cookie and the current action is not a
         login callback (ticket != nil).  */
      if (!newLocation || !ticket)
        {
          oldLocation = [[self clientObject] baseURLInContext: context];
          newLocation = [NSString stringWithFormat: @"%@%@",
                                  oldLocation, [login stringByEscapingURL]];
        }

      loggedInUser = [SOGoUser userWithLogin: login];
      [self _checkAutoReloadWebCalendars: loggedInUser];
    }
  else
    {
      newLocation = [SOGoCASSession CASURLWithAction: @"login"
                                       andParameters: [self _casRedirectKeys]];
      casLocationCookie = [self _authLocationCookie: NO
                                           withName: @"cas-location"
                                           withValue: nil];
    }
  response = [self redirectToLocation: newLocation];
  if (casCookie)
    [response addCookie: casCookie];
  if (casLocationCookie)
    [response addCookie: casLocationCookie];

  return response;
}

- (id <WOActionResults>) _openidDefaultAction: (NSString *) _domain
{
  WOResponse *response;
  NSString *login, *redirectLocation, *serverUrl;
  NSString *sessionState, *code, *refreshTokenValue;
  NSURL *newLocation, *oldLocation;
  NSDictionary *formValues;
  SOGoUser *loggedInUser;
  WOCookie *openIdCookie, *openIdCookieLocation, *openIdRefreshCookie, *domainCookie;
  WORequest *rq;
  SOGoWebAuthenticator *auth;
  SOGoOpenIdSession *openIdSession;
  id value;

  openIdCookie = nil;
  openIdCookieLocation = nil;
  openIdRefreshCookie = nil;
  domainCookie = nil;
  newLocation = nil;

  rq = [context request];

  //Check if the domain is stored in a cookie if not given
  if(_domain == nil || [_domain length] == 0)
    _domain = [rq cookieValueForKey: @"sogo-user-domain"]; //_domain can still be nil aftert his

  openIdSession = [SOGoOpenIdSession OpenIdSession: _domain];

  if(![openIdSession sessionIsOk])
  {
    return [NSException exceptionWithHTTPStatus: 502 /* Bad OpenId Configuration */
                                       reason: [NSString stringWithFormat: @"OpenId server not found or has unexpected behavior, contact your admin."]];
  }

  login = [[context activeUser] login];
  if ([login isEqualToString: @"anonymous"])
    login = nil;
  if (!login)
  {
    //You get here if you nerver been logged in or if you token is expired
    serverUrl = [[context serverURL] absoluteString];
    redirectLocation = [NSString stringWithFormat: @"%@/%@/", serverUrl, [rq applicationName]];
    if((formValues = [rq formValues]) && [formValues objectForKey: @"code"])
    {
      //You get here if this is the callback of openid after you logged in

      //NOT MANDATORY
      // value = [formValues objectForKey: @"session_state"];
      // if ([value isKindOfClass: [NSArray class]])
      //   sessionState = [value lastObject];
      // else
      //   sessionState = value;

      value = [formValues objectForKey: @"code"];
      if ([value isKindOfClass: [NSArray class]])
        code = [value lastObject];
      else
        code = value;
      [openIdSession fetchToken: code redirect: redirectLocation];
      login = [openIdSession login: @""];
      if ([login length])
      {
        auth = [[WOApplication application] authenticatorInContext: context];
        openIdCookie = [auth cookieWithUsername: login
                                  andPassword: [openIdSession getToken]
                                    inContext: context];
      }
      newLocation = [rq cookieValueForKey: @"openid-location"];
      openIdCookieLocation = [self _authLocationCookie: YES withName: @"openid-location" withValue: nil];
      domainCookie = [self _domainCookie: YES withDomain: _domain];
    }
    // else if((formValues = [rq formValues]) && [formValues objectForKey: @"action"])
    // {
    //   value = [formValues objectForKey: @"action"];
    //   if ([value isKindOfClass: [NSArray class]])
    //     code = [value lastObject];
    //   else
    //     code = value;
    //   if([code isEqualToString:@"redirect"])
    //   {
    //     //this action onlye serve to make a redirection to openId server after a GET request
    //     newLocation = [openIdSession loginUrl: redirectLocation];
    //   }
    //}
    else
    {
      // //You get here the first time you access sogo, it redirect to last location
      // if([[rq method] isEqualToString: @"POST"])
      //   //To avoid making a redirection to openid server after a post request, we first redirect to a get method
      //   newLocation = [NSString stringWithFormat: @"%@?action=redirect", redirectLocation];
      // else
      if(_domain != nil && [_domain length] > 0)
      {
        //add the domain cookie to get it after the redirect
        domainCookie = [self _domainCookie: NO withDomain: _domain];
      }
      newLocation = [openIdSession loginUrl: redirectLocation];
      openIdCookieLocation = [self _authLocationCookie: NO withName: @"openid-location" withValue: nil];
    }
  }
  else
  {
    if (!newLocation)
    {
      oldLocation = [[self clientObject] baseURLInContext: context];
      newLocation = [NSString stringWithFormat: @"%@%@", oldLocation, [login stringByEscapingURL]];
    }

    loggedInUser = [SOGoUser userWithLogin: login];
    [self _checkAutoReloadWebCalendars: loggedInUser];
  }

  response = [self redirectToLocation: newLocation];
  if (openIdCookie)
    [response addCookie: openIdCookie];
  if (openIdCookieLocation)
    [response addCookie: openIdCookieLocation];
  if(domainCookie)
    [response addCookie: domainCookie];
  //[response setStatus: 303];
  return response;
}



#if defined(SAML2_CONFIG)
- (id <WOActionResults>) _saml2DefaultAction
{
  WOResponse *response;
  NSString *login, *newLocation, *oldLocation;
  SOGoUser *loggedInUser;
  WOCookie *saml2LocationCookie;
  WORequest *rq;

  saml2LocationCookie = nil;

  newLocation = nil;

  login = [[context activeUser] login];
  if ([login isEqualToString: @"anonymous"])
    login = nil;

  if (login)
    {
      rq = [context request];
      newLocation = [rq cookieValueForKey: @"saml2-location"];
      if (newLocation)
        saml2LocationCookie = [self _authLocationCookie: YES
                                               withName: @"saml2-location"
                                               withValue: nil];
      else
        {
          oldLocation = [[self clientObject] baseURLInContext: context];
          newLocation = [NSString stringWithFormat: @"%@%@",
                                  oldLocation, [login stringByEscapingURL]];
        }

      loggedInUser = [SOGoUser userWithLogin: login];
      [self _checkAutoReloadWebCalendars: loggedInUser];
    }
  else
    {
      newLocation = [SOGoSAML2Session authenticationURLInContext: context];
      saml2LocationCookie = [self _authLocationCookie: NO
                                             withName: @"saml2-location"
                                             withValue: nil];
    }

  response = [self redirectToLocation: newLocation];
  if (saml2LocationCookie)
    [response addCookie: saml2LocationCookie];

  return response;
}
#endif /* SAML2_CONFIG */

- (id <WOActionResults>) _standardDefaultAction
{
  NSObject <WOActionResults> *response;
  NSString *login, *oldLocation;

  login = [[context activeUser] login];
  if ([login isEqualToString: @"anonymous"])
    login = nil;

  if (login)
  {
    oldLocation = [[self clientObject] baseURLInContext: context];
    response = [self redirectToLocation: [NSString stringWithFormat: @"%@%@",  oldLocation,
                  [[SOGoUser getEncryptedUsernameIfNeeded:login request: [context request]] stringByEscapingURL]]];
  }
  else
  {
    oldLocation = [[context request] uri];
    if ([context clientObject] && ![oldLocation hasSuffix: @"/"] && ![oldLocation hasSuffix: @"/view"])
      response = [self redirectToLocation: [NSString stringWithFormat: @"%@/", oldLocation]];
    else
      response = self;
  }

  return response;
}

- (WOResponse *) connectNameAction
{
  WOResponse *response;
  WORequest *request;
  NSDictionary *params;
  NSString *username, *language, *domain, *type, *serverUrl, *redirectLocation;
  NSRange r;

  request = [context request];
  params = [[request contentAsString] objectFromJSONString];

  username = [params objectForKey: @"userName"];

  //Extract the domain
  r = [username rangeOfString: @"@"];
  if (r.location != NSNotFound)
  {
    domain = [username substringFromIndex: r.location+1];
    type = [[SOGoSystemDefaults sharedSystemDefaults] getLoginTypeForDomain: domain];
    if(type != nil)
    {
      if([type isEqualToString: @"plain"])
      {
        //Only reload the page with the name
        serverUrl = [[context serverURL] absoluteString];
        redirectLocation = [NSString stringWithFormat: @"%@/%@/login?hint=%@", serverUrl, [request applicationName], username];
        //response = [self redirectToLocation: [NSString stringWithFormat: @"%@/", redirectLocation]];
        response = [self responseWithStatus: 200 andJSONRepresentation:
          [NSDictionary dictionaryWithObjectsAndKeys: redirectLocation, @"redirect", nil]];
      }
      else if([type isEqualToString: @"openid"])
      {
        SOGoOpenIdSession *openIdSession;
        WOCookie *domainCookie, *openIdCookieLocation;

        //With openId, the user will be redirected to the openid server for login
        //With set the domain in a cookie to know it after the openid does the callbacl
        serverUrl = [[context serverURL] absoluteString];
        redirectLocation = [NSString stringWithFormat: @"%@/%@/", serverUrl, [request applicationName]];

        openIdSession = [SOGoOpenIdSession OpenIdSession: domain];

        domainCookie = [self _domainCookie: NO withDomain: domain];
        openIdCookieLocation = [self _authLocationCookie: NO withName: @"openid-location" withValue: redirectLocation];

        response = [self responseWithStatus: 200 andJSONRepresentation:
          [NSDictionary dictionaryWithObjectsAndKeys: [openIdSession loginUrl: redirectLocation], @"redirect", nil]];
        [response addCookie: domainCookie];
        [response addCookie: openIdCookieLocation];
      }
      else if([type isEqualToString: @"cas"] || [type isEqualToString: @"saml2"])
      {
        [self logWithFormat: @"Unsupported type for now: %@", type];
        response = [self responseWithStatus: 400
                              andString: @"Domain Authentication type not supported"];
      }
      else
      {
        [self logWithFormat: @"Unknown type: %@", type];
        response = [self responseWithStatus: 400
                              andString: @"Unknwon Authentication type"];
      }
    }
    else
    {
      [self logWithFormat: @"Auth type for Domain given is not set or there is no default value: %@", domain];
      response = [self responseWithStatus: 400
                              andString: @"Domain unknown"];
    }

  }
  else
  {
    [self logWithFormat: @"Domain is required but not found for user recovery exception for user %@", username];
    response = [self responseWithStatus: 400
                              andString: @"Domain needed in the login"];
  }

  return response;
}


- (id <WOActionResults>) defaultAction
{
  NSString *authenticationType, *loginDomain, *type, *_domain;
  SOGoSystemDefaults* sd;
  id <WOActionResults> result;

  loginDomain = nil;
  sd = [SOGoSystemDefaults sharedSystemDefaults];
  if([sd doesLoginTypeByDomain])
  {
    NSString *login;
    //In this mode sogo will ask the mail of the user before doing any authentication
    //Check if a user is already logged in

    _domain = [[context request] cookieValueForKey: @"sogo-user-domain"]; //_domain can still be nil aftert his
    if(_domain != nil)
    {
      //This is a callback of an openid session.
      return [self _openidDefaultAction: _domain];
    }

    login = [[context activeUser] login];
    if ([login isEqualToString: @"anonymous"])
      login = nil;
    if(!login && !_domain)
      return [self _standardDefaultAction];
    else
    {
      //User already logged in. Extract the domain in that case
      NSRange r;
      r = [login rangeOfString: @"@"];
      if (r.location != NSNotFound)
      {
        loginDomain = [login substringFromIndex: r.location+1];
        type = [sd getLoginTypeForDomain: loginDomain];
        if(type)
        {
          if([type isEqualToString: @"plain"])
          {
            result = [self _standardDefaultAction];
          }
          else if([type isEqualToString: @"openid"])
          {
            result = [self _openidDefaultAction: loginDomain];
          }
          else if([type isEqualToString: @"cas"] || [type isEqualToString: @"saml2"])
          {
            [self logWithFormat: @"Unsupported type for now: %@", type];
            result = [self responseWithStatus: 400
                                  andString: @"Domain Authentication type not supported"];
          }
          else
          {
            [self logWithFormat: @"Unknown type: %@", type];
            result = [self responseWithStatus: 400
                                  andString: @"Unknwon Authentication type"];
          }
        }
        else
        {
          [self logWithFormat: @"Auth type for Domain given is not set or there is no default value: %@", loginDomain];
          result = [self responseWithStatus: 400
                                  andString: @"Domain unknown"];
        }
      }
      else
      {
        loginDomain = nil;
        result = [self _standardDefaultAction];
      }
    }
  }
  else {
    authenticationType = [sd authenticationType];

    if ([authenticationType isEqualToString: @"cas"])
      result = [self _casDefaultAction];
    else if ([authenticationType isEqualToString: @"openid"])
      result = [self _openidDefaultAction: loginDomain];
    #if defined(SAML2_CONFIG)
    else if ([authenticationType isEqualToString: @"saml2"])
      result = [self _saml2DefaultAction];
    #endif /* SAML2_CONFIG */
    else
      result = [self _standardDefaultAction];
  }

  return result;
}

- (BOOL) isPublicInContext: (WOContext *) localContext
{
  return YES;
}

- (NSString *) loginSuffix
{
  return [[SOGoSystemDefaults sharedSystemDefaults] loginSuffix];
}

- (BOOL) hasLoginSuffix
{
  return ([[self loginSuffix] length]);
}

- (NSArray *) loginDomains
{
  return [[SOGoSystemDefaults sharedSystemDefaults] loginDomains];
}

- (BOOL) hasLoginDomains
{
  return ([[self loginDomains] count] > 0);
}

- (BOOL) doLoginUsernameFirst
{
  return [[SOGoSystemDefaults sharedSystemDefaults] doesLoginTypeByDomain];
}

- (BOOL) doFullLogin
{
  //Either we directly do the full login (meaning the user inputs its username and password)
  //Or we do it in two times:
  //phase 1: user types its username first -> only show the username input
  //phase 2: user types its password -> show all inputs
  //In phase 2, the username will be in the query at key "login"
  if([self doLoginUsernameFirst]){
    WORequest *rq;
    BOOL hasLogin;
    NSDictionary *formValues;

    rq = [context request];
    hasLogin = ((formValues=[rq formValues]) && [formValues objectForKey: @"hint"]);
    return hasLogin;
  }

  return YES;
}

- (BOOL) doPartialLogin
{
  return ![self doFullLogin];
}


- (NSString *) getLoginHint
{
  id value;
  WORequest *rq;
  NSString* login;
  NSDictionary *formValues;

  login = @"";

  rq = [context request];
  if((formValues=[rq formValues]) && (value=[formValues objectForKey: @"hint"]))
  {
    if ([value isKindOfClass: [NSArray class]])
      login = [value lastObject];
    else
      login = value;
  }
  return login;
}

- (BOOL) hasPasswordRecovery
{
  return [[SOGoSystemDefaults sharedSystemDefaults] isPasswordRecoveryEnabled];
}

- (void) setItem: (id) _item
{
  ASSIGN (item, _item);
}

- (id) item
{
  return item;
}

- (NSString *) language
{
  return [[context resourceLookupLanguages] objectAtIndex: 0];
}

- (NSString *) localizedLanguage
{
  return [self labelForKey: [self language]];
}


- (NSArray *) languages
{
  return [[[SOGoSystemDefaults sharedSystemDefaults] supportedLanguages] sortedArrayUsingFunction: languageSort context: self];
}

- (NSString *) languageText
{
  NSString *text;

  text = [self labelForKey: item];

  return text;
}

- (NSString *) version
{
  NSString *aString;

  aString = [NSString stringWithString: SOGoVersion];

  return aString;
}

- (WOResponse *) changePasswordAction
{
  NSString *username, *domain, *password, *newPassword, *value, *token;
  WOCookie *authCookie, *xsrfCookie;
  NSDictionary *message;
  NSArray *creds;
  SOGoUserManager *um;
  SOGoPasswordPolicyError error;
  SOGoSystemDefaults *sd;
  SOGoWebAuthenticator *auth;
  WOResponse *response;
  WORequest *request;
  BOOL passwordRecovery;
  SOGoUserSettings *us;
  SOGoUser *loggedInUser;

  request = [context request];
  message = [[request contentAsString] objectFromJSONString];

  auth = [[WOApplication application] authenticatorInContext: context];
  value = [[context request] cookieValueForKey: [auth cookieNameInContext: context]];
  creds = nil;
  username = nil;
  passwordRecovery = NO;

  if (value)
    {
      // User is logged in; extract username from session
      creds = [auth parseCredentials: value];

      [SOGoSession decodeValue: [SOGoSession valueForSessionKey: [creds objectAtIndex: 1]]
                      usingKey: [creds objectAtIndex: 0]
                         login: &username
                        domain: &domain
                      password: &password];
    }
  else
    {
      // We are using ppolicy and changing the password upon login
      username = [message objectForKey: @"userName"];
      domain = [message objectForKey: @"domain"];
    }

  newPassword = [message objectForKey: @"newPassword"];
  // overwrite the value from the session to compare the actual input
  password = [message objectForKey: @"oldPassword"];
  // get session id for password recovery
  token = [message objectForKey: @"token"];
  // If no old password but sessionid set, this is password recovery mode
  if ((!password || password == [NSNull null]) && token) {
    passwordRecovery = YES;
  }

  // Validate required parameters
  if (!username)
    {
     response = [self responseWithStatus: 403
                              andString: @"Missing 'username' parameter"];
    }
  else if (!password && !passwordRecovery)
    {
     response = [self responseWithStatus: 403
                              andString: @"Missing 'oldPassword' parameter"];
    }
  else if (!newPassword)
    {
     response = [self responseWithStatus: 403
                              andString: @"Missing 'newPassword' parameter"];
    }
  else
    {
      um = [SOGoUserManager sharedUserManager];

      // This will also update the cached password in memcached.
      if ([um changePasswordForLogin: username
                            inDomain: domain
                         oldPassword: password
                         newPassword: newPassword
                    passwordRecovery: passwordRecovery
                               token: token
                                perr: &error])
        {
          if (creds)
            {
              // We delete the previous session
              [SOGoSession deleteValueForSessionKey: [creds objectAtIndex: 1]];
            }

          if ([domain isNotNull])
            {
              sd = [SOGoSystemDefaults sharedSystemDefaults];
              if ([sd enableDomainBasedUID] &&
                  [username rangeOfString: @"@"].location == NSNotFound)
                username = [NSString stringWithFormat: @"%@@%@", username, domain];
            }

          loggedInUser = [SOGoUser userWithLogin: username];
          
          if (loggedInUser) {
            us = [loggedInUser userSettings];
            if (us && [us objectForKey: @"ForceResetPassword"]) {
              [us disableForceResetPassword];
            }
          }
          
          response = [self responseWithStatus: 200 andJSONRepresentation: 
                  [NSDictionary dictionaryWithObjectsAndKeys: [SOGoUser getEncryptedUsernameIfNeeded:username request: request], @"username", nil]];

          if (!passwordRecovery) {
            authCookie = [auth cookieWithUsername: username
                                      andPassword: newPassword
                                        inContext: context];
            [response addCookie: authCookie];

            // We update the XSRF protection cookie
            creds = [auth parseCredentials: [authCookie value]];
            xsrfCookie = [WOCookie cookieWithName: @"XSRF-TOKEN"
                                            value: [[SOGoSession valueForSessionKey: [creds lastObject]] asSHA1String]];
            [xsrfCookie setPath: [NSString stringWithFormat: @"/%@/", [request applicationName]]];
            [response addCookie: xsrfCookie];
          }
        }
      else
        response = [self _responseWithLDAPPolicyError: error];
    }

  return response;
}

/**
 * This action get password recovery data for specified user (mode, secret question, recovery email)
 * @return Response
 */
- (WOResponse *) passwordRecoveryAction
{
  NSString *username, *domain;
  NSDictionary *jsonData, *message;
  WORequest *request;
  SOGoUserManager *um;

  username = nil;
  domain = nil;
  request = [context request];

  message = [[request contentAsString] objectFromJSONString];
  username = [message objectForKey: @"userName"];
  domain = [message objectForKey: @"domain"];
  um = [SOGoUserManager sharedUserManager];


  jsonData = [um getPasswordRecoveryInfosForUsername: username domain: domain];
  return [self responseWithStatus: 200
          andJSONRepresentation: jsonData];
}

/**
 * This action generates JWT token and send password recovery mail
 * Then the JWT token is passed and controlled to changePassword (when clicking on link)
 * @return Response
 */
- (WOResponse *) passwordRecoveryEmailAction
{
  NSString *username, *domain, *mode, *uid, *mailDomain, *fromEmail, *toEmail, *jwtToken, *url, *mailContent;
  NSDictionary *message, *info;
  WORequest *request;
  SOGoUserManager *um;
  SOGoUserDefaults *userDefaults;
  WOResponse *response;
  SOGoDomainDefaults *dd;
  SOGoUser *ownerUser;
  SOGoMailer *mailer;
  NSException *e;

  username = nil;
  domain = nil;
  request = [context request];
  message = [[request contentAsString] objectFromJSONString];
  username = [message objectForKey: @"userName"];
  domain = [message objectForKey: @"domain"];
  mailDomain = [message objectForKey: @"mailDomain"];
  mode = [message objectForKey: @"mode"];
  um = [SOGoUserManager sharedUserManager];
  jwtToken = [request formValueForKey:@"token"];

  if (!mode && jwtToken) {
    response = [self _standardDefaultAction];
  } else if ([mode isEqualToString: SOGoPasswordRecoverySecondaryEmail]) {
    if (username) {
        ownerUser = [SOGoUser userWithLogin: username];
        dd = [ownerUser domainDefaults];

        // Email recovery

        // Create email from
        if (mailDomain) {
          fromEmail = [NSString stringWithFormat:@"noreply@%@", mailDomain];
        } else {
          fromEmail = [dd passwordRecoveryFrom];
        }

        // Get password recovery email
        info = [um contactInfosForUserWithUIDorEmail: username];
        uid = [info objectForKey: @"c_uid"];
        userDefaults = [SOGoUserDefaults defaultsForUser: uid
                              inDomain: domain];
        toEmail = [userDefaults passwordRecoverySecondaryEmail];

        if (toEmail) {
          // Generate token
          jwtToken = [um generateAndSavePasswordRecoveryTokenWithUid: uid username: username domain: domain];

          // Send mail
          mailer = [SOGoMailer mailerWithDomainDefaults: dd];
          url = [NSString stringWithFormat:@"%@%@?token=%@"
                      , [[request headers] objectForKey:@"origin"]
                      , [request uri]
                      , jwtToken];

          mailContent = [NSString stringWithFormat: @"Subject: %@\n\n%@"
                            , [self labelForKey: @"Password reset"]
                            , [self labelForKey: @"Hi %{0},\nThere was a request to change your password!\n\nIf you did not make this request then please ignore this email.\n\nOtherwise, please click this link to change your password: %{1}"]];
          // Replace message placeholders
          mailContent = [mailContent stringByReplacingOccurrencesOfString: @"%{0}" withString: username];
          mailContent = [mailContent stringByReplacingOccurrencesOfString: @"%{1}" withString: url];
          e = [mailer sendMailData: [mailContent dataUsingEncoding: NSUTF8StringEncoding]
                      toRecipients: [NSArray arrayWithObjects: toEmail, nil]
                            sender: fromEmail
                 withAuthenticator: [SOGoEmptyAuthenticator sharedSOGoEmptyAuthenticator]
                         inContext: [self context]
                     systemMessage: YES];

          if (!e) {
            response = [self responseWithStatus: 200
                andJSONRepresentation: nil];
          } else {
            [self logWithFormat: @"Password recovery exception for user %@ : %@", uid, [e reason]];
            response = [self responseWithStatus: 403
                              andString: @"Password recovery email in error"];
          }
        } else {
          [self logWithFormat: @"No recovery email found for password recovery for user %@", uid];
          response = [self responseWithStatus: 403
                              andString: @"Invalid configuration for email password recovery"];
        }
    } else {
      [self logWithFormat: @"No user found for password recovery"];
      response = [self responseWithStatus: 403
                              andString: @"Invalid configuration for email password recovery"];
    }
  }

  return response;
}
 
/**
 * This action check secret question answer and generates JWT token.
 * Then the JWT token is passed and controlled to changePassword
 * @return Response
 */
- (WOResponse *) passwordRecoveryCheckAction
{
  NSString *username, *domain, *token, *mode;
  NSDictionary *message;
  WORequest *request;
  SOGoUserManager *um;
  WOResponse *response;

  username = nil;
  domain = nil;
  request = [context request];
  message = [[request contentAsString] objectFromJSONString];
  username = [message objectForKey: @"userName"];
  domain = [message objectForKey: @"domain"];
  mode = [message objectForKey: @"mode"];
  um = [SOGoUserManager sharedUserManager];

  if ([mode isEqualToString: SOGoPasswordRecoveryQuestion]) {
    // Secret question recovery
    token = [um getTokenAndCheckPasswordRecoveryDataForUsername: username domain: domain withData: message];
    if (!token) {
      response = [self responseWithStatus: 403
                  andString: @"Invalid secret question answer"];
    } else {
      response = [self responseWithStatus: 200
              andJSONRepresentation: [NSDictionary dictionaryWithObject: token forKey: kJwtKey]];
    }
  } else {
    response = [self responseWithStatus: 403
              andJSONRepresentation: nil];
  }

  return response;
}

/**
 * Check if password recovery is enabled for user domain
 * @return Response
 */
- (WOResponse *) passwordRecoveryEnabledAction
{
  NSString *username, *domain, *domainName;
  NSArray *usernameComponents, *passwordRecoveryDomains;
  NSDictionary *message, *result;
  WORequest *request;

  username = nil;
  domain = nil;
  domainName = nil;
  result = nil;
  request = [context request];

  message = [[request contentAsString] objectFromJSONString];
  username = [message objectForKey: @"userName"];
  domain = [message objectForKey: @"domain"];
  if ([[SOGoSystemDefaults sharedSystemDefaults] isPasswordRecoveryEnabled]) {
      // If no domain, try to retrieve domain from username
      if (nil != domain && domain != [NSNull null]) {
        domainName = domain;
      } else if (nil != username) {
        usernameComponents = [username componentsSeparatedByString:@"@"]; // Split on @ and take right part
        if (2 == [usernameComponents count]) {
          domainName = [[usernameComponents objectAtIndex: 1] lowercaseString];
        }
      }
      
      if (domainName) {
        result = [NSDictionary dictionaryWithObject: domainName forKey: @"domain"];
      }
  }
  
  passwordRecoveryDomains = [[SOGoSystemDefaults sharedSystemDefaults]
                             passwordRecoveryDomains];
  if (![[SOGoSystemDefaults sharedSystemDefaults] isPasswordRecoveryEnabled]) {
    return [self responseWithStatus: 403
            andJSONRepresentation: nil];
  } else if (username && [NSNull null] != username && 
      domainName && passwordRecoveryDomains && 
      [passwordRecoveryDomains containsObject: domainName]) {
    return [self responseWithStatus: 200
            andJSONRepresentation: result];
  } else if (username && [NSNull null] != username && !passwordRecoveryDomains) {
    return [self responseWithStatus: 200
            andJSONRepresentation: result];
  } else {
    return [self responseWithStatus: 403
            andJSONRepresentation: nil];
  }
}

- (BOOL) isTotpEnabled
{
#if defined(MFA_CONFIG)
  return YES;
#else
  return NO;
#endif
}


- (NSString *)motd
{
  return [[SOGoAdmin sharedInstance] getMotd];
}

- (NSString *)motdEscaped
{
  return [[[SOGoAdmin sharedInstance] getMotd] removeHTMLTagsExceptAnchorTags];
}

- (BOOL)hasMotd
{
  return [[SOGoAdmin sharedInstance] getMotd] && [[[SOGoAdmin sharedInstance] getMotd] length] > 1;
}

- (BOOL) hasUrlCreateAccount
{
  return ([[SOGoSystemDefaults sharedSystemDefaults]
                              urlCreateAccount] != nil);
}

- (NSString *) urlCreateAccount
{
  return [[SOGoSystemDefaults sharedSystemDefaults]
                              urlCreateAccount];
}

@end /* SOGoRootPage */
