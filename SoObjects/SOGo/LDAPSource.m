/* LDAPSource.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2011 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Ludovic Marcotte <lmarcotte@inverse.ca>
 *         Francis Lachapelle <flachapelle@inverse.ca>
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

#include <ldap.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSObject+Logs.h>
#import <EOControl/EOControl.h>
#import <NGLdap/NGLdapConnection.h>
#import <NGLdap/NGLdapAttribute.h>
#import <NGLdap/NGLdapEntry.h>
#import <NGLdap/NGLdapModification.h>

#import "NSArray+Utilities.h"
#import "NSString+Utilities.h"
#import "SOGoDomainDefaults.h"
#import "SOGoSystemDefaults.h"

#import "LDAPSource.h"

#import "../../Main/SOGo.h"

#define SafeLDAPCriteria(x) [[[x stringByReplacingString: @"\\" withString: @"\\\\"] \
                                 stringByReplacingString: @"'" withString: @"\\'"] \
                                 stringByReplacingString: @"%" withString: @"%%"]
static NSArray *commonSearchFields;

@implementation LDAPSource

+ (void) initialize
{
  if (!commonSearchFields)
    {
      commonSearchFields = [NSArray arrayWithObjects:
				      @"title",
				    @"company",
				    @"o",
				    @"displayname",
				    @"modifytimestamp",
				    @"mozillahomestate",
				    @"mozillahomeurl",
				    @"homeurl",
				    @"st",
				    @"region",
				    @"mozillacustom2",
				    @"custom2",
				    @"mozillahomecountryname",
				    @"description",
				    @"notes",
				    @"department",
				    @"departmentnumber",
				    @"ou",
				    @"orgunit",
				    @"mobile",
				    @"cellphone",
				    @"carphone",
				    @"mozillacustom1",
				    @"custom1",
				    @"mozillanickname",
				    @"xmozillanickname",
				    @"mozillaworkurl",
				    @"workurl",
				    @"fax",
				    @"facsimiletelephonenumber",
				    @"telephonenumber",
				    @"mozillahomestreet",
				    @"mozillasecondemail",
				    @"xmozillasecondemail",
				    @"mozillacustom4",
				    @"custom4",
				    @"nsaimid",
				    @"nscpaimscreenname",
				    @"street",
				    @"streetaddress",
				    @"postofficebox",
				    @"homephone",
				    @"cn",
				    @"commonname",
				    @"givenname",
				    @"mozillahomepostalcode",
				    @"mozillahomelocalityname",
				    @"mozillaworkstreet2",
				    @"mozillausehtmlmail",
				    @"xmozillausehtmlmail",
				    @"mozillahomestreet2",
				    @"postalcode",
				    @"zip",
				    @"c",
				    @"countryname",
				    @"pager",
				    @"pagerphone",
				    @"mail",
				    @"sn",
				    @"surname",
				    @"mozillacustom3",
				    @"custom3",
				    @"l",
				    @"locality",
				    @"birthyear",
				    @"serialnumber",
				    @"calfburl",
                                    @"proxyaddresses",
				    nil];	
      [commonSearchFields retain];
    }
}

+ (id) sourceFromUDSource: (NSDictionary *) udSource
                 inDomain: (NSString *) sourceDomain
{
  id newSource;

  newSource = [[self alloc] initFromUDSource: udSource
                                    inDomain: sourceDomain];
  [newSource autorelease];

  return newSource;
}

- (id) init
{
  if ((self = [super init]))
    {
      bindDN = nil;
      hostname = nil;
      port = 389;
      encryption = nil;
      password = nil;
      sourceID = nil;
      domain = nil;

      baseDN = nil;
      IDField = @"cn"; /* the first part of a user DN */
      CNField = @"cn";
      UIDField = @"uid";
      mailFields = [NSArray arrayWithObject: @"mail"];
      [mailFields retain];
      searchFields = [NSArray arrayWithObjects: @"sn", @"displayname", @"telephonenumber", nil];
      [searchFields retain];
      IMAPHostField = nil;
      IMAPLoginField = nil;
      bindFields = nil;
      _scope = @"sub";
      _filter = nil;

      searchAttributes = nil;
      passwordPolicy = NO;

      kindField = nil;
      multipleBookingsField = nil;

      _dnCache = [[NSMutableDictionary alloc] init];
    }

  return self;
}

- (void) dealloc
{
  [bindDN release];
  [hostname release];
  [encryption release];
  [password release];
  [baseDN release];
  [IDField release];
  [CNField release];
  [UIDField release];
  [mailFields release];
  [searchFields release];
  [IMAPHostField release];
  [IMAPLoginField release];
  [bindFields release];
  [_filter release];
  [sourceID release];
  [modulesConstraints release];
  [_scope release];
  [searchAttributes release];
  [domain release];
  [_dnCache release];
  [kindField release];
  [multipleBookingsField release];
  [super dealloc];
}

