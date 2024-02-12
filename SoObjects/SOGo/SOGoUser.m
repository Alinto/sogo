/*
  Copyright (C) 2006-2021 Inverse inc.

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSURL+misc.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <Appointments/SOGoAppointmentFolders.h>
#import <Contacts/SOGoContactFolders.h>

#import "NSArray+Utilities.h"
#import "SOGoCache.h"
#import "SOGoDateFormatter.h"
#import "SOGoPermissions.h"
#import "SOGoSystemDefaults.h"
#import "SOGoUserFolder.h"
#import "SOGoUserManager.h"
#import "SOGoUserSettings.h"
#import "WOResourceManager+SOGo.h"
#import "NSString+Crypto.h"

#if defined(MFA_CONFIG)
#include <liboath/oath.h>
#endif

#import "SOGoUser.h"

static const NSString *kEncryptedUserNamePrefix = @"uenc";

@implementation SoUser (SOGoExtension)

- (SOGoDomainDefaults *) userDefaults
{
  return [SOGoSystemDefaults sharedSystemDefaults];
}

- (SOGoDomainDefaults *) domainDefaults
{
  return [SOGoSystemDefaults sharedSystemDefaults];
}

@end

@implementation SOGoUser

// + (NSString *) language
// {
//   NSArray *bLanguages;
//   WOContext *context;
//   NSString *lng;

//   context = [[WOApplication application] context];
//   bLanguages = [[context request] browserLanguages];
//   if ([bLanguages count] > 0)
//     lng = [bLanguages objectAtIndex: 0];

//   if (![lng length])
//     lng = defaultLanguage;

//   return lng;
// }

+ (SOGoUser *) userWithLogin: (NSString *) newLogin
{
  return [self userWithLogin: newLogin  roles: nil];
}

+ (SOGoUser *) userWithLogin: (NSString *) newLogin
		       roles: (NSArray *) newRoles
{
  return [self userWithLogin: newLogin  roles: newRoles  trust: NO];
}

+ (SOGoUser *) userWithLogin: (NSString *) newLogin
		       roles: (NSArray *) newRoles
		       trust: (BOOL) b
{
  SOGoCache *cache;
  SOGoUser *user;

  cache = [SOGoCache sharedCache];
  user = [cache userNamed: newLogin];
  if (!user)
    {
      user = [[self alloc] initWithLogin: newLogin roles: newRoles trust: b];
      if (user)
	{
 	  [cache registerUser: user withName: newLogin];
	  [user release];
	}
    }
  if (newRoles)
    [user setPrimaryRoles: newRoles];

  return user;
}

/**
 * Return a new instance for the login name, which can be appended by a
 * domain name. The domain is extracted only if the system defaults
 * SOGoEnableDomainBasedUID is enabled.
 *
 * @param newLogin a login name optionally follow by @domain
 * @param newRoles
 * @param b is set to YES if newLogin can be trust
 * @see loginInDomain
 * @see [SOGoSession decodeValue:usingKey:login:domain:password:]
 */
- (id) initWithLogin: (NSString *) newLogin
	       roles: (NSArray *) newRoles
	       trust: (BOOL) b
{
  SOGoUserManager *um;
  SOGoSystemDefaults *sd;
  NSDictionary *contactInfos;
  NSString *realUID, *uid, *domain;
  NSRange r;

  _defaults = nil;
  _settings = nil;

  uid = nil;
  realUID = nil;
  domain = nil;

  if ([newLogin isEqualToString: @"anonymous"]
      || [newLogin isEqualToString: @"freebusy"])
    realUID = newLogin;
  else
    {
      sd = [SOGoSystemDefaults sharedSystemDefaults];
      if ([sd enableDomainBasedUID] || [[sd loginDomains] count] > 0)
        {
          r = [newLogin rangeOfString: @"@" options: NSBackwardsSearch];
          if (r.location != NSNotFound)
            {
              // The domain is probably appended to the username;
              // make sure it is defined as a domain in the configuration.
              domain = [newLogin substringFromIndex: (r.location + r.length)];
              if ([[SOGoUserManager sharedUserManager] isDomainDefined: domain] &&
                  ![sd enableDomainBasedUID])
                newLogin = [newLogin substringToIndex: r.location];

              if (domain != nil && ![sd enableDomainBasedUID])
                // Login domains are enabled (SOGoLoginDomains) but not
                // domain-based UID (SOGoEnableDomainBasedUID).
                // Drop the domain from the login name.
                domain = nil;
            }
        }

      newLogin = [newLogin stringByReplacingString: @"%40"
                                        withString: @"@"];
      if (b)
	realUID = newLogin;
      else
	{
	  um = [SOGoUserManager sharedUserManager];
          contactInfos = [um contactInfosForUserWithUIDorEmail: newLogin
                                                      inDomain: domain];
	  realUID = [contactInfos objectForKey: @"c_uid"];
          if (domain == nil && [sd enableDomainBasedUID])
            domain = [contactInfos objectForKey: @"c_domain"];
	}

      if ([realUID length] && [domain length])
        {
          // When the user is associated to a domain, the [SOGoUser login]
          // method returns the combination login@domain while
          // [SOGoUser loginInDomain] only returns the login.
          r = [realUID rangeOfString: domain  options: NSBackwardsSearch|NSCaseInsensitiveSearch];

          // Do NOT strip @domain.com if SOGoEnableDomainBasedUID is enabled since
          // the real login most likely is the email address.
          if (r.location != NSNotFound && ![sd enableDomainBasedUID])
            uid = [realUID substringToIndex: r.location-1];
          // If we don't have the domain in the UID but SOGoEnableDomainBasedUID is
          // enabled, let's add it internally so so it becomes unique across
          // all potential domains.
          else if (r.location == NSNotFound && [sd enableDomainBasedUID])
            {
              uid = [NSString stringWithString: realUID];
              realUID = [NSString stringWithFormat: @"%@@%@", realUID, domain];
            }
          // We found the domain and SOGoEnableDomainBasedUID is enabled,
          // we keep realUID.. This would happen for example if the user
          // authenticates with foo@bar.com and the UIDFieldName is also foo@bar.com
          else if ([sd enableDomainBasedUID])
            uid = [NSString stringWithString: realUID];
        }
    }

  if ([realUID length])
    {
      if ((self = [super initWithLogin: realUID roles: newRoles]))
	{
	  allEmails = nil;
	  currentPassword = nil;
	  cn = nil;
          ASSIGN (loginInDomain, (uid ? uid : realUID));
          _defaults = nil;
          _domainDefaults = nil;
          _settings = nil;
          mailAccounts = nil;
	}
    }
  else
    {
      [self release];
      self = nil;
    }

  return self;
}

