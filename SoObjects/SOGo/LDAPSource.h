/* LDAPSource.h - this file is part of SOGo
 *
 * Copyright (C) 2007-2013 Inverse inc.
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

#include "SOGoSource.h"
#include "SOGoConstants.h"

@class LDAPSourceSchema;
@class NGLdapEntry;
@class NSException;
@class NSMutableArray;
@class NSMutableDictionary;
@class NSString;

@interface LDAPSource : NSObject <SOGoDNSource>
{
  int queryLimit;
  int queryTimeout;

  NSString *sourceID;
  NSString *displayName;

  NSString *bindDN;       // The bindDN/password could be either the source's one
  NSString *password;     // or the current user if _bindAsCurrentUser is set to YES
  NSString *sourceBindDN; // while sourceBindDN/sourceBindPassword always belong to the source
  NSString *sourceBindPassword;
  NSString *hostname;
  unsigned int port;
  NSString *encryption;
  NSString *_filter;
  BOOL _bindAsCurrentUser;
  NSString *_scope;
  NSString *_userPasswordAlgorithm;

  NSString *baseDN;
  LDAPSourceSchema *schema;
  NSString *IDField;     // the first part of a user DN
  NSString *CNField;
  NSString *UIDField;
  NSArray *mailFields;
  NSArray *searchFields;
  NSString *IMAPHostField;
  NSString *IMAPLoginField;
  NSString *SieveHostField;
  NSArray *bindFields;

  BOOL listRequiresDot;

  NSString *domain;
  NSString *contactInfoAttribute;

  NSDictionary *contactMapping;
  NSArray *contactObjectClasses;

  NSDictionary *modulesConstraints;

  NSMutableArray *searchAttributes;
  
  BOOL passwordPolicy;

  NSMutableDictionary *_dnCache;

  /* resources handling */
  NSString *kindField;
  NSString *multipleBookingsField;

  NSString *MSExchangeHostname;

  /* user addressbooks */
  NSString *abOU;

  /* ACL */
  NSArray *modifiers;
}

- (void) setBindDN: (NSString *) newBindDN
	  password: (NSString *) newBindPassword
	  hostname: (NSString *) newBindHostname
	      port: (NSString *) newBindPort
	encryption: (NSString *) newEncryption
 bindAsCurrentUser: (NSString *) bindAsCurrentUser;

- (void) setBaseDN: (NSString *) newBaseDN
	   IDField: (NSString *) newIDField
	   CNField: (NSString *) newCNField
	  UIDField: (NSString *) newUIDField
	mailFields: (NSArray *) newMailFields
      searchFields: (NSArray *) newSearchFields
     IMAPHostField: (NSString *) newIMAPHostField
    IMAPLoginField: (NSString *) newIMAPLoginField
    SieveHostField: (NSString *) newSieveHostField
        bindFields: (id) newBindFields
	 kindField: (NSString *) newKindField
andMultipleBookingsField: (NSString *) newMultipleBookingsField;

/* This enable the convertion of a contact entry with inetOrgPerson and mozillaAbPerson
   to and from an LDAP record */
- (void) setContactMapping: (NSDictionary *) newMapping
          andObjectClasses: (NSArray *) newObjectClasses;

- (NGLdapEntry *) lookupGroupEntryByUID: (NSString *) theUID;
- (NGLdapEntry *) lookupGroupEntryByEmail: (NSString *) theEmail;

@end

#endif /* LDAPSOURCE_H */
