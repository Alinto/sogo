/*
  Copyright (C) 2006-2009 Inverse inc.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSURL.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/SoObject.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import "LDAPUserManager.h"
#import "NSArray+Utilities.h"
#import "SOGoCache.h"
#import "SOGoDateFormatter.h"
#import "SOGoObject.h"
#import "SOGoPermissions.h"
#import "SOGoUserDefaults.h"
#import "SOGoUserFolder.h"

#import "../../Main/SOGo.h"

#import "SOGoUser.h"

static NSTimeZone *serverTimeZone = nil;
static NSString *fallbackIMAP4Server = nil;
static BOOL fallbackIsConfigured = NO;
static NSString *defaultLanguage = nil;
static NSString *defaultReplyPlacement = nil;
static NSString *defaultSignaturePlacement = nil;
static NSString *defaultMessageForwarding = nil;
static NSString *defaultMessageCheck = nil;
static NSArray *superUsernames = nil;
static NSURL *SOGoProfileURL = nil;
// static BOOL acceptAnyUser = NO;
static int sogoFirstDayOfWeek = -1;
static int defaultDayStartTime = -1;
static int defaultDayEndTime = -1;

NSString *SOGoWeekStartJanuary1 = @"January1";
NSString *SOGoWeekStartFirst4DayWeek = @"First4DayWeek";
NSString *SOGoWeekStartFirstFullWeek = @"FirstFullWeek";

@interface NSObject (SOGoRoles)

- (NSArray *) rolesOfUser: (NSString *) uid;

@end

@implementation SoUser (SOGoExtension)

- (NSString *) language
{
  return [SOGoUser language];
}

@end

@implementation SOGoUser

static int
_timeValue (NSString *key)
{
  int time;

  if (key && [key length] > 1)
    time = [[key substringToIndex: 2] intValue];
  else
    time = -1;

  return time;
}

+ (void) initialize
{
  NSString *tzName;
  NSUserDefaults *ud;
  NSString *profileURL;

  ud = [NSUserDefaults standardUserDefaults];
  if (!serverTimeZone)
    {
      tzName = [ud stringForKey: @"SOGoServerTimeZone"];
      if (!tzName)
        tzName = @"UTC";
      serverTimeZone = [NSTimeZone timeZoneWithName: tzName];
      [serverTimeZone retain];
    }
  if (sogoFirstDayOfWeek == -1)
    sogoFirstDayOfWeek = [ud integerForKey: @"SOGoFirstDayOfWeek"];
  if (defaultDayStartTime == -1)
    {
      defaultDayStartTime
	= _timeValue ([ud stringForKey: @"SOGoDayStartTime"]);
      if (defaultDayStartTime == -1)
	defaultDayStartTime = 8;
    }
  if (defaultDayEndTime == -1)
    {
      defaultDayEndTime
	= _timeValue ([ud stringForKey: @"SOGoDayEndTime"]);
      if (defaultDayEndTime == -1)
	defaultDayEndTime = 18;
    }

  if (!SOGoProfileURL)
    {
      profileURL = [ud stringForKey: @"SOGoProfileURL"];
      if (!profileURL)
	{
	  profileURL = [ud stringForKey: @"AgenorProfileURL"];
	  if (profileURL)
	    {
	      [ud setObject: profileURL forKey: @"SOGoProfileURL"];
	      [ud removeObjectForKey: @"AgenorProfileURL"];
	      [ud synchronize];
	      [self warnWithFormat: @"the user defaults key 'AgenorProfileURL'"
		    @" was renamed to 'SOGoProfileURL'"];
	    }
	}
      SOGoProfileURL = [[NSURL alloc] initWithString: profileURL];
    }
  if (!fallbackIMAP4Server)
    ASSIGN (fallbackIMAP4Server,
	    [ud stringForKey: @"SOGoFallbackIMAP4Server"]);
  if (fallbackIMAP4Server)
    fallbackIsConfigured = YES;
  else
    {
      [self warnWithFormat:
	      @"no server specified for SOGoFallbackIMAP4Server,"
	    @" value set to 'localhost'"];
      fallbackIMAP4Server = @"localhost";
    }
  if (!defaultLanguage)
    {
      ASSIGN (defaultLanguage, [ud stringForKey: @"SOGoDefaultLanguage"]);
      if (!defaultLanguage)
	ASSIGN (defaultLanguage, @"English");
    }
  if (!defaultReplyPlacement)
    {
      ASSIGN (defaultReplyPlacement, [ud stringForKey: @"SOGoMailReplyPlacement"]);
      if (!defaultReplyPlacement)
	ASSIGN (defaultReplyPlacement, @"below");
    }
  if (!defaultSignaturePlacement)
    {
      ASSIGN (defaultSignaturePlacement, [ud stringForKey: @"SOGoMailSignaturePlacement"]);
      if (!defaultSignaturePlacement)
	ASSIGN (defaultSignaturePlacement, @"below");
    }
  if (!defaultMessageForwarding)
    {
      ASSIGN (defaultMessageForwarding, [ud stringForKey: @"SOGoMailMessageForwarding"]);
      if (!defaultMessageForwarding)
	ASSIGN (defaultMessageForwarding, @"inline");
    }
  if (!defaultMessageCheck)
    {
      ASSIGN (defaultMessageCheck, [ud stringForKey: @"SOGoMailMessageCheck"]);
      if (!defaultMessageCheck)
	ASSIGN (defaultMessageCheck, @"manually");
    }

  if (!superUsernames)
    ASSIGN (superUsernames, [ud arrayForKey: @"SOGoSuperUsernames"]);

//   acceptAnyUser = ([[ud stringForKey: @"SOGoAuthentificationMethod"]
// 		     isEqualToString: @"bypass"]);
}

+ (NSString *) language
{
  NSArray *bLanguages;
  WOContext *context;
  NSString *lng;

  context = [[WOApplication application] context];
  bLanguages = [[context request] browserLanguages];
  if ([bLanguages count] > 0)
    lng = [bLanguages objectAtIndex: 0];

  if (![lng length])
    lng = defaultLanguage;

  return lng;
}

+ (NSString *) fallbackIMAP4Server
{
  return fallbackIMAP4Server;
}

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
      user = [[self alloc] initWithLogin: newLogin  roles: newRoles  trust: b];
      if (user)
	{
	  [user autorelease];
 	  [cache registerUser: user withName: newLogin];
	}
    }
  if (newRoles)
    [user setPrimaryRoles: newRoles];

  return user;
}

- (id) initWithLogin: (NSString *) newLogin
	       roles: (NSArray *) newRoles
	       trust: (BOOL) b
{
  LDAPUserManager *um;
  NSString *realUID;

  _defaults = nil;
  _settings = nil;
  
  if ([newLogin isEqualToString: @"anonymous"]
      || [newLogin isEqualToString: @"freebusy"])
    realUID = newLogin;
  else
    {
      if (b)
	realUID = newLogin;
      else
	{
	  um = [LDAPUserManager sharedUserManager];
	  realUID = [[um contactInfosForUserWithUIDorEmail: newLogin]
		      objectForKey: @"c_uid"];
	}
    }

  if ([realUID length])
    {
      if ((self = [super initWithLogin: realUID roles: newRoles]))
	{
	  allEmails = nil;
	  currentPassword = nil;
	  cn = nil;
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
  [_settings release];
  [allEmails release];
  [currentPassword release];
  [cn release];
  [language release];
  [super dealloc];
}

- (void) setPrimaryRoles: (NSArray *) newRoles
{
  ASSIGN(roles, newRoles);
}

- (void) setCurrentPassword: (NSString *) newPassword
{
  ASSIGN(currentPassword, newPassword);
}

- (NSString *) currentPassword
{
  return currentPassword;
}

- (id) _fetchFieldForUser: (NSString *) field
{
  NSDictionary *contactInfos;
  LDAPUserManager *um;

  um = [LDAPUserManager sharedUserManager];
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
  [cn retain];
}

/* properties */
- (NSArray *) allEmails
{
  if (!allEmails)
    [self _fetchAllEmails];

  return allEmails;
}

