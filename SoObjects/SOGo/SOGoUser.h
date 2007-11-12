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

#ifndef __SOGoUser_H__
#define __SOGoUser_H__

#import <NGObjWeb/SoUser.h>

/*
  SOGoUser

  This adds some additional SOGo properties to the SoUser object. The
  properties are (currently) looked up using the AgenorUserManager.

  You have access to this object from the WOContext:
    context.activeUser
*/

@class NSString;
@class NSArray;
@class NSDictionary;
@class NSURL;
@class NSUserDefaults;
@class NSTimeZone;
@class WOContext;
@class SOGoDateFormatter;

extern NSString *SOGoWeekStartHideWeekNumbers;
extern NSString *SOGoWeekStartJanuary1;
extern NSString *SOGoWeekStartFirst4DayWeek;
extern NSString *SOGoWeekStartFirstFullWeek;

@interface SoUser (SOGoExtension)

- (NSString *) language;

@end

@interface SOGoUser : SoUser
{
  NSString *currentPassword;
  NSString *cn;
  NSString *language;
  NSArray *allEmails;
  NSUserDefaults *userDefaults;
  NSUserDefaults *userSettings;
  NSTimeZone *userTimeZone;
  SOGoDateFormatter *dateFormatter;
  NSMutableArray *mailAccounts;
}

+ (NSString *) language;

+ (SOGoUser *) userWithLogin: (NSString *) login
		       roles: (NSArray *) roles;
- (void) setCurrentPassword: (NSString *) newPassword;
- (NSString *) currentPassword;

/* properties */

// - (NSString *) fullEmail;

// - (NSString *) primaryEmail;
// - (NSString *) systemEmail;
- (NSArray *) allEmails;

- (BOOL) hasEmail: (NSString *) email;

- (NSString *) cn;
- (NSURL *) freeBusyURL;

- (SOGoDateFormatter *) dateFormatterInContext: (WOContext *) context;

/* shares and identities */

// - (NSString *) primaryIMAP4AccountString;

// - (NSString *) primaryIMAP4AccountString;
// - (NSString *) primaryMailServer;
// - (NSArray *) additionalIMAP4AccountStrings;
// - (NSArray *) additionalEMailAddresses;
// - (NSDictionary *) additionalIMAP4AccountsAndEMails;

/* defaults */

- (NSUserDefaults *) userDefaults;
- (NSUserDefaults *) userSettings;

- (NSString *) language;
- (NSTimeZone *) timeZone;
- (NSTimeZone *) serverTimeZone;

- (NSArray *) mailAccounts;
- (NSArray *) allIdentities;
- (NSDictionary *) primaryIdentity;
- (NSString *) messageForwarding;
- (NSString *) messageCheck;

/* folders */

- (id) homeFolderInContext: (id) _ctx;
// - (id) schedulingCalendarInContext: (id) _ctx;

- (NSArray *) rolesForObject: (NSObject *) object
                   inContext: (WOContext *) context;

@end

#endif /* __SOGoUser_H__ */
