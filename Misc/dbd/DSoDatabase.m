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
// $Id: DSoDatabase.m 54 2004-06-21 12:40:06Z helge $

#include "DSoDatabase.h"
#include "DSoTable.h"
#include "DSoAuthenticator.h"
#include "common.h"

// TODO: PG databases do have an owner!
// TODO: PG databases have an ACL

@implementation DSoDatabase

- (id)initWithHostName:(NSString *)_hostname port:(int)_port 
  databaseName:(NSString *)_dbname
{
  if ((self = [super init])) {
    self->hostName     = [_hostname copy];
    self->databaseName = [_dbname copy];
    self->port         = _port > 0 ? _port : 5432;
  }
  return self;
}

- (void)dealloc {
  [self->databaseName release];
  [self->hostName     release];
  [super dealloc];
}

/* accessors */

- (NSString *)hostName {
  return self->hostName;
}
- (int)port {
  return self->port;
}

- (NSString *)databaseName {
  return self->databaseName;
}

// TODO: add baseURL generation

/* support */

- (EOAdaptor *)adaptorInContext:(WOContext *)_ctx {
  return [self adaptorForHostName:[self hostName] port:[self port]
	       databaseName:[self databaseName] inContext:_ctx];
}

/* authentication */

- (id)authenticatorInContext:(id)_ctx {
  return [DSoAuthenticator authenticatorWithHostName:[self hostName]
			   port:[self port] databaseName:[self databaseName]];
}

/* name lookup */

- (id)lookupName:(NSString *)_key inContext:(id)_ctx acquire:(BOOL)_flag {
  id obj;
  
  /* 
     Note: acquire:NO - otherwise acquired stuff will override the stuff
           below!
  */
  if ((obj = [super lookupName:_key inContext:_ctx acquire:NO]))
    return obj;
  
  obj = [[DSoTable alloc] initWithName:_key inContainer:self];
  return [obj autorelease];
}

@end /* DSoDatabase */
