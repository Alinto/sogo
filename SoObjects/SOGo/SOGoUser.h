/*
  Copyright (C) 2006-2011 Inverse inc.
  Copyright (C) 2005 SKYRIX Software AG

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
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __SOGoUser_H__
#define __SOGoUser_H__

#import <NGObjWeb/SoUser.h>

/*
  SOGoUser

  This adds some additional SOGo properties to the SoUser object. The
  properties are (currently) looked up using the SOGoUserManager.

  You have access to this object from the WOContext:
    context.activeUser
*/

@class NSArray;
@class NSDictionary;
@class NSMutableArray;
@class NSMutableDictionary;
@class NSString;

@class WOContext;

@class SOGoAppointmentFolder;
@class SOGoAppointmentFolders;
@class SOGoDateFormatter;
@class SOGoDomainDefaults;
@class SOGoUserDefaults;
@class SOGoUserFolder;
@class SOGoUserProfile;
@class SOGoUserSettings;

@protocol SOGoSource;

@interface SOGoUser : SoUser
{
  SOGoUserDefaults *_defaults;
  SOGoDomainDefaults *_domainDefaults;
  SOGoUserSettings *_settings;
  SOGoUserFolder *homeFolder;
  NSString *currentPassword;
  NSString *loginInDomain;
  //NSString *language;
  NSArray *allEmails;
  NSMutableArray *mailAccounts;
  NSString *cn;
}

+ (SOGoUser *) userWithLogin: (NSString *) newLogin;

+ (SOGoUser *) userWithLogin: (NSString *) login
		       roles: (NSArray *) roles;

+ (SOGoUser *) userWithLogin: (NSString *) login
		       roles: (NSArray *) roles
		       trust: (BOOL) b;

- (id) initWithLogin: (NSString *) newLogin
	       roles: (NSArray *) newRoles
	       trust: (BOOL) b;

- (void) setPrimaryRoles: (NSArray *) newRoles;

- (void) setCurrentPassword: (NSString *) newPassword;
- (NSString *) currentPassword;

- (NSString *) loginInDomain;

/* properties */
- (NSString *) domain;
- (id <SOGoSource>) authenticationSource;

- (NSArray *) allEmails;
- (BOOL) hasEmail: (NSString *) email;
- (NSString *) systemEmail;
- (NSString *) cn;

- (SOGoDateFormatter *) dateFormatterInContext: (WOContext *) context;

/* defaults */
- (SOGoUserDefaults *) userDefaults;
- (SOGoDomainDefaults *) domainDefaults;
- (SOGoUserSettings *) userSettings;

- (NSCalendarDate *) firstDayOfWeekForDate: (NSCalendarDate *) date;
- (unsigned int) dayOfWeekForDate: (NSCalendarDate *) date;

- (NSCalendarDate *) firstWeekOfYearForDate: (NSCalendarDate *) date;
- (unsigned int) weekNumberForDate: (NSCalendarDate *) date;

- (NSArray *) mailAccounts;
- (NSDictionary *) accountWithName: (NSString *) accountName;
- (NSArray *) allIdentities;
- (NSDictionary *) primaryIdentity;
- (NSMutableDictionary *) defaultIdentity;

- (BOOL) isSuperUser;
- (BOOL) canAuthenticate;

/* resource */
- (BOOL) isResource;
- (int) numberOfSimultaneousBookings;

/* module access */
- (BOOL) canAccessModule: (NSString *) module;

/* folders */
- (SOGoUserFolder *) homeFolderInContext: (id) context;
- (SOGoAppointmentFolders *) calendarsFolderInContext: (WOContext *) context;
- (SOGoAppointmentFolder *) personalCalendarFolderInContext: (WOContext *) context;

@end

#endif /* __SOGoUser_H__ */