- (id) initFromUDSource: (NSDictionary *) udSource
               inDomain: (NSString *) sourceDomain
{
  SOGoDomainDefaults *dd;
  NSNumber *udQueryLimit, *udQueryTimeout;

  if ((self = [self init]))
    {
      ASSIGN (sourceID, [udSource objectForKey: @"id"]);

      [self setBindDN: [udSource objectForKey: @"bindDN"]
             password: [udSource objectForKey: @"bindPassword"]
             hostname: [udSource objectForKey: @"hostname"]
                 port: [udSource objectForKey: @"port"]
           encryption: [udSource objectForKey: @"encryption"]
    bindAsCurrentUser: [udSource objectForKey: @"bindAsCurrentUser"]];

      [self setBaseDN: [udSource objectForKey: @"baseDN"]
              IDField: [udSource objectForKey: @"IDFieldName"]
              CNField: [udSource objectForKey: @"CNFieldName"]
             UIDField: [udSource objectForKey: @"UIDFieldName"]
           mailFields: [udSource objectForKey: @"MailFieldNames"]
	 searchFields: [udSource objectForKey: @"SearchFieldNames"]
	IMAPHostField: [udSource objectForKey: @"IMAPHostFieldName"]
       IMAPLoginField: [udSource objectForKey: @"IMAPLoginFieldName"]
	   bindFields: [udSource objectForKey: @"bindFields"]
	    kindField: [udSource objectForKey: @"KindFieldName"]
	    andMultipleBookingsField: [udSource objectForKey: @"MultipleBookingsFieldName"]];

      if ([sourceDomain length])
        {
          dd = [SOGoDomainDefaults defaultsForDomain: sourceDomain];
          ASSIGN (domain, sourceDomain);
        }
      else
        dd = [SOGoSystemDefaults sharedSystemDefaults];

      contactInfoAttribute
        = [udSource objectForKey: @"SOGoLDAPContactInfoAttribute"];
      if (!contactInfoAttribute)
        contactInfoAttribute = [dd ldapContactInfoAttribute];
      [contactInfoAttribute retain];
      
      udQueryLimit = [udSource objectForKey: @"SOGoLDAPQueryLimit"];
      if (udQueryLimit)
        queryLimit = [udQueryLimit intValue];
      else
        queryLimit = [dd ldapQueryLimit];

      udQueryTimeout = [udSource objectForKey: @"SOGoLDAPQueryTimeout"];
      if (udQueryTimeout)
        queryTimeout = [udQueryTimeout intValue];
      else
        queryTimeout = [dd ldapQueryTimeout];

      ASSIGN (modulesConstraints,
              [udSource objectForKey: @"ModulesConstraints"]);
      ASSIGN (_filter, [udSource objectForKey: @"filter"]);
      ASSIGN (_scope, ([udSource objectForKey: @"scope"]
                       ? [udSource objectForKey: @"scope"]
                       : (id)@"sub"));

      if ([udSource objectForKey: @"passwordPolicy"])
	passwordPolicy = [[udSource objectForKey: @"passwordPolicy"] boolValue];
    }
  
  return self;
}

- (void) setBindDN: (NSString *) theDN
{
  ASSIGN(bindDN, theDN);
}

- (void) setBindPassword: (NSString *) thePassword
{
  ASSIGN (password, thePassword);
}

- (BOOL) bindAsCurrentUser
{
  return _bindAsCurrentUser;
}

- (void) setBindDN: (NSString *) newBindDN
	  password: (NSString *) newBindPassword
	  hostname: (NSString *) newBindHostname
	      port: (NSString *) newBindPort
	encryption: (NSString *) newEncryption
 bindAsCurrentUser: (NSString *) bindAsCurrentUser
{
  ASSIGN (bindDN, newBindDN);
  ASSIGN (encryption, [newEncryption uppercaseString]);
  if ([encryption isEqualToString: @"SSL"])
    port = 636;
  ASSIGN (hostname, newBindHostname);
  if (newBindPort)
    port = [newBindPort intValue];
  ASSIGN (password, newBindPassword);
  _bindAsCurrentUser = [bindAsCurrentUser boolValue];
}

- (void) setBaseDN: (NSString *) newBaseDN
	   IDField: (NSString *) newIDField
	   CNField: (NSString *) newCNField
	  UIDField: (NSString *) newUIDField
	mailFields: (NSArray *) newMailFields
      searchFields: (NSArray *) newSearchFields
     IMAPHostField: (NSString *) newIMAPHostField
    IMAPLoginField: (NSString *) newIMAPLoginField
	bindFields: (id) newBindFields
	 kindField: (NSString *) newKindField