- (void) dealloc
{
  [_defaults release];
  [_domainDefaults release];
  [_settings release];
  [allEmails release];
  [mailAccounts release];
  [currentPassword release];
  [cn release];
  [loginInDomain release];
  [super dealloc];
}

- (void) setPrimaryRoles: (NSArray *) newRoles
{
  ASSIGN (roles, newRoles);
}

- (void) setCurrentPassword: (NSString *) newPassword
{
  ASSIGN (currentPassword, newPassword);
}

- (NSString *) currentPassword
{
  return currentPassword;
}

- (NSString *) loginInDomain
{
  return loginInDomain;
}

- (id) _fetchFieldForUser: (NSString *) field
{
  NSDictionary *contactInfos;
  SOGoUserManager *um;

  um = [SOGoUserManager sharedUserManager];
  contactInfos = [um contactInfosForUserWithUIDorEmail: login];

  return [contactInfos objectForKey: field];
}

- (void) _fetchAllEmails
{
  allEmails = [self _fetchFieldForUser: @"emails"];
  [allEmails retain];
}

- (void) _fetchCN
{
  cn = [self _fetchFieldForUser: @"cn"];
  if ([cn isNotNull])
    cn = [cn stringByTrimmingSpaces];
  else
    cn = [NSString stringWithString: login];
  [cn retain];
}

/* properties */
- (NSString *) domain
{
  return [self _fetchFieldForUser: @"c_domain"];
}

- (id <SOGoSource>) authenticationSource
{
  NSString *sourceID;
  SOGoUserManager *um;

  sourceID = [self _fetchFieldForUser: @"SOGoSource"];
  um = [SOGoUserManager sharedUserManager];

  return [um sourceWithID: sourceID];
}

- (NSArray *) allEmails
{
  if (!allEmails)
    [self _fetchAllEmails];

  return allEmails;
}

//
// We always return the last object among our list of email addresses. This value
// is always added in SOGoUserManager: -_fillContactMailRecords:
//
- (NSString *) systemEmail
{
  if (!allEmails)
    [self _fetchAllEmails];

  return [allEmails objectAtIndex: 0];
}

- (BOOL) hasEmail: (NSString *) email
{
  if (!allEmails)
    [self _fetchAllEmails];

  return [allEmails containsCaseInsensitiveString: email];
}

- (NSString *) cn
{
  if (!cn)
    [self _fetchCN];

  return cn;
}

- (NSMutableDictionary *) defaultIdentity
{
  NSDictionary *defaultAccount, *currentIdentity;
  NSMutableDictionary *defaultIdentity;
  NSArray *identities;
  NSString *defaultEmail;
  unsigned int count, max;

  defaultEmail = [self systemEmail];
  defaultAccount = [[self mailAccounts] objectAtIndex: 0];
  defaultIdentity = nil;

  identities = [defaultAccount objectForKey: @"identities"];
  max = [identities count];

  for (count = 0; count < max; count++)
    {
      currentIdentity = [identities objectAtIndex: count];
      if ([[currentIdentity objectForKey: @"isDefault"] boolValue])
        {
          defaultIdentity = [NSMutableDictionary dictionaryWithDictionary: currentIdentity];
          break;
        }
      else if ([[currentIdentity objectForKey: @"email"] caseInsensitiveCompare: defaultEmail] == NSOrderedSame)
        {
          defaultIdentity = [NSMutableDictionary dictionaryWithDictionary: currentIdentity];
        }
    }

  return defaultIdentity; // can be nil
}

- (SOGoDateFormatter *) dateFormatterInContext: (WOContext *) context
{
  SOGoDateFormatter *dateFormatter;
  NSString *format;
  SOGoUserDefaults *ud;
  NSDictionary *locale;
  WOResourceManager *resMgr;

  dateFormatter = [SOGoDateFormatter new];
  [dateFormatter autorelease];

  ud = [self userDefaults];
  resMgr = [[WOApplication application] resourceManager];
  locale = [resMgr localeForLanguageNamed: [ud language]];
  [dateFormatter setLocale: locale];
  format = [ud shortDateFormat];
  if (format)
    [dateFormatter setShortDateFormat: format];
  format = [ud longDateFormat];
  if (format)
    [dateFormatter setLongDateFormat: format];
  format = [ud timeFormat];
  if (format)
    [dateFormatter setTimeFormat: format];

  return dateFormatter;
}

