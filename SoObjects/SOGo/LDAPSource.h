/* LDAPSource.h - this file is part of SOGo
 *
 * Copyright (C) 2007-2019 Inverse inc.
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

#include "SOGoSource.h"

@class LDAPSourceSchema;
@class NGLdapEntry;
@class NSException;
@class NSMutableArray;
@class NSMutableDictionary;
@class NSString;

@interface LDAPSource : NSObject <SOGoDNSource>
{
  int _queryLimit;
  int _queryTimeout;

  NSString *_sourceID;
  NSString *_displayName;

  NSString *_bindDN;       // The bindDN/password could be either the source's one
  NSString *_password;     // or the current user if _bindAsCurrentUser is set to YES
  NSString *_sourceBindDN; // while sourceBindDN/sourceBindPassword always belong to the source
  NSString *_sourceBindPassword;
  NSString *_hostname;
  unsigned int _port;
  NSString *_encryption;
  NSString *_filter;
  BOOL _bindAsCurrentUser;
  NSString *_scope;
  NSString *_userPasswordAlgorithm;

  NSString *_baseDN;
  NSString *_pristineBaseDN;
  LDAPSourceSchema *_schema;
  NSString *_IDField;     // the first part of a user DN
  NSString *_CNField;
  NSString *_UIDField;
  NSArray *_mailFields;
  NSArray *_searchFields;
  NSString *_IMAPHostField;
  NSString *_IMAPLoginField;
  NSString *_SieveHostField;
  NSArray *_bindFields;

  BOOL _listRequiresDot;

  NSString *_domain;
  NSString *_contactInfoAttribute;

  NSDictionary *_contactMapping;
  NSArray *_contactObjectClasses;
  NSArray *_groupObjectClasses;

  NSDictionary *_modulesConstraints;

  BOOL _passwordPolicy;
  BOOL _updateSambaNTLMPasswords;

  /* resources handling */
  NSString *_kindField;
  NSString *_multipleBookingsField;

  NSString *_MSExchangeHostname;

  /* user addressbooks */
  NSString *_abOU;

  /* ACL */
  NSArray *_modifiers;
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
groupObjectClasses: (NSArray *) newGroupObjectClasses
     IMAPHostField: (NSString *) newIMAPHostField
    IMAPLoginField: (NSString *) newIMAPLoginField
    SieveHostField: (NSString *) newSieveHostField
        bindFields: (id) newBindFields
	 kindField: (NSString *) newKindField
andMultipleBookingsField: (NSString *) newMultipleBookingsField;

/* This enable the convertion of a contact entry with inetOrgPerson and mozillaAbPerson
   to and from an LDAP record */
- (void) setContactMapping: (NSDictionary *) theMapping
          andObjectClasses: (NSArray *) theObjectClasses;

- (NGLdapEntry *) lookupGroupEntryByUID: (NSString *) theUID
                               inDomain: (NSString *) theDomain;
- (NGLdapEntry *) lookupGroupEntryByEmail: (NSString *) theEmail
                                 inDomain: (NSString *) theDomain;

- (void) applyContactMappingToResult: (NSMutableDictionary *) ldifRecord;

@end

#endif /* LDAPSOURCE_H */
