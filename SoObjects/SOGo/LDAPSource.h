/* LDAPSource.h - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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

#ifndef LDAPSOURCE_H
#define LDAPSOURCE_H

#import <Foundation/NSObject.h>

@class NSDictionary;
@class NSString;
@class NGLdapConnection;

@interface LDAPSource : NSObject
{
  NSString *bindDN;
  NSString *hostname;
  unsigned int port;
  NSString *password;

  NSString *baseDN;
  NSString *IDField; /* the first part of a user DN */
  NSString *CNField;
  NSString *UIDField;
  NSString *bindFields;

  NGLdapConnection *ldapConnection;
  NSMutableArray *searchAttributes;
}

+ (id) sourceFromUDSource: (NSDictionary *) udSource;

- (id) initFromUDSource: (NSDictionary *) udSource;

- (void) setBindDN: (NSString *) newBindDN
	  hostname: (NSString *) newBindHostname
	      port: (NSString *) newBindPort
       andPassword: (NSString *) newBindPassword;
- (void) setBaseDN: (NSString *) newBaseDN
	   IDField: (NSString *) newIDField
	   CNField: (NSString *) newCNField
	  UIDField: (NSString *) newUIDField
     andBindFields: (NSString *) newBindFields;

- (BOOL) checkLogin: (NSString *) login
	andPassword: (NSString *) password;

- (NSDictionary *) lookupContactEntry: (NSString *) entryID;
- (NSDictionary *) lookupContactEntryWithUIDorEmail: (NSString *) entryID;
- (NSArray *) allEntryIDs;
- (NSArray *) fetchContactsMatching: (NSString *) filter;

@end

#endif /* LDAPSOURCE_H */