- (NSDictionary *) currentDay
{
  NSCalendarDate *now;
  NSDictionary *description, *abbr;
  NSDictionary *locale;
  SOGoUserDefaults *ud;
  WOResourceManager *resMgr;
  NSUInteger seconds;

  now = [NSCalendarDate calendarDate];
  ud = [self userDefaults];
  resMgr = [[WOApplication application] resourceManager];
  locale = [resMgr localeForLanguageNamed: [ud language]];

  [now setTimeZone: [ud timeZone]];
  seconds = [now hourOfDay]*3600 + [now minuteOfHour]*60 + [now secondOfMinute];

  abbr = [NSDictionary dictionaryWithObjectsAndKeys:
                 [now descriptionWithCalendarFormat: @"%a" locale: locale], @"weekday",
                 [now descriptionWithCalendarFormat: @"%b" locale: locale], @"month",
                       nil];
  description = [NSDictionary dictionaryWithObjectsAndKeys:
                        [now descriptionWithCalendarFormat: @"%A" locale: locale], @"weekday",
                        [now descriptionWithCalendarFormat: @"%B" locale: locale], @"month",
                        [now descriptionWithCalendarFormat: @"%d" locale: locale], @"day",
                        [now descriptionWithCalendarFormat: @"%Y" locale: locale], @"year",
                        abbr, @"abbr",
                        [NSNumber numberWithInt: (24*3600 - seconds)], @"secondsBeforeTomorrow",
                        nil];

  return description;
}

- (SOGoUserDefaults *) userDefaults
{
  if (!_defaults)
    {
      _defaults = [SOGoUserDefaults defaultsForUser: login
                                           inDomain: [self domain]];
      [_defaults retain];
    }
  //else
  //  NSLog(@"User defaults cache hit for %@", login);

  return _defaults;
}

- (SOGoDomainDefaults *) domainDefaults
{
  NSString *domain;

  if (!_domainDefaults)
    {
      domain = [self domain];
      if ([domain length])
        {
          _domainDefaults = [SOGoDomainDefaults defaultsForDomain: domain];
          if (!_domainDefaults)
            {
              //[self errorWithFormat: @"domain '%@' does not exist!", domain];
              _domainDefaults = [SOGoSystemDefaults sharedSystemDefaults];
            }
        }
      else
        _domainDefaults = [SOGoSystemDefaults sharedSystemDefaults];
      [_domainDefaults retain];
    }
  //else
  //  NSLog(@"User defaults cache hit for %@", login);

  return _domainDefaults;
}

- (SOGoUserSettings *) userSettings
{
  if (!_settings)
    {
      _settings = [SOGoUserSettings settingsForUser: login];
      [_settings retain];
    }

  return _settings;
}

- (NSCalendarDate *) firstDayOfWeekForDate: (NSCalendarDate *) date
{
  int offset;
  NSCalendarDate *firstDay;

  offset = [[self userDefaults] firstDayOfWeek] - [date dayOfWeek];
  if (offset > 0)
    offset -= 7;

  firstDay = [date addTimeInterval: offset * 86400];

  return firstDay;
}

- (unsigned int) dayOfWeekForDate: (NSCalendarDate *) date
{
  unsigned int offset, baseDayOfWeek, dayOfWeek;

  offset = [[self userDefaults] firstDayOfWeek];
  baseDayOfWeek = [date dayOfWeek];
  if (offset > baseDayOfWeek)
    baseDayOfWeek += 7;

  dayOfWeek = baseDayOfWeek - offset;

  return dayOfWeek;
}

- (NSCalendarDate *) firstWeekOfYearForDate: (NSCalendarDate *) date
{
  NSString *firstWeekRule;
  NSCalendarDate *januaryFirst, *firstWeek;
  unsigned int dayOfWeek;

  firstWeekRule = [[self userDefaults] firstWeekOfYear];

  januaryFirst = [NSCalendarDate dateWithYear: [date yearOfCommonEra]
				 month: 1 day: 1 hour: 0 minute: 0 second: 0
				 timeZone: [date timeZone]];
  if ([firstWeekRule isEqualToString: SOGoWeekStartFirst4DayWeek])
    {
      dayOfWeek = [self dayOfWeekForDate: januaryFirst];
      if (dayOfWeek < 4)
	firstWeek = [self firstDayOfWeekForDate: januaryFirst];
      else
	firstWeek = [self firstDayOfWeekForDate: [januaryFirst
						   dateByAddingYears: 0
						   months: 0
						   days: 7]];
    }
  else if ([firstWeekRule isEqualToString: SOGoWeekStartFirstFullWeek])
    {
      dayOfWeek = [self dayOfWeekForDate: januaryFirst];
      if (dayOfWeek == 0)
	firstWeek = [self firstDayOfWeekForDate: januaryFirst];
      else
	firstWeek = [self firstDayOfWeekForDate: [januaryFirst
						   dateByAddingYears: 0
						   months: 0
						   days: 7]];
    }
  else
    firstWeek = [self firstDayOfWeekForDate: januaryFirst];

  return firstWeek;
}