- (NSString *) systemEmail
{
  if (!allEmails)
    [self _fetchAllEmails];

  return [allEmails lastObject];
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
  NSMutableDictionary *currentIdentity, *defaultIdentity;
  NSEnumerator *identities;

  defaultIdentity = nil;

  identities = [[self allIdentities] objectEnumerator];
  while (!defaultIdentity
	 && (currentIdentity = [identities nextObject]))
    if ([[currentIdentity objectForKey: @"isDefault"] boolValue])
      defaultIdentity = currentIdentity;

  return defaultIdentity;
}

- (void) saveMailAccounts
{
  BOOL doSave;

  doSave = YES;
  if (!fallbackIsConfigured)
    {
      [self logWithFormat: @"'SOGoFallbackIMAP4Server' is not set"];
      doSave = NO;
    }
  if (![LDAPUserManager defaultMailDomainIsConfigured])
    {
      [self logWithFormat: @"'SOGoDefaultMailDomain' is not set"];
      doSave = NO;
    }
  doSave = NO;
  if (doSave)
    [[self userDefaults] setObject: [self mailAccounts]
			 forKey: @"MailAccounts"];
  else
    [self logWithFormat: @"saving mail accounts is disabled until the"
	  @" variable(s) mentionned above are configured"];
}

- (NSURL *) freeBusyURL
{
  return nil;
}