andMultipleBookingsField: (NSString *) newMultipleBookingsField
{
  ASSIGN (baseDN, [newBaseDN lowercaseString]);
  if (newIDField)
    ASSIGN (IDField, newIDField);
  if (newCNField)
    ASSIGN (CNField, newCNField);
  if (newUIDField)
    ASSIGN (UIDField, newUIDField);
  if (newIMAPHostField)
    ASSIGN (IMAPHostField, newIMAPHostField);
  if (newIMAPLoginField)
    ASSIGN (IMAPLoginField, newIMAPLoginField);
  if (newMailFields)
    ASSIGN (mailFields, newMailFields);
  if (newSearchFields)
    ASSIGN (searchFields, newSearchFields);
  if (newBindFields)
    {
      // Before SOGo v1.2.0, bindFields was a comma-separated list
      // of values. So it could be configured as:
      //
      // bindFields = foo;
      // bindFields = "foo, bar, baz";
      //
      // SOGo v1.2.0 and upwards redefined that parameter as an array
      // so we would have instead:
      //
      // bindFields = (foo);
      // bindFields = (foo, bar, baz);
      //
      // We check for the old format and we support it.
      if ([newBindFields isKindOfClass: [NSArray class]])
	ASSIGN(bindFields, newBindFields);
      else
	{
	  [self logWithFormat: @"WARNING: using old bindFields format - please update it"];
	  ASSIGN(bindFields, [newBindFields componentsSeparatedByString: @","]);
	}
    }
  if (newKindField)
    ASSIGN(kindField, newKindField);
  if (newMultipleBookingsField)
    ASSIGN(multipleBookingsField, newMultipleBookingsField);
}

- (BOOL) _setupEncryption: (NGLdapConnection *) encryptedConn
{
  BOOL rc;

  if ([encryption isEqualToString: @"SSL"])
    rc = [encryptedConn useSSL];
  else if ([encryption isEqualToString: @"STARTTLS"])
    rc = [encryptedConn startTLS];
  else
    {
      [self errorWithFormat:
	      @"encryption scheme '%@' not supported:"
	    @" use 'SSL' or 'STARTTLS'", encryption];
      rc = NO;
    }

  return rc;
}

- (NGLdapConnection *) _ldapConnection
{
  NGLdapConnection *ldapConnection;

  NS_DURING
    {
      //NSLog(@"Creating NGLdapConnection instance for bindDN '%@'", bindDN);

      ldapConnection = [[NGLdapConnection alloc] initWithHostName: hostname
						 port: port];
      [ldapConnection autorelease];
      if (![encryption length] || [self _setupEncryption: ldapConnection])
	{
	  [ldapConnection bindWithMethod: @"simple"
			  binddn: bindDN
			  credentials: password];
	  if (queryLimit > 0)
	    [ldapConnection setQuerySizeLimit: queryLimit];
	  if (queryTimeout > 0)
	    [ldapConnection setQueryTimeLimit: queryTimeout];
	}
      else
	ldapConnection = nil;
    }
  NS_HANDLER
    {
      NSLog(@"Could not bind to the LDAP server %@ (%d) using the bind DN: %@", hostname, port, bindDN);
      ldapConnection = nil;
    }
  NS_ENDHANDLER;

  return ldapConnection;
}

- (NSString *) domain
{
  return domain;
}

/* user management */
- (EOQualifier *) _qualifierForBindFilter: (NSString *) uid
{
  NSMutableString *qs;
  NSString *escapedUid;
  NSEnumerator *fields;
  NSString *currentField;

  qs = [NSMutableString string];

  escapedUid = SafeLDAPCriteria(uid);

  fields = [bindFields objectEnumerator];
  while ((currentField = [fields nextObject]))
    [qs appendFormat: @" OR (%@='%@')", currentField, escapedUid];

  if (_filter && [_filter length])
    [qs appendFormat: @" AND %@", _filter];

  [qs deleteCharactersInRange: NSMakeRange(0, 4)];

  return [EOQualifier qualifierWithQualifierFormat: qs];
}

- (NSString *) _fetchUserDNForLogin: (NSString *) loginToCheck
{
  NSEnumerator *entries;
  EOQualifier *qualifier;
  NSArray *attributes;
  NGLdapConnection *ldapConnection;
  NSString *userDN;

  ldapConnection = [self _ldapConnection];
  qualifier = [self _qualifierForBindFilter: loginToCheck];
  attributes = [NSArray arrayWithObject: @"dn"];

  if ([_scope caseInsensitiveCompare: @"BASE"] == NSOrderedSame)
    entries = [ldapConnection baseSearchAtBaseDN: baseDN
                                       qualifier: qualifier
                                      attributes: attributes];
  else if ([_scope caseInsensitiveCompare: @"ONE"] == NSOrderedSame)
    entries = [ldapConnection flatSearchAtBaseDN: baseDN
                                       qualifier: qualifier
                                      attributes: attributes];
  else
    entries = [ldapConnection deepSearchAtBaseDN: baseDN
                                       qualifier: qualifier
                                      attributes: attributes];

  userDN = [[entries nextObject] dn];

  return userDN;
}