- (unsigned int) weekNumberForDate: (NSCalendarDate *) date
{
  NSCalendarDate *firstWeek, *previousWeek;
  unsigned int weekNumber;

  firstWeek = [self firstWeekOfYearForDate: date];
  if ([firstWeek earlierDate: date] == firstWeek)
    {
      weekNumber = ([date timeIntervalSinceDate: firstWeek] / (86400 * 7) + 1);
    }
  else
    {
      // Date is within the last week of the previous year;
      // Compute the previous week number to find the week number of the requested date.
      // The number will either be 52 or 53.
      previousWeek = [date dateByAddingYears: 0
                                      months: 0
                                        days: -7];
      firstWeek = [self firstWeekOfYearForDate: previousWeek];
      weekNumber = ([previousWeek timeIntervalSinceDate: firstWeek] / (86400 * 7) + 1);
      weekNumber += 1;
    }

  return weekNumber;
}

/* mail */
- (BOOL) _migrateFolderWithPurpose: (NSString *) purpose
                          withName: (NSString *) folderName
{
  NSString *methodName;
  SEL methodSel;
  BOOL rc;

  [self userDefaults];
  methodName = [NSString stringWithFormat: @"set%@FolderName:", purpose];
  methodSel = NSSelectorFromString (methodName);
  if ([_defaults respondsToSelector: methodSel])
    {
      [_defaults performSelector: methodSel withObject: folderName];
      rc = YES;
    }
  else
    {
      [self errorWithFormat: @"method '%@' not available with user defaults"
            @" object, folder migration fails", methodName];
      rc = NO;
    }

  return rc;
}

- (void) _migrateFolderSettings
{
  NSMutableDictionary *mailSettings;
  NSString *folderName, *key;
  BOOL migrated;
  NSString **purpose;
  NSString *purposes[] = { @"Drafts", @"Sent", @"Trash", nil };

  [self userSettings];
  mailSettings = [_settings objectForKey: @"Mail"];
  if (mailSettings)
    {
      migrated = NO;
      purpose = purposes;
      while (*purpose)
        {
          key = [NSString stringWithFormat: @"%@Folder", *purpose];
          folderName = [mailSettings objectForKey: key];
          if ([folderName length]
              && [self _migrateFolderWithPurpose: *purpose
                                        withName: folderName])
            {
              migrated = YES;
              [mailSettings removeObjectForKey: key];
              folderName = nil;
            }
          purpose++;
        }
      if (migrated)
        {
          [_settings synchronize];
          [self userDefaults];
          [_defaults synchronize];
        }
    }
}

