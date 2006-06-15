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

#include "AgenorUserManager.h"
#include "common.h"

static void usage(NSArray *args) {
  fprintf(stderr, "usage: %s <email1> <email2> <email3>\n",
	  [[args objectAtIndex:0] cString]);
}

static void doIt(NSArray *args) {
  AgenorUserManager *userManager;
  NSEnumerator *e;
  NSString     *email;
  
  if ([args count] < 2) {
    usage(args);
    return;
  }
  
  userManager = [AgenorUserManager sharedUserManager];
  
  e = [args objectEnumerator];
  [e nextObject]; /* consume the command name */

  while ((email = [e nextObject]) != nil) {
    NSString *uid;
    
    uid = [userManager getUIDForEmail:email];
    
    if ([uid isNotNull])
      printf("%s: %s\n", [email cString], [uid cString]);
    else {
      fprintf(stderr, "ERROR: did not find uid for email: '%s'\n", 
	      [email cString]);
    }
  }
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