- (BOOL) checkLogin: (NSString *) _login
	   password: (NSString *) _pwd
	       perr: (SOGoPasswordPolicyError *) _perr
	     expire: (int *) _expire
	      grace: (int *) _grace
{
  NGLdapConnection *bindConnection;
  NSString *userDN;
  BOOL didBind;

  didBind = NO;

  if ([_login length] > 0)
    {
      bindConnection = [[NGLdapConnection alloc] initWithHostName: hostname
						 port: port];
      if (![encryption length] || [self _setupEncryption: bindConnection])
	{
	  if (queryTimeout > 0)
	    [bindConnection setQueryTimeLimit: queryTimeout];

	  userDN = [_dnCache objectForKey: _login];

	  if (!userDN)
	    {
	      if (bindFields)
		userDN = [self _fetchUserDNForLogin: _login];
	      else
		userDN = [NSString stringWithFormat: @"%@=%@,%@",
				   IDField, _login, baseDN];
	    }

	  if (userDN)
	    {
	      // We cache the _login <-> userDN entry to speed up things
	      [_dnCache setObject: userDN  forKey: _login];
	      
	      NS_DURING
		if (!passwordPolicy)
		  didBind = [bindConnection bindWithMethod: @"simple"
					    binddn: userDN
					    credentials: _pwd];
	        else  
		  didBind = [bindConnection bindWithMethod: @"simple"
					    binddn: userDN
					    credentials: _pwd
					    perr: (void *)_perr
					    expire: _expire
					    grace: _grace];
	      NS_HANDLER
                ;
              NS_ENDHANDLER
                ;
            }
	}
      [bindConnection release];
    }
  
  return didBind;
}

- (BOOL) changePasswordForLogin: (NSString *) login
		    oldPassword: (NSString *) oldPassword
		    newPassword: (NSString *) newPassword
			   perr: (SOGoPasswordPolicyError *) perr
  
{
  NGLdapConnection *bindConnection;
  NSString *userDN;
  BOOL didChange;

  didChange = NO;

  if ([login length] > 0)
    {
      bindConnection = [[NGLdapConnection alloc] initWithHostName: hostname
						 port: port];
     if (![encryption length] || [self _setupEncryption: bindConnection])
	{
	  if (queryTimeout > 0)
	    [bindConnection setQueryTimeLimit: queryTimeout];
	  if (bindFields)
	    userDN = [self _fetchUserDNForLogin: login];
	  else
	    userDN = [NSString stringWithFormat: @"%@=%@,%@",
			       IDField, login, baseDN];
	  if (userDN)
	    {
	      NS_DURING
		if (!passwordPolicy)
		  {
		    // We don't use a password policy - we simply use
		    // a modify-op to change the password
		    NGLdapModification *mod;
		    NGLdapAttribute *attr;
		    NSArray *changes;
		    
		    attr = [[NGLdapAttribute alloc] initWithAttributeName: @"userPassword"];
		    [attr addStringValue: newPassword];
		    
		    mod = [NGLdapModification replaceModification: attr];
		    changes = [NSArray arrayWithObject: mod];
		    *perr = PolicyNoError;

		    if ([bindConnection bindWithMethod: @"simple"
					binddn: userDN
					credentials: oldPassword])
		      didChange = [bindConnection modifyEntryWithDN: userDN
						  changes: changes]; 
		    else
		      didChange = NO;
		  }
	      else
		didChange = [bindConnection changePasswordAtDn: userDN
					    oldPassword: oldPassword
					    newPassword: newPassword
					    perr: (void *)perr];
	      NS_HANDLER
                ;
              NS_ENDHANDLER
                ;
            }
	}
      [bindConnection release];
    }
  
  return didChange;
}


/**
 * Search for contacts matching some string.
 * @param filter the string to search for
 * @see fetchContactsMatching:
 * @return a EOQualifier matching the filter
 */
