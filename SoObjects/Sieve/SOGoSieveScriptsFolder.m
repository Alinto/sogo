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

#include "SOGoSieveScriptsFolder.h"
#include <NGImap4/NGSieveClient.h>
#include "common.h"

@implementation SOGoSieveScriptsFolder

- (void)dealloc {
  [self->listedScripts release];
  [super dealloc];
}

/* listing */

- (NSDictionary *)fetchScripts {
  if (self->listedScripts != nil)
    return self->listedScripts;
  
  self->listedScripts = [[[self sieveClient] listScripts] copy];
  return self->listedScripts;
}

/* standard methods */

- (NSArray *)toOneRelationshipKeys {
  return [[self fetchScripts] allKeys];
}

/* operations */

- (NSException *)activateScript:(NSString *)_name {
  NSDictionary *res;
  NSString *r;
  
  res = [[self sieveClient] setActiveScript:_name];
  if ([[res valueForKey:@"result"] boolValue])
    return nil;

  // TODO: make it a debug log
  [self logWithFormat:@"sieve activate failed: %@", res];
  
  r = [@"Script activation failed: " 
	stringByAppendingString:[res description]];
  return [NSException exceptionWithHTTPStatus:500 /* Server Error */
		      reason:r];
}

/* name lookup */

- (NSString *)lookupScript:(NSString *)_key inContext:(id)_ctx {
  Class clazz;
  
  clazz = NSClassFromString(@"SOGoSieveScriptObject");
  return [[[clazz alloc] initWithName:_key inContainer:self] autorelease];
}

- (id)lookupName:(NSString *)_key inContext:(id)_ctx acquire:(BOOL)_flag {
  id obj;
  
  /* first check attributes directly bound to the object */
  if ((obj = [super lookupName:_key inContext:_ctx acquire:NO]))
    return obj;
  
  /* lookup script */
  if ((obj = [self lookupScript:_key inContext:_ctx]))
    return obj;
  
  /* return 404 to stop acquisition */
  return [NSException exceptionWithHTTPStatus:404 /* Not Found */];
}

/* folder type */

- (NSString *)outlookFolderClass {
  return @"IPF.Filter";
}

@end /* SOGoSieveScriptsFolder */
