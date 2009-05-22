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

#import <dlfcn.h>
#import <unistd.h>

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/SoApplication.h>

#if defined(LDAP_CONFIG)
#import <SOGo/SOGoLDAPUserDefaults.h>
#endif

typedef void (*NSUserDefaultsInitFunction) ();

#define DIR_SEP "/"

static void
BootstrapNSUserDefaults ()
{
  char *filename;
  NSUserDefaultsInitFunction SOGoNSUserDefaultsBootstrap;
  void *handle;

  filename = SOGO_LIBDIR DIR_SEP "libSOGoNSUserDefaults.so.1";
  handle = dlopen (filename, RTLD_NOW | RTLD_GLOBAL);
  if (handle)
    {
      SOGoNSUserDefaultsBootstrap = dlsym (handle,
					   "SOGoNSUserDefaultsBootstrap");
      if (SOGoNSUserDefaultsBootstrap)
	SOGoNSUserDefaultsBootstrap ();
    }
}

static void
convertOldSOGoDomain (NSUserDefaults *ud)
{
  NSDictionary *domain;

  domain = [ud persistentDomainForName: @"sogod"];
  if (![domain count])
    {
      domain = [ud persistentDomainForName: @"sogod-0.9"];
      if ([domain count])
	{
	  NSLog (@"migrating user defaults from sogod-0.9");
	  [ud setPersistentDomain: domain forName: @"sogod"];
	  [ud removePersistentDomainForName: @"sogod-0.9"];
	  [ud synchronize];
	}
    }
}

int
main (int argc, char **argv, char **env)
{
  NSString *tzName, *redirectURL;
  NSUserDefaults *ud;
  NSAutoreleasePool *pool;
  int rc;

  pool = [NSAutoreleasePool new];

  BootstrapNSUserDefaults ();

  rc = -1;

  if (getuid() > 0)
    {
#if LIB_FOUNDATION_LIBRARY
      [NSProcessInfo initializeWithArguments: argv
		     count: argc environment: env];
#endif
      ud = [NSUserDefaults standardUserDefaults];
      convertOldSOGoDomain (ud);

      redirectURL = [ud stringForKey: @"WOApplicationRedirectURL"];
      if (redirectURL && [redirectURL hasSuffix: @"/"])
	{
	  [ud setObject: [redirectURL substringToIndex: [redirectURL length] - 1]
	      forKey: @"WOApplicationRedirectURL"];
	  [ud synchronize];
	}

      rc = 0;
      tzName = [ud stringForKey: @"SOGoServerTimeZone"];
      if (!tzName)
	tzName = @"UTC";
      [NSTimeZone setDefaultTimeZone:
		    [NSTimeZone timeZoneWithName: tzName]];
      WOWatchDogApplicationMain (@"SOGo", argc, (void *) argv);
    }
  else
    NSLog (@"Don't run SOGo as root!");

  [pool release];

  return rc;
}
