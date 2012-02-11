/* SOGoSource.h - this file is part of SOGo
 *
 * Copyright (C) 2009-2012 Inverse inc.
 *
 * Author: Ludovic Marcotte <lmarcotte@inverse.ca>
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

#ifndef SOGOSOURCE_H
#define SOGOSOURCE_H

#import <Foundation/NSObject.h>

#import "SOGoConstants.h"

@class NSDictionary;
@class NSException;
@class NSString;

@protocol SOGoSource <NSObject>

+ (id) sourceFromUDSource: (NSDictionary *) udSource
                 inDomain: (NSString *) domain;

- (id) initFromUDSource: (NSDictionary *) udSource
               inDomain: (NSString *) domain;

- (NSString *) domain;

/* requires a "." to obtain the full list of contacts */
- (void) setListRequiresDot: (BOOL) aBool;
- (BOOL) listRequiresDot;

- (BOOL) checkLogin: (NSString *) _login
	   password: (NSString *) _pwd
	       perr: (SOGoPasswordPolicyError *) _perr
	     expire: (int *) _expire
	      grace: (int *) _grace;

- (BOOL) changePasswordForLogin: (NSString *) login
		    oldPassword: (NSString *) oldPassword
		    newPassword: (NSString *) newPassword
			   perr: (SOGoPasswordPolicyError *) perr;

- (NSDictionary *) lookupContactEntry: (NSString *) theID;
- (NSDictionary *) lookupContactEntryWithUIDorEmail: (NSString *) entryID
                                           inDomain: (NSString *) domain;

- (NSArray *) allEntryIDs;
- (NSArray *) fetchContactsMatching: (NSString *) filter
                           inDomain: (NSString *) domain;

- (void) setSourceID: (NSString *) newSourceID;
- (NSString *) sourceID;

- (void) setDisplayName: (NSString *) newDisplayName;
- (NSString *) displayName;

- (void) setModifiers: (NSArray *) newModifiers;
- (NSArray *) modifiers;

- (BOOL) hasUserAddressBooks;
- (NSArray *) addressBookSourcesForUser: (NSString *) user;

- (NSException *) addContactEntry: (NSDictionary *) roLdifRecord
                           withID: (NSString *) aId;
- (NSException *) updateContactEntry: (NSDictionary *) ldifRecord;
- (NSException *) removeContactEntryWithID: (NSString *) aId;

/* user address books */
- (NSArray *) addressBookSourcesForUser: (NSString *) user;

- (NSException *) addAddressBookSource: (NSString *) newId
                       withDisplayName: (NSString *) newDisplayName
                               forUser: (NSString *) user;
- (NSException *) renameAddressBookSource: (NSString *) newId
                          withDisplayName: (NSString *) newDisplayName
                                  forUser: (NSString *) user;
- (NSException *) removeAddressBookSource: (NSString *) newId
                                  forUser: (NSString *) user;

@end

@protocol SOGoDNSource <SOGoSource>

- (void) setBindDN: (NSString *) theDN;
- (NSString *) bindDN;
- (void) setBindPassword: (NSString *) thePassword;
- (NSString *) bindPassword;
- (BOOL) bindAsCurrentUser;

- (NSString *) lookupLoginByDN: (NSString *) theDN;
- (NSString *) lookupDNByLogin: (NSString *) theLogin;

- (NSString *) baseDN;
- (NSString *) MSExchangeHostname;

@end

#endif /* SOGOSOURCE_H */