- (EOQualifier *) _qualifierForFilter: (NSString *) filter
{
  NSMutableArray *fields;
  NSString *fieldFormat, *searchFormat, *escapedFilter;
  EOQualifier *qualifier;
  NSMutableString *qs;

  escapedFilter = SafeLDAPCriteria(filter);
  if ([escapedFilter length] > 0)
    {
      qs = [NSMutableString string];
      if ([escapedFilter isEqualToString: @"."])
        [qs appendFormat: @"(%@='*')", CNField];
      else
	{
	  fieldFormat = [NSString stringWithFormat: @"(%%@='%@*')", escapedFilter];
	  fields = [NSMutableArray arrayWithArray: searchFields];
	  [fields addObjectsFromArray: mailFields];
	  [fields addObject: CNField];
	  searchFormat = [[[fields uniqueObjects] stringsWithFormat: fieldFormat]
				    componentsJoinedByString: @" OR "];
	  [qs appendString: searchFormat];
	}

      if (_filter && [_filter length])
	[qs appendFormat: @" AND %@", _filter];

      qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
    }
  else
    qualifier = nil;

  return qualifier;
}

- (EOQualifier *) _qualifierForUIDFilter: (NSString *) uid
{
  NSString *mailFormat, *fieldFormat, *escapedUid, *currentField;
  NSEnumerator *bindFieldsEnum;
  NSMutableString *qs;

  escapedUid = SafeLDAPCriteria(uid);

  fieldFormat = [NSString stringWithFormat: @"(%%@='%@')", escapedUid];
  mailFormat = [[mailFields stringsWithFormat: fieldFormat]
		 componentsJoinedByString: @" OR "];
  qs = [NSMutableString stringWithFormat: @"(%@='%@') OR %@",
                        UIDField, escapedUid, mailFormat];
  if (bindFields)
    {
      bindFieldsEnum = [bindFields objectEnumerator];
      while ((currentField = [bindFieldsEnum nextObject]))
	{
	  if ([currentField caseInsensitiveCompare: UIDField] != NSOrderedSame
	      && ![mailFields containsObject: currentField])
	    [qs appendFormat: @" OR (%@='%@')", [currentField stringByTrimmingSpaces], escapedUid];
	}
    }

  if (_filter && [_filter length])
    [qs appendFormat: @" AND %@", _filter];

  return [EOQualifier qualifierWithQualifierFormat: qs];
}

- (NSArray *) _constraintsFields
{
  NSMutableArray *fields;
  NSEnumerator *values;
  NSDictionary *currentConstraint;

  fields = [NSMutableArray array];
  values = [[modulesConstraints allValues] objectEnumerator];
  while ((currentConstraint = [values nextObject]))
    [fields addObjectsFromArray: [currentConstraint allKeys]];

  return fields;
}

- (NSArray *) _searchAttributes
{
  if (!searchAttributes)
    {
      searchAttributes = [NSMutableArray new];
      [searchAttributes addObject: @"objectClass"];
      if (CNField)
	[searchAttributes addObject: CNField];
      if (UIDField)
	[searchAttributes addObject: UIDField];
      [searchAttributes addObjectsFromArray: mailFields];
      [searchAttributes addObjectsFromArray: [self _constraintsFields]];
      [searchAttributes addObjectsFromArray: commonSearchFields];
      [searchAttributes addObjectUniquely: IDField];

      // Add SOGoLDAPContactInfoAttribute from user defaults
      if ([contactInfoAttribute length])
        [searchAttributes addObjectUniquely: contactInfoAttribute];

      // Add IMAP hostname from user defaults
      if ([IMAPHostField length])
        [searchAttributes addObjectUniquely: IMAPHostField];

      // Add IMAP login from user defaults
      if ([IMAPLoginField length])
        [searchAttributes addObjectUniquely: IMAPLoginField];

      // Add the resources handling attributes
      if ([kindField length])
	[searchAttributes addObjectUniquely: kindField];

      if ([multipleBookingsField length])
	[searchAttributes addObjectUniquely: multipleBookingsField];
    }

  return searchAttributes;
}

- (NSArray *) allEntryIDs
{
  NSEnumerator *entries;
  NGLdapEntry *currentEntry;
  NGLdapConnection *ldapConnection;
  NSString *value;
  NSArray *attributes;
  NSMutableArray *ids;

  ids = [NSMutableArray array];

  ldapConnection = [self _ldapConnection];
  attributes = [NSArray arrayWithObject: IDField];
  if ([_scope caseInsensitiveCompare: @"BASE"] == NSOrderedSame) 
    entries = [ldapConnection baseSearchAtBaseDN: baseDN
                                       qualifier: nil
                                      attributes: attributes];
  else if ([_scope caseInsensitiveCompare: @"ONE"] == NSOrderedSame) 
    entries = [ldapConnection flatSearchAtBaseDN: baseDN
                                       qualifier: nil
                                      attributes: attributes];
  else
    entries = [ldapConnection deepSearchAtBaseDN: baseDN
                                       qualifier: nil
                                      attributes: attributes];

  while ((currentEntry = [entries nextObject]))
    {
      value = [[currentEntry attributeWithName: IDField]
		    stringValueAtIndex: 0];
      if ([value length] > 0)
        [ids addObject: value];
    }

  return ids;
}

