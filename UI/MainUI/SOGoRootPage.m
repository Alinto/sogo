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
{
  WOCookie *locationCookie;
  NSString *appName;
  WORequest *rq;
  NSCalendarDate *date;

  rq = [context request];
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
                                                   withName: @"cas-location"];
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
                                           withName: @"cas-location"];
    }
  response = [self redirectToLocation: newLocation];
  if (casCookie)
    [response addCookie: casCookie];
  if (casLocationCookie)
    [response addCookie: casLocationCookie];

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
                                               withName: @"saml2-location"];
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
                                             withName: @"saml2-location"];
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
      response
	= [self redirectToLocation: [NSString stringWithFormat: @"%@%@",
					      oldLocation,
                                              [[SOGoUser getEncryptedUsernameIfNeeded:login request: [context request]] stringByEscapingURL]]];
    }
  else
    {
      oldLocation = [[context request] uri];
      if ([context clientObject]
          && ![oldLocation hasSuffix: @"/"]
          && ![oldLocation hasSuffix: @"/view"])
        response = [self redirectToLocation:
                           [NSString stringWithFormat: @"%@/", oldLocation]];
      else
        response = self;
    }

  return response;
}

- (id <WOActionResults>) defaultAction
{
  NSString *authenticationType;
  id <WOActionResults> result;

  authenticationType = [[SOGoSystemDefaults sharedSystemDefaults]
                         authenticationType];
  if ([authenticationType isEqualToString: @"cas"])
    result = [self _casDefaultAction];
#if defined(SAML2_CONFIG)
  else if ([authenticationType isEqualToString: @"saml2"])
    result = [self _saml2DefaultAction];
#endif /* SAML2_CONFIG */
  else
    result = [self _standardDefaultAction];

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
  if ([[SOGoSystemDefaults sharedSystemDefaults]
                             isPasswordRecoveryEnabled]) {
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

@end /* SOGoRootPage */
