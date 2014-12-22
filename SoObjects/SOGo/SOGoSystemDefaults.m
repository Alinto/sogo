/* SOGoSystemDefaults.m - this file is part of SOGo
 *
 * Copyright (C) 2009-2014 Inverse inc.
 * Copyright (C) 2012 Jeroen Dekkers <jeroen@dekkers.ch>
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
#import <Foundation/NSDictionary.h>
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

static void
_injectConfigurationFromFile (NSMutableDictionary *defaultsDict,
                              NSString *filename, NSObject *logger)
{
  NSDictionary *newConfig, *fileAttrs;
  NSFileManager *fm;

  fm = [NSFileManager defaultManager];
  if ([fm fileExistsAtPath: filename])
    {
      fileAttrs = [fm fileAttributesAtPath: filename
                              traverseLink: YES];
      if (![fileAttrs objectForKey: @"NSFileSize"])
        {
          [logger errorWithFormat:
                  @"Can't get file attributes from '%@'",
                  filename];
          exit(1);
        }
      if ([[fileAttrs objectForKey: @"NSFileSize"] intValue] == 0 )
        {
          [logger warnWithFormat:
                  @"Empty file: '%@'. Skipping",
                  filename];
        }
      else
        {
          newConfig = [NSDictionary dictionaryWithContentsOfFile: filename];
          if (newConfig)
              [defaultsDict addEntriesFromDictionary: newConfig];
          else
            {
              [logger errorWithFormat:
                      @"Cannot read configuration from '%@'. Aborting",
                      filename];
              exit(1);
            }
        }
    }
}

+ (void) prepareUserDefaults
{
  /* Load settings from configuration files and
   * enforce the following order of precedence.
   * First match wins
   *   1. Command line arguments
   *   2. .GNUstepDefaults
   *   3. /etc/sogo/{debconf,sogo}.conf
   *   4. SOGoDefaults.plist
   *
   * The default standardUserDefaults search list is as follows:
   *   GSPrimaryDomain
   *   NSArgumentDomain (command line arguments)
   *   applicationDomain (sogod)
   *   NSGlobalDomain
   *   GSConfigDomain
   *   (languages)
   *   NSRegistrationDomain
   *
   * We'll end up with this search list:
   *   NSArgumentDomain (command line arguments)
   *   sogodRuntimeDomain (config from all config files)
   *   GSPrimaryDomain
   *   NSGlobalDomain
   *   GSConfigDomain
   *   (languages)
   *   NSRegistrationDomain (SOPE loads its defaults in this one)
   */

  NSDictionary *sogodDomain;
  NSMutableDictionary *configFromFiles;
  NSUserDefaults *ud;
  SOGoStartupLogger *logger;
  NSBundle *bundle;
  NSString *confFiles[] = {@"/etc/sogo/debconf.conf",
                           @"/etc/sogo/sogo.conf"};
  NSString *filename, *redirectURL;
  NSUInteger count;

  logger = [SOGoStartupLogger sharedLogger];

  /* Load the configuration from the standard user default files */
  ud = [NSUserDefaults standardUserDefaults];

  /* Populate configFromFiles with default values from SOGoDefaults.plist */
  configFromFiles = [NSMutableDictionary dictionaryWithCapacity:0];
  bundle = [NSBundle bundleForClass: self];
  filename = [bundle pathForResource: @"SOGoDefaults" ofType: @"plist"];
  if (filename)
    _injectConfigurationFromFile (configFromFiles, filename, logger);

  /* Fill/Override configFromFiles values with configuration stored
   *  in "/etc" */
  for (count = 0; count < sizeof(confFiles)/sizeof(confFiles[0]); count++)
    _injectConfigurationFromFile (configFromFiles, confFiles[count], logger);

  /* This dance is required to let other appplications (sogo-tool) use
   * options from the sogod domain while preserving the order of precedence
   *  - remove the 'sogod' domain from the user defaults search list 
   *  - Load the content of the sogod domain into configFromFiles
   *    Thereby overriding values from the config files loaded above
   */
  [ud removeSuiteNamed: @"sogod"];
  sogodDomain = [ud persistentDomainForName: @"sogod"];
  if ([sogodDomain count])
    [configFromFiles addEntriesFromDictionary: sogodDomain];

  /* Add a volatile domain containing the config to the search list.
   * The domain is added at the very front of the search list
   */
  [ud setVolatileDomain: configFromFiles
                forName: @"sogodRuntimeDomain"];
  [ud addSuiteNamed: @"sogodRuntimeDomain"];

  /* NSArgumentsDomain goes back in front of the search list */
  [ud addSuiteNamed: @"NSArgumentDomain"];

  /* issue a warning if WOApplicationRedirectURL is used */
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

