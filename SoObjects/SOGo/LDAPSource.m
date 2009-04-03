/* LDAPSource.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2009 Inverse inc.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGExtensions/NSObject+Logs.h>
#import <EOControl/EOControl.h>
#import <NGLdap/NGLdapConnection.h>
#import <NGLdap/NGLdapAttribute.h>
#import <NGLdap/NGLdapEntry.h>

#import "LDAPUserManager.h"
#import "NSArray+Utilities.h"
#import "NSString+Utilities.h"

#import "LDAPSource.h"

static NSArray *commonSearchFields;
static NSString *LDAPContactInfoAttribute = nil;
static int timeLimit;
static int sizeLimit;

#if defined(THREADSAFE)
static NSLock *lock;
#endif

@implementation LDAPSource

+ (void) initialize
{
  NSUserDefaults *ud;

  if (!commonSearchFields)
    {
      ud = [NSUserDefaults standardUserDefaults];
      LDAPContactInfoAttribute
	= [ud stringForKey: @"SOGoLDAPContactInfoAttribute"];
      [LDAPContactInfoAttribute retain];
      sizeLimit = [ud integerForKey: @"SOGoLDAPQueryLimit"];
      timeLimit = [ud integerForKey: @"SOGoLDAPQueryTimeout"];

      commonSearchFields = [NSArray arrayWithObjects:
				      @"title",
				    @"company",
				    @"o",
				    @"displayName",
				    @"modifytimestamp",
				    @"mozillaHomeState",
				    @"mozillaHomeUrl",
				    @"homeurl",
				    @"st",
				    @"region",
				    @"mozillaCustom2",
				    @"custom2",
				    @"mozillaHomeCountryName",
				    @"description",
				    @"notes",
				    @"department",
				    @"departmentnumber",
				    @"ou",
				    @"orgunit",
				    @"mobile",
				    @"cellphone",
				    @"carphone",
				    @"mozillaCustom1",
				    @"custom1",
				    @"mozillaNickname",
				    @"xmozillanickname",
				    @"mozillaWorkUrl",
				    @"workurl",
				    @"fax",
				    @"facsimileTelephoneNumber",
				    @"telephoneNumber",
				    @"mozillaHomeStreet",
				    @"mozillaSecondEmail",
				    @"xmozillasecondemail",
				    @"mozillaCustom4",
				    @"custom4",
				    @"nsAIMid",
				    @"nscpaimscreenname",
				    @"street",
				    @"streetAddress",
				    @"postOfficeBox",
				    @"homePhone",
				    @"cn",
				    @"commonname",
				    @"givenName",
				    @"mozillaHomePostalCode",
				    @"mozillaHomeLocalityName",
				    @"mozillaWorkStreet2",
				    @"mozillaUseHtmlMail",
				    @"xmozillausehtmlmail",
				    @"mozillaHomeStreet2",
				    @"postalCode",
				    @"zip",
				    @"c",
				    @"countryname",
				    @"pager",
				    @"pagerphone",
				    @"mail",
				    @"sn",
				    @"surname",
				    @"mozillaCustom3",
				    @"custom3",
				    @"l",
				    @"locality",
				    @"birthyear",
				    @"serialNumber",
				    @"calFBURL", @"proxyAddresses",
				    nil];	
      [commonSearchFields retain];

#if defined(THREADSAFE)
      lock = [NSLock new];
#endif
    }
}

+ (id) sourceFromUDSource: (NSDictionary *) udSource
{
  id newSource;

  newSource = [[self alloc] initFromUDSource: udSource];
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

      baseDN = nil;
      IDField = @"cn"; /* the first part of a user DN */
      CNField = @"cn";
      UIDField = @"uid";
      mailFields = [NSArray arrayWithObject: @"mail"];
      [mailFields retain];
      bindFields = nil;
      _filter = nil;

      ldapConnection = nil;
      searchAttributes = nil;
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
  [bindFields release];
  [_filter release];
  [ldapConnection release];
  [sourceID release];
  [modulesConstraints release];
  [super dealloc];
}

