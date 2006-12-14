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

#include <NGObjWeb/SoApplication.h>

@interface SOGo : SoApplication
{
    NSMutableDictionary *localeLUT;
}

- (NSDictionary *) currentLocaleConsideringLanguages:(NSArray *)_langs;
- (NSDictionary *) localeForLanguageNamed:(NSString *)_name;

@end

#include "SOGoProductLoader.h"
#include <WEExtensions/WEResourceManager.h>
#include <SOGo/SOGoAuthenticator.h>
#include <SOGo/SOGoUserFolder.h>
#include <SOGo/SOGoPermissions.h>
#include "common.h"

@implementation SOGo

static unsigned int vMemSizeLimit = 0;
static BOOL doCrashOnSessionCreate = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  SoClassSecurityInfo *sInfo;
  NSArray *basicRoles;
  id tmp;
  
  doCrashOnSessionCreate = [ud boolForKey:@"SOGoCrashOnSessionCreate"];

  /* vMem size check - default is 200MB */
    
  tmp = [ud objectForKey:@"SxVMemLimit"];
  vMemSizeLimit = (tmp != nil)
    ? [tmp intValue]
    : 200;
  if (vMemSizeLimit > 0) {
    NSLog(@"Note: vmem size check enabled: shutting down app when "
	  @"vmem > %d MB", vMemSizeLimit);
  }
#if LIB_FOUNDATION_LIBRARY
  if ([ud boolForKey:@"SOGoEnableDoubleReleaseCheck"])
    [NSAutoreleasePool enableDoubleReleaseCheck:YES];
#endif

  /* SoClass security declarations */
  sInfo = [self soClassSecurityInfo];
  /* require View permission to access the root (bound to authenticated ...) */
  [sInfo declareObjectProtected: SoPerm_View];

  /* to allow public access to all contained objects (subkeys) */
  [sInfo setDefaultAccess: @"allow"];

  basicRoles = [NSArray arrayWithObjects: SoRole_Authenticated,
                        SOGoRole_FreeBusy, nil];

  /* require Authenticated role for View and WebDAV */
  [sInfo declareRoles: basicRoles asDefaultForPermission: SoPerm_View];
  [sInfo declareRoles: basicRoles asDefaultForPermission: SoPerm_WebDAVAccess];
}

- (id)init {
  if ((self = [super init])) {
    WOResourceManager *rm;
    
    /* ensure core SoClass'es are setup */
    [NSClassFromString(@"SOGoObject")        soClass];
    [NSClassFromString(@"SOGoContentObject") soClass];
    [NSClassFromString(@"SOGoFolder")        soClass];
    
    /* setup locale cache */
    self->localeLUT = [[NSMutableDictionary alloc] initWithCapacity:2];
    
    /* load products */
    [[SOGoProductLoader productLoader] loadProducts];
    
    /* setup resource manager */
    rm = [[WEResourceManager alloc] init];
    [self setResourceManager:rm];
  }
  return self;
}

- (void)dealloc {
  [self->localeLUT release];
  [super dealloc];
}

/* authenticator */

- (id)authenticatorInContext:(id)_ctx {
  return [$(@"SOGoAuthenticator") sharedSOGoAuthenticator];
}

/* name lookup */

- (BOOL)isUserName:(NSString *)_key inContext:(id)_ctx {
  if ([_key length] < 1)
    return NO;
  
  if (isdigit([_key characterAtIndex:0]))
    return NO;

  return YES;
}

- (id)lookupUser:(NSString *)_key inContext:(id)_ctx {
  NSLog (@"lookupUser: %@", _key);
  return [[[NSClassFromString(@"SOGoUserFolder") alloc] 
	    initWithName:_key inContainer:self] autorelease];
}

- (void)_setupLocaleInContext:(WOContext *)_ctx {
  NSArray      *langs;
  NSDictionary *locale;
  
  if ([[_ctx valueForKey:@"locale"] isNotNull])
    return;

  langs = [[(WOContext *)_ctx request] browserLanguages];
  locale = [self currentLocaleConsideringLanguages:langs];
  [_ctx takeValue:locale forKey:@"locale"];
}

- (id)lookupName:(NSString *)_key inContext:(id)_ctx acquire:(BOOL)_flag {
  id obj;

  /* put locale info into the context in case it's not there */
  [self _setupLocaleInContext:_ctx];
  
  /* first check attributes directly bound to the application */
  if ((obj = [super lookupName:_key inContext:_ctx acquire:_flag]))
    return obj;
  
  /* 
     The problem is, that at this point we still get request for resources,
     eg 'favicon.ico'.
     
     Addition: we also get queries for various other methods, like "GET" if
               no method was provided in the query path.
  */
  
  if ([_key isEqualToString:@"favicon.ico"])
    return nil;

  if ([self isUserName:_key inContext:_ctx])
    return [self lookupUser:_key inContext:_ctx];
  
  return nil;
}

