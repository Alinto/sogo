/*

  Copyright (C) 2006-2011 Inverse inc. 
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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOCookie.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <Appointments/SOGoAppointmentFolders.h>

#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoCASSession.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoWebAuthenticator.h>
#import <SOGo/SOGoSession.h>
#import <SOGo/SOGoConstants.h>

#import "SOGoRootPage.h"

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

- (NSString *) connectURL
{
  return [NSString stringWithFormat: @"%@/connect", [self applicationPath]];
}

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
                       andPassword: (NSString *) password
                  forAuthenticator: (SOGoWebAuthenticator *) auth
{
  WOCookie *authCookie;
  NSString *cookieValue, *cookieString, *appName, *sessionKey, *userKey, *securedPassword;

  //
  // We create a new cookie - thus we create a new session
  // associated to the user. For security, we generate:
  //
  // A- a session key
  // B- a user key
  //
  // In memcached, the session key will be associated to the user's password
  // which will be XOR'ed with the user key.
  //
  sessionKey = [SOGoSession generateKeyForLength: 16];
  userKey = [SOGoSession generateKeyForLength: 64];

  NSString *value = [NSString stringWithFormat: @"%@:%@", username, password];
  securedPassword = [SOGoSession securedValue: value  usingKey: userKey];


  [SOGoSession setValue: securedPassword  forSessionKey: sessionKey];

  //cookieString = [NSString stringWithFormat: @"%@:%@",
  //                         username, password];
  cookieString = [NSString stringWithFormat: @"%@:%@",
                           userKey, sessionKey];
  cookieValue = [NSString stringWithFormat: @"basic %@",
                          [cookieString stringByEncodingBase64]];
  authCookie = [WOCookie cookieWithName: [auth cookieNameInContext: context]
                                  value: cookieValue];
  appName = [[context request] applicationName];
  [authCookie setPath: [NSString stringWithFormat: @"/%@/", appName]];
  
  return authCookie;
}

- (WOCookie *) _cookieWithUsername: (NSString *) username
{
  WOCookie *loginCookie;
  NSString *appName;
  NSCalendarDate *date;

  appName = [[context request] applicationName];
  date = [NSCalendarDate calendarDate];
  [date setTimeZone: [NSTimeZone timeZoneWithAbbreviation: @"GMT"]];
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

- (WOCookie *) _casLocationCookie: (BOOL) cookieReset
{
  WOCookie *locationCookie;
  NSString *appName;
  WORequest *rq;
  NSCalendarDate *date;

  rq = [context request];
  locationCookie = [WOCookie cookieWithName: @"cas-location" value: [rq uri]];
  appName = [rq applicationName];
  [locationCookie setPath: [NSString stringWithFormat: @"/%@/", appName]];
  if (cookieReset)
    {
      date = [NSCalendarDate calendarDate];
      [date setTimeZone: [NSTimeZone timeZoneWithAbbreviation: @"GMT"]];
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

  jsonError
    = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: error]
                                  forKey: @"LDAPPasswordPolicyError"];
  return [self responseWithStatus: 403
            andJSONRepresentation: jsonError];
}

- (id <WOActionResults>) connectAction
{
  WOResponse *response;
  WORequest *request;
  WOCookie *authCookie;
  SOGoWebAuthenticator *auth;
  SOGoAppointmentFolders *calendars;
  SOGoUserDefaults *ud;
  SOGoSystemDefaults *sd;
  SOGoUser *loggedInUser;
  NSString *username, *password, *language, *domain;
  NSArray *supportedLanguages;
  
  SOGoPasswordPolicyError err;
  int expire, grace;
  BOOL rememberLogin, b;
  
  err = PolicyNoError;
  expire = grace = -1;
  
  auth = [[WOApplication application]
	    authenticatorInContext: context];
  request = [context request];
  username = [request formValueForKey: @"userName"];
  password = [request formValueForKey: @"password"];
  language = [request formValueForKey: @"language"];
  rememberLogin = [[request formValueForKey: @"rememberLogin"] boolValue];
  domain = [request formValueForKey: @"domain"];
  
  if ((b = [auth checkLogin: username password: password domain: &domain
		 perr: &err expire: &expire grace: &grace])
      && (err == PolicyNoError)  
      // no password policy
      && ((expire < 0 && grace < 0)     // no password policy or everything is alright
      || (expire < 0 && grace > 0)      // password expired, grace still permits login
      || (expire >= 0 && grace == -1))) // password about to expire OR ppolicy activated and passwd never changed
    {
      NSDictionary *json;

      [self logWithFormat: @"successful login for user '%@' - expire = %d  grace = %d", username, expire, grace];
      
      json = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt: expire], @"expire",
                                [NSNumber numberWithInt: grace], @"grace", nil];
      
      response = [self responseWithStatus: 200
		       andJSONRepresentation: json];
      
      if ([domain isNotNull])
        {
          sd = [SOGoSystemDefaults sharedSystemDefaults];
          if ([sd enableDomainBasedUID])
            username = [NSString stringWithFormat: @"%@@%@", username, domain];
        }

      authCookie = [self _cookieWithUsername: username
                                 andPassword: password
                            forAuthenticator: auth];
      [response addCookie: authCookie];

      supportedLanguages = [[SOGoSystemDefaults sharedSystemDefaults]
                             supportedLanguages];
      loggedInUser = [SOGoUser userWithLogin: username];
      [context setActiveUser: loggedInUser];
      if (language && [supportedLanguages containsObject: language])
	{
	  ud = [loggedInUser userDefaults];
	  [ud setLanguage: language];
	  [ud synchronize];
	}

      calendars = [loggedInUser calendarsFolderInContext: context];
      if ([calendars respondsToSelector: @selector (reloadWebCalendars:)])
        [calendars reloadWebCalendars: NO];
    }
  else
    {
      [self logWithFormat: @"Login for user '%@' might not have worked - password policy: %d  grace: %d  expire: %d  bound: %d", username, err, grace, expire, b];

      response = [self _responseWithLDAPPolicyError: err];
    }

  if (rememberLogin)
    [response addCookie: [self _cookieWithUsername: username]];
  else
    [response addCookie: [self _cookieWithUsername: nil]];

  return response;
}

- (NSDictionary *) _casRedirectKeys
{
  NSDictionary *redirectKeys;
  NSURL *soURL;

  soURL = [[WOApplication application] soURL];

  redirectKeys = [NSDictionary dictionaryWithObject: [soURL absoluteString]
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
  NSString *login, *newLocation, *oldLocation, *ticket;
  SOGoCASSession *casSession;
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
              casCookie = [self _cookieWithUsername: login
                                        andPassword: [casSession identifier]
                                   forAuthenticator: auth];
              [casSession updateCache];
              newLocation = [rq cookieValueForKey: @"cas-location"];
              /* login callback, we expire the "cas-location" cookie, created
                 below */
              casLocationCookie = [self _casLocationCookie: YES];
            }
        }
    }
  else
    ticket = nil;

  if (login)
    {
      /* We redirect the user to his "homepage" when newLocation could not be
         deduced from the "cas-location" cookie and the current action is not a
         login callback (ticket != nil).  */
      if (!newLocation || !ticket)
        {
          oldLocation = [[self clientObject] baseURLInContext: context];
          newLocation = [NSString stringWithFormat: @"%@%@",
                                  oldLocation, [login stringByEscapingURL]];
        }
    }
  else
    {
      newLocation
        = [SOGoCASSession CASURLWithAction: @"login"
                             andParameters: [self _casRedirectKeys]];
      casLocationCookie = [self _casLocationCookie: NO];
    }
  response = [self redirectToLocation: newLocation];
  if (casCookie)
    [response addCookie: casCookie];
  if (casLocationCookie)
    [response addCookie: casLocationCookie];

  return response;
}

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
                                              [login stringByEscapingURL]]];
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
  SOGoSystemDefaults *sd;

  sd = [SOGoSystemDefaults sharedSystemDefaults];

  return ([[sd authenticationType] isEqualToString: @"cas"]
          ? [self _casDefaultAction]
          : [self _standardDefaultAction]);
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

