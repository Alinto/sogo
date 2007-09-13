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

#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOCookie.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <SoObjects/SOGo/SOGoWebAuthenticator.h>
#import <SoObjects/SOGo/SOGoUser.h>

#import "SOGoRootPage.h"

@implementation SOGoRootPage

- (void) dealloc
{
  [userName release];
  [super dealloc];
}

/* accessors */

- (void) setUserName: (NSString *) _value
{
  ASSIGNCOPY (userName, _value);
}

- (NSString *) userName
{
  return userName;
}

- (NSString *) connectURL
{
  return [NSString stringWithFormat: @"%@connect", [self applicationPath]];
}

/* actions */
- (id <WOActionResults>) connectAction
{
  WOResponse *response;
  WOCookie *authCookie;
  SOGoWebAuthenticator *auth;
  NSString *cookieValue, *cookieString;

  auth = [[WOApplication application]
	   authenticatorInContext: context];
  response = [self responseWith204];
  cookieString = [NSString stringWithFormat: @"%@:%@",
			   [self queryParameterForKey: @"userName"],
			   [self queryParameterForKey: @"password"]];
  cookieValue = [NSString stringWithFormat: @"basic%@",
			  [cookieString stringByEncodingBase64]];
  authCookie = [WOCookie cookieWithName: [auth cookieNameInContext: context]
			 value: cookieValue];
  [authCookie setPath: @"/"];
  [response addCookie: authCookie];

  return response;
}

- (id <WOActionResults>) defaultAction
{
  id <WOActionResults> response;
  NSString *login, *oldLocation;

  login = [[context activeUser] login];
  if ([login isEqualToString: @"anonymous"])
    response = self;
  else
    {
      oldLocation = [[self clientObject] baseURLInContext: context];
      response
	= [self redirectToLocation: [NSString stringWithFormat: @"%@/%@",
					      oldLocation, login]];
    }

  return response;
}

- (BOOL) isPublicInContext: (WOContext *) localContext
{
  return YES;
}

@end /* SOGoRootPage */
