/*
  Copyright (C) 2005 SKYRIX Software AG

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

#include "LDAPUserManager.h"
#include "common.h"

static void usage(NSArray *args) {
  fprintf(stderr, "usage: %s <uid> read|write|info [<key>] [<value>]\n",
	  [[args objectAtIndex:0] cString]);
}

static void doInfo(NSUserDefaults *defaults) {
  printf("defaults for: '%s'\n", [[defaults valueForKey:@"uid"] cString]);
  printf("  profile table: '%s'\n",
	 [[[defaults valueForKey:@"tableURL"] absoluteString] cString]);
}

static void doRead(NSUserDefaults *defaults, NSString *key) {
  id value;

  if (key == nil) {
    NSArray  *defNames;
    unsigned i, count;
    
    defNames = [defaults valueForKey:@"primaryDefaultNames"];
    if ((count = [defNames count]) == 0) {
      fprintf(stderr, "There are no keys in the SOGo profile!\n");
      return;
    }
    
    for (i = 0; i < count; i++) {
      printf("%s: %s\n",
	     [[defNames objectAtIndex:i] cString],
	     [[[defaults objectForKey:[defNames objectAtIndex:i]]
		description] cString]);
    }
  }
  else if ((value = [defaults objectForKey:key]) == nil) {
    fprintf(stderr, "There is no key '%s' in the SOGo profile!\n", 
	    [key cString]);
  }
  else
    printf("%s\n", [[value description] cString]);
}

static void doWrite(NSUserDefaults *defaults, NSString *key, NSString *value) {
  [defaults setObject:value forKey:key];
  
  if (![defaults synchronize]) {
    fprintf(stderr, "Failed to synchronize defaults with profile!\n");
    return;
  }
}

static void doIt(NSArray *args) {
  LDAPUserManager *userManager;
  NSUserDefaults    *defaults;
  NSString *uid, *op, *key, *value;

  /* extract arguments */
  
  if ([args count] < 3) {
    usage(args);
    return;
  }

  uid   = [args objectAtIndex:1];
  op    = [args objectAtIndex:2];
  key   = nil;
  value = nil;
  
  if ([args count] > 3)
    key = [args objectAtIndex:3];
  
  if ([op isEqualToString:@"write"]) {
    if ([args count] < 5) {
      usage(args);
      return;
    }
    value = [args objectAtIndex:4];
  }
  
  /* run */
  
  userManager = [LDAPUserManager sharedUserManager];
  defaults    = [userManager getUserDefaultsForUID:uid];
  
  if (![defaults isNotNull]) {
    fprintf(stderr, "Error: found no userdefaults for UID: '%s'\n", 
	    [uid cString]);
    exit(1);
  }
  
  if ([op isEqualToString:@"read"])
    doRead(defaults, key);
  else if ([op isEqualToString:@"write"])
    doWrite(defaults, key, value);
  else if ([op isEqualToString:@"info"])
    doInfo(defaults);
  else
    usage(args);
}

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  
  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  doIt([[NSProcessInfo processInfo] argumentsWithoutDefaults]);
  
  [pool release];
  return 0;
}
