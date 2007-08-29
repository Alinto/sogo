/* LDAPSource.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <EOControl/EOControl.h>
#import <NGLdap/NGLdapConnection.h>
#import <NGLdap/NGLdapAttribute.h>
#import <NGLdap/NGLdapEntry.h>

#import "LDAPSource.h"

static NSArray *commonSearchFields;
static int timeLimit;
static int sizeLimit;

@implementation LDAPSource

+ (void) initialize
{
  NSUserDefaults *ud;

  if (!commonSearchFields)
    {
      ud = [NSUserDefaults standardUserDefaults];
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
				    @"calFBURL",
				    nil];
      [commonSearchFields retain];
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
      password = nil;

      baseDN = nil;
      IDField = @"cn"; /* the first part of a user DN */
      CNField = @"cn";
      UIDField = @"uid";
      bindFields = nil;

      ldapConnection = nil;
      searchAttributes = nil;
    }

  return self;
}

- (void) dealloc
{
  [bindDN release];
  [hostname release];
  [password release];
  [baseDN release];
  [IDField release];
  [CNField release];
  [UIDField release];
  [bindFields release];
  [ldapConnection release];
  [super dealloc];
}

- (id) initFromUDSource: (NSDictionary *) udSource
{
  self = [self init];

  [self setBindDN: [udSource objectForKey: @"bindDN"]
	hostname: [udSource objectForKey: @"hostname"]
	port: [udSource objectForKey: @"port"]
	andPassword: [udSource objectForKey: @"bindPassword"]];
  [self setBaseDN: [udSource objectForKey: @"baseDN"]
	IDField: [udSource objectForKey: @"IDFieldName"]
	CNField: [udSource objectForKey: @"CNFieldName"]
	UIDField:  [udSource objectForKey: @"UIDFieldName"]
	andBindFields: [udSource objectForKey: @"bindFields"]];

  return self;
}

- (void) setBindDN: (NSString *) newBindDN
	  hostname: (NSString *) newBindHostname
	      port: (NSString *) newBindPort
       andPassword: (NSString *) newBindPassword
{
  ASSIGN (bindDN, newBindDN);
  ASSIGN (hostname, newBindHostname);
  if (newBindPort)
    port = [newBindPort intValue];
  ASSIGN (password, newBindPassword);
}

- (void) setBaseDN: (NSString *) newBaseDN
	   IDField: (NSString *) newIDField
	   CNField: (NSString *) newCNField
	  UIDField: (NSString *) newUIDField
     andBindFields: (NSString *) newBindFields
{
  ASSIGN (baseDN, newBaseDN);
  if (newIDField)
    ASSIGN (IDField, newIDField);
  if (CNField)
    ASSIGN (CNField, newCNField);
  if (UIDField)
    ASSIGN (UIDField, newUIDField);
  if (newBindFields)
    ASSIGN (bindFields, newBindFields);
}

- (void) _initLDAPConnection
{
  ldapConnection = [[NGLdapConnection alloc] initWithHostName: hostname
					     port: port];
  [ldapConnection bindWithMethod: @"simple"
		  binddn: bindDN
		  credentials: password];
  if (sizeLimit > 0)
    [ldapConnection setQuerySizeLimit: sizeLimit];
  if (timeLimit > 0)
    [ldapConnection setQueryTimeLimit: timeLimit];
}

/* user management */
- (EOQualifier *) _qualifierForBindFilter: (NSString *) uid
{
  NSMutableString *qs;
  NSEnumerator *fields;
  NSString *currentField;

  qs = [NSMutableString string];
  fields = [[bindFields componentsSeparatedByString: @","] objectEnumerator];
  currentField = [fields nextObject];
  while (currentField)
    {
      [qs appendFormat: @"OR (%@='%@')", currentField, uid];
      currentField = [fields nextObject];
    }
  [qs deleteCharactersInRange: NSMakeRange (0, 3)];

  return [EOQualifier qualifierWithQualifierFormat: qs];
}

- (NSString *) _fetchUserDNForLogin: (NSString *) loginToCheck
{
  NSString *userDN;
  NSEnumerator *entries;
  NGLdapEntry *userEntry;

  [self _initLDAPConnection];
  entries = [ldapConnection deepSearchAtBaseDN: baseDN
			    qualifier: [self _qualifierForBindFilter: loginToCheck]
			    attributes: [NSArray arrayWithObject: @"dn"]];
  userEntry = [entries nextObject];
  if (userEntry)
    userDN = [userEntry dn];
  else
    userDN = nil;
  [ldapConnection release];

  return userDN;
}

