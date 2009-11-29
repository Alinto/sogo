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

#import <Foundation/NSException.h>

#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOCookie.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSObject+Logs.h>

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

/* actions */
- (id <WOActionResults>) connectAction
{
  WOResponse *response;
  WORequest *request;
  WOCookie *authCookie;
  SOGoWebAuthenticator *auth;
  SOGoUserDefaults *ud;
  NSString *cookieValue, *cookieString;
  NSString *userName, *password, *language;
  NSArray *supportedLanguages;

  auth = [[WOApplication application]
	   authenticatorInContext: context];
  request = [context request];
  userName = [request formValueForKey: @"userName"];
  password = [request formValueForKey: @"password"];
  language = [request formValueForKey: @"language"];
  if ([auth checkLogin: userName password: password])
    {
      [self logWithFormat: @"successful login for user '%@'", userName];
      response = [self responseWith204];
      cookieString = [NSString stringWithFormat: @"%@:%@",
			       userName, password];
      cookieValue = [NSString stringWithFormat: @"basic %@",
			      [cookieString stringByEncodingBase64]];
      authCookie = [WOCookie cookieWithName: [auth cookieNameInContext: context]
			     value: cookieValue];
      [authCookie setPath: @"/"];
      /* enable this when we have code to determine whether request is HTTPS:
         [authCookie setIsSecure: YES]; */
      [response addCookie: authCookie];

      supportedLanguages = [[SOGoSystemDefaults sharedSystemDefaults]
                             supportedLanguages];
      if (language && [supportedLanguages containsObject: language])
	{
	  ud = [[SOGoUser userWithLogin: userName roles: nil]
                           userDefaults];
	  [ud setLanguage: language];
	  [ud synchronize];
	}
    }
  else
    {
      [self logWithFormat: @"failed login for user '%@'", userName];
      response = [self responseWithStatus: 403];
    }

  return response;
}

- (id <WOActionResults>) defaultAction
{
  id <WOActionResults> response;
  NSString *login, *oldLocation;

  login = [[context activeUser] login];
  if (!login || [login isEqualToString: @"anonymous"])
    response = self;
  else
    {
      oldLocation = [[self clientObject] baseURLInContext: context];
      response
	= [self redirectToLocation: [NSString stringWithFormat: @"%@/%@",
					      oldLocation,
                                              [login stringByEscapingURL]]];
    }

  return response;
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