- (void) _fillEmailsOfEntry: (NGLdapEntry *) ldapEntry
	   intoContactEntry: (NSMutableDictionary *) contactEntry
{
  NSEnumerator *emailFields;
  NSString *currentFieldName, *ldapValue;
  NSMutableArray *emails;
  NSArray *allValues;

  emails = [[NSMutableArray alloc] init];
  emailFields = [mailFields objectEnumerator];
  while ((currentFieldName = [emailFields nextObject]))
    {
      allValues = [[ldapEntry attributeWithName: currentFieldName]
		    allStringValues];
      [emails addObjectsFromArray: allValues];
    }
  [contactEntry setObject: emails forKey: @"c_emails"];
  [emails release];

  if (IMAPHostField)
    {
      ldapValue = [[ldapEntry attributeWithName: IMAPHostField] stringValueAtIndex: 0];
      if ([ldapValue length] > 0)
	[contactEntry setObject: ldapValue forKey: @"c_imaphostname"];
    }

  if (IMAPLoginField)
    {
      ldapValue = [[ldapEntry attributeWithName: IMAPLoginField] stringValueAtIndex: 0];
      if ([ldapValue length] > 0)
	[contactEntry setObject: ldapValue forKey: @"c_imaplogin"];
    }
}

- (void) _fillConstraints: (NGLdapEntry *) ldapEntry
		forModule: (NSString *) module
	 intoContactEntry: (NSMutableDictionary *) contactEntry
{
  NSDictionary *constraints;
  NSEnumerator *matches;
  NSString *currentMatch, *currentValue, *ldapValue;
  BOOL result;

  result = YES;

  constraints = [modulesConstraints objectForKey: module];
  if (constraints)
    {
      matches = [[constraints allKeys] objectEnumerator];
      currentMatch = [matches nextObject];
      while (result && currentMatch)
	{
	  ldapValue = [[ldapEntry attributeWithName: currentMatch]
			stringValueAtIndex: 0];
	  currentValue = [constraints objectForKey: currentMatch];
	  if ([ldapValue caseInsensitiveMatches: currentValue])
	    currentMatch = [matches nextObject];
	  else
	    result = NO;
	}
    }

  [contactEntry setObject: [NSNumber numberWithBool: result]
		forKey: [NSString stringWithFormat: @"%@Access", module]];
}

