/* SOGoSystemDefaults.m - this file is part of SOGo
 *
 * Copyright (C) 2009-2021 Inverse inc.
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

#import <Foundation/NSBundle.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSProcessInfo.h>

#import <NGExtensions/NSObject+Logs.h>

#import "NSArray+Utilities.h"
#import "NSString+Crypto.h"
#import "NSDictionary+Utilities.h"
#import "SOGoStartupLogger.h"

#import "SOGoSystemDefaults.h"
#import "SOGoConstants.h"

@implementation SOGoSystemDefaults

#if defined(LDAP_CONFIG)
#endif

typedef void (*NSUserDefaultsInitFunction) ();

#define DIR_SEP "/"

#ifndef NSUIntegerMax
#define NSUIntegerMax UINTPTR_MAX
#endif

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
  NSDictionary *domains = [self dictionaryForKey: @"domains"];
  return [domains allKeys];
}

- (BOOL) doesLoginTypeByDomain
{
  return ([self dictionaryForKey: @"SOGoLoginTypeByDomain"] != nil);
}

- (NSString *) getLoginTypeForDomain: (NSString*) _domain
{
  NSDictionary *domains, *config;
  NSString *type;
  if(![self doesLoginTypeByDomain])
    return nil;
  domains = [self dictionaryForKey: @"SOGoLoginTypeByDomain"];
  if([domains objectForKey: _domain])
  {
    config = [domains objectForKey: _domain];
  }
  else if([domains objectForKey: @"login_default"])
  {
    config = [domains objectForKey: @"login_default"];
  }
  else
    return nil;

  if((type = [config objectForKey: @"type"]))
  {
    return type;
  }
  else
    return nil;
}

- (NSString *) getImapAuthMechForDomain: (NSString*) _domain
{
  NSDictionary *domains, *config;
  NSString *type;

  if(![self doesLoginTypeByDomain])
    return nil;

  domains = [self dictionaryForKey: @"SOGoLoginTypeByDomain"];

  if([domains objectForKey: _domain])
  {
    config = [domains objectForKey: _domain];
  }
  else if([domains objectForKey: @"login_default"])
  {
    config = [domains objectForKey: @"login_default"];
  }
  else
    return nil;

  if((type = [config objectForKey: @"imapAuthMech"]))
  {
    return type;
  }
  else
    return nil;
}

- (NSString *) getSmtpAuthMechForDomain: (NSString*) _domain
{
  NSDictionary *domains, *config;
  NSString *type;
  
  if(![self doesLoginTypeByDomain])
    return nil;

  domains = [self dictionaryForKey: @"SOGoLoginTypeByDomain"];

  if([domains objectForKey: _domain])
  {
    config = [domains objectForKey: _domain];
  }
  else if([domains objectForKey: @"login_default"])
  {
    config = [domains objectForKey: @"login_default"];
  }
  else
    return nil;

  if((type = [config objectForKey: @"smtpAuthMech"]))
  {
    return type;
  }
  else
    return nil;
}

- (NSString *) getLoginConfigForDomain: (NSDictionary*) _domain
{
  NSDictionary *domains, *config;
  if(![self doesLoginTypeByDomain])
    return nil;
  domains = [self dictionaryForKey: @"SOGoLoginTypeByDomain"];
  if([domains objectForKey: _domain])
  {
    config = [domains objectForKey: _domain];
  }
  else if([domains objectForKey: @"login_default"])
  {
    config = [domains objectForKey: @"login_default"];
  }
  
  if(config)
    return config;
  else
    return nil;
}

- (BOOL) hasOpenIdType
{
  if([self doesLoginTypeByDomain])
  {
    NSDictionary *domainsConfig;
    NSEnumerator *e; 
    NSString *domain, *type;
    if(![self doesLoginTypeByDomain])
      return NO;
    domainsConfig = [self dictionaryForKey: @"SOGoLoginTypeByDomain"];
    e = [domainsConfig keyEnumerator];
    while((domain = [e nextObject]))
    {
      if((type = [[domainsConfig objectForKey: domain] objectForKey: @"type"]))
      {
        if([type isEqualToString: @"openid"])
          return YES;
      }
    }
    return NO;
  }
  else
    return [[self authenticationType] isEqualToString: @"openid"];

}


- (BOOL) enableDomainBasedUID
{
  return [self boolForKey: @"SOGoEnableDomainBasedUID"];
}

- (BOOL) forbidUnknownDomainsAuth
{
  return [self boolForKey: @"SOGoForbidUnknownDomainsAuth"];
}

- (NSArray *) domainsAllowed
{
  return [NSMutableArray arrayWithArray: [self stringArrayForKey: @"SOGoDomainAllowed"]];
}

- (NSArray *) loginDomains
{
  NSMutableArray *filteredLoginDomains;
  NSArray *domains;
  id currentObject;
  int count;
  
  if (self->loginDomains == nil)
    {
      filteredLoginDomains = [NSMutableArray arrayWithArray: [self stringArrayForKey: @"SOGoLoginDomains"]];
      domains = [self domainIds];
      count = [filteredLoginDomains count];
      while (count > 0)
        {
          count--;
          currentObject = [filteredLoginDomains objectAtIndex: count];
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


- (BOOL) isSogoSecretSet
{
  NSString *type;
  type = [self stringForKey: @"SOGoSecretType"];
  if(!type || [type isEqualToString:@"none"])
    return NO;
  else
    return YES;
}

- (NSString *) sogoSecretValue
{
  NSString *value, *type;
  NSDictionary *env;

  type = [self stringForKey: @"SOGoSecretType"];
  if(!type)
    type = @"none";

  if ([type isEqualToString:@"plain"])
  {
    value = [self stringForKey: @"SOGoSecretValue"];
  }
  else if ([type isEqualToString:@"env"])
  {
    value = [self stringForKey: @"SOGoSecretValue"];
    [self errorWithFormat: @"SOGo env fetching %@", value];
    if(!value || [value length] < 1)
    {
      [self errorWithFormat: @"SOGoSecretValue is not set!"];
      return nil;
    }
    env = [[NSProcessInfo processInfo] environment];
    value = [env objectForKey:value];
  }
  else if ([type isEqualToString:@"none"])
  {
    return nil;
  }
  else {
    [self errorWithFormat: @"SOGo can't understand the type of secret SOGoSecretType"];
    return nil;
  }

  if(!value || [value length] != 32){
    [self errorWithFormat: @"SOGo doesn't have a correct secret value of 32 chars SOGoSecretValue"];
    return nil;
  }

  return value;
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

- (BOOL) isCalendarJitsiLinkEnabled
{
  return [self boolForKey: @"SOGoCalendarEnableJitsiLink"];
}

- (BOOL) isAddressBookDAVAccessEnabled
{
  return [self boolForKey: @"SOGoAddressBookDAVAccessEnabled"];
}

- (BOOL) enableEMailAlarms
{
  return [self boolForKey: @"SOGoEnableEMailAlarms"];
}

- (BOOL) disableOrganizerEventCheck
{
  return [self boolForKey: @"SOGoDisableOrganizerEventCheck"];
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

- (BOOL) easDebugEnabled
{
  return [self boolForKey: @"SOGoEASDebugEnabled"];
}

- (BOOL) openIdDebugEnabled
{
  return [self boolForKey: @"SOGoOpenIDDebugEnabled"];
}

- (BOOL) tnefDecoderDebugEnabled
{
  return [self boolForKey: @"SOGoTnefDecoderDebugEnabled"];
}

- (BOOL) xsrfValidationEnabled
{
  id o;

  if (!(o = [self objectForKey: @"SOGoXSRFValidationEnabled"]))
    {
      return YES;
    }

  return [o boolValue];
}

- (NSString *) pageTitle
{
  return [self stringForKey: @"SOGoPageTitle"];
}

- (NSString *) helpURL
{
  return [self stringForKey: @"SOGoHelpURL"];
}

NSComparisonResult languageSort(id el1, id el2, void *context)
{
    NSString *t1, *t2;

    t1 = [context labelForKey: el1];
    t2 = [context labelForKey: el2];

    return [t1 compare: t2 options: NSCaseInsensitiveSearch];
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

- (BOOL) isSsoUsed: (NSString *) domain
{
  NSString* authType;

  authType = [self getLoginTypeForDomain: domain];
  if(!authType)
    authType = [self authenticationType];
  return ([authType isEqualToString: @"cas"] || [authType isEqualToString: @"saml2"] || [authType isEqualToString: @"openid"]);
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

/* OpenId Support */
- (NSString *) openIdConfigUrl
{
  return [self stringForKey: @"SOGoOpenIdConfigUrl"];
}