- (void) _appendSystemMailAccountWithDelegatedIdentities: (BOOL) appendDeletegatedIdentities
{
  NSString *fullName, *imapLogin, *imapServer, *cImapServer, *smtpServer,
    *imapEncryption, *smtpEncryption, *imapScheme, *smtpScheme, *action, *imapQueryTls, *smtpQueryTls, 
    *customEmail, *sieveServer, *imapTlsVerifyMode, *smtpTlsVerifyMode;
  NSMutableDictionary *mailAccount, *identity, *mailboxes, *receipts, *security, *mailSettings;
  NSDictionary *imapQueryComponents, *smtpQueryComponents;
  NSNumber *imapPort, *smtpPort;
  NSMutableArray *identities, *mails;
  NSArray *delegators, *delegates;
  NSURL *imapUrl, *cImapUrl, *smtpUrl;
  unsigned int count, max; //, default_identity;
  NSInteger imapDefaultPort, smtpDefaultPort;
  NSUInteger index;
  BOOL hasDefaultIdentity;

  [self userDefaults]; // set _defaults
  [self userSettings]; // set _settings

  mailSettings = [_settings objectForKey: @"Mail"];
  mailAccount = [NSMutableDictionary new];

  // 1. login
  imapLogin = [[SOGoUserManager sharedUserManager]
                     getExternalLoginForUID: [self loginInDomain]
                                   inDomain: [self domain]];
  [mailAccount setObject: imapLogin forKey: @"userName"];

  // 2.1 IMAP server
  // imapServer might have the following format
  // localhost
  // localhost:143
  // imap://localhost
  // imap://localhost:143
  // imaps://localhost:993
  // imaps://localhost:143/?tls=YES
  // imaps://localhost/?tls=YES

  cImapServer = [self _fetchFieldForUser: @"c_imaphostname"];
  imapServer = [[self domainDefaults] imapServer];
  cImapUrl = [NSURL URLWithString: (cImapServer ? cImapServer : @"")];
  imapUrl = [NSURL URLWithString: imapServer];
  if([cImapUrl host])
    imapServer = [cImapUrl host];
  else
    if(cImapServer)
      imapServer = cImapServer;
    else
      if([imapUrl host])
        imapServer = [imapUrl host];
  [mailAccount setObject: imapServer forKey: @"serverName"];

  // 2.2 IMAP port & encryption
  imapScheme = [cImapUrl scheme] ? [cImapUrl scheme] : [imapUrl scheme];
  imapQueryComponents = [cImapUrl query] ? [cImapUrl queryComponents] : [imapUrl queryComponents];
  imapQueryTls = [imapQueryComponents valueForKey: @"tls"];
  imapTlsVerifyMode = [imapQueryComponents valueForKey: @"tlsVerifyMode"];

  if (!imapTlsVerifyMode)
    imapTlsVerifyMode = @"default";

  if (imapScheme && [imapScheme caseInsensitiveCompare: @"imaps"] == NSOrderedSame)
    {
      if (imapQueryTls && [imapQueryTls caseInsensitiveCompare: @"YES"] == NSOrderedSame)
        {
          imapDefaultPort = 143;
          imapEncryption = @"tls";
        }
      else
        {
          imapEncryption = @"ssl";
          imapDefaultPort = 993;
        }
    }
  else
    {
      if (imapQueryTls && [imapQueryTls caseInsensitiveCompare: @"YES"] == NSOrderedSame)
        imapEncryption = @"tls";
      else
        imapEncryption = @"none";

      imapDefaultPort = 143;
    }

  imapPort = [cImapUrl port] ? [cImapUrl port] : [imapUrl port];
  if ([imapPort intValue] == 0) /* port is nil or intValue == 0 */
    imapPort = [NSNumber numberWithInt: imapDefaultPort];
  [mailAccount setObject: imapPort forKey: @"port"];
  [mailAccount setObject: imapEncryption forKey: @"encryption"];
  [mailAccount setObject: imapTlsVerifyMode forKey: @"tlsVerifyMode"];

  //3.1 SMTP server
  smtpServer = [[self domainDefaults] smtpServer];
  smtpUrl = [NSURL URLWithString: smtpServer];
  if([smtpUrl host])
    smtpServer = [smtpUrl host];
  [mailAccount setObject: smtpServer forKey: @"smtpServerName"];

  // 3.2 SMTP port and encryption
  smtpScheme = [smtpUrl scheme];
  smtpQueryComponents = [smtpUrl queryComponents];
  smtpQueryTls = [smtpQueryComponents valueForKey: @"tls"];
  smtpTlsVerifyMode = [smtpQueryComponents valueForKey: @"tlsVerifyMode"];

  if (!smtpTlsVerifyMode)
    smtpTlsVerifyMode = @"default";

  if (smtpScheme && [smtpScheme caseInsensitiveCompare: @"smtps"] == NSOrderedSame)
    {
      if (smtpQueryTls && [smtpQueryTls caseInsensitiveCompare: @"YES"] == NSOrderedSame)
        {
          smtpDefaultPort = 465; //Shoud be 587 but sope sope-mime/NGMail/NGSmtpClient.m initWithUrl doesn't agree...
          smtpEncryption = @"tls";
        }
      else
        {
          smtpEncryption = @"ssl";
          smtpDefaultPort = 465; //Shoud be 587 but sope sope-mime/NGMail/NGSmtpClient.m initWithUrl doesn't agree...
        }
    }
  else
    {
      if (smtpQueryTls && [smtpQueryTls caseInsensitiveCompare: @"YES"] == NSOrderedSame)
      {
        smtpEncryption = @"tls";
        smtpDefaultPort = 465;
      }
      else {
        smtpEncryption = @"none";
        smtpDefaultPort = 25;
      }
    }

  smtpPort = [smtpUrl port];
  if ([smtpPort intValue] == 0) /* port is nil or intValue == 0 */
    smtpPort = [NSNumber numberWithInt: smtpDefaultPort];
  [mailAccount setObject: smtpPort forKey: @"smtpPort"];
  [mailAccount setObject: smtpEncryption forKey: @"smtpEncryption"];
  [mailAccount setObject: smtpTlsVerifyMode forKey: @"smtpTlsVerifyMode"];

  // 4. Sieve server
  sieveServer = [self _fetchFieldForUser: @"c_sievehostname"];

  if (sieveServer)
    {
      [mailAccount setObject: sieveServer  forKey: @"sieveServerName"];
    }

  // 5. Identities
  identities = [NSMutableArray new];
  [identities addObjectsFromArray: [_defaults mailIdentities]];
  mails = [NSMutableArray arrayWithArray: [self allEmails]];
  [mailAccount setObject: [mails objectAtIndex: 0] forKey: @"name"];
  max = [identities count];
  hasDefaultIdentity = NO;
  fullName = [self cn];
  if ([fullName length] == 0)
    fullName = login;

  // Sanitize identities
  for (count = 0; count < max; count++)
    {
      identity = [NSMutableDictionary dictionaryWithDictionary: [identities objectAtIndex: count]];
      customEmail = [identity objectForKey: @"email"];
      if ([customEmail length])
        {
          if (![[self domainDefaults] mailCustomFromEnabled])
            {
              // No custom from -- enforce a valid email
              index = [mails indexOfObject: customEmail];
              if (index == NSNotFound)
                {
                  [identity setObject: [self systemEmail] forKey: @"email"];
                }
            }
        }
      else
        {
          // Email must be defined
          [identity setObject: [self systemEmail] forKey: @"email"];
        }
      if (![[self domainDefaults] mailCustomFromEnabled])
        {
          // No custom from -- enforce a valid fullname and remove reply-to
          [identity setObject: fullName forKey: @"fullName"];
          [identity removeObjectForKey: @"replyTo"];
        }
      if (!appendDeletegatedIdentities)
        {
          [identity setObject: [NSNumber numberWithBool: YES] forKey: @"isReadOnly"];
        }
      if ([[identity objectForKey: @"isDefault"] boolValue])
        {
          if (hasDefaultIdentity || !appendDeletegatedIdentities)
            [identity removeObjectForKey: @"isDefault"]; // only one possible default identity
          else
            hasDefaultIdentity = YES;
        }
      [identities replaceObjectAtIndex: count withObject: identity];
    }

  // Create an identity for each missing email address
  max = [mails count];
  for (count = 0; count < max; count++)
    {
      BOOL noIdentityForEmail;
      NSString *identityEmail;

      noIdentityForEmail = YES;
      customEmail = [mails objectAtIndex: count];
      for (index = 0; noIdentityForEmail && index < [identities count]; index++)
        {
          identity = [identities objectAtIndex: index];
          identityEmail = [identity objectForKey: @"email"];
          if ([customEmail caseInsensitiveCompare: identityEmail] == NSOrderedSame)
            {
              noIdentityForEmail = NO;
            }
        }

      if (noIdentityForEmail)
        {
          identity = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                            fullName, @"fullName",
                                                  customEmail, @"email", nil];
          if (appendDeletegatedIdentities &&
              count == 0 &&
              [identities count] == 0)
            {
              // First identity uses the system email -- mark it as the default and keep it editable
              [identity setObject: [NSNumber numberWithBool: YES] forKey: @"isDefault"];
              hasDefaultIdentity = YES;
            }
          else
            {
              // This additional identity should not appear in the identity manager of the Preferences
              [identity setObject: [NSNumber numberWithBool: YES] forKey: @"isReadOnly"];
              [identity setObject: [NSNumber numberWithBool: NO] forKey: @"isDefault"];
            }
          [identities addObject: identity];
        }
    }

  /* identities from delegators */
  if (appendDeletegatedIdentities)
    {
      delegators = [mailSettings objectForKey: @"DelegateFrom"];
      if (delegators)
        {
          BOOL dirty;
          NSDictionary *delegatorAccount, *delegatorSettings;
          NSMutableArray *validDelegators;
          NSString *delegatorLogin;
          SOGoUser *delegatorUser;

          dirty = NO;
          validDelegators = [NSMutableArray array];
          max = [delegators count];
          for (count = 0; count < max; count++)
            {
              // 1. Verify if delegator is valid
              delegatorLogin = [delegators objectAtIndex: count];
              delegatorUser = [SOGoUser userWithLogin: delegatorLogin];
              if (delegatorUser)
                {
                  // 2. Verify if delegator still delegates to user
                  delegatorSettings = [[delegatorUser userSettings] objectForKey: @"Mail"];
                  delegates = [delegatorSettings objectForKey: @"DelegateTo"];
                  if ([delegates containsObject: [self login]])
                    {
                      [validDelegators addObject: delegatorLogin];
                      delegatorAccount = [[delegatorUser mailAccountsWithDelegatedIdentities: NO] objectAtIndex: 0];
                      [identities addObjectsFromArray: [delegatorAccount objectForKey: @"identities"]];
                    }
                  else
                    dirty = YES;
                }
              else
                dirty = YES;
            }

          if (dirty)
            {
              [mailSettings setObject: validDelegators
                               forKey: @"DelegateFrom"];
              [_settings synchronize];
            }
        }
    }

  [mailAccount setObject: identities forKey: @"identities"];
  [identities release];

  if ([_defaults mailForceDefaultIdentity])
    [mailAccount setObject: [NSNumber numberWithBool: YES] forKey: @"forceDefaultIdentity"];

  // 6. Receipts
  if ([_defaults allowUserReceipt])
    {
      receipts = [NSMutableDictionary new];

      [receipts setObject: @"allow" forKey: @"receiptAction"];
      action = [_defaults userReceiptNonRecipientAction];
      if (action)
        [receipts setObject: action forKey: @"receiptNonRecipientAction"];
      action = [_defaults userReceiptOutsideDomainAction];
      if (action)
        [receipts setObject: action forKey: @"receiptOutsideDomainAction"];
      action = [_defaults userReceiptAnyAction];
      if (action)
        [receipts setObject: action forKey: @"receiptAnyAction"];

      [mailAccount setObject: receipts forKey: @"receipts"];
      [receipts release];
    }

  // 7. Mailboxes
  mailboxes = [NSMutableDictionary new];

  [self _migrateFolderSettings];
  [mailboxes setObject: [_defaults draftsFolderName]
                forKey: @"Drafts"];
  [mailboxes setObject: [_defaults sentFolderName]
                forKey: @"Sent"];
  [mailboxes setObject: [_defaults trashFolderName]
                forKey: @"Trash"];
  [mailboxes setObject: [_defaults junkFolderName]
                forKey: @"Junk"];
  [mailboxes setObject: [_defaults templatesFolderName]
                forKey: @"Templates"];
  [mailAccount setObject: mailboxes forKey: @"specialMailboxes"];
  [mailboxes release];

  // 8. Delegates
  delegates = [mailSettings objectForKey: @"DelegateTo"];
  if (!delegates)
    delegates = [NSArray array];
  else
    {
      NSMutableArray *allDelegates;
      SOGoUser *delegate;

      allDelegates = [NSMutableArray array];
      for (count = 0; count < [delegates count]; count++)
        {
          delegate = [SOGoUser userWithLogin: [delegates objectAtIndex: count]];
          [allDelegates addObject: [NSDictionary dictionaryWithObjectsAndKeys: [delegates objectAtIndex: count], @"uid",
                                                 [delegate cn], @"cn",
                                                 [delegate systemEmail], @"c_email", nil]];
        }

      delegates = allDelegates;
    }
  [mailAccount setObject: delegates  forKey: @"delegates"];

  // 9. Security
  if ([[self domainDefaults] mailCertificateEnabled] && [[_defaults mailCertificate] length])
    {
      security = [NSMutableDictionary new];

      [security setObject: [NSNumber numberWithBool: YES] forKey: @"hasCertificate"];

      if ([_defaults mailCertificateAlwaysSign])
        [security setObject: [NSNumber numberWithBool: YES] forKey: @"alwaysSign"];

      if ([_defaults mailCertificateAlwaysEncrypt])
        [security setObject: [NSNumber numberWithBool: YES] forKey: @"alwaysEncrypt"];

      [mailAccount setObject: security forKey: @"security"];
      [security release];
    }

  [mailAccounts addObject: mailAccount];
  [mailAccount release];
}

