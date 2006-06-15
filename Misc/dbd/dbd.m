/*
  Copyright (C) 2004 SKYRIX Software AG

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
// $Id: dbd.m 40 2004-06-16 15:28:47Z helge $

#include <NGObjWeb/SoApplication.h>

@interface DBDaemon : SoApplication
{
}

@end

#include "DSoHost.h"
#include "common.h"

@implementation DBDaemon

- (id)init {
  if ((self = [super init])) {
  }
  return self;
}

/* name lookup */

- (BOOL)isHostName:(NSString *)_key inContext:(id)_ctx {
  NSRange r;
  
  r = [_key rangeOfString:@"."]; // TODO: this also catches IPs!
  if (r.length > 0)
    return NO;
  
  return YES;
}

- (id)lookupHost:(NSString *)_key inContext:(id)_ctx {
  NSRange  r;
  NSString *hostName;
  int      port;
  
  r = [_key rangeOfString:@":"];
  if (r.length == 0) {
    hostName = _key;
    port = 5432;
  }
  else {
    hostName = [_key substringToIndex:r.location];
    port = [[_key substringFromIndex:(r.location + r.length)] intValue];
  }
  return [DSoHost dHostWithName:hostName port:port];
}

- (id)lookupName:(NSString *)_key inContext:(id)_ctx acquire:(BOOL)_flag {
  id obj;
  
  /* first check attributes directly bound to the application */
  if ((obj = [super lookupName:_key inContext:_ctx acquire:_flag]))
    return obj;
  
  /* 
     The problem is, that at this point we still get request for resources,
     eg 'favicon.ico'.
     The hack here is to check for a dot in the key, but we should find a way
     to catch that in a more sensible way.
     
     One way to check for a valid key would be to check whether the key is a
     valid hostname, but I would like to avoid that for performance reasons.
     
     Addition: we also get queries for various other methods, like "GET" if
               no method was provided in the query path.
  */
  if ([self isHostName:_key inContext:_ctx])
    return [self lookupHost:_key inContext:_ctx];
  
  return nil;
}

/* exception handling */

- (WOResponse *)handleException:(NSException *)_exc
  inContext:(WOContext *)_ctx
{
  printf("EXCEPTION: %s\n", [[_exc description] cString]);
  abort();
}

@end /* DBDaemon */


int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;

  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  [NGBundleManager defaultBundleManager];
  
  WOWatchDogApplicationMain(@"DBDaemon", argc, (void*)argv);

  [pool release];
  return 0;
}
