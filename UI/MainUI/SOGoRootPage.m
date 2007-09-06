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
  response = [context response];
  cookieString = [NSString stringWithFormat: @"%@:%@",
			   [self queryParameterForKey: @"userName"],
			   [self queryParameterForKey: @"password"]];
  cookieValue = [NSString stringWithFormat: @"basic%@",
			  [cookieString stringByEncodingBase64]];
  authCookie = [WOCookie cookieWithName: [auth cookieNameInContext: context]
			 value: cookieValue];
  [authCookie setPath: @"/"];
  [response setStatus: 204];
  [response addCookie: authCookie];

  return response;
}

// - (id <WOActionResults>) defaultAction
// {
//   WOResponse *r;
//   NSString *login, *rhk;
//   SOGoWebAuthenticator *auth;
//   SOGoUser *user;
//   SOGoUserFolder *home;
//   WOApplication *base;

//   /* 
//      Note: ctx.activeUser is NOT set here. Don't know why, so we retrieve
//            the user from the authenticator.
//   */
  
//   auth = [[self clientObject] authenticatorInContext: context];
//   user = [auth userInContext: context];
//   login = [user login];

//   if ([login isEqualToString:@"anonymous"]) {
//     /* use root page for unauthenticated users */
//     return self;
//   }

//   /* check base */

//   base = [self application];
//   rhk = [[context request] requestHandlerKey];
//   if (([rhk length] == 0) || ([base requestHandlerForKey:rhk] == nil)) {
//     base = [base lookupName: @"so" inContext: context acquire: NO];
    
//     if (![base isNotNull] || [base isKindOfClass:[NSException class]]) {
//       /* use root page if home could not be found */
//       [self errorWithFormat:@"Did not find 'so' request handler!"];
//       return self;
//     }
//   }
  
//   /* lookup home-page */

//   home = [base lookupName: login inContext: context acquire: NO];
//   if (![home isNotNull] || [home isKindOfClass:[NSException class]]) {
//     /* use root page if home could not be found */
//     return self;
//   }
  
//   /* redirect to home-page */
  
//   r = [context response];
//   [r setStatus: 302 /* moved */];
//   [r setHeader: [home baseURLInContext: context]
//      forKey: @"location"];

//   return r;
// }

/* response generation */

// - (void) appendToResponse: (WOResponse *) response
// 		inContext: (WOContext *) ctx
// {
//   NSString *rhk;

//   // TODO: we might also want to look into the HTTP basic-auth to redirect to
//   //       the login URL!
  
//   rhk = [[ctx request] requestHandlerKey];
//   if ([rhk length] == 0
//       || [[self application] requestHandlerForKey: rhk] == nil)
//     {
//       /* a small hack to redirect to a valid URL */
//       NSString *url;
    
//       url = [ctx urlWithRequestHandlerKey: @"so" path: @"/" queryString: nil];
//       [response setStatus: 302 /* moved */];
//       [response setHeader: url forKey: @"location"];
//       [self logWithFormat: @"URL: %@", url];
//       return;
//     }

//   [response setHeader: @"text/html" forKey: @"content-type"];
//   [super appendToResponse: response inContext: ctx];
// }

- (BOOL) isPublicInContext: (WOContext *) localContext
{
  return YES;
}

@end /* SOGoRootPage */