- (NSString *) openIdScope
{
  return [self stringForKey: @"SOGoOpenIdScope"];
}

- (NSString *) openIdClient
{
  return [self stringForKey: @"SOGoOpenIdClient"];
}

- (NSString *) openIdClientSecret
{
  return [self stringForKey: @"SOGoOpenIdClientSecret"];
}

- (NSString *) openIdEmailParam
{
  NSString *emailParam;
  emailParam = [self stringForKey: @"SOGoOpenIdEmailParam"];
  if(!emailParam)
    emailParam = @"email";
  return emailParam;
}

- (BOOL) openIdLogoutEnabled: (NSString *) _domain
{
  if(_domain && [self doesLoginTypeByDomain])
  {
    NSDictionary *config;
    NSString *type;
    id value;
    if((config = [self getLoginConfigForDomain: _domain]))
    {
      if((type = [config objectForKey: @"type"]) && [type isEqualToString:@"openid"])
        return [self boolForKey: @"SOGoOpenIdLogoutEnabled" andDict: config];
    }
    return NO;
  }
  return [self boolForKey: @"SOGoOpenIdLogoutEnabled"];
}

- (BOOL) openIdSendDomainInfo
{
  return [self boolForKey: @"SOGoOpenIdSendDomainInfo"];
}

- (int) openIdTokenCheckInterval
{

  int v;

  v = [self integerForKey: @"SOGoOpenIdTokenCheckInterval"];

  if (!v)
    v = 0;
  if(v<0)
    v = 0;

  return v;
}

