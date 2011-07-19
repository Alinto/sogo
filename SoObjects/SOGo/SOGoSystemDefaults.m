/* SOGoSystemDefaults.m - this file is part of SOGo
 *
 * Copyright (C) 2009-2011 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Francis Lachapelle <flachapelle@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <dlfcn.h>
#import <unistd.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSUserDefaults.h>

#import <NGExtensions/NSObject+Logs.h>

#import "NSArray+Utilities.h"
#import "NSDictionary+Utilities.h"
#import "SOGoStartupLogger.h"

#import "SOGoSystemDefaults.h"
#import "SOGoConstants.h"

@implementation SOGoSystemDefaults

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

+ (void) injectSOGoDefaults: (NSUserDefaults *) ud
{
  NSBundle *bundle;
  NSDictionary *baseSOGoDefaults;
  NSString *filename;

  bundle = [NSBundle bundleForClass: self];
  filename = [bundle pathForResource: @"SOGoDefaults" ofType: @"plist"];
  if (filename
      && [[NSFileManager defaultManager] fileExistsAtPath: filename])
    {
      baseSOGoDefaults
        = [[NSDictionary alloc] initWithContentsOfFile: filename];
      if (baseSOGoDefaults)
        {
          [ud registerDefaults: baseSOGoDefaults];
          [baseSOGoDefaults autorelease];
        }
      else
        [bundle errorWithFormat: @"Unable to deserialize SOGoDefaults.plist"];
    }
  else
    [bundle errorWithFormat: @"SOGoDefaults.plist not found"];
}

+ (void) prepareUserDefaults
{
  NSString *redirectURL;
  NSDictionary *domain;
  NSUserDefaults *ud;
  SOGoStartupLogger *logger;

  logger = [SOGoStartupLogger sharedLogger];

  ud = [NSUserDefaults standardUserDefaults];
  domain = [ud persistentDomainForName: @"sogod"];
  if (![domain count])
    {
      domain = [ud persistentDomainForName: @"sogod-0.9"];
      if ([domain count])
	{
	  [logger logWithFormat: @"migrating user defaults from sogod-0.9"];
	  [ud setPersistentDomain: domain forName: @"sogod"];
	  [ud removePersistentDomainForName: @"sogod-0.9"];
	  [ud synchronize];
	}
      else
        [logger warnWithFormat: @"No configuration found."
                @" SOGo will not work properly."];
    }
  [self injectSOGoDefaults: ud];

  redirectURL = [ud stringForKey: @"WOApplicationRedirectURL"];
  if (redirectURL)
    {
      [logger warnWithFormat:
                @"Using obsolete 'WOApplicationRedirectURL' user default."];
      [logger warnWithFormat:
                @"  Please configure the use of the x-webobjects-XXX headers"
              @" with your webserver (see sample files)."];
      if ([redirectURL hasSuffix: @"/"])
        [ud setObject: [redirectURL substringToIndex: [redirectURL length] - 1]
               forKey: @"WOApplicationRedirectURL"];
    }
}

+ (void) initialize
{
  BootstrapNSUserDefaults ();
  [self prepareUserDefaults];
}

+ (SOGoSystemDefaults *) sharedSystemDefaults
{
  static SOGoSystemDefaults *sharedSystemDefaults = nil;
  NSUserDefaults *ud;

  if (!sharedSystemDefaults)
    {
      ud = [NSUserDefaults standardUserDefaults];
      sharedSystemDefaults = [self defaultsSourceWithSource: ud
                                            andParentSource: nil];
      [sharedSystemDefaults retain];
    }

  return sharedSystemDefaults;
}

- (id) init
{
  if ((self = [super init]))
    {
      loginDomains = nil;
    }

  return self;
}

- (void) dealloc
{
  [loginDomains release];
  [super dealloc];
}

- (BOOL) migrate
{
  static NSDictionary *migratedKeys = nil;

  if (!migratedKeys)
    {
      migratedKeys = [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"SOGoProfileURL", @"AgenorProfileURL",
                                   @"SOGoTimeZone", @"SOGoServerTimeZone",
                                   nil];
      [migratedKeys retain];
    }

  return ([self migrateOldDefaultsWithDictionary: migratedKeys]
          | [super migrate]);
}

- (NSArray *) domainIds
{
  return [[self dictionaryForKey: @"domains"] allKeys];
}

- (BOOL) enableDomainWithUID
{
  return ([[self domainIds] count] > 0 && [self boolForKey: @"SOGoEnableDomainWithUID"]);
}

- (NSArray *) loginDomains
{
  NSMutableArray *filteredLoginDomains;
  NSArray *domains;
  NSEnumerator *objects;
  id currentObject;
  
  if (self->loginDomains == nil)
    {
      filteredLoginDomains = [NSMutableArray arrayWithArray: [self stringArrayForKey: @"SOGoLoginDomains"]];
      domains = [self domainIds];
      objects = [filteredLoginDomains objectEnumerator];
      while ((currentObject = [objects nextObject]))
        {
          if (![domains containsObject: currentObject])
            {
              [filteredLoginDomains removeObject: currentObject];
              [self warnWithFormat: @"SOGoLoginDomains contains an invalid domain : %@", currentObject];
            }
        }

      ASSIGN (self->loginDomains, filteredLoginDomains);
    }
  
  return self->loginDomains;
}

- (NSArray *) visibleDomainsForDomain: (NSString *) domain
{
  NSMutableArray *domains;
  NSArray *definedDomains, *visibleDomains, *currentGroup;
  NSEnumerator *groups;
  NSString *currentDomain;

  definedDomains = [self domainIds];
  visibleDomains = [self arrayForKey: @"SOGoDomainsVisibility"];
  domains = [NSMutableArray array];
  groups = [visibleDomains objectEnumerator];
  while ((currentGroup = (NSArray *)[groups nextObject]))
    {
      if ([currentGroup containsObject: domain])
        [domains addObjectsFromArray: currentGroup];
    }
  
  // Remove lookup domain and invalid domains
  groups = [domains objectEnumerator];
  while ((currentDomain = [groups nextObject]))
    {
      if ([currentDomain isEqualToString: domain] || ![definedDomains containsObject: currentDomain])
        [domains removeObject: currentDomain];
    }
  
  return [domains uniqueObjects];
}

/* System-level only */