- (SOGoDateFormatter *) dateFormatterInContext: (WOContext *) context
{
  SOGoDateFormatter *dateFormatter;
  NSString *format;
  NSUserDefaults *ud;

  dateFormatter = [SOGoDateFormatter new];
  [dateFormatter autorelease];

  [dateFormatter setLocale: [[WOApplication application] localeForLanguageNamed: [self language]]];
  ud = [self userDefaults];
  format = [ud stringForKey: @"ShortDateFormat"];
  if (format)
    [dateFormatter setShortDateFormat: format];
  format = [ud stringForKey: @"LongDateFormat"];
  if (format)
    [dateFormatter setLongDateFormat: format];
  format = [ud stringForKey: @"TimeFormat"];
  if (format)
    [dateFormatter setTimeFormat: format];
  
  return dateFormatter;
}

- (SOGoUserDefaults *) primaryUserDefaults
{
  SOGoUserDefaults *o;

  o = [[SOGoUserDefaults alloc] initWithTableURL: SOGoProfileURL
                                             uid: login
                                       fieldName: @"c_defaults"];

  return o;
}

- (SOGoUserDefaults *) primaryUserSettings
{
  SOGoUserDefaults *o;

  o = [[SOGoUserDefaults alloc] initWithTableURL: SOGoProfileURL
                                             uid: login
                                       fieldName: @"c_settings"];

  return o;
}

