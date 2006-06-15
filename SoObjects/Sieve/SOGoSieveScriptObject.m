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

#include "SOGoSieveScriptObject.h"
#include "SOGoSieveScriptsFolder.h"
#include "common.h"
#include <NGImap4/NGSieveClient.h>

@implementation SOGoSieveScriptObject

/* script */

- (NSString *)fetchScript {
  NGSieveClient *client;
  
  if ((client = [self sieveClient]) == nil)
    return nil;
  
  return [client getScript:[self nameInContainer]];
}

/* content */

- (NSString *)contentAsString {
  return [self fetchScript];
}
- (NSData *)content {
  return [[self contentAsString] dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSException *)exceptionForFailedPutResult:(NSDictionary *)_result {
  NSString *reason;
  
  /* Note: valueForKey:@"reason" does not work?! */
  reason = [(NSDictionary *)[_result valueForKey:@"RawResponse"] 
			    objectForKey:@"reason"];
  if (![reason isNotNull])
    reason = @"Failed to upload Sieve script.";
  
  return [NSException exceptionWithHTTPStatus:500 /* Server Error */
		      reason:reason];
}

- (NSException *)writeContent:(id)_content {
  NGSieveClient *client;
  NSDictionary  *result;
  
  if (_content == nil) {
    return [NSException exceptionWithHTTPStatus:400 /* Bad Request */
			reason:@"Missing content to write!"];
  }
  
  if ((client = [self sieveClient]) == nil) {
    return [NSException exceptionWithHTTPStatus:500 /* Server Error */
			reason:@"Failed to create NGSieveClient object"];
  }
  
  result = [client putScript:[self nameInContainer] script:_content];
  if (![[result valueForKey:@"result"] boolValue])
    return [self exceptionForFailedPutResult:result];
  
  return nil; /* everything is great */
}

/* operations */

- (NSException *)delete {
  NSDictionary *res;
  NSString *r;
  
  res = [[self sieveClient] deleteScript:[self nameInContainer]];
  if ([[res valueForKey:@"result"] boolValue])
    return nil;
  
  // TODO: make it a debug log
  [self logWithFormat:@"sieve delete failed: %@", res];
  
  r = [@"Sieve delete failed: " stringByAppendingString:[res description]];
  return [NSException exceptionWithHTTPStatus:500 /* Server Error */
		      reason:r];
}

- (NSException *)activate {
  return [[self container] activateScript:[self nameInContainer]];
}

/* name lookup */

- (id)lookupName:(NSString *)_key inContext:(id)_ctx acquire:(BOOL)_flag {
  id obj;
  
  /* first check attributes directly bound to the object */
  if ((obj = [super lookupName:_key inContext:_ctx acquire:NO]))
    return obj;
  
  /* return 404 to stop acquisition */
  return [NSException exceptionWithHTTPStatus:404 /* Not Found */];
}

/* operations */

- (id)PUTAction:(id)_context {
  NSException *e;
  NSString *content;

  content = [[(WOContext *)_context request] contentAsString];
  
  if ((e = [self writeContent:content]))
    return e;
  
  return self;
}

/* message type */

- (NSString *)outlookMessageClass {
  return @"IPM.Filter";
}


@end /* SOGoSieveScriptObject */
