/* SOGoCache.h - this file is part of SOGo
 *
 * Copyright (C) 2008-2014 Inverse inc.
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

#ifndef SOGOCACHE_H
#define SOGOCACHE_H

#import <Foundation/NSObject.h>

#include <libmemcached/memcached.h>

@class NSMutableDictionary;
@class NSString;
@class NSUserDefaults;

@class NGImap4Connection;

@class SOGoGroup;
@class SOGoObject;
@class SOGoUser;
@class SOGoUserDefaults;

@interface SOGoCache : NSObject
{
  NSMutableDictionary *localCache;
  NSMutableDictionary *imap4Connections;
  NSMutableDictionary *cache;
  BOOL requestsCacheEnabled;
  NSMutableDictionary *users;
  NSMutableDictionary *groups;
  float cleanupInterval;
  NSString *memcachedServerName;
}

+ (SOGoCache *) sharedCache;

- (void) disableRequestsCache;
- (void) disableLocalCache;

- (void) killCache;

- (void) registerObject: (id) object
	       withName: (NSString *) name
	    inContainer: (SOGoObject *) container;
- (void) unregisterObjectWithName: (NSString *) name
                      inContainer: (SOGoObject *) container;
- (id) objectNamed: (NSString *) name
       inContainer: (SOGoObject *) container;

- (void) registerUser: (SOGoUser *) user
             withName: (NSString *) userName;
- (id) userNamed: (NSString *) name;

- (void) registerGroup: (SOGoGroup *) group
              withName: (NSString *) groupName
	      inDomain: (NSString *) domainName;

- (id) groupNamed: (NSString *) groupName
	 inDomain: (NSString *) domainName;

- (void) registerIMAP4Connection: (NGImap4Connection *) connection
                          forKey: (NSString *) key;
- (NGImap4Connection *) imap4ConnectionForKey: (NSString *) key;

/* NSDictionary-like methods */
- (void) setValue: (NSString *) value forKey: (NSString *) key;
- (NSString *) valueForKey: (NSString *) key;
- (void) removeValueForKey: (NSString *) key;

- (void) setUserAttributes: (NSString *) attributes
                  forLogin: (NSString *) login;
- (NSString *) userAttributesForLogin: (NSString *) theLogin;

- (void) setUserDefaults: (NSString *) attributes
                forLogin: (NSString *) login;
- (NSString *) userDefaultsForLogin: (NSString *) theLogin;

- (void) setUserSettings: (NSString *) attributes
                forLogin: (NSString *) login;
- (NSString *) userSettingsForLogin: (NSString *) theLogin;

- (void) setFailedCount: (int) theCount
               forLogin: (NSString *) theLogin;

- (NSDictionary *) failedCountForLogin: (NSString *) login;

- (void) setMessageSubmissionsCount: (int) theCount
                    recipientsCount: (int) theRecipientsCount
                           forLogin: (NSString *) theLogin;

- (NSDictionary *) messageSubmissionsCountForLogin: (NSString *) theLogin;

- (NSString *) distinguishedNameForLogin: (NSString *) theLogin;

- (void) setDistinguishedName: (NSString *) theDN
                     forLogin: (NSString *) theLogin;

//
// CAS support
//
- (NSString *) CASTicketFromIdentifier: (NSString *) identifier;
- (NSString *) CASSessionWithTicket: (NSString *) ticket;
- (void) setCASSession: (NSString *) casSession
            withTicket: (NSString *) ticket
         forIdentifier: (NSString *) identifier;

- (NSString *) CASPGTIdFromPGTIOU: (NSString *) pgtIou;
- (void) setCASPGTId: (NSString *) pgtId
           forPGTIOU: (NSString *) pgtIou;

- (void) removeCASSessionWithTicket: (NSString *) ticket;

//
// SAML2 support
//
- (NSDictionary *) saml2LoginDumpsForIdentifier: (NSString *) identifier;
- (void) setSaml2LoginDumps: (NSDictionary *) dump
              forIdentifier: (NSString *) identifier;
- (void) removeSAML2LoginDumpsForIdentifier: (NSString *) identifier;

//
// ACL caching support
//
- (void) setACLs: (NSDictionary *) theACLs
	 forPath: (NSString *) thePath;
- (NSMutableDictionary *) aclsForPath: (NSString *) thePath;

@end

#endif /* SOGOCACHE_H */
