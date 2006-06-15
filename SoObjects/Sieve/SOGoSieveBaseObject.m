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

#include "SOGoSieveBaseObject.h"
#include <Mailer/SOGoMailManager.h>
#include <Mailer/SOGoMailAccount.h>
#include "common.h"
#include <NGImap4/NGSieveClient.h>
#include <NGObjWeb/SoObject+SoDAV.h>
#include <NGObjWeb/SoHTTPAuthenticator.h>
#include <NGExtensions/NSURL+misc.h>

@implementation SOGoSieveBaseObject

- (void)dealloc {
  [self->sieveClient release];
  [super dealloc];
}

/* hierarchy */

- (SOGoMailAccount *)mailAccountFolder {
  if (![[self container] respondsToSelector:_cmd]) {
    [self logWithFormat:@"WARNING: weird container of mailfolder: %@",
	    [self container]];
    return nil;
  }
  
  return [[self container] mailAccountFolder];
}

/* IMAP4 */

- (NGImap4ConnectionManager *)mailManager {
  return [[self mailAccountFolder] mailManager];
}
- (NSURL *)imap4URL {
  return [[self mailAccountFolder] imap4URL];
}

- (NSString *)imap4Password {
  return [[self mailAccountFolder] imap4Password];
}

- (void)flushMailCaches {
}

/* Sieve */

- (NGSieveClient *)sieveClient {
  id res;
  
  if (self->sieveClient != nil)
    return self->sieveClient;
  
  /* check container */

  res = [self container];
  if ([res respondsToSelector:_cmd]) {
    if ((res = [res sieveClient]) != nil) {
      self->sieveClient = [res retain];
      return self->sieveClient;
    }
  }
  
  /* create client */
  
  self->sieveClient =
    [[NGSieveClient alloc] initWithHost:[[self imap4URL] host]];
  if (self->sieveClient == nil)
    return nil;
  
  /* login */
  
  res = [self->sieveClient 
	     login:[[self imap4URL] user] 
	     password:[self imap4Password]];
  
  if (![[res valueForKey:@"result"] boolValue]) {
    [self logWithFormat:
	    @"ERROR: could not login '%@'(%@) into Sieve server: %@: %@",
	    [[self imap4URL] user], [self imap4Password],
	    self->sieveClient, res];
    [self->sieveClient release]; self->sieveClient = nil;
    return nil;
  }
  
  return self->sieveClient;
}

/* debugging */

- (NSString *)loggingPrefix {
  /* improve perf ... */
  return [NSString stringWithFormat:@"<0x%08X[%@]:%@>",
		     self, NSStringFromClass([self class]),
		     [self nameInContainer]];
}
@end /* SOGoSieveBaseObject */