- (NSArray *) mailAccounts
{
  return [self mailAccountsWithDelegatedIdentities: YES];
}

- (NSArray *) mailAccountsWithDelegatedIdentities: (BOOL) appendDeletegatedIdentities
{
  NSArray *auxAccounts;

  if (!mailAccounts)
    {
      mailAccounts = [NSMutableArray new];
      [self _appendSystemMailAccountWithDelegatedIdentities: appendDeletegatedIdentities];
      if ([[self domainDefaults] mailAuxiliaryUserAccountsEnabled])
        {
          auxAccounts = [[self userDefaults] auxiliaryMailAccounts];
          if (auxAccounts)
          {
            //Check if we need to decrypt password
            NSString* sogoSecret;
            sogoSecret = [[SOGoSystemDefaults sharedSystemDefaults] sogoSecretValue];
            if(sogoSecret)
            {
              int i;
              NSString *encryptedPassword, *password, *iv, *tag;
              NSDictionary *account, *accountPassword;
              NSException* exception = nil;
              for (i = 0; i < [auxAccounts count]; i++)
              {
                account = [auxAccounts objectAtIndex: i];
                if (![[account objectForKey: @"password"] isKindOfClass: [NSDictionary class]])
                {
                  [self errorWithFormat:@"Can't decrypt the password for auxiliary account %@, is not a dictionnary",
                              [account objectForKey: @"name"]];
                  continue;
                }

                accountPassword = [account objectForKey: @"password"];
                encryptedPassword = [accountPassword objectForKey: @"cypher"];
                iv = [accountPassword objectForKey: @"iv"];
                tag = [accountPassword objectForKey: @"tag"];
                NS_DURING
                {
                  password = [encryptedPassword decryptAES256GCM: sogoSecret iv: iv tag: tag exception:&exception];
                }
                NS_HANDLER
                {
                  [self errorWithFormat:@"Can't decrypt the password for auxiliary account %@",
                              [account objectForKey: @"name"]];
                  password = [account objectForKey: @"password"];
                }
                NS_ENDHANDLER
                if(exception)
                  [self errorWithFormat:@"Can't decrypt the password for auxiliary account %@: %@",
                              [account objectForKey: @"name"], [exception reason]];
                else if(!password)
                  [self errorWithFormat:@"No exception but decyrpted password is empty for account %@",[account objectForKey: @"name"]];
                else
                  [account setObject: password forKey: @"password"];
              }
            }

            [mailAccounts addObjectsFromArray: auxAccounts];
          }
        }
    }

  return mailAccounts;
}

