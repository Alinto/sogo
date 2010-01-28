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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSURL.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOCookie.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoCASSession.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoWebAuthenticator.h>

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

  auth = [[WOApplication application]
	   authenticatorInContext: context];
  request = [context request];
  username = [request formValueForKey: @"userName"];
  password = [request formValueForKey: @"password"];
  language = [request formValueForKey: @"language"];
  if ([auth checkLogin: username password: password])
    {
      [self logWithFormat: @"successful login for user '%@'", username];
      response = [self responseWith204];
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
      [self logWithFormat: @"failed login for user '%@'", username];
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
  WOCookie *casCookie;

  casCookie = nil;

  login = [[context activeUser] login];
  if ([login isEqualToString: @"anonymous"])
    login = nil;
  if (!login)
    {
      ticket = [[context request] formValueForKey: @"ticket"];
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
            }
        }
    }

  if (login)
    {
      oldLocation = [[self clientObject] baseURLInContext: context];
      newLocation = [NSString stringWithFormat: @"%@%@",
                              oldLocation, [login stringByEscapingURL]];
    }
  else
    newLocation = [SOGoCASSession CASURLWithAction: @"login"
                                     andParameters: [self _casRedirectKeys]];
  response = [self redirectToLocation: newLocation];
  if (casCookie)
    [response addCookie: casCookie];

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
    response = self;

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

@end /* SOGoRootPage */