- (NSDictionary *) _convertLDAPEntryToContact: (NGLdapEntry *) ldapEntry
{
  NSMutableDictionary *contactEntry;
  NSEnumerator *attributes;
  NSString *currentAttribute, *value;
  NSMutableArray *classes;
  id o;

  contactEntry = [NSMutableDictionary dictionary];
  [contactEntry setObject: [ldapEntry dn] forKey: @"dn"];
  attributes = [[self _searchAttributes] objectEnumerator];

  // We get our objectClass attribute values. We lowercase
  // everything for ease of search after.
  o = [ldapEntry objectClasses];
  classes = nil;

  if (o)
    {
      int i, c;

      classes = [NSMutableArray arrayWithArray: o];
      c = [classes count];
      for (i = 0; i < c; i++)
	[classes replaceObjectAtIndex: i
		 withObject: [[classes objectAtIndex: i] lowercaseString]];
    }

  if (classes)
    {
      [contactEntry setObject: classes
		       forKey: @"objectclasses"];

      // We check if our entry is a group. If so, we set the
      // 'isGroup' custom attribute.
      if ([classes containsObject: @"group"] ||
	  [classes containsObject: @"groupofnames"] ||
	  [classes containsObject: @"groupofuniquenames"] ||
	  [classes containsObject: @"posixgroup"])
	{
	  [contactEntry setObject: [NSNumber numberWithInt: 1]
			   forKey: @"isGroup"];
	}
      // We check if our entry is a resource. We also support
      // determining resources based on the KindFieldName attribute
      // value - see below.
      else if ([classes containsObject: @"calendarresource"])
	{
	  [contactEntry setObject: [NSNumber numberWithInt: 1]
			forKey: @"isResource"];
	}
    }

  while ((currentAttribute = [attributes nextObject]))
    {
      value = [[ldapEntry attributeWithName: currentAttribute]
		stringValueAtIndex: 0];

      // It's important here to set our attributes' key in lowercase.
      if (value)
	{
	  currentAttribute = [currentAttribute lowercaseString];
	  [contactEntry setObject: value forKey: currentAttribute];

	  // We check if that entry corresponds to a resource. For this,
	  // kindField must be defined and it must hold one of those values
	  //				       
	  // location
	  // thing
	  // group
	  //
	  if (kindField &&
	      [kindField caseInsensitiveCompare: currentAttribute] == NSOrderedSame)
	    {
	      if ([value caseInsensitiveCompare: @"location"] == NSOrderedSame ||
		  [value caseInsensitiveCompare: @"thing"] == NSOrderedSame ||
		  [value caseInsensitiveCompare: @"group"] == NSOrderedSame) 
		{
		  [contactEntry setObject: [NSNumber numberWithInt: 1]
				forKey: @"isResource"];
		}
	    }
	  // We check for the number of simultanous bookings that is allowed.
	  // A value of 0 means that there's no limit.
	  if (multipleBookingsField &&
	      [multipleBookingsField caseInsensitiveCompare: currentAttribute] == NSOrderedSame)
	    {
	      [contactEntry setObject: [NSNumber numberWithInt: [value intValue]]
			    forKey: @"numberOfSimultaneousBookings"];
	    }
	}
    }

  value = [[ldapEntry attributeWithName: IDField] stringValueAtIndex: 0];
  if (!value)
    value = @"";
  [contactEntry setObject: value forKey: @"c_name"];
  value = [[ldapEntry attributeWithName: UIDField] stringValueAtIndex: 0];
  if (!value)
    value = @"";
//  else
//    {
//      Eventually, we could check at this point if the entry is a group
//      and prefix the UID with a "@"
//    }
  [contactEntry setObject: value forKey: @"c_uid"];
  value = [[ldapEntry attributeWithName: CNField] stringValueAtIndex: 0];
  if (!value)
    value = @"";
  [contactEntry setObject: value forKey: @"c_cn"];

  if (contactInfoAttribute)
    {
      value = [[ldapEntry attributeWithName: contactInfoAttribute]
                stringValueAtIndex: 0];
      if (!value)
        value = @"";
    }
  else
    value = @"";
  [contactEntry setObject: value forKey: @"c_info"];

  if (domain)
    value = domain;
  else
    value = @"";
  [contactEntry setObject: value forKey: @"c_domain"];

  [self _fillEmailsOfEntry: ldapEntry intoContactEntry: contactEntry];
  [self _fillConstraints: ldapEntry forModule: @"Calendar"
	intoContactEntry: (NSMutableDictionary *) contactEntry];
  [self _fillConstraints: ldapEntry forModule: @"Mail"
	intoContactEntry: (NSMutableDictionary *) contactEntry];

  return contactEntry;
}

- (NSArray *) fetchContactsMatching: (NSString *) match
{
  NGLdapConnection *ldapConnection;
  NGLdapEntry *currentEntry;
  NSEnumerator *entries;
  NSMutableArray *contacts;
  EOQualifier *qualifier;
  NSArray *attributes;

  contacts = [NSMutableArray array];

  if ([match length] > 0)
    {
      ldapConnection = [self _ldapConnection];
      qualifier = [self _qualifierForFilter: match];
      attributes = [self _searchAttributes];

      if ([_scope caseInsensitiveCompare: @"BASE"] == NSOrderedSame)
        entries = [ldapConnection baseSearchAtBaseDN: baseDN
                                           qualifier: qualifier
                                          attributes: attributes];
      else if ([_scope caseInsensitiveCompare: @"ONE"] == NSOrderedSame)
        entries = [ldapConnection flatSearchAtBaseDN: baseDN
                                           qualifier: qualifier
                                          attributes: attributes];
      else /* we do it like before */ 
        entries = [ldapConnection deepSearchAtBaseDN: baseDN
                                           qualifier: qualifier
                                          attributes: attributes];
      while ((currentEntry = [entries nextObject]))
        [contacts addObject:
                    [self _convertLDAPEntryToContact: currentEntry]];
    }

  return contacts;
}

- (NSDictionary *) lookupContactEntry: (NSString *) theID
{
  NGLdapEntry *ldapEntry;
  NGLdapConnection *ldapConnection;
  NSEnumerator *entries;
  EOQualifier *qualifier;
  NSArray *attributes;
  NSString *s;
  NSDictionary *contactEntry;

  contactEntry = nil;

  if ([theID length] > 0)
    {
      ldapConnection = [self _ldapConnection];
      s = [NSString stringWithFormat: @"(%@='%@')",
                    IDField, SafeLDAPCriteria(theID)];
      qualifier = [EOQualifier qualifierWithQualifierFormat: s];
      attributes = [self _searchAttributes];

      if ([_scope caseInsensitiveCompare: @"BASE"] == NSOrderedSame)
        entries = [ldapConnection baseSearchAtBaseDN: baseDN
                                           qualifier: qualifier
                                          attributes: attributes];
      else if ([_scope caseInsensitiveCompare: @"ONE"] == NSOrderedSame)
        entries = [ldapConnection flatSearchAtBaseDN: baseDN
                                           qualifier: qualifier
                                          attributes: attributes];
      else
        entries = [ldapConnection deepSearchAtBaseDN: baseDN
                                           qualifier: qualifier
                                          attributes: attributes];

      ldapEntry = [entries nextObject];
      if (ldapEntry)
        contactEntry = [self _convertLDAPEntryToContact: ldapEntry];
    }

  return contactEntry;
}