- (NSDictionary *) accountWithName: (NSString *) accountName;
{
  NSEnumerator *accounts;
  NSDictionary *mailAccount, *currentAccount;

  mailAccount = nil;

  accounts = [[self mailAccounts] objectEnumerator];
  while (!mailAccount
	 && ((currentAccount = [accounts nextObject])))
    if ([[currentAccount objectForKey: @"name"]
	  isEqualToString: accountName])
      mailAccount = currentAccount;

  return mailAccount;
}

- (NSArray *) allIdentities
{
  NSArray *identities;

  identities = [[self mailAccounts] objectsForKey: @"identities"
                                   notFoundMarker: nil];

  return [identities flattenedArray];
}

- (NSDictionary *) primaryIdentity
{
  NSArray *identities;
  NSDictionary *defaultIdentity, *defaultAccount;

  defaultIdentity = [self defaultIdentity];

  if (!defaultIdentity && [[self mailAccounts] count])
    {
      defaultAccount = [[self mailAccounts] objectAtIndex: 0];
      identities = [defaultAccount objectForKey: @"identities"];
      defaultIdentity = [identities objectAtIndex: 0];
    }

  return defaultIdentity;
}

/* folders */

// TODO: those methods should check whether the traversal stack in the context
//       already contains proper folders to improve caching behaviour

- (SOGoUserFolder *) homeFolderInContext: (id) context
{
  return [SOGoUserFolder objectWithName: login
                            inContainer: [WOApplication application]];
}

- (SOGoAppointmentFolders *) calendarsFolderInContext: (WOContext *) context
{
  return [[self homeFolderInContext: context] lookupName: @"Calendar"
                                               inContext: context
                                                 acquire: NO];
}

- (SOGoAppointmentFolder *) personalCalendarFolderInContext: (WOContext *) context
{
  return [[self calendarsFolderInContext: context] lookupPersonalFolder: @"personal"
                                                         ignoringRights: YES];
}

- (SOGoContactFolder *) personalContactsFolderInContext: (WOContext *) context
{
  SOGoContactFolders *folders;

  folders = [[self homeFolderInContext: context] lookupName: @"Contacts"
                                                  inContext: context
                                                    acquire: NO];

  return [folders lookupPersonalFolder: @"personal"
                        ignoringRights: YES];
}


