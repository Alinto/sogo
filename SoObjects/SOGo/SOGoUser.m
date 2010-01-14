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
#import <Foundation/NSValue.h>
#import <Foundation/NSURL.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/SoObject.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import "NSArray+Utilities.h"
#import "SOGoCache.h"
#import "SOGoDateFormatter.h"
#import "SOGoDomainDefaults.h"
#import "SOGoObject.h"
#import "SOGoPermissions.h"
#import "SOGoSystemDefaults.h"
#import "SOGoUserDefaults.h"
#import "SOGoUserFolder.h"
#import "SOGoUserManager.h"
#import "SOGoUserProfile.h"
#import "SOGoUserSettings.h"

#import "../../Main/SOGo.h"

#import "SOGoUser.h"

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
  SOGoUserManager *um;
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
	  um = [SOGoUserManager sharedUserManager];
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
          _defaults = nil;
          _domainDefaults = nil;
          _settings = nil;
          allEmails = nil;
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
  [language release];
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
  [cn retain];
}

/* properties */
- (NSString *) domain
{
  return [self _fetchFieldForUser: @"c_domain"];
}

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

- (SOGoDateFormatter *) dateFormatterInContext: (WOContext *) context
{
  SOGoDateFormatter *dateFormatter;
  NSString *format;
  SOGoUserDefaults *ud;
  NSDictionary *locale;

  dateFormatter = [SOGoDateFormatter new];
  [dateFormatter autorelease];

  ud = [self userDefaults];
  locale = [[WOApplication application] localeForLanguageNamed: [ud language]];
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
              [self errorWithFormat: @"domain '%@' does not exist!", domain];
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
- (NSArray *) mailAccounts
{
  NSMutableDictionary *mailAccount, *identity;
  NSMutableArray *identities;
  NSString *name, *fullName, *imapLogin, *imapServer;
  NSArray *mails;
  unsigned int count, max;

  if (!mailAccounts)
    {
      imapLogin = [[SOGoUserManager sharedUserManager]
                    getImapLoginForUID: login];
      imapServer = [self _fetchFieldForUser: @"c_imaphostname"];
      if (!imapServer)
        imapServer = [[self domainDefaults] imapServer];
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
      
      mailAccounts = [NSArray arrayWithObject: mailAccount];
      [mailAccounts retain];
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
  [self domainDefaults];

  return [[_domainDefaults superUsernames] containsObject: login];
}

/* module access */
- (BOOL) canAccessModule: (NSString *) module
{
  id accessValue;

  accessValue = [self _fetchFieldForUser:
			[NSString stringWithFormat: @"%@Access", module]];

  return [accessValue boolValue];
}

@end /* SOGoUser */