- (BOOL) checkLogin: (NSString *) loginToCheck
	andPassword: (NSString *) passwordToCheck
{
  BOOL didBind;
  NSString *userDN;
  NGLdapConnection *bindConnection;

  didBind = NO;

  if ([loginToCheck length] > 0)
    {
      bindConnection = [[NGLdapConnection alloc] initWithHostName: hostname
						 port: port];
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

  return didBind;
}

/* contact management */
- (EOQualifier *) _qualifierForFilter: (NSString *) filter
{
  NSString *qs;
  EOQualifier *qualifier;

  if ([filter length] > 0)
    {
      if ([filter isEqualToString: @"."])
        qs = @"(cn='*')";
      else
        qs = [NSString stringWithFormat:
                         @"(cn='%@*')"
                       @"OR (sn='%@*')"
                       @"OR (displayName='%@*')"
                       @"OR (mail='%@*')"
                       @"OR (telephoneNumber='*%@*')",
                       filter, filter, filter, filter, filter];
      qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
    }
  else
    qualifier = nil;

  return qualifier;
}

- (EOQualifier *) _qualifierForUIDFilter: (NSString *) uid
{
  NSString *qs;

  qs = [NSString stringWithFormat: (@"(%@='%@') OR (mail='%@')"
				    @" OR (mozillaSecondEmail='%@')"
				    @" OR (xmozillasecondemail='%@')"),
		 UIDField, uid, uid, uid, uid];

  return [EOQualifier qualifierWithQualifierFormat: qs];
}

- (NSArray *) _searchAttributes
{
  if (!searchAttributes)
    {
      searchAttributes = [NSMutableArray new];
      if (CNField)
	[searchAttributes addObject: CNField];
      if (UIDField)
	[searchAttributes addObject: UIDField];
      [searchAttributes addObjectsFromArray: commonSearchFields];
    }

  return searchAttributes;
}

- (NSArray *) allEntryIDs
{
  NSMutableArray *ids;
  NSEnumerator *entries;
  NGLdapEntry *currentEntry;
  NSString *value;

  ids = [NSMutableArray array];

  [self _initLDAPConnection];
  entries = [ldapConnection deepSearchAtBaseDN: baseDN
			    qualifier: nil
			    attributes: [NSArray arrayWithObject: IDField]];
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
  [ldapConnection release];

  return ids;
}

- (NSDictionary *) _convertLDAPEntryToContact: (NGLdapEntry *) ldapEntry
{
  NSMutableDictionary *contactEntry;
  NSEnumerator *attributes;
  NSString *currentAttribute, *value;

  contactEntry = [NSMutableDictionary dictionary];
  attributes = [[self _searchAttributes] objectEnumerator];
  currentAttribute = [attributes nextObject];
  while (currentAttribute)
    {
      value = [[ldapEntry attributeWithName: currentAttribute]
		stringValueAtIndex: 0];
      if (value)
	[contactEntry setObject: value forKey: currentAttribute];
      currentAttribute = [attributes nextObject];
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

  return contactEntry;
}

- (NSArray *) fetchContactsMatching: (NSString *) match
{
  NSMutableArray *contacts;
  NGLdapEntry *currentEntry;
  NSEnumerator *entries;

  contacts = [NSMutableArray array];

  if ([match length] > 0)
    {
      [self _initLDAPConnection];
      entries = [ldapConnection deepSearchAtBaseDN: baseDN
				qualifier: [self _qualifierForFilter: match]
				attributes: [self _searchAttributes]];
      if (entries)
	{
	  currentEntry = [entries nextObject];
	  while (currentEntry)
	    {
	      [contacts addObject:
			  [self _convertLDAPEntryToContact: currentEntry]];
	      currentEntry = [entries nextObject];
	    }
	}
      [ldapConnection release];
    }

  return contacts;
}

- (NSDictionary *) lookupContactEntry: (NSString *) entryID;
{
  NSDictionary *contactEntry;
  NGLdapEntry *ldapEntry;

  contactEntry = nil;

  if ([entryID length] > 0)
    {
      [self _initLDAPConnection];
      ldapEntry
	= [ldapConnection entryAtDN: [NSString stringWithFormat: @"%@=%@,%@",
					       IDField, entryID, baseDN]
			  attributes: [self _searchAttributes]];
      if (ldapEntry)
	contactEntry = [self _convertLDAPEntryToContact: ldapEntry];
      [ldapConnection release];
    }

  return contactEntry;
}

- (NSDictionary *) lookupContactEntryWithUIDorEmail: (NSString *) uid;
{
  NSDictionary *contactEntry;
  NGLdapEntry *ldapEntry;
  NSEnumerator *entries;
  EOQualifier *qualifier;

  contactEntry = nil;

  if ([uid length] > 0)
    {
      [self _initLDAPConnection];
      qualifier = [self _qualifierForUIDFilter: uid];
      entries = [ldapConnection deepSearchAtBaseDN: baseDN
				qualifier: qualifier
				attributes: [self _searchAttributes]];
      ldapEntry = [entries nextObject];
      if (ldapEntry)
	contactEntry = [self _convertLDAPEntryToContact: ldapEntry];
      [ldapConnection release];
    }

  return contactEntry;
}

@end
