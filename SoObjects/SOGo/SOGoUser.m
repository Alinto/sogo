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

#import <Foundation/NSArray.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/SoObject.h>
#import <NGExtensions/NSNull+misc.h>

#import "AgenorUserDefaults.h"
#import "LDAPUserManager.h"
#import "SOGoDateFormatter.h"
#import "SOGoObject.h"
#import "SOGoPermissions.h"
#import "NSArray+Utilities.h"

#import "SOGoUser.h"

static NSTimeZone *serverTimeZone = nil;
static NSString *fallbackIMAP4Server = nil;
static NSString *defaultLanguage = nil;
static NSString *superUsername = nil;
static NSURL *AgenorProfileURL = nil;
static BOOL acceptAnyUser = NO;

NSString *SOGoWeekStartHideWeekNumbers = @"HideWeekNumbers";
NSString *SOGoWeekStartJanuary1 = @"January1";
NSString *SOGoWeekStartFirst4DayWeek = @"First4DayWeek";
NSString *SOGoWeekStartFirstFullWeek = @"FirstFullWeek";

@interface NSObject (SOGoRoles)

- (NSArray *) rolesOfUser: (NSString *) uid;

@end

@implementation SOGoUser

+ (void) initialize
{
  NSString *tzName, *nsUsername;
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
  if (!AgenorProfileURL)
    {
      profileURL = [ud stringForKey: @"AgenorProfileURL"];
      AgenorProfileURL = [[NSURL alloc] initWithString: profileURL];
    }
  if (!fallbackIMAP4Server)
    ASSIGN (fallbackIMAP4Server,
	    [ud stringForKey: @"SOGoFallbackIMAP4Server"]);
  if (!defaultLanguage)
    {
      ASSIGN (defaultLanguage, [ud stringForKey: @"SOGoDefaultLanguage"]);
      if (!defaultLanguage)
	ASSIGN (defaultLanguage, @"English");
    }
  if (!superUsername)
    {
      nsUsername = [ud stringForKey: @"SOGoSuperUsername"];
      if ([nsUsername length] > 0)
	ASSIGN (superUsername, nsUsername);
    }

  acceptAnyUser = ([[ud stringForKey: @"SOGoAuthentificationMethod"]
		     isEqualToString: @"bypass"]);
}

+ (SOGoUser *) userWithLogin: (NSString *) newLogin
		       roles: (NSArray *) newRoles
{
  SOGoUser *user;

  user = [[self alloc] initWithLogin: newLogin roles: newRoles];
  [user autorelease];

  return user;
}

- (id) init
{
  if ((self = [super init]))
    {
      userDefaults = nil;
      userSettings = nil;
      allEmails = nil;
      language = nil;
      currentPassword = nil;
      dateFormatter = nil;
    }

  return self;
}

- (id) initWithLogin: (NSString *) newLogin
	       roles: (NSArray *) newRoles
{
  LDAPUserManager *um;
  NSString *realUID;

  if (acceptAnyUser
      || [newLogin isEqualToString: @"anonymous"]
      || [newLogin isEqualToString: @"freebusy"])
    realUID = newLogin;
  else
    {
      um = [LDAPUserManager sharedUserManager];
      realUID = [[um contactInfosForUserWithUIDorEmail: newLogin]
		  objectForKey: @"c_uid"];
    }
  self = [super initWithLogin: realUID roles: newRoles];

  return self;
}

