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
// $Id: DSoAuthenticator.m 52 2004-06-21 08:28:13Z helge $

#include "DSoAuthenticator.h"
#include "common.h"
#include <GDLAccess/GDLAccess.h>

/*
  Things to note:
  - authenticators themselves are _not_ bound to a context or a SOPE
    traversal path
    - because of that we need to duplicate some stuff
      => or use a separate layer which handles uniquing
*/

@implementation DSoAuthenticator

static BOOL debugOn = NO;

// TODO: might want to cache authenticator objects ...

- (id)initWithHostName:(NSString *)_hostname port:(int)_port
  databaseName:(NSString *)_dbname
{
  if ((self = [super init])) {
    self->hostname = [_hostname copy];
    self->port     = _port;
    self->dbname   = [_dbname copy];
  }
  return self;
}

+ (id)authenticatorWithHostName:(NSString *)_hostname port:(int)_port {
  return [[[self alloc] initWithHostName:_hostname port:_port 
			databaseName:nil] autorelease];
}
+ (id)authenticatorWithHostName:(NSString *)_hostname port:(int)_port
  databaseName:(NSString *)_dbname
{
  return [[[self alloc] initWithHostName:_hostname port:_port 
			databaseName:_dbname] autorelease];
}

- (void)dealloc {
  [self->hostname release];
  [self->dbname   release];
  [super dealloc];
}

/* realm */

- (NSString *)authRealm {
  /* 
     the HTTP authentication realm, we use the database info (default is the 
     application name, but in our case we can be more specific)
  */
  if (self->dbname == nil)
    return self->hostname;
  
  return [[self->dbname stringByAppendingString:@"@"]
	                stringByAppendingString:self->hostname];
}

/* adaptor setup */

- (NSString *)defaultDatabase {
  /* template1 is supposed to exist always (#postgresql channel ;-) */
  return @"template1";
}

- (EOAdaptor *)adaptorForLogin:(NSString *)_login password:(NSString *)_pwd {
  EOAdaptor    *adaptor;
  NSDictionary *condict;
  NSString     *dbn;
  
  if ((adaptor = [EOAdaptor adaptorWithName:@"PostgreSQL72"]) == nil)
    return nil;

  if (![_login isNotNull]) _login = @"";
  if (![_pwd   isNotNull]) _pwd   = @"";

  dbn = [self->dbname isNotNull] ? self->dbname : [self defaultDatabase];
  
  // TODO: ignores port
  condict = [[NSDictionary alloc] initWithObjectsAndKeys:
				    self->hostname, @"hostName",
				    _login,         @"userName",
				    _pwd,           @"password",
				    dbn,            @"databaseName",
				  nil];
  [adaptor setConnectionDictionary:condict];
  [condict release];
  return adaptor;
}

/* check credentials */

- (BOOL)checkLogin:(NSString *)_login password:(NSString *)_pwd {
  EOAdaptor        *adaptor;
  EOAdaptorContext *adctx;
  EOAdaptorChannel *adch;
  BOOL             ok;
  
  [self debugWithFormat:@"check login: %@", _login];
  
  /* create all necessary objects */
  
  adaptor = [self    adaptorForLogin:_login password:_pwd];
  adctx   = [adaptor createAdaptorContext];
  adch    = [adctx   createAdaptorChannel];
  
  [self debugWithFormat:@"  channel: %@", adch];
  
  /* open channel to check whether credentials are valid */
  
  if ((ok = [adch openChannel]))
    [adch closeChannel];
  else
    [self debugWithFormat:@"could not open the channel."];
  
  return ok;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* DSoAuthenticator */