- (NSUserDefaults *) userDefaults
{
  NSDictionary *values;

  if (!_defaults)    
    {
      _defaults = [self primaryUserDefaults];
      if (_defaults)
	{
	  values = [[SOGoCache sharedCache] userDefaultsForLogin: login];

	  if (values)
	    {
	      [_defaults setValues: values];
	    }
	  else
	    {
	      [_defaults fetchProfile];
	      values = [_defaults values];
	      
	      if (values)
		{		  
		  // Required parameters for the Web interface. This will trigger the
		  // preferences to load so it's important to leave those calls here.
		  if (![[_defaults stringForKey: @"ReplyPlacement"] length])
		    [_defaults setObject: defaultReplyPlacement forKey: @"ReplyPlacement"];
		  if (![[_defaults stringForKey: @"SignaturePlacement"] length])
		    [_defaults setObject: defaultSignaturePlacement forKey: @"SignaturePlacement"];
		  if (![[_defaults stringForKey: @"MessageForwarding"] length])
		    [_defaults setObject: defaultMessageForwarding forKey: @"MessageForwarding"];
		  if (![[_defaults stringForKey: @"MessageCheck"] length])
		    [_defaults setObject: defaultMessageCheck forKey: @"MessageCheck"];

		  [[SOGoCache sharedCache] cacheValues: [_defaults values]  ofType: @"defaults"  forLogin: login];
		}
	    }
	  
	  // See explanation in -language
	  [self invalidateLanguage];
	}
    }
  //else
  //  NSLog(@"User defaults cache hit for %@", login);

  return (NSUserDefaults *) _defaults;
}

- (NSUserDefaults *) userSettings
{
  NSDictionary *values;

  if (!_settings)    
    {
      _settings = [self primaryUserSettings];
      if (_settings)
	{
	  values = [[SOGoCache sharedCache] userSettingsForLogin: login];
	  
	  if (values)
	    {
	      [_settings setValues: values];
	    }
	  else
	    {
	      [_settings fetchProfile];
	      values = [_settings values];
	      
	      if (values)
		{
		  [[SOGoCache sharedCache] cacheValues: values  ofType: @"settings"  forLogin: login];
		}
	    }
	  
	  // See explanation in -language
	  [self invalidateLanguage];
	}
    }
  //else
  //  NSLog(@"User settings cache hit for %@", login);

  return (NSUserDefaults *) _settings;
}

- (void) invalidateLanguage
{
  DESTROY(language);
}

- (NSString *) language
{
  if (![language length])
    {
      language = [[self userDefaults] stringForKey: @"Language"];
      // This is a workaround until we handle the connection errors to the db in a
      // better way. It enables us to avoid retrieving the userDefaults too
      // many times when the DB is down, causing a huge delay.
      if (![language length])
        language = [SOGoUser language];

      [language retain];
    }

  return language;
}

- (NSTimeZone *) timeZone
{
  NSTimeZone *userTimeZone;
  NSString *timeZoneName;
 
  timeZoneName = [[self userDefaults] stringForKey: @"TimeZone"];
  userTimeZone = nil;

  if ([timeZoneName length] > 0)
    userTimeZone = [NSTimeZone timeZoneWithName: timeZoneName];
  if (!userTimeZone)
    userTimeZone = serverTimeZone;
  
  return userTimeZone;
}

- (NSTimeZone *) serverTimeZone
{
  return serverTimeZone;
}

- (unsigned int) firstDayOfWeek
{
  unsigned int firstDayOfWeek;
  NSNumber *value;

  value = [[self userDefaults] objectForKey: @"WeekStartDay"];
  if (value)
    firstDayOfWeek = [value unsignedIntValue];
  else
    firstDayOfWeek = sogoFirstDayOfWeek;

  return firstDayOfWeek;
}

- (NSCalendarDate *) firstDayOfWeekForDate: (NSCalendarDate *) date
{
  int offset;
  NSCalendarDate *firstDay;

  offset = ([self firstDayOfWeek] - [date dayOfWeek]);
  if (offset > 0)
    offset -= 7;

  firstDay = [date addTimeInterval: offset * 86400];

  return firstDay;
}

- (unsigned int) dayOfWeekForDate: (NSCalendarDate *) date
{
  unsigned int offset, baseDayOfWeek, dayOfWeek;

  offset = [self firstDayOfWeek];
  baseDayOfWeek = [date dayOfWeek];
  if (offset > baseDayOfWeek)
    baseDayOfWeek += 7;

  dayOfWeek = baseDayOfWeek - offset;

  return dayOfWeek;
}

