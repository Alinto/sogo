/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
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

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSDictionary+BSJSONAdditions.h>
#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoCASSession.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoWebAuthenticator.h>

#import <SOGo/SOGoConstants.h>

#import "SOGoRootPage.h"

@interface SOGoRootPage (crashAdditions)

- (void) segfault;

@end

@implementation SOGoRootPage

/* accessors */

- (NSString *) connectURL
{
  return [NSString stringWithFormat: @"%@/connect", [self applicationPath]];
}

- (WOCookie *) _cookieWithUsername: (NSString *) username
                       andPassword: (NSString *) password
                  forAuthenticator: (SOGoWebAuthenticator *) auth
{
  WOCookie *authCookie;
  NSString *cookieValue, *cookieString, *appName;

  cookieString = [NSString stringWithFormat: @"%@:%@",
                           username, password];
  cookieValue = [NSString stringWithFormat: @"basic %@",
                          [cookieString stringByEncodingBase64]];
  authCookie = [WOCookie cookieWithName: [auth cookieNameInContext: context]
                                  value: cookieValue];
  appName = [[context request] applicationName];
  [authCookie setPath: [NSString stringWithFormat: @"/%@/", appName]];
  /* enable this when we have code to determine whether request is HTTPS:
     [authCookie setIsSecure: YES]; */
  
  return authCookie;
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

/* actions */
- (id <WOActionResults>) connectAction
{
  WOResponse *response;
  WORequest *request;
  WOCookie *authCookie;
  SOGoWebAuthenticator *auth;
  SOGoUserDefaults *ud;
  NSString *username, *password, *language;
  NSArray *supportedLanguages;
  
  SOGoPasswordPolicyError err;
  int expire, grace;
  BOOL b;
  
  err = PolicyNoError;
  expire = grace = 0;
  
  auth = [[WOApplication application]
	    authenticatorInContext: context];
  request = [context request];
  username = [request formValueForKey: @"userName"];
  password = [request formValueForKey: @"password"];
  language = [request formValueForKey: @"language"];
  
  if ((b = [auth checkLogin: username 
		 password: password
		 perr: &err
		 expire: &expire
		 grace: &grace])
      && (err == PolicyNoError || err == PolicyChangeAfterReset))
    {
      [self logWithFormat: @"successful login for user '%@'", username];
      response = [self responseWith204];

      // We must warn the user that he has to change his password
      if (err == PolicyChangeAfterReset)
	{
	  
	}

      authCookie = [self _cookieWithUsername: username andPassword: password
                            forAuthenticator: auth];
      [response addCookie: authCookie];

      supportedLanguages = [[SOGoSystemDefaults sharedSystemDefaults]
                             supportedLanguages];
      if (language && [supportedLanguages containsObject: language])
	{
	  ud = [[SOGoUser userWithLogin: username] userDefaults];
	  [ud setLanguage: language];
	  [ud synchronize];
	}
    }
  else
    {
      [self logWithFormat: @"Login for user '%@' might not have worked - password policy: %d  bound: ", username, err, b];
      
      if (err == PolicyNoError)
	{
	  [self logWithFormat: @"failed login for user '%@' due to wrong password", username];
	}
      else if (err == PolicyAccountLocked)
	{
	  // Account has been locked due to too many failures
	}
      else if (err == PolicyPasswordExpired)
	{
	  // The password MUST be changed - we need to ask for the old password and the new one here
	}
      
      response = [self responseWithStatus: 403];
    }

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
          casSession = [SOGoCASSession CASSessionWithTicket: ticket];
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

- (id <WOActionResults>) crashAction
{
  [self segfault];

  return nil;
}

- (id <WOActionResults>) exceptionAction
{
  return (id <WOActionResults>)
    [NSException exceptionWithName: @"ExceptionAction"
		 reason: @"This exception is brought to you by SOGo"
		 userInfo: nil];
}

- (id <WOActionResults>) raisedExceptionAction
{
  [NSException raise: @"ExceptionAction"
	       format: @"This exception is brought to you by SOGo"];

  return nil;
}

- (NSString *) loginSuffix
{
  return [[SOGoSystemDefaults sharedSystemDefaults] loginSuffix];
}

- (BOOL) hasLoginSuffix
{
  return ([[self loginSuffix] length]);
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

// - (NSString *) language
// {
//   return [SOGoUser language];
// }

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
  NSString *username, *password, *newPassword;
  SOGoUserManager *um;
  SOGoPasswordPolicyError error;
  WOResponse *response;
  WORequest *request;
  NSDictionary *message, *jsonError;

  request = [context request];
  message = [NSMutableDictionary dictionaryWithJSONString: [request contentAsString]];
  username = [message objectForKey: @"userName"];
  password = [message objectForKey: @"password"];
  newPassword = [message objectForKey: @"newPassword"];

  um = [SOGoUserManager sharedUserManager];

  // This will also update the cached password in memcached.
  if ([um changePasswordForLogin: username
	  oldPassword: password
	  newPassword: newPassword
	  perr: &error])
    response = [self responseWith204];
  else
    {
      jsonError
	= [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: error]
			forKey: @"LDAPPasswordPolicyError"];
      response = [self responseWithStatus: 403
		       andJSONRepresentation: jsonError];
      [response setHeader: @"application/json"
		forKey: @"content-type"];
    }

  return response;
}

@end /* SOGoRootPage */