- (void) setItem: (id) _item
{
  ASSIGN (item, _item);
}

- (id) item
{
  return item;
}

- (NSArray *) languages
{
  return [[SOGoSystemDefaults sharedSystemDefaults] supportedLanguages];
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

  aString = [NSString stringWithFormat: @"%d.%d.%d",
		      SOGO_MAJOR_VERSION,
		      SOGO_MINOR_VERSION,
		      SOGO_SUBMINOR_VERSION];

  return aString;
}

- (WOResponse *) changePasswordAction
{
  NSString *username, *domain, *password, *newPassword, *value;
  NSDictionary *message;
  WOCookie *authCookie;
  NSArray *creds;
  SOGoUserManager *um;
  SOGoPasswordPolicyError error;
  SOGoSystemDefaults *sd;
  SOGoWebAuthenticator *auth;
  WOResponse *response;
  WORequest *request;

  request = [context request];
  message = [[request contentAsString] objectFromJSONString];
  
  auth = [[WOApplication application]
	   authenticatorInContext: context];
  value = [[context request]
           cookieValueForKey: [auth cookieNameInContext: context]];
  creds = [auth parseCredentials: value];

  [SOGoSession decodeValue: [SOGoSession valueForSessionKey: [creds objectAtIndex: 1]]
                  usingKey: [creds objectAtIndex: 0]
                     login: &username
                    domain: &domain
                  password: &password];

  newPassword = [message objectForKey: @"newPassword"];

  um = [SOGoUserManager sharedUserManager];

  // This will also update the cached password in memcached.
  if ([um changePasswordForLogin: username
                        inDomain: domain
                     oldPassword: password
                     newPassword: newPassword
                            perr: &error])
    {
      // We delete the previous session
      [SOGoSession deleteValueForSessionKey: [creds objectAtIndex: 1]]; 

      if ([domain isNotNull])
        {
          sd = [SOGoSystemDefaults sharedSystemDefaults];
          if ([sd enableDomainBasedUID])
            username = [NSString stringWithFormat: @"%@@%@", username, domain];
        }
      
      response = [self responseWith204];
      authCookie = [self _cookieWithUsername: username
                                 andPassword: newPassword
                            forAuthenticator: auth];
      [response addCookie: authCookie];
    }
  else
    response = [self _responseWithLDAPPolicyError: error];

  return response;
}

@end /* SOGoRootPage */