- (void) dealloc
{
  [currentPassword release];
  [userDefaults release];
  [userSettings release];
  [allEmails release];
  [language release];
  [dateFormatter release];
  [super dealloc];
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

// - (NSString *) fullEmail
// {
//   return [[LDAPUserManager sharedUserManager] getFullEmailForUID: login];
// }

// - (NSString *) primaryEmail
// {
//   if (!allEmails)
//     [self _fetchAllEmails];

//   return [allEmails objectAtIndex: 0];
// }

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

// - (NSString *) primaryMailServer
// {
//   return [[self userManager] getServerForUID: [self login]];
// }

// - (NSArray *) additionalIMAP4AccountStrings
// {
//   return [[self userManager]getSharedMailboxAccountStringsForUID: [self login]];
// }

// - (NSArray *) additionalEMailAddresses
// {
//   return [[self userManager] getSharedMailboxEMailsForUID: [self login]];
// }

// - (NSDictionary *) additionalIMAP4AccountsAndEMails
// {
//   return [[self userManager] getSharedMailboxesAndEMailsForUID: [self login]];
// }

- (NSURL *) freeBusyURL
{
  return nil;
}

- (SOGoDateFormatter *) dateFormatterInContext: (WOContext *) context
{
  NSString *format;
  NSUserDefaults *ud;

  if (!dateFormatter)
    {
      dateFormatter = [SOGoDateFormatter new];
      [dateFormatter setLocale: [context valueForKey: @"locale"]];
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
    }

  return dateFormatter;
}

/* defaults */

- (NSUserDefaults *) userDefaults
{
  if (!userDefaults)
    userDefaults
      = [[AgenorUserDefaults alloc] initWithTableURL: AgenorProfileURL
				    uid: login
				    fieldName: @"c_defaults"];

  return userDefaults;
}

- (NSUserDefaults *) userSettings
{
  if (!userSettings)
    userSettings
      = [[AgenorUserDefaults alloc] initWithTableURL: AgenorProfileURL
				    uid: login
				    fieldName: @"c_settings"];

  return userSettings;
}

- (NSString *) language
{
  NSArray *bLanguages;
  WOContext *context;

  if (!language)
    {
      language = [[self userDefaults] stringForKey: @"Language"];
      if (![language length])
	{
	  context = [[WOApplication application] context];
	  bLanguages = [[context request] browserLanguages];
	  if ([bLanguages count] > 0)
	    language = [bLanguages objectAtIndex: 0];
	}
      if (![language length])
	language = defaultLanguage;
      [language retain];
    }

  return language;
}

- (NSTimeZone *) timeZone
{
  NSString *timeZoneName;

  if (!userTimeZone)
    {
      timeZoneName = [[self userDefaults] stringForKey: @"TimeZone"];
      if ([timeZoneName length] > 0)
	userTimeZone = [NSTimeZone timeZoneWithName: timeZoneName];
      if (!userTimeZone)
	userTimeZone = serverTimeZone;
      [userTimeZone retain];
    }

  return userTimeZone;
}

- (NSTimeZone *) serverTimeZone
{
  return serverTimeZone;
}

/* mail */
- (NSArray *) mailAccounts
{
#warning should be implemented with the user defaults interfaces
  NSMutableDictionary *mailAccount, *identity;
  NSMutableArray *identities;
  NSString *name, *fullName;

  if (!mailAccounts)
    {
      NSArray *mails;
      int i;

      mailAccount = [NSMutableDictionary dictionary];
      name = [NSString stringWithFormat: @"%@@%@", login, fallbackIMAP4Server];
      [mailAccount setObject: login forKey: @"userName"];
      [mailAccount setObject: fallbackIMAP4Server forKey: @"serverName"];
      [mailAccount setObject: name forKey: @"name"];

      identities = [NSMutableArray array];
      mails = [self allEmails];

      for (i = 0; i < [mails count]; i++)
	{
	  identity = [NSMutableDictionary dictionary];
	  fullName = [self cn];
	  if (![fullName length])
	    fullName = login;
	  [identity setObject: fullName forKey: @"fullName"];
	  [identity setObject: [mails objectAtIndex: i] forKey: @"email"];
	  
	  if (i == 0) [identity setObject: [NSNumber numberWithBool: YES] forKey: @"isDefault"];
	  [identities addObject: identity];
	}
	
      [mailAccount setObject: identities forKey: @"identities"];

      mailAccounts = [NSMutableArray new];
      [mailAccounts addObject: mailAccount];
    }

  return mailAccounts;
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

  [self mailAccounts];
  identities = [mailAccounts objectsForKey: @"identities"];

  return [identities flattenedArray];
}

- (NSDictionary *) primaryIdentity
{
  NSDictionary *defaultAccount;

  [self mailAccounts];
  defaultAccount = [mailAccounts objectAtIndex: 0];

  return [[defaultAccount objectForKey: @"identities"] objectAtIndex: 0];
}

- (NSString *) messageForwarding
{
  NSString *messageForwarding;

  messageForwarding
    = [[self userDefaults] stringForKey: @"MessageForwarding"];
  if (![messageForwarding length])
    messageForwarding = @"attached";

  return messageForwarding;
}

/* folders */

// TODO: those methods should check whether the traversal stack in the context
//       already contains proper folders to improve caching behaviour

- (id) homeFolderInContext: (id) _ctx
{
  /* Note: watch out for cyclic references */
  // TODO: maybe we should add an [activeUser reset] method to SOPE
  id folder;
  
  folder = [(WOContext *)_ctx objectForKey:@"ActiveUserHomeFolder"];
  if (folder != nil)
    return [folder isNotNull] ? folder : nil;
  
  folder = [[WOApplication application] lookupName: [self login]
					inContext: _ctx
					acquire: NO];
  if ([folder isKindOfClass:[NSException class]])
    return folder;
  
  [(WOContext *)_ctx setObject: ((folder)
				 ? folder
				 : (id)[NSNull null])
		forKey: @"ActiveUserHomeFolder"];
  return folder;
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

  rolesForObject = [NSMutableArray new];
  [rolesForObject autorelease];

  sogoRoles = [super rolesForObject: object inContext: context];
  if (sogoRoles)
    [rolesForObject addObjectsFromArray: sogoRoles];

  if ((superUsername && [login isEqualToString: superUsername])
      || [[object ownerInContext: context] isEqualToString: login])
    [rolesForObject addObject: SoRole_Owner];
  if ([object isKindOfClass: [SOGoObject class]])
    {
      sogoRoles = [(SOGoObject *) object aclsForUser: login];
      if (sogoRoles)
        [rolesForObject addObjectsFromArray: sogoRoles];
    }

  return rolesForObject;
}

@end /* SOGoUser */