- (BOOL) enableDomainBasedUID
{
  return ([[self domainIds] count] > 0 && [self boolForKey: @"SOGoEnableDomainBasedUID"]);
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

- (NSString *) encryptionKey;
{
  return [self stringForKey: @"SOGoEncryptionKey"];
}

- (BOOL) useRelativeURLs
{
  return [self boolForKey: @"WOUseRelativeURLs"];
}

- (NSString *) sieveFolderEncoding
{
  return [self stringForKey: @"SOGoSieveFolderEncoding"];
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
  static NSArray *supportedLanguages = nil;

  if (!supportedLanguages)
    {
      supportedLanguages = [self stringArrayForKey: @"SOGoSupportedLanguages"];
      [supportedLanguages retain];
    }

  return supportedLanguages;
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

/* SAML2 support */
- (NSString *) SAML2PrivateKeyLocation
{
  return [self stringForKey: @"SOGoSAML2PrivateKeyLocation"];
}

- (NSString *) SAML2CertificateLocation;
{
  return [self stringForKey: @"SOGoSAML2CertificateLocation"];
}

- (NSString *) SAML2IdpMetadataLocation
{
  return [self stringForKey: @"SOGoSAML2IdpMetadataLocation"];
}

- (NSString *) SAML2IdpPublicKeyLocation
{
  return [self stringForKey: @"SOGoSAML2IdpPublicKeyLocation"];
}

- (NSString *) SAML2IdpCertificateLocation
{
  return [self stringForKey: @"SOGoSAML2IdpCertificateLocation"];
}

- (BOOL) SAML2LogoutEnabled
{
  return [self boolForKey: @"SOGoSAML2LogoutEnabled"];
}

- (NSString *) SAML2LogoutURL
{
  return [self stringForKey: @"SOGoSAML2LogoutURL"];
}

- (NSString *) SAML2LoginAttribute
{
  return [self stringForKey: @"SOGoSAML2LoginAttribute"];
}

- (BOOL) enablePublicAccess
{
  return [self boolForKey: @"SOGoEnablePublicAccess"];
}

//
//
//
- (int) maximumFailedLoginCount
{
  return [self integerForKey: @"SOGoMaximumFailedLoginCount"];
}

- (int) maximumFailedLoginInterval
{
  int v;

  v = [self integerForKey: @"SOGoMaximumFailedLoginInterval"];

  if (!v)
    v = 10;

  return v;
}

- (int) failedLoginBlockInterval
{
  int v;

  v = [self integerForKey: @"SOGoFailedLoginBlockInterval"];

  if (!v)
    v = 300;

  return v;
}

//
//
//
- (int) maximumMessageSubmissionCount
{
  return [self integerForKey: @"SOGoMaximumMessageSubmissionCount"];
}

- (int) maximumRecipientCount
{
  return [self integerForKey: @"SOGoMaximumRecipientCount"];
}

- (int) maximumSubmissionInterval
{
  int v;

  v = [self integerForKey: @"SOGoMaximumSubmissionInterval"];

  if (!v)
    v = 30;

  return v;
}

- (int) messageSubmissionBlockInterval
{
  int v;

  v = [self integerForKey: @"SOGoMessageSubmissionBlockInterval"];

  if (!v)
    v = 300;

  return v;
}

- (int) maximumPingInterval
{
  int v;

  v = [self integerForKey: @"SOGoMaximumPingInterval"];

  if (!v)
    v = 10;

  return v;
}

- (int) maximumSyncInterval
{
  int v;

  v = [self integerForKey: @"SOGoMaximumSyncInterval"];

  if (!v)
    v = 30;

  return v;
}

- (int) internalSyncInterval
{
  int v;

  v = [self integerForKey: @"SOGoInternalSyncInterval"];

  if (!v)
    v = 10;

  return v;
}

- (int) maximumSyncWindowSize
{
  return [self integerForKey: @"SOGoMaximumSyncWindowSize"];
}

- (int) maximumSyncResponseSize
{
  int v;

  v = [self integerForKey: @"SOGoMaximumSyncResponseSize"];

  if (v > 0)
    v = v * 1024;
  
  return v;
}

@end