- (id) initFromUDSource: (NSDictionary *) udSource
{
  self = [self init];

  ASSIGN (sourceID, [udSource objectForKey: @"id"]);

  [self setBindDN: [udSource objectForKey: @"bindDN"]
	password: [udSource objectForKey: @"bindPassword"]
	hostname: [udSource objectForKey: @"hostname"]
	port: [udSource objectForKey: @"port"]
	encryption: [udSource objectForKey: @"encryption"]];
  [self setBaseDN: [udSource objectForKey: @"baseDN"]
	IDField: [udSource objectForKey: @"IDFieldName"]
	CNField: [udSource objectForKey: @"CNFieldName"]
	UIDField: [udSource objectForKey: @"UIDFieldName"]
	mailFields: [udSource objectForKey: @"MailFieldNames"]
	andBindFields: [udSource objectForKey: @"bindFields"]];
  ASSIGN (modulesConstraints, [udSource objectForKey: @"ModulesConstraints"]);
  ASSIGN (_filter, [udSource objectForKey: @"filter"]);

  return self;
}

- (void) setBindDN: (NSString *) newBindDN
	  password: (NSString *) newBindPassword
	  hostname: (NSString *) newBindHostname
	      port: (NSString *) newBindPort
	encryption: (NSString *) newEncryption
{
  ASSIGN (bindDN, newBindDN);
  ASSIGN (encryption, [newEncryption uppercaseString]);
  if ([encryption isEqualToString: @"SSL"])
    port = 636;
  ASSIGN (hostname, newBindHostname);
  if (newBindPort)
    port = [newBindPort intValue];
  ASSIGN (password, newBindPassword);
}