- (unsigned int) dayStartHour
{
  int limit;

  limit = _timeValue ([[self userDefaults] stringForKey: @"DayStartTime"]);
  if (limit == -1)
    limit = defaultDayStartTime;

  return limit;
}

- (unsigned int) dayEndHour
{
  int limit;

  limit = _timeValue ([[self userDefaults] stringForKey: @"DayEndTime"]);
  if (limit == -1)
    limit = defaultDayEndTime;

  return limit;
}

- (NSCalendarDate *) firstWeekOfYearForDate: (NSCalendarDate *) date
{
  NSString *firstWeekRule;
  NSCalendarDate *januaryFirst, *firstWeek;
  unsigned int dayOfWeek;

  firstWeekRule = [[self userDefaults] objectForKey: @"FirstWeek"];

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
  NSCalendarDate *firstWeek;
  unsigned int weekNumber;

  firstWeek = [self firstWeekOfYearForDate: date];
  if ([firstWeek earlierDate: date] == firstWeek)
    weekNumber = ([date timeIntervalSinceDate: firstWeek]
		  / (86400 * 7) + 1);
  else
    weekNumber = 0;

  return weekNumber;
}

/* mail */
- (NSArray *) _prepareDefaultMailAccounts
{
  NSMutableDictionary *mailAccount, *identity;
  NSMutableArray *identities, *mailAccounts;
  NSString *name, *fullName, *imapLogin, *imapServer;
  NSArray *mails;
  unsigned int count, max;

  imapLogin = [[LDAPUserManager sharedUserManager] getImapLoginForUID: login];
  imapServer = [self _fetchFieldForUser: @"c_imaphostname"];
  if (!imapServer)
    imapServer = fallbackIMAP4Server;
  mailAccount = [NSMutableDictionary dictionary];
  name = [NSString stringWithFormat: @"%@@%@",
		   imapLogin, imapServer];
  [mailAccount setObject: imapLogin forKey: @"userName"];
  [mailAccount setObject: imapServer forKey: @"serverName"];
  [mailAccount setObject: name forKey: @"name"];

  identities = [NSMutableArray array];
  mails = [self allEmails];

  max = [mails count];
  if (max > 1)
    max--;
  for (count = 0; count < max; count++)
    {
      identity = [NSMutableDictionary dictionary];
      fullName = [self cn];
      if (![fullName length])
	fullName = login;
      [identity setObject: fullName forKey: @"fullName"];
      [identity setObject: [mails objectAtIndex: count] forKey: @"email"];
      [identities addObject: identity];
    }
  [[identities objectAtIndex: 0] setObject: [NSNumber numberWithBool: YES]
				 forKey: @"isDefault"];

  [mailAccount setObject: identities forKey: @"identities"];

  mailAccounts = [NSMutableArray array];
  [mailAccounts addObject: mailAccount];

  return mailAccounts;
}