- (NSDictionary *) lookupContactEntryWithUIDorEmail: (NSString *) uid
{
  NGLdapConnection *ldapConnection;
  NGLdapEntry *ldapEntry;
  NSEnumerator *entries;
  EOQualifier *qualifier;
  NSArray *attributes;
  NSDictionary *contactEntry;

  contactEntry = nil;

  if ([uid length] > 0)
    {
      ldapConnection = [self _ldapConnection];
      qualifier = [self _qualifierForUIDFilter: uid];
      attributes = [self _searchAttributes];

      if ([_scope caseInsensitiveCompare: @"BASE"] == NSOrderedSame)
        entries = [ldapConnection baseSearchAtBaseDN: baseDN
                                           qualifier: qualifier
                                          attributes: attributes];
      else if ([_scope caseInsensitiveCompare: @"ONE"] == NSOrderedSame)
        entries = [ldapConnection flatSearchAtBaseDN: baseDN
                                           qualifier: qualifier
                                          attributes: attributes];
      else
        entries = [ldapConnection deepSearchAtBaseDN: baseDN
                                           qualifier: qualifier
                                          attributes: attributes];
	  
      ldapEntry = [entries nextObject];
      if (ldapEntry)
        contactEntry = [self _convertLDAPEntryToContact: ldapEntry];
    }

  return contactEntry;
}

- (NSString *) lookupLoginByDN: (NSString *) theDN
{
  NGLdapConnection *ldapConnection;
  NGLdapEntry *entry;
  NSString *login;
  
  login = nil;

  ldapConnection = [self _ldapConnection];
  entry = [ldapConnection entryAtDN: theDN
                         attributes: [NSArray arrayWithObject: UIDField]];
  if (entry)
    login = [[entry attributeWithName: UIDField] stringValueAtIndex: 0];

  return login;
}

- (NSString *) lookupDNByLogin: (NSString *) theLogin
{
  return [_dnCache objectForKey: theLogin];
}

- (NGLdapEntry *) lookupGroupEntryByUID: (NSString *) theUID
{
  return [self lookupGroupEntryByAttribute: UIDField
	       andValue: theUID];
}

- (NGLdapEntry *) lookupGroupEntryByEmail: (NSString *) theEmail
{
#warning We should support MailFieldNames
  return [self lookupGroupEntryByAttribute: @"mail"
	       andValue: theEmail];
}

// This method should accept multiple attributes
- (NGLdapEntry *) lookupGroupEntryByAttribute: (NSString *) theAttribute 
				     andValue: (NSString *) theValue
{
  NSMutableArray *attributes;
  NSEnumerator *entries;
  EOQualifier *qualifier;
  NSString *s;
  NGLdapConnection *ldapConnection;
  NGLdapEntry *ldapEntry;

  if ([theValue length] > 0)
    {
      ldapConnection = [self _ldapConnection];
	  
      s = [NSString stringWithFormat: @"(%@='%@')",
                    theAttribute, SafeLDAPCriteria(theValue)];
      qualifier = [EOQualifier qualifierWithQualifierFormat: s];

      // We look for additional attributes - the ones related to group
      // membership
      attributes = [NSMutableArray arrayWithArray: [self _searchAttributes]];
      [attributes addObject: @"member"];
      [attributes addObject: @"uniqueMember"];
      [attributes addObject: @"memberUid"];
      [attributes addObject: @"memberOf"];

      if ([_scope caseInsensitiveCompare: @"BASE"] == NSOrderedSame)
        entries = [ldapConnection baseSearchAtBaseDN: baseDN
                                           qualifier: qualifier
                                          attributes: attributes];
      else if ([_scope caseInsensitiveCompare: @"ONE"] == NSOrderedSame)
        entries = [ldapConnection flatSearchAtBaseDN: baseDN
                                           qualifier: qualifier
                                          attributes: attributes];
      else
        entries = [ldapConnection deepSearchAtBaseDN: baseDN
                                           qualifier: qualifier
                                          attributes: attributes];
      
      ldapEntry = [entries nextObject];
    }
  else
    ldapEntry = nil;

  return ldapEntry;
}

- (NSString *) sourceID
{
  return sourceID;
}

- (NSString *) baseDN
{
  return baseDN;
}

@end