- (BOOL) crashOnSessionCreate
{
  return [self boolForKey: @"SOGoCrashOnSessionCreate"];
}

- (BOOL) debugRequests
{
  return [self boolForKey: @"SOGoDebugRequests"];
}

- (BOOL) debugLeaks;
{
  return [self boolForKey: @"SOGoDebugLeaks"];
}

- (int) vmemLimit
{
  return [self integerForKey: @"SxVMemLimit"];
}

- (BOOL) trustProxyAuthentication;
{
  return [self boolForKey: @"SOGoTrustProxyAuthentication"];
}

- (BOOL) useRelativeURLs
{
  return [self boolForKey: @"WOUseRelativeURLs"];
}

- (BOOL) isWebAccessEnabled
{
  return [self boolForKey: @"SOGoWebAccessEnabled"];
}

- (BOOL) isCalendarDAVAccessEnabled
{
  return [self boolForKey: @"SOGoCalendarDAVAccessEnabled"];
}

- (BOOL) isAddressBookDAVAccessEnabled
{
  return [self boolForKey: @"SOGoAddressBookDAVAccessEnabled"];
}

- (BOOL) enableEMailAlarms
{
  return [self boolForKey: @"SOGoEnableEMailAlarms"];
}

- (NSString *) faviconRelativeURL
{
  return [self stringForKey: @"SOGoFaviconRelativeURL"];
}

- (NSString *) zipPath
{
  return [self stringForKey: @"SOGoZipPath"];
}

- (int) port
{
  return [self integerForKey: @"WOPort"];
}

- (int) workers
{
  return [self integerForKey: @"WOWorkersCount"];
}

- (NSString *) logFile
{
  return [self stringForKey: @"WOLogFile"];
}

- (NSString *) pidFile
{
  return [self stringForKey: @"WOPidFile"];
}

- (NSTimeInterval) cacheCleanupInterval
{
  return [self floatForKey: @"SOGoCacheCleanupInterval"];
}

- (NSString *) memcachedHost
{
  return [self stringForKey: @"SOGoMemcachedHost"];
}

- (BOOL) uixDebugEnabled
{
  return [self boolForKey: @"SOGoUIxDebugEnabled"];
}

- (NSString *) pageTitle
{
  return [self stringForKey: @"SOGoPageTitle"];
}

- (NSArray *) supportedLanguages
{
  return [self stringArrayForKey: @"SOGoSupportedLanguages"];
}

- (BOOL) userCanChangePassword
{
  return [self boolForKey: SOGoPasswordChangeEnabled];
}

- (BOOL) uixAdditionalPreferences
{
  return [self boolForKey: @"SOGoUIxAdditionalPreferences"];
}

- (NSString *) loginSuffix
{
  return [self stringForKey: @"SOGoLoginSuffix"];
}

- (NSString *) authenticationType
{
  return [[self stringForKey: @"SOGoAuthenticationType"] lowercaseString];
}

- (NSString *) davAuthenticationType
{
  return [[self stringForKey: @"SOGoDAVAuthenticationType"] lowercaseString];
}

- (NSString *) CASServiceURL
{
  return [self stringForKey: @"SOGoCASServiceURL"];
}

- (BOOL) CASLogoutEnabled
{
  return [self boolForKey: @"SOGoCASLogoutEnabled"];
}

- (BOOL) enablePublicAccess
{
  return [self boolForKey: @"SOGoEnablePublicAccess"];
}

@end