- (BOOL) openIdEnableRefreshToken
{
  return [self boolForKey: @"SOGoOpenIdEnableRefreshToken"];
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
- (int) maximumMessageSizeLimit
{
  return [self integerForKey: @"SOGoMaximumMessageSizeLimit"];
}

//
//
//
- (NSUInteger) maximumMessageSubmissionCount
{
  NSUInteger v;

  v = [self integerForKey: @"SOGoMaximumMessageSubmissionCount"];

  if (!v)
    return NSUIntegerMax;

  return v;
}

- (NSUInteger) maximumRecipientCount
{
  NSUInteger v;

  v = [self integerForKey: @"SOGoMaximumRecipientCount"];

  if (!v)
    return NSUIntegerMax;

  return v;
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

//
// SOGo rate-limiting
//
- (int) maximumRequestCount
{
  return [self integerForKey: @"SOGoMaximumRequestCount"];
}

- (int) maximumRequestInterval
{
  int v;

  v = [self integerForKey: @"SOGoMaximumRequestInterval"];

  if (!v)
    v = 30;

  return v;
}

- (int) requestBlockInterval
{
  int v;

  v = [self integerForKey: @"SOGoRequestBlockInterval"];

  if (!v)
    v = 300;

  return v;
}


//
// SOGo EAS settings
//
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
  {
    NSLog(@"EASLOG: SOGoInternalSyncInterval didn't find value in conf, go with default 10");
    v = 10;
  }
  else {
    NSLog(@"EASLOG: SOGoInternalSyncInterval found, value is %d", v);
  }

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

- (BOOL) easSearchInBody
{
  return [self boolForKey: @"SOGoEASSearchInBody"];
}

- (BOOL) isEasUIDisabled
{
  return [self boolForKey: @"SOGoEASDisableUI"];
}

//
// See https://msdn.microsoft.com/en-us/library/gg672032(v=exchg.80).aspx
//
- (int) maximumPictureSize
{
  int v;

  v = [self integerForKey: @"SOGoMaximumPictureSize"];

  if (!v)
    v = 102400;

  return v;
}

- (BOOL) isPasswordRecoveryEnabled
{
  return [self boolForKey: @"SOGoPasswordRecoveryEnabled"];
}

- (NSArray *) passwordRecoveryDomains
{
  static NSArray *passwordRecoveryDomains = nil;

  if (!passwordRecoveryDomains)
    {
      passwordRecoveryDomains = [self stringArrayForKey: @"SOGoPasswordRecoveryDomains"];
      [passwordRecoveryDomains retain];
    }

  return passwordRecoveryDomains;
}

- (NSString *) JWTSecret
{
  NSString *secret;

  secret = [self stringForKey: @"SOGoJWTSecret"];

  if (!secret)
    secret = @"SOGo"; // Default secret

  return secret;
}

- (NSArray *) disableSharing
{
  static NSArray *disableSharing = nil;

  if (!disableSharing)
    {
      disableSharing = [self stringArrayForKey: @"SOGoDisableSharing"];
      [disableSharing retain];
    }
  
  return disableSharing;
}

- (BOOL)isURLEncryptionEnabled {
  return [self boolForKey: @"SOGoURLEncryptionEnabled"];
}

- (NSString *) urlEncryptionPassphrase
{
  NSString *passphrase;

  passphrase = [self stringForKey: @"SOGoURLEncryptionPassphrase"];

  if (!passphrase)
    passphrase = @"SOGoSuperSecret0"; // Default passphrase

  return passphrase;
}

- (NSArray *) disableSharingAnyAuthUser
{
  static NSArray *disableSharingAnyAuthUser = nil;

  if (!disableSharingAnyAuthUser)
    {
      disableSharingAnyAuthUser = [self stringArrayForKey: @"SOGoDisableSharingAnyAuthUser"];
      [disableSharingAnyAuthUser retain];
    }
  
  return disableSharingAnyAuthUser;
}

- (NSArray *) disableExport
{
  static NSArray *disableExport = nil;

  if (!disableExport)
    {
      disableExport = [self stringArrayForKey: @"SOGoDisableExport"];
      [disableExport retain];
    }
  
  return disableExport;
}

- (BOOL) enableMailCleaning
{
  return [self boolForKey: @"SOGoEnableMailCleaning"];
}

@end