- (NSArray *) rolesForObject: (NSObject *) object
                   inContext: (WOContext *) context
{
  NSMutableArray *rolesForObject;
  NSArray *sogoRoles;
  NSString *rqMethod;

  rolesForObject = [NSMutableArray array];

  sogoRoles = [super rolesForObject: object inContext: context];
  if (sogoRoles)
    [rolesForObject addObjectsFromArray: sogoRoles];

  if ([self isSuperUser]
      || [[object ownerInContext: context] isEqualToString: login])
    [rolesForObject addObject: SoRole_Owner];
  else if ([object isKindOfClass: [SOGoObject class]])
    {
      sogoRoles = [(SOGoObject *) object aclsForUser: login];
      if ([sogoRoles count])
        [rolesForObject addObjectsFromArray: sogoRoles];
      sogoRoles = [(SOGoObject *) object subscriptionRoles];
      if ([sogoRoles firstObjectCommonWithArray: rolesForObject])
	[rolesForObject addObject: SOGoRole_AuthorizedSubscriber];
      if ([login isEqualToString: @"anonymous"]
          && [(SOGoObject *) object isInPublicZone])
        [rolesForObject addObject: SOGoRole_PublicUser];
    }

#warning this is a hack to work-around the poor implementation of PROPPATCH in SOPE
  rqMethod = [[context request] method];
  if ([rqMethod isEqualToString: @"PROPPATCH"])
    [rolesForObject addObject: @"PROPPATCHer"];

  return rolesForObject;
}

- (BOOL) isEqual: (id) otherUser
{
  return ([otherUser isKindOfClass: [SoUser class]]
	  && [login isEqualToString: [otherUser login]]);
}

- (BOOL) isSuperUser
{
  [self domainDefaults];

  return [[_domainDefaults superUsernames] containsObject: login];
}

- (BOOL) canAuthenticate
{
  id authValue;

  authValue = [self _fetchFieldForUser: @"canAuthenticate"];

  return [authValue boolValue];
}

- (NSString *) totpKey
{
#if defined(MFA_CONFIG)
  NSString *key, *result;
  const char *s;
  char *secret;

  size_t s_len, secret_len;

  key = [[[self userSettings] userPrivateSalt] substringToIndex: 12];
  s = [key UTF8String];
  s_len = strlen(s);

  oath_init();
  oath_base32_encode(s,s_len, &secret, &secret_len);
  oath_done();

  result = [[NSString alloc] initWithBytesNoCopy: secret
                                          length: secret_len
                                        encoding: NSASCIIStringEncoding
                                    freeWhenDone: YES];

  return [result autorelease];
#else
  return nil;
#endif
}

/* resource */
- (BOOL) isResource
{
  NSNumber *v;

  v = [self _fetchFieldForUser: @"isResource"];

  return (v && [v intValue]);
}

- (int) numberOfSimultaneousBookings
{
  NSNumber *v;

  v = [self _fetchFieldForUser: @"numberOfSimultaneousBookings"];

  if (v)
    return [v intValue];

  return 0;
}

/* module access */
- (BOOL) canAccessModule: (NSString *) module
{
  id accessValue;

  accessValue = [self _fetchFieldForUser:
			[NSString stringWithFormat: @"%@Access", module]];

  return [accessValue boolValue];
}

/* Encryption */
+ (NSString *) getEncryptedUsernameIfNeeded:(NSString *)username request: (WORequest *)request
{
  NSException *exception;
  NSString *tmp, *cacheKey;
  SOGoCache *cache;

  if (![[SOGoSystemDefaults sharedSystemDefaults] isURLEncryptionEnabled] || [username isEqualToString: @"anonymous"] || [[request requestHandlerKey] isEqualToString:@"dav"])
    return username;

  cache = [SOGoCache sharedCache];
  cacheKey = [NSString stringWithFormat: @"%@_%@", kEncryptedUserNamePrefix, username];
  
  exception = nil;
  tmp = nil;

  tmp = [cache valueForKey: cacheKey];
  if (tmp) {
    return tmp;
  } else {
    if (username && [username length] > 0) {
      tmp = [username encodeAES128ECBBase64: [[SOGoSystemDefaults sharedSystemDefaults] urlEncryptionPassphrase] encodedURL:YES exception: &exception];
      if (!exception) {
        [cache setValue:tmp forKey:cacheKey];
        return tmp;
      } else {
        [self errorWithFormat: @"URL Encryption error : %@", [exception reason]];
        return username;
      }
    } else {
      [self logWithFormat: @"Empty username for encryption"];
      return username;
    }
  }
}

+ (NSString *) getDecryptedUsernameIfNeeded:(NSString *)username request: (WORequest *)request
{
  NSException *exception;
  NSString *tmp, *cacheKey;
  SOGoCache *cache;

  if (![[SOGoSystemDefaults sharedSystemDefaults] isURLEncryptionEnabled] || [username isEqualToString: @"anonymous"] || [[request requestHandlerKey] isEqualToString:@"dav"])
    return username;

  cache = [SOGoCache sharedCache];
  cacheKey = [NSString stringWithFormat: @"%@_%@", kEncryptedUserNamePrefix, username];
  exception = nil;
  tmp = nil;
  
  tmp = [cache valueForKey: cacheKey];
  if (tmp) {
    return tmp;
  } else {
    if (username && [username length] > 0) {
      tmp = [username decodeAES128ECBBase64: [[SOGoSystemDefaults sharedSystemDefaults] urlEncryptionPassphrase] encodedURL:YES exception: &exception];
      if (tmp) {
        [cache setValue:tmp forKey:cacheKey];
      } else {
        [cache setValue:username forKey:cacheKey];
      }
      if (!exception) {
        return tmp;
      } else {
        [self errorWithFormat: @"URL Decryption error : %@", [exception reason]];
        return username;
      }
    } else {
      [self errorWithFormat: @"Empty username for decryption"];
      return username;
    }
    
  }
}


@end /* SOGoUser */
