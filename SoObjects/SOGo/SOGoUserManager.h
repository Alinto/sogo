/* SOGoUserManager.h - this file is part of SOGo
 *
 * Copyright (C) 2007-2015 Inverse inc.
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

#ifndef SOGOUSERMANAGER_H
#define SOGOUSERMANAGER_H

#import <Foundation/NSObject.h>

#import "SOGoConstants.h"

@class NSDictionary;
@class NSMutableDictionary;
@class NSString;
@class NSTimer;
@class NGLdapEntry;

@class LDAPSource;

@protocol SOGoSource;

@interface SOGoUserManagerRegistry : NSObject

+ (id) sharedRegistry;

- (NSString *) sourceClassForType: (NSString *) type;

@end

@interface SOGoUserManager : NSObject
{
  @private
    SOGoUserManagerRegistry *_registry;
    NSMutableDictionary *_sources;
    NSMutableDictionary *_sourcesMetadata;
}

+ (id) sharedUserManager;

- (NSString *) registryClass;

- (NSArray *) sourceIDsInDomain: (NSString *) domain;
- (NSArray *) authenticationSourceIDsInDomain: (NSString *) domain;
- (NSArray *) addressBookSourceIDsInDomain: (NSString *) domain;

- (NSObject <SOGoSource> *) sourceWithID: (NSString *) sourceID;
- (NSDictionary *) metadataForSourceID: (NSString *) sourceID;
- (NSString *) displayNameForSourceWithID: (NSString *) sourceID;
- (NSDictionary *) contactInfosForUserWithUIDorEmail: (NSString *) uid;
- (NSDictionary *) contactInfosForUserWithUIDorEmail: (NSString *) uid
                                            inDomain: (NSString *) domain;
- (NSDictionary *) fetchContactWithUID: (NSString *) uid
                              inDomain: (NSString *) domain;
- (NSArray *) fetchContactsMatching: (NSString *) match
                           inDomain: (NSString *) domain;
- (NSArray *) fetchUsersMatching: (NSString *) filter
                        inDomain: (NSString *) domain;
- (NSArray *) _compactAndCompleteContacts: (NSEnumerator *) contacts;

- (NSString *) getCNForUID: (NSString *) uid;
- (NSString *) getEmailForUID: (NSString *) uid;
- (NSString *) getFullEmailForUID: (NSString *) uid;
- (NSString *) getExternalLoginForUID: (NSString *) uid
                             inDomain: (NSString *) domain;
- (NSString *) getUIDForEmail: (NSString *) email;
- (NSString *) getLoginForDN: (NSString *) theDN;

- (BOOL) checkLogin: (NSString *) _login
           password: (NSString *) _pwd
             domain: (NSString **) _domain
               perr: (SOGoPasswordPolicyError *) _perr
             expire: (int *) _expire
              grace: (int *) _grace;

- (BOOL) checkLogin: (NSString *) _login
           password: (NSString *) _pwd
             domain: (NSString **) _domain
               perr: (SOGoPasswordPolicyError *) _perr
             expire: (int *) _expire
              grace: (int *) _grace
           useCache: (BOOL) _useCache;

- (BOOL) changePasswordForLogin: (NSString *) login
                       inDomain: (NSString *) domain
		    oldPassword: (NSString *) oldPassword
		    newPassword: (NSString *) newPassword
			   perr: (SOGoPasswordPolicyError *) perr;
@end

#endif /* SOGOUSERMANAGER_H */
