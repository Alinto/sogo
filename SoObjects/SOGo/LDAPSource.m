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

#define SafeLDAPCriteria(x) [[x stringByReplacingString: @"\\" withString: @"\\\\"] \
                                stringByReplacingString: @"'" withString: @"\\'"]
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
      IMAPHostField = nil;
      bindFields = nil;
      _scope = @"sub";
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
  [IMAPHostField release];
  [bindFields release];
  [_filter release];
  [ldapConnection release];
  [sourceID release];
  [modulesConstraints release];
  [_scope release];
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
	IMAPHostField: [udSource objectForKey: @"IMAPHostFieldName"]
	andBindFields: [udSource objectForKey: @"bindFields"]];
  ASSIGN (modulesConstraints,
          [udSource objectForKey: @"ModulesConstraints"]);
  ASSIGN (_filter, [udSource objectForKey: @"filter"]);
  ASSIGN (_scope, ([udSource objectForKey: @"scope"]
                   ? [udSource objectForKey: @"scope"]
                   : @"sub"));
  
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
     IMAPHostField: (NSString *) newIMAPHostField
     andBindFields: (NSString *) newBindFields
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
  NSString *escapedUid;
  NSEnumerator *fields;
  NSString *currentField;

  qs = [NSMutableString string];

  escapedUid = SafeLDAPCriteria (uid);

  fields = [[bindFields componentsSeparatedByString: @","] objectEnumerator];
  while ((currentField = [fields nextObject]))
    [qs appendFormat: @" OR (%@='%@')", currentField, escapedUid];

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
      EOQualifier *qualifier;
      NSArray *attributes;

      qualifier = [self _qualifierForBindFilter: loginToCheck];
      attributes = [NSArray arrayWithObject: @"dn"];
      
      if ([_scope caseInsensitiveCompare: @"BASE"] == NSOrderedSame) 
        {
          entries = [ldapConnection baseSearchAtBaseDN: baseDN
				    qualifier: qualifier
				    attributes: attributes];
        }
      else if ([_scope caseInsensitiveCompare: @"ONE"] == NSOrderedSame) 
        {
          entries = [ldapConnection flatSearchAtBaseDN: baseDN
				    qualifier: qualifier
				    attributes: attributes];
	} 
      else 
        {
          entries = [ldapConnection deepSearchAtBaseDN: baseDN
				    qualifier: qualifier
				    attributes: attributes];
        }

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
  NSString *mailFormat, *fieldFormat, *escapedFilter;
  EOQualifier *qualifier;
  NSMutableString *qs;

  escapedFilter = SafeLDAPCriteria (filter);
  if ([escapedFilter length] > 0)
    {
      fieldFormat = [NSString stringWithFormat: @"(%%@='%@*')", escapedFilter];
      mailFormat = [[mailFields stringsWithFormat: fieldFormat]
                     componentsJoinedByString: @" OR "];

      qs = [NSMutableString string];
      if ([escapedFilter isEqualToString: @"."])
        [qs appendFormat: @"(%@='*')", CNField];
      else
        [qs appendFormat: @"(%@='%@*') OR (sn='%@*') OR (displayName='%@*')"
	    @"OR %@ OR (telephoneNumber='*%@*')",
	    CNField, escapedFilter, escapedFilter, escapedFilter, mailFormat,
            escapedFilter];

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
  NSString *mailFormat, *fieldFormat, *escapedUid;
  NSMutableString *qs;

  escapedUid = SafeLDAPCriteria (uid);

  fieldFormat = [NSString stringWithFormat: @"(%%@='%@')", escapedUid];
  mailFormat = [[mailFields stringsWithFormat: fieldFormat]
		 componentsJoinedByString: @" OR "];
  qs = [NSMutableString string];
  
  [qs appendFormat: (@"(%@='%@') OR %@"), UIDField, escapedUid, mailFormat];

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
      NSUserDefaults *ud;
      NSString *attribute;

      ud = [NSUserDefaults standardUserDefaults];
      searchAttributes = [NSMutableArray new];
      [searchAttributes addObject: @"objectClass"];
      if (CNField)
	[searchAttributes addObject: CNField];
      if (UIDField)
	[searchAttributes addObject: UIDField];
      [searchAttributes addObjectsFromArray: mailFields];
      [searchAttributes addObjectsFromArray: [self _constraintsFields]];
      [searchAttributes addObjectsFromArray: commonSearchFields];

      // Add SOGoLDAPContactInfoAttribute from user defaults
      attribute = [ud stringForKey: @"SOGoLDAPContactInfoAttribute"];
      if ([attribute length] > 0 &&
	  ![searchAttributes containsObject: attribute])
	[searchAttributes addObject: attribute];

      // Add IMAP hostname from user defaults
      if (IMAPHostField && [IMAPHostField length] > 0 &&
	  ![searchAttributes containsObject: IMAPHostField])
	[searchAttributes addObject: IMAPHostField];
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
    {
      NSArray *attributes;
      
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
    }
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
  NSString *currentFieldName, *ldapValue;
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

  if (IMAPHostField)
    {
      ldapValue = [[ldapEntry attributeWithName: IMAPHostField] stringValueAtIndex: 0];
      if ([ldapValue length] > 0)
	[contactEntry setObject: ldapValue forKey: @"c_imaphostname"];
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
	{    
	  EOQualifier *qualifier;
	  NSArray *attributes;

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
	}
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

- (NSDictionary *) lookupContactEntry: (NSString *) theID
{
  NSDictionary *contactEntry;
  NGLdapEntry *ldapEntry;

#if defined(THREADSAFE)
  [lock lock];
#endif

  contactEntry = nil;

  if ([theID length] > 0)
    {
      if ([self _initLDAPConnection])
	{
	  NSEnumerator *entries;
	  EOQualifier *qualifier;
	  NSArray *attributes;
	  NSString *s;

	  s = [NSString stringWithFormat: @"(%@='%@')",
                        IDField, SafeLDAPCriteria (theID)];
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
	}
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

- (NSDictionary *) lookupContactEntryWithUIDorEmail: (NSString *) uid
{
  NSDictionary *contactEntry;
  NGLdapEntry *ldapEntry;

#if defined(THREADSAFE)
  [lock lock];
#endif

  contactEntry = nil;

  if ([uid length] > 0)
    {
      if ([self _initLDAPConnection])
	{				       
	  NSEnumerator *entries;
	  EOQualifier *qualifier;
	  NSArray *attributes;
	  
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

- (NSString *) lookupLoginByDN: (NSString *) theDN
{
  NGLdapEntry *entry;
  NSString *login;
  
  login = nil;
  if ([self _initLDAPConnection])
    {
      entry = [ldapConnection entryAtDN: theDN
			      attributes: [NSArray arrayWithObject: UIDField]];
      if (entry)
	login = [[entry attributeWithName: UIDField] stringValueAtIndex: 0];
      [ldapConnection autorelease];
    }
  
  return login;
}

- (NGLdapEntry *) lookupGroupEntryByUID: (NSString *) theUID
{
  return [self lookupGroupEntryByAttribute: UIDField
	       andValue: theUID];
}

- (NGLdapEntry *) lookupGroupEntryByEmail: (NSString *) theEmail
{
  return [self lookupGroupEntryByAttribute: @"mail"
	       andValue: theEmail];
}

- (NGLdapEntry *) lookupGroupEntryByAttribute: (NSString *) theAttribute 
				     andValue: (NSString *) theValue
{
  NGLdapEntry *ldapEntry;

#if defined(THREADSAFE)
  [lock lock];
#endif

  ldapEntry = nil;

  if ([theValue length] > 0)
    {
      if ([self _initLDAPConnection])
	{
	  NSMutableArray *attributes;
	  NSEnumerator *entries;
	  EOQualifier *qualifier;
	  NSString *s;
	  
	  // FIXME

	  // we should support MailFieldNames?
	  s = [NSString stringWithFormat: @"(%@='%@')",
                        theAttribute, SafeLDAPCriteria (theValue)];
	  qualifier = [EOQualifier qualifierWithQualifierFormat: s];
	  
	  // We look for additional attributes - the ones related to group membership
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

      [ldapConnection autorelease];
    }

#if defined(THREADSAFE)
  [lock unlock];
#endif

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
