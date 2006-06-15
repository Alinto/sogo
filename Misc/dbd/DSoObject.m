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
// $Id: DSoObject.m 46 2004-06-17 01:23:37Z helge $

#include "DSoObject.h"
#include "common.h"
#include <NGObjWeb/SoHTTPAuthenticator.h>
#include <GDLAccess/GDLAccess.h>

@implementation DSoObject

- (void)dealloc {
  [super dealloc];
}

/* common methods */

- (NSString *)defaultDatabase {
  /* template1 is supposed to exist always (#postgresql channel ;-) */
  return @"template1";
}

- (EOAdaptor *)adaptorForHostName:(NSString *)_hname port:(int)_port
  databaseName:(NSString *)_dbname inContext:(WOContext *)_ctx
{
  EOAdaptor    *adaptor;
  NSDictionary *condict;
  NSString     *login = nil, *pwd = nil, *auth;
  NSArray      *creds;
  
  if ((adaptor = [EOAdaptor adaptorWithName:@"PostgreSQL72"]) == nil) {
    [self logWithFormat:@"missing PostgreSQL72 adaptor"];
    return nil;
  }
  
  /* extract login/password */

  if ((auth = [[_ctx request] headerForKey:@"authorization"]) == nil) {
    [self logWithFormat:@"missing 'authorization' .."];
    return nil;
  }
  creds = [SoHTTPAuthenticator parseCredentials:auth];
  if ([creds count] < 2) {
    [self logWithFormat:@"cannot use credentials: %@", creds];
    return nil;
  }
  login = [creds objectAtIndex:0];
  pwd   = [creds objectAtIndex:1];
  
  /* create adaptor */
  
  _dbname = [_dbname isNotNull] ? _dbname : [self defaultDatabase];
  
  // TODO: ignores port
  condict = [[NSDictionary alloc] initWithObjectsAndKeys:
				    _hname,  @"hostName",
				    login,   @"userName",
				    pwd,     @"password",
				    _dbname, @"databaseName",
				  nil];
  [adaptor setConnectionDictionary:condict];
  [condict release];
  return adaptor;
}

#if 0
- (id)GETAction:(id)_ctx {
  /* per default, return nothing ... */
  WOResponse *r = [(WOContext *)_ctx response];
  NSString   *defName;
  
  if ((defName = [self defaultMethodNameInContext:_ctx])) {
    [r setStatus:302 /* moved */];
    [r setHeader:[[self baseURL] stringByAppendingPathComponent:defName]
       forKey:@"location"];
    return r;
  }
  
  [r setStatus:200 /* Ok */];
  [self logWithFormat:@"GET on folder, just saying OK"];
  return r;
}
#endif

/* OSX hack */

- (id)valueForUndefinedKey:(NSString *)_key {
  [self debugWithFormat:@"queried undefined key: '%@'", _key];
  return nil;
}

- (BOOL)isCollection {
  return YES;
}

@end /* DSoObject */
