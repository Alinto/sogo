/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#ifndef	__AgenorUserManager_H_
#define	__AgenorUserManager_H_

#import <Foundation/NSObject.h>

/*
  AgenorUserManager

  TODO: document
*/

@class NSString, NSArray, NSURL, NSUserDefaults, NSMutableDictionary, NSTimer;
@class NSDictionary;
@class iCalPerson;

@interface AgenorUserManager : NSObject
{
  NSMutableDictionary *cnCache;
  NSMutableDictionary *serverCache;
  NSMutableDictionary *uidCache;
  NSMutableDictionary *emailCache;
  NSMutableDictionary *shareStoreCache;
  NSMutableDictionary *shareEMailCache;
  NSMutableDictionary *changeInternetAccessCache;
  NSMutableDictionary *internetAutoresponderFlagCache;
  NSMutableDictionary *intranetAutoresponderFlagCache;
  NSTimer *gcTimer;
}

+ (id)sharedUserManager;

- (NSString *)getUIDForEmail:(NSString *)_email;
- (NSString *)getEmailForUID:(NSString *)_uid;

- (iCalPerson *) iCalPersonWithUid: (NSString *) uid;

- (NSString *) getUIDForICalPerson: (iCalPerson *) _person;
/* may insert NSNulls into returned array if _mapStrictly -> YES */
- (NSArray  *)getUIDsForICalPersons:(NSArray *)_persons
  applyStrictMapping:(BOOL)_mapStrictly;

/* i.e. BUTTO Hercule, CETE Lyon/DI/ET/TEST */
- (NSString *)getCNForUID:(NSString *)_uid;

/* i.e. hercule.butto@amelie-ida01.melanie2.i2 */
- (NSString *)getIMAPAccountStringForUID:(NSString *)_uid;

/* i.e. amelie-ida01.melanie2.i2 */
- (NSString *)getServerForUID:(NSString *)_uid;

- (NSArray *)getSharedMailboxAccountStringsForUID:(NSString *)_uid;
- (NSArray *)getSharedMailboxEMailsForUID:(NSString *)_uid;
- (NSDictionary *)getSharedMailboxesAndEMailsForUID:(NSString *)_uid;

- (NSURL *)getFreeBusyURLForUID:(NSString *)_uid;

- (NSUserDefaults *) getUserDefaultsForUID: (NSString *) uid;
- (NSUserDefaults *) getUserSettingsForUID: (NSString *) uid;

- (BOOL)isUserAllowedToChangeSOGoInternetAccess:(NSString *)_uid;

- (BOOL)isInternetAutoresponderEnabledForUser:(NSString *)_uid;
- (BOOL)isIntranetAutoresponderEnabledForUser:(NSString *)_uid;

@end

#endif	/* __AgenorUserManager_H_ */