- (void) setBaseDN: (NSString *) newBaseDN
	   IDField: (NSString *) newIDField
	   CNField: (NSString *) newCNField
	  UIDField: (NSString *) newUIDField
	mailFields: (NSArray *) newMailFields
     andBindFields: (NSString *) newBindFields
{
  ASSIGN (baseDN, newBaseDN);
  if (newIDField)
    ASSIGN (IDField, newIDField);
  if (newCNField)
    ASSIGN (CNField, newCNField);
  if (newUIDField)
    ASSIGN (UIDField, newUIDField);
  if (newMailFields)
    ASSIGN (mailFields, newMailFields);
  if (newBindFields)
    ASSIGN (bindFields, newBindFields);
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

- (BOOL) _initLDAPConnection
{
  BOOL b;

  NS_DURING
    {
      ldapConnection = [[NGLdapConnection alloc] initWithHostName: hostname
						 port: port];
      if (![encryption length] || [self _setupEncryption: ldapConnection])
	{
	  [ldapConnection bindWithMethod: @"simple"
			  binddn: bindDN
			  credentials: password];
	  if (sizeLimit > 0)
	    [ldapConnection setQuerySizeLimit: sizeLimit];
	  if (timeLimit > 0)
	    [ldapConnection setQueryTimeLimit: timeLimit];
	  b = YES;
	}
      else
	b = NO;
    }
  NS_HANDLER
    {
      NSLog(@"Could not bind to the LDAP server %@ (%d) using the bind DN: %@", hostname, port, bindDN);
      b = NO;
    }
  NS_ENDHANDLER;

  return b;
}

/* user management */
- (EOQualifier *) _qualifierForBindFilter: (NSString *) uid
{
  NSMutableString *qs;
  NSEnumerator *fields;
  NSString *currentField;

  qs = [NSMutableString string];

  fields = [[bindFields componentsSeparatedByString: @","] objectEnumerator];
  while ((currentField = [fields nextObject]))
    [qs appendFormat: @" OR (%@='%@')", currentField, uid];
  
  if (_filter && [_filter length])
    [qs appendFormat: @" AND %@", _filter];

  [qs deleteCharactersInRange: NSMakeRange(0, 4)];

  return [EOQualifier qualifierWithQualifierFormat: qs];
}

- (NSString *) _fetchUserDNForLogin: (NSString *) loginToCheck
{
  NSString *userDN;
  NSEnumerator *entries;
  NGLdapEntry *userEntry;

  if ([self _initLDAPConnection])
    {
      entries = [ldapConnection deepSearchAtBaseDN: baseDN
				qualifier:
				  [self _qualifierForBindFilter: loginToCheck]
				attributes: [NSArray arrayWithObject: @"dn"]];
      userEntry = [entries nextObject];
    }
  else
    userEntry = nil;

  if (userEntry)
    userDN = [userEntry dn];
  else
    userDN = nil;

  [ldapConnection autorelease];

  return userDN;
}

- (BOOL) checkLogin: (NSString *) loginToCheck
	andPassword: (NSString *) passwordToCheck
{
  BOOL didBind;
  NSString *userDN;
  NGLdapConnection *bindConnection;

#if defined(THREADSAFE)
  [lock lock];
#endif

  didBind = NO;

  if ([loginToCheck length] > 0)
    {
      bindConnection = [[NGLdapConnection alloc] initWithHostName: hostname
						 port: port];
      if (![encryption length] || [self _setupEncryption: bindConnection])
	{
	  if (timeLimit > 0)
	    [ldapConnection setQueryTimeLimit: timeLimit];
	  if (bindFields)
	    userDN = [self _fetchUserDNForLogin: loginToCheck];
	  else
	    userDN = [NSString stringWithFormat: @"%@=%@,%@",
			       IDField, loginToCheck, baseDN];
	  if (userDN)
	    {
	      NS_DURING
		didBind = [bindConnection bindWithMethod: @"simple"
					  binddn: userDN
					  credentials: passwordToCheck];
	      NS_HANDLER
		NS_ENDHANDLER
		}
	  [bindConnection release];
	}
    }

#if defined(THREADSAFE)
  [lock unlock];
#endif

  return didBind;
}

/* contact management */
- (EOQualifier *) _qualifierForFilter: (NSString *) filter
{
  NSString *mailFormat, *fieldFormat;
  EOQualifier *qualifier;
  NSMutableString *qs;
  
  fieldFormat = [NSString stringWithFormat: @"(%%@='%@*')", filter];
  mailFormat = [[mailFields stringsWithFormat: fieldFormat]
		 componentsJoinedByString: @" OR "];
  qs = [NSMutableString string];

  if ([filter length] > 0)
    {
      if ([filter isEqualToString: @"."])
        [qs appendFormat: @"(%@='*')", CNField];
      else
        [qs appendFormat: @"(%@='%@*')"
	    @"OR (sn='%@*')"
	    @"OR (displayName='%@*')"
	    @"OR %@"
	    @"OR (telephoneNumber='*%@*')",
	    CNField, filter, filter, filter, mailFormat, filter];
      
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
  NSString *mailFormat, *fieldFormat;
  NSMutableString *qs;

  fieldFormat = [NSString stringWithFormat: @"(%%@='%@')", uid];
  mailFormat = [[mailFields stringsWithFormat: fieldFormat]
		 componentsJoinedByString: @" OR "];
  qs = [NSMutableString string];
  
  [qs appendFormat: (@"(%@='%@') OR %@"), UIDField, uid, mailFormat];
  
  if (_filter && [_filter length])
    [qs appendFormat: @" AND %@", _filter];

  return [EOQualifier qualifierWithQualifierFormat: qs];
}

- (NSArray *) _contraintsFields
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
  NSUserDefaults *ud;
  NSString *contactInfo;

  if (!searchAttributes)
    {
      ud = [NSUserDefaults standardUserDefaults];
      searchAttributes = [NSMutableArray new];
      if (CNField)
	[searchAttributes addObject: CNField];
      if (UIDField)
	[searchAttributes addObject: UIDField];
      [searchAttributes addObjectsFromArray: mailFields];
      [searchAttributes addObjectsFromArray: [self _contraintsFields]];
      [searchAttributes addObjectsFromArray: commonSearchFields];

      // Add SOGoLDAPContactInfoAttribute from user defaults
      contactInfo = [ud stringForKey: @"SOGoLDAPContactInfoAttribute"];
      if ([contactInfo length] > 0 &&
	  ![searchAttributes containsObject: contactInfo])
	[searchAttributes addObject: contactInfo];
    }

  return searchAttributes;
}

- (NSArray *) allEntryIDs
{
  NSMutableArray *ids;
  NSEnumerator *entries;
  NGLdapEntry *currentEntry;
  NSString *value;

#if defined(THREADSAFE)
  [lock lock];
#endif

  ids = [NSMutableArray array];

  if ([self _initLDAPConnection])
    entries = [ldapConnection deepSearchAtBaseDN: baseDN
			      qualifier: nil
			      attributes: [NSArray arrayWithObject: IDField]];
  else
    entries = nil;

  if (entries)
    {
      currentEntry = [entries nextObject];
      while (currentEntry)
	{
	  value = [[currentEntry attributeWithName: IDField]
		    stringValueAtIndex: 0];
	  if ([value length] > 0)
	    [ids addObject: value];
	  currentEntry = [entries nextObject];
	}
    }

  [ldapConnection autorelease];

#if defined(THREADSAFE)
  [lock unlock];
#endif

  return ids;
}

- (void) _fillEmailsOfEntry: (NGLdapEntry *) ldapEntry
	   intoContactEntry: (NSMutableDictionary *) contactEntry
{
  NSEnumerator *emailFields;
  NSString *currentFieldName;
  NSMutableArray *emails;
  NSArray *allValues;

  emails = [NSMutableArray new];
  emailFields = [mailFields objectEnumerator];
  while ((currentFieldName = [emailFields nextObject]))
    {
      allValues = [[ldapEntry attributeWithName: currentFieldName]
		    allStringValues];
      [emails addObjectsFromArray: allValues];
    }
  [contactEntry setObject: emails forKey: @"c_emails"];
  [emails release];
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

  contactEntry = [NSMutableDictionary dictionary];
  attributes = [[self _searchAttributes] objectEnumerator];
  while ((currentAttribute = [attributes nextObject]))
    {
      value = [[ldapEntry attributeWithName: currentAttribute]
		stringValueAtIndex: 0];
      if (value)
	[contactEntry setObject: value forKey: currentAttribute];
    }
  value = [[ldapEntry attributeWithName: IDField] stringValueAtIndex: 0];
  if (!value)
    value = @"";
  [contactEntry setObject: value forKey: @"c_name"];
  value = [[ldapEntry attributeWithName: UIDField] stringValueAtIndex: 0];
  if (!value)
    value = @"";
  [contactEntry setObject: value forKey: @"c_uid"];
  value = [[ldapEntry attributeWithName: CNField] stringValueAtIndex: 0];
  if (!value)
    value = @"";
  [contactEntry setObject: value forKey: @"c_cn"];
  [self _fillEmailsOfEntry: ldapEntry intoContactEntry: contactEntry];
  [self _fillConstraints: ldapEntry forModule: @"Calendar"
	intoContactEntry: (NSMutableDictionary *) contactEntry];
  [self _fillConstraints: ldapEntry forModule: @"Mail"
	intoContactEntry: (NSMutableDictionary *) contactEntry];

  return contactEntry;
}

- (NSArray *) fetchContactsMatching: (NSString *) match
{
  NSMutableArray *contacts;
  NGLdapEntry *currentEntry;
  NSEnumerator *entries;

#if defined(THREADSAFE)
  [lock lock];
#endif

  contacts = [NSMutableArray array];

  if ([match length] > 0)
    {
      if ([self _initLDAPConnection])
	entries = [ldapConnection deepSearchAtBaseDN: baseDN
				  qualifier: [self _qualifierForFilter: match]
				  attributes: [self _searchAttributes]];
      else
	entries = nil;

      if (entries)
	while ((currentEntry = [entries nextObject]))
	  [contacts addObject:
		      [self _convertLDAPEntryToContact: currentEntry]];

      [ldapConnection release];
    }

#if defined(THREADSAFE)
  [lock unlock];
#endif

  return contacts;
}

- (NSDictionary *) lookupContactEntry: (NSString *) entryID;
{
  NSDictionary *contactEntry;
  NGLdapEntry *ldapEntry;

#if defined(THREADSAFE)
  [lock lock];
#endif

  contactEntry = nil;

  if ([entryID length] > 0)
    {
      if ([self _initLDAPConnection])
	ldapEntry
	  = [ldapConnection entryAtDN: [NSString stringWithFormat: @"%@=%@,%@",
						 IDField, entryID, baseDN]
			    attributes: [self _searchAttributes]];
      else
	ldapEntry = nil;
      
      if (ldapEntry)
	contactEntry = [self _convertLDAPEntryToContact: ldapEntry];

      [ldapConnection autorelease];
    }

#if defined(THREADSAFE)
  [lock unlock];
#endif

  return contactEntry;
}

- (NSDictionary *) lookupContactEntryWithUIDorEmail: (NSString *) uid;
{
  NSDictionary *contactEntry;
  NGLdapEntry *ldapEntry;
  NSEnumerator *entries;
  EOQualifier *qualifier;

#if defined(THREADSAFE)
  [lock lock];
#endif

  contactEntry = nil;

  if ([uid length] > 0)
    {
      if ([self _initLDAPConnection])
	{
	  qualifier = [self _qualifierForUIDFilter: uid];
	  entries = [ldapConnection deepSearchAtBaseDN: baseDN
				    qualifier: qualifier
				    attributes: [self _searchAttributes]];
	  ldapEntry = [entries nextObject];
	}
      else
	ldapEntry = nil;
      
      if (ldapEntry)
	contactEntry = [self _convertLDAPEntryToContact: ldapEntry];

      [ldapConnection release];
    }

#if defined(THREADSAFE)
  [lock unlock];
#endif

  return contactEntry;
}

- (NSString *) sourceID
{
  return sourceID;
}

@end
