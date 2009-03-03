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

#ifndef __SOGoUser_H__
#define __SOGoUser_H__

#import <NGObjWeb/SoUser.h>

/*
  SOGoUser

  This adds some additional SOGo properties to the SoUser object. The
  properties are (currently) looked up using the LDAPUserManager.

  You have access to this object from the WOContext:
    context.activeUser
*/

@class NSArray;
@class NSDictionary;
@class NSMutableArray;
@class NSMutableDictionary;
@class NSString;
@class NSTimeZone;
@class NSURL;
@class NSUserDefaults;

@class WOContext;

@class SOGoAppointmentFolder;
@class SOGoAppointmentFolders;
@class SOGoDateFormatter;
@class SOGoUserDefaults;
@class SOGoUserFolder;

extern NSString *SOGoWeekStartJanuary1;
extern NSString *SOGoWeekStartFirst4DayWeek;
extern NSString *SOGoWeekStartFirstFullWeek;

@interface SoUser (SOGoExtension)

- (NSString *) language;

@end

@interface SOGoUser : SoUser
{
  NSMutableArray *mailAccounts;
  SOGoUserFolder *homeFolder;
  NSString *currentPassword;
  NSArray *allEmails;
  NSString *cn;
}

+ (NSString *) language;

+ (SOGoUser *) userWithLogin: (NSString *) login
		       roles: (NSArray *) roles;

- (void) setPrimaryRoles: (NSArray *) newRoles;

- (void) setCurrentPassword: (NSString *) newPassword;
- (NSString *) currentPassword;

/* properties */
- (NSArray *) allEmails;
- (BOOL) hasEmail: (NSString *) email;
- (NSString *) cn;
- (NSURL *) freeBusyURL;

- (SOGoDateFormatter *) dateFormatterInContext: (WOContext *) context;

/* defaults */
- (NSUserDefaults *) userDefaults;
- (NSUserDefaults *) userSettings;

- (NSString *) language;
- (NSTimeZone *) timeZone;
- (NSTimeZone *) serverTimeZone;

- (unsigned int) firstDayOfWeek;
- (NSCalendarDate *) firstDayOfWeekForDate: (NSCalendarDate *) date;
- (unsigned int) dayOfWeekForDate: (NSCalendarDate *) date;

- (unsigned int) dayStartHour;
- (unsigned int) dayEndHour;

- (NSCalendarDate *) firstWeekOfYearForDate: (NSCalendarDate *) date;
- (unsigned int) weekNumberForDate: (NSCalendarDate *) date;

- (NSArray *) mailAccounts;
- (NSDictionary *) accountWithName: (NSString *) accountName;
- (NSArray *) allIdentities;
- (NSDictionary *) primaryIdentity;
- (NSMutableDictionary *) defaultIdentity;
- (NSString *) messageForwarding;

- (NSString *) signature;
- (NSString *) replyPlacement;
- (NSString *) signaturePlacement;

- (void) saveMailAccounts;

- (BOOL) isSuperUser;

/* module access */
- (BOOL) canAccessModule: (NSString *) module;

/* folders */

- (SOGoUserFolder *) homeFolderInContext: (id) context;

- (SOGoAppointmentFolders *) calendarsFolderInContext: (WOContext *) context;
- (SOGoAppointmentFolder *)
 personalCalendarFolderInContext: (WOContext *) context;

- (NSArray *) rolesForObject: (NSObject *) object
                   inContext: (WOContext *) context;

@end

#endif /* __SOGoUser_H__ */
