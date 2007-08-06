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

#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/SoComponent.h>
#import <NGObjWeb/SoObject.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <SOGo/SOGoAuthenticator.h>
#import <SOGo/SOGoUser.h>

@interface SOGoRootPage : SoComponent
{
  NSString *userName;
}

@end

@implementation SOGoRootPage

static BOOL doNotRedirect = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  if ((doNotRedirect = [ud boolForKey:@"SOGoDoNotRedirectRootPage"]))
    NSLog(@"SOGoRootPage: home-page redirect is disabled.");
}

- (void)dealloc {
  [self->userName release];
  [super dealloc];
}

/* accessors */

- (void)setUserName:(NSString *)_value {
  ASSIGNCOPY(self->userName, _value);
}
- (NSString *)userName {
  return self->userName;
}

/* actions */

- (id)connectAction {
  NSString *url;
  
  [self takeFormValuesForKeys:@"userName", nil];
  
  if ([[self userName] length] == 0)
    return nil;
  
  url = [@"/" stringByAppendingString:[[self userName] stringByEscapingURL]];
  if (![url hasSuffix:@"/"])
    url = [url stringByAppendingString:@"/"];
  
  url = [[self context] urlWithRequestHandlerKey:@"so" 
			path:url queryString:nil];
  return [self redirectToLocation:url];
}

- (id<WOActionResults>)defaultAction {
  WOResponse *r;
  NSString *login, *rhk;
  id auth, user;
  id home, base;

  if (doNotRedirect)
    return self;
  
  /* 
     Note: ctx.activeUser is NOT set here. Don't know why, so we retrieve
           the user from the authenticator.
  */
  
  auth  = [[self clientObject] authenticatorInContext:[self context]];
  user  = [auth userInContext:[self context]];
  login = [user login];
  
  if ([login isEqualToString:@"anonymous"]) {
    /* use root page for unauthenticated users */
    return self;
  }

  /* check base */
  
  base = [self application];
  rhk = [[[self context] request] requestHandlerKey];
  if (([rhk length] == 0) || ([base requestHandlerForKey:rhk] == nil)) {
    base = [base lookupName:@"so" inContext:[self context] acquire:NO];
    
    if (![base isNotNull] || [base isKindOfClass:[NSException class]]) {
      /* use root page if home could not be found */
      [self errorWithFormat:@"Did not find 'so' request handler!"];
      return self;
    }
  }
  
  /* lookup home-page */

  home = [base lookupName:login inContext:[self context] acquire:NO];
  if (![home isNotNull] || [home isKindOfClass:[NSException class]]) {
    /* use root page if home could not be found */
    return self;
  }
  
  /* redirect to home-page */
  
  r = [[self context] response];
  [r setStatus:302 /* moved */];
  [r setHeader:[home baseURLInContext:[self context]] forKey:@"location"];
  return r;
}

/* response generation */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *rhk;

  // TODO: we might also want to look into the HTTP basic-auth to redirect to
  //       the login URL!
  
  rhk = [[_ctx request] requestHandlerKey];
  if ([rhk length]==0 || [[self application] requestHandlerForKey:rhk]==nil) {
    /* a small hack to redirect to a valid URL */
    NSString *url;
    
    url = [_ctx urlWithRequestHandlerKey:@"so" path:@"/" queryString:nil];
    [_response setStatus:302 /* moved */];
    [_response setHeader:url forKey:@"location"];
    [self logWithFormat:@"URL: %@", url];
    return;
  }
  
  [super appendToResponse:_response inContext:_ctx];
}

@end /* SOGoRootPage */
