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
// $Id: DSoTable.m 54 2004-06-21 12:40:06Z helge $

#include "DSoTable.h"
#include "DSoDatabase.h"
#include "common.h"

@implementation DSoTable

- (id)initWithName:(NSString *)_name inContainer:(id)_container {
  if ((self = [super init])) {
    self->tableName = [_name      copy];
    self->database  = [_container retain];
  }
  return self;
}

- (void)dealloc {
  [self->database  release];
  [self->tableName release];
  [super dealloc];
}

/* accessors */

- (DSoDatabase *)database {
  return self->database;
}
- (NSString *)tableName {
  return self->tableName;
}

- (NSString *)hostName {
  return [[self database] hostName];
}
- (int)port {
  return [[self database] port];
}
- (NSString *)databaseName {
  return [[self database] databaseName];
}

- (id)container {
  return [self database];
}
- (NSString *)nameInContainer {
  return [self tableName];
}

/* support */

- (EOAdaptor *)adaptorInContext:(WOContext *)_ctx {
  return [self->database adaptorInContext:_ctx];
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

  // here we need to differentiate between entry-ids and field names
  // TODO
  return nil;
}

@end /* DSoTable */