/* WebDAV */

- (NSString *)davDisplayName {
  /* this is used in the UI, eg in the navigation */
  return @"SOGo";
}

/* exception handling */

- (WOResponse *)handleException:(NSException *)_exc
  inContext:(WOContext *)_ctx
{
  printf("EXCEPTION: %s\n", [[_exc description] cString]);
  abort();
}

/* runtime maintenance */

- (void)checkIfDaemonHasToBeShutdown {
  unsigned int limit, vmem;
  
  if ((limit = vMemSizeLimit) == 0)
    return;

  vmem = [[NSProcessInfo processInfo] virtualMemorySize]/1048576;

  if (vmem > limit) {
    [self logWithFormat:
          @"terminating app, vMem size limit (%d MB) has been reached"
          @" (currently %d MB)",
          limit, vmem];
    [self terminate];
  }
}

- (WOResponse *)dispatchRequest:(WORequest *)_request {
  static NSArray *runLoopModes = nil;
  WOResponse *resp;

  resp = [super dispatchRequest:_request];

  if ([self isTerminating])
    return resp;

  if (runLoopModes == nil)
    runLoopModes = [[NSArray alloc] initWithObjects:NSDefaultRunLoopMode, nil];
  
  // TODO: a bit complicated? (-perform:afterDelay: doesn't work?)
  [[NSRunLoop currentRunLoop] performSelector:
				@selector(checkIfDaemonHasToBeShutdown)
			      target:self argument:nil
			      order:1 modes:runLoopModes];
  return resp;
}

/* session management */

- (id)createSessionForRequest:(WORequest *)_request {
  [self warnWithFormat:@"session creation requested!"];
  if (doCrashOnSessionCreate)
    abort();
  return [super createSessionForRequest:_request];
}

/* localization */

- (NSDictionary *)currentLocaleConsideringLanguages:(NSArray *)_langs {
  unsigned i, count;

  /* assume _langs is ordered by priority */
  count = [_langs count];
  for (i = 0; i < count; i++) {
    NSString     *lname;
    NSDictionary *locale;
    
    lname  = [_langs objectAtIndex:i];
    locale = [self localeForLanguageNamed:lname];
    if (locale != nil)
      return locale;
  }
  /* no appropriate language, fallback to default */
  return [self localeForLanguageNamed:@"English"];
}

- (NSString *)pathToLocaleForLanguageNamed:(NSString *)_name {
  static Class MainProduct = Nil;
  NSString *lpath;

  lpath = [[self resourceManager] pathForResourceNamed:@"Locale"
				  inFramework:nil
				  languages:[NSArray arrayWithObject:_name]];
  if ([lpath isNotNull])
    return lpath;
  
  if (MainProduct == Nil) {
    if ((MainProduct = NSClassFromString(@"MainUIProduct")) == Nil)
      [self errorWithFormat:@"did not find MainUIProduct class!"];
  }
  
  lpath = [(id)MainProduct pathToLocaleForLanguageNamed:_name];
  if ([lpath isNotNull])
    return lpath;
  
  return nil;
}

- (NSDictionary *)localeForLanguageNamed:(NSString *)_name {
  NSString     *lpath;
  id           data;
  NSDictionary *locale;
  
  if (![_name isNotNull]) {
    [self errorWithFormat:@"%s: name parameter must not be nil!",
	  __PRETTY_FUNCTION__];
    return nil;
  }
  
  if ((locale = [self->localeLUT objectForKey:_name]) != nil)
    return locale;
  
  if ((lpath = [self pathToLocaleForLanguageNamed:_name]) == nil) {
    [self errorWithFormat:@"did not find Locale for language: %@", _name];
    return nil;
  }
  
  if ((data = [NSData dataWithContentsOfFile:lpath]) == nil) {
    [self logWithFormat:@"%s didn't find locale with name:%@",
	  __PRETTY_FUNCTION__,
	  _name];
    return nil;
  }
  data = [[[NSString alloc] initWithData:data
                            encoding:NSUTF8StringEncoding] autorelease];
  locale = [data propertyList];
  if (locale == nil) {
    [self logWithFormat:@"%s couldn't load locale with name:%@",
	  __PRETTY_FUNCTION__,
	  _name];
    return nil;
  }
  [self->localeLUT setObject:locale forKey:_name];
  return locale;
}

/* name (used by the WEResourceManager) */

- (NSString *)name {
  return @"SOGo-0.9";
}

@end /* SOGo */