- (NSArray *) mailAccounts
{
  NSUserDefaults *ud;
  NSArray *mailAccounts;

  ud = [self userDefaults];
  mailAccounts = [ud objectForKey: @"MailAccounts"];
  if (!mailAccounts)
    mailAccounts = [self _prepareDefaultMailAccounts];

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

/*
@interface SOGoMailIdentity : NSObject
{
  NSString *name;
  NSString *email;
  NSString *replyTo;
  NSString *organization;
  NSString *signature;
  NSString *vCard;
  NSString *sentFolderName;
  NSString *sentBCC;
  NSString *draftsFolderName;
  NSString *templatesFolderName;
  struct
  {
    int composeHTML:1;
    int reserved:31;
  } idFlags;
}

- (void) setName: (NSString *) _value;
- (NSString *) name;

- (void) setEmail: (NSString *) _value;
- (NSString *) email;

- (void) setReplyTo: (NSString *) _value;
- (NSString *) replyTo;

- (void) setOrganization: (NSString *) _value;
- (NSString *) organization;

- (void) setSignature: (NSString *) _value;
- (NSString *) signature;
- (BOOL) hasSignature;

- (void) setVCard: (NSString *) _value;
- (NSString *) vCard;
- (BOOL) hasVCard;

- (void) setSentFolderName: (NSString *) _value;
- (NSString *) sentFolderName;

- (void) setSentBCC: (NSString *) _value;
- (NSString *) sentBCC;

- (void) setDraftsFolderName: (NSString *) _value;
- (NSString *) draftsFolderName;

- (void) setTemplatesFolderName: (NSString *) _value;
- (NSString *) templatesFolderName;

@end */

- (NSArray *) allIdentities
{
  NSArray *identities;

  identities = [[self mailAccounts] objectsForKey: @"identities"
				    notFoundMarker: nil];

  return [identities flattenedArray];
}

- (NSDictionary *) primaryIdentity
{
  NSDictionary *defaultAccount;

  defaultAccount = [[self mailAccounts] objectAtIndex: 0];

  return [[defaultAccount objectForKey: @"identities"] objectAtIndex: 0];
}

- (void) migrateSignature
{
  NSString *signature;
  NSUserDefaults *ud;

  signature = [[self primaryIdentity] objectForKey: @"signature"];

  if ([signature length])
    {
      ud = [self userDefaults];
      [ud setObject: signature forKey: @"MailSignature"];
      [ud removeObjectForKey: @"MailAccounts"];
      [ud synchronize];
    }
}

- (NSString *) signature
{
  [self migrateSignature];

  return [[self userDefaults] stringForKey: @"MailSignature"];
}

- (NSString *) replyPlacement
{
  return [[self userDefaults] stringForKey: @"ReplyPlacement"];
}

- (NSString *) signaturePlacement
{
  return [[self userDefaults] stringForKey: @"SignaturePlacement"];
}

- (NSString *) messageForwarding
{
  return [[self userDefaults] stringForKey: @"MessageForwarding"];
}

/* folders */

// TODO: those methods should check whether the traversal stack in the context
//       already contains proper folders to improve caching behaviour

- (SOGoUserFolder *) homeFolderInContext: (id) context
{
  return [[WOApplication application] lookupName: [self login]
                                       inContext: context
                                         acquire: NO];
}

- (SOGoAppointmentFolders *) calendarsFolderInContext: (WOContext *) context
{
  return [[self homeFolderInContext: context] lookupName: @"Calendar"
                                               inContext: context
                                                 acquire: NO];
}

- (SOGoAppointmentFolder *)
 personalCalendarFolderInContext: (WOContext *) context
{
  return [[self calendarsFolderInContext: context] lookupName: @"personal"
						   inContext: context
						   acquire: NO];
}

// - (id) schedulingCalendarInContext: (id) _ctx
// {
//   /* Note: watch out for cyclic references */
//   id folder;

//   folder = [(WOContext *)_ctx objectForKey:@"ActiveUserCalendar"];
//   if (folder != nil)
//     return [folder isNotNull] ? folder : nil;

//   folder = [self homeFolderInContext:_ctx];
//   if ([folder isKindOfClass:[NSException class]])
//     return folder;

//   folder = [folder lookupName:@"Calendar" inContext:_ctx acquire:NO];
//   if ([folder isKindOfClass:[NSException class]])
//     return folder;

//   [(WOContext *)_ctx setObject:folder ? folder : [NSNull null]
//                 forKey:@"ActiveUserCalendar"];
//   return folder;
// }

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
  return [superUsernames containsObject: login];
}

/* module access */
- (BOOL) canAccessModule: (NSString *) module
{
  NSString *accessValue;

  accessValue = [self _fetchFieldForUser:
			[NSString stringWithFormat: @"%@Access", module]];

  return [accessValue boolValue];
}

@end /* SOGoUser */
