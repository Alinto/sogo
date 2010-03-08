/* SOGoUserManager.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2010 Inverse inc.
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
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSException.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSValue.h>
#import <NGExtensions/NSObject+Logs.h>

#import "NSDictionary+BSJSONAdditions.h"
#import "NSArray+Utilities.h"
#import "SOGoDomainDefaults.h"
#import "SOGoSource.h"
#import "SOGoSystemDefaults.h"
#import "SOGoUserManager.h"
#import "SOGoCache.h"
#import "SOGoConstants.h"
#import "SOGoSource.h"

@implementation SOGoUserManagerRegistry

+ (id) sharedRegistry
{
  static id sharedRegistry = nil;

  if (!sharedRegistry)
    sharedRegistry = [self new];

  return sharedRegistry;
}

- (NSString *) sourceClassForType: (NSString *) type
{
  NSString *sourceClass;

  if (type)
    {
      if ([type isEqualToString: @"ldap"])
        sourceClass = @"LDAPSource";
      else if ([type isEqualToString: @"sql"])
        sourceClass = @"SQLSource";
      else
        [NSException raise: @"SOGoUserManagerRegistryException"
                    format: @"No class known for type '%@'", type];
    }
  else
    sourceClass = @"LDAPSource";

  return sourceClass;
}

@end

@implementation SOGoUserManager

+ (id) sharedUserManager
{
  static id sharedUserManager = nil;

  if (!sharedUserManager)
    sharedUserManager = [self new];

  return sharedUserManager;
}

- (void) _registerSource: (NSDictionary *) udSource
                inDomain: (NSString *) domain
{
  NSString *sourceID, *value, *type;
  NSMutableDictionary *metadata;
  NSObject <SOGoSource> *sogoSource;
  BOOL isAddressBook;
  Class c;

  sourceID = [udSource objectForKey: @"id"];
  if ([sourceID length] > 0)
    {
      type = [[udSource objectForKey: @"type"] lowercaseString];
      c = NSClassFromString([_registry sourceClassForType: type]);
      sogoSource = [c sourceFromUDSource: udSource inDomain: domain];
      if (sourceID)
        [_sources setObject: sogoSource forKey: sourceID];
      else
        [self errorWithFormat: @"id field missing in an user source,"
              @" check the SOGoUserSources defaults"];
      metadata = [NSMutableDictionary dictionary];
      if (domain)
        [metadata setObject: domain forKey: @"domain"];
      value = [udSource objectForKey: @"canAuthenticate"];
      if (value)
        [metadata setObject: value forKey: @"canAuthenticate"];
      value = [udSource objectForKey: @"isAddressBook"];
      if (value)
        {
          [metadata setObject: value forKey: @"isAddressBook"];
          isAddressBook = [value boolValue];
        }
      else
        isAddressBook = NO;
      value = [udSource objectForKey: @"displayName"];
      if (value)
        [metadata setObject: value forKey: @"displayName"];
      else
        {
          if (isAddressBook)
            [self errorWithFormat: @"addressbook source '%@' has"
                  @" no displayname", sourceID];
        }
      value = [udSource objectForKey: @"MailFieldNames"];
      if (value)
        [metadata setObject: value forKey: @"MailFieldNames"];
      [_sourcesMetadata setObject: metadata forKey: sourceID];
    }
  else
    [self errorWithFormat: @"attempted to register a contact/user source"
          @" without id (skipped)"];
}

- (int) _registerSourcesInDomain: (NSString *) domain
{
  NSArray *userSources;
  unsigned int count, max;
  SOGoDomainDefaults *dd;

  if (domain)
    dd = [SOGoDomainDefaults defaultsForDomain: domain];
  else
    dd = [SOGoSystemDefaults sharedSystemDefaults];

  userSources = [dd userSources];
  max = [userSources count];
  for (count = 0; count < max; count++)
    [self _registerSource: [userSources objectAtIndex: count]
                 inDomain: domain];

  return max;
}

- (void) _prepareSources
{
  NSArray *domains;
  unsigned int count, max, total;

  _sources = [[NSMutableDictionary alloc] init];
  _sourcesMetadata = [[NSMutableDictionary alloc] init];

  total = [self _registerSourcesInDomain: nil];
  domains = [[SOGoSystemDefaults sharedSystemDefaults] domainIds];
  max = [domains count];
  for (count = 0; count < max; count++)
    total += [self _registerSourcesInDomain: [domains objectAtIndex: count]];

  if (!total)
    [self errorWithFormat: @"No authentication sources defined - nobody will be able to login. Check your defaults."];
}

- (id) init
{
  if ((self = [super init]))
    {
      _sources = nil;
      _sourcesMetadata = nil;
      _registry = [NSClassFromString ([self registryClass]) sharedRegistry];
      [self _prepareSources];
    }

  return self;
}

- (void) dealloc
{
  [_sources release];
  [_sourcesMetadata release];
  [super dealloc];
}

- (NSString *) registryClass
{
  return @"SOGoUserManagerRegistry";
}

- (NSArray *) sourceIDsInDomain: (NSString *) domain
{
  NSMutableArray *sourceIDs;
  NSArray *keys;
  int count, max;
  NSString *currentID, *sourceDomain;
  NSObject <SOGoSource> *currentSource;

  keys = [_sources allKeys];
  max = [keys count];
  sourceIDs = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      currentID = [keys objectAtIndex: count];
      currentSource = [_sources objectForKey: currentID];
      sourceDomain = [currentSource domain];
      if (![sourceDomain length] || [sourceDomain isEqualToString: domain])
        [sourceIDs addObject: currentID];
    }

  return sourceIDs;
}

- (NSObject <SOGoSource> *) sourceWithID: (NSString *) sourceID
{
  return [_sources objectForKey: sourceID];
}

- (NSDictionary *) metadataForSourceID: (NSString *) sourceID
{
  return [_sourcesMetadata objectForKey: sourceID];
}

- (NSArray *) authenticationSourceIDsInDomain: (NSString *) domain
{
  NSMutableArray *sourceIDs;
  NSEnumerator *allIDs;
  NSString *currentID, *sourceDomain;
  NSDictionary *metadata;

  sourceIDs = [NSMutableArray array];
  allIDs = [[_sources allKeys] objectEnumerator];
  while ((currentID = [allIDs nextObject]))
    {
      sourceDomain = [[_sources objectForKey: currentID] domain];
      if (![domain length] || [domain isEqualToString: sourceDomain])
        {
          metadata = [_sourcesMetadata objectForKey: currentID];
          if ([[metadata objectForKey: @"canAuthenticate"] boolValue])
            [sourceIDs addObject: currentID];
        }
    }

  return sourceIDs;
}

- (NSArray *) addressBookSourceIDsInDomain: (NSString *) domain
{
  NSMutableArray *sourceIDs;
  NSEnumerator *allIDs;
  NSString *currentID;
  NSDictionary *metadata;

  sourceIDs = [NSMutableArray array];
  allIDs = [[self sourceIDsInDomain: domain] objectEnumerator];
  while ((currentID = [allIDs nextObject]))
    {
      metadata = [_sourcesMetadata objectForKey: currentID];
      if ([[metadata objectForKey: @"isAddressBook"] boolValue])
        [sourceIDs addObject: currentID];
    }

  return sourceIDs;
}

- (NSString *) displayNameForSourceWithID: (NSString *) sourceID
{
  NSDictionary *metadata;

  metadata = [_sourcesMetadata objectForKey: sourceID];

  return [metadata objectForKey: @"displayName"];
}

- (NSString *) getCNForUID: (NSString *) uid
{
  NSDictionary *contactInfos;

//   NSLog (@"getCNForUID: %@", uid);
  contactInfos = [self contactInfosForUserWithUIDorEmail: uid];

  return [contactInfos objectForKey: @"cn"];
}

- (NSString *) getEmailForUID: (NSString *) uid
{
  NSDictionary *contactInfos;

//   NSLog (@"getEmailForUID: %@", uid);
  contactInfos = [self contactInfosForUserWithUIDorEmail: uid];

  return [contactInfos objectForKey: @"c_email"];
}

- (NSString *) getFullEmailForUID: (NSString *) uid
{
  NSDictionary *contactInfos;

  contactInfos = [self contactInfosForUserWithUIDorEmail: uid];

  return [NSString stringWithFormat: @"%@ <%@>",
		   [contactInfos objectForKey: @"cn"],
		   [contactInfos objectForKey: @"c_email"]];
}

- (NSString *) getImapLoginForUID: (NSString *) uid
{
  NSDictionary *contactInfos;
  NSString *domain;
  SOGoDomainDefaults *dd;

  contactInfos = [self contactInfosForUserWithUIDorEmail: uid];
  domain = [contactInfos objectForKey: @"c_domain"];
  if ([domain length])
    dd = [SOGoDomainDefaults defaultsForDomain: domain];
  else
    dd = [SOGoSystemDefaults sharedSystemDefaults];

  return ([dd forceIMAPLoginWithEmail] ? [self getEmailForUID: uid] : uid);
}

- (NSString *) getUIDForEmail: (NSString *) email
{
  NSDictionary *contactInfos;

  contactInfos = [self contactInfosForUserWithUIDorEmail: email];

  return [contactInfos objectForKey: @"c_uid"];
}

- (BOOL) _sourceChangePasswordForLogin: (NSString *) login
                           oldPassword: (NSString *) oldPassword
			   newPassword: (NSString *) newPassword
			   perr: (SOGoPasswordPolicyError *) perr
{
  NSObject <SOGoSource> *sogoSource;
  NSEnumerator *authIDs;
  NSString *currentID;
  BOOL didChange;
  
  didChange = NO;
  
  authIDs = [[self authenticationSourceIDsInDomain: nil] objectEnumerator];
  while (!didChange && (currentID = [authIDs nextObject]))
    {
      sogoSource = [_sources objectForKey: currentID];
      didChange = [sogoSource changePasswordForLogin: login
			      oldPassword: oldPassword
			      newPassword: newPassword
			      perr: perr];
    }

  return didChange;
}

- (BOOL) _sourceCheckLogin: (NSString *) login
               andPassword: (NSString *) password
	       perr: (SOGoPasswordPolicyError *) perr
	       expire: (int *) expire
	       grace: (int *) grace
{
  NSObject <SOGoSource> *sogoSource;
  NSEnumerator *authIDs;
  NSString *currentID;
  BOOL checkOK;
  
  checkOK = NO;
  
  authIDs = [[self authenticationSourceIDsInDomain: nil] objectEnumerator];
  while (!checkOK && (currentID = [authIDs nextObject]))
    {
      sogoSource = [_sources objectForKey: currentID];
      checkOK = [sogoSource checkLogin: login
			    password: password
			    perr: perr
			    expire: expire
			    grace: grace];
    }


  return checkOK;
}

- (BOOL) checkLogin: (NSString *) _login
	   password: (NSString *) _pwd
	       perr: (SOGoPasswordPolicyError *) _perr
	     expire: (int *) _expire
	      grace: (int *) _grace
{
  NSString *dictPassword, *jsonUser;
  NSMutableDictionary *currentUser;
  BOOL checkOK;
 
  jsonUser = [[SOGoCache sharedCache] userAttributesForLogin: _login];
  currentUser = [NSMutableDictionary dictionaryWithJSONString: jsonUser];
  dictPassword = [currentUser objectForKey: @"password"];
  if (currentUser && dictPassword)
    checkOK = ([dictPassword isEqualToString: _pwd]);
  else if ([self _sourceCheckLogin: _login
		 andPassword: _pwd
		 perr: _perr
		 expire: _expire
		 grace: _grace])
    {
      checkOK = YES;
      if (!currentUser)
	{
	  currentUser = [NSMutableDictionary dictionary];
	}

      // It's important to cache the password here as we might have cached the
      // user's entry in -contactInfosForUserWithUIDorEmail: and if we don't
      // set the password and recache the entry, the password would never be
      // cached for the user unless its entry expires from memcached's
      // internal cache.
      [currentUser setObject: _pwd forKey: @"password"];
      [[SOGoCache sharedCache]
        setUserAttributes: [currentUser jsonStringValue]
                 forLogin: _login];
    }
    else
      checkOK = NO;

  return checkOK;
}

- (BOOL) changePasswordForLogin: (NSString *) login
		    oldPassword: (NSString *) oldPassword
		    newPassword: (NSString *) newPassword
			   perr: (SOGoPasswordPolicyError *) perr
{
  NSString *dictPassword, *jsonUser;
  NSMutableDictionary *currentUser;
  BOOL didChange;
 
  jsonUser = [[SOGoCache sharedCache] userAttributesForLogin: login];
  currentUser = [NSMutableDictionary dictionaryWithJSONString: jsonUser];
  dictPassword = [currentUser objectForKey: @"password"];

  if ([self _sourceChangePasswordForLogin: login
	    oldPassword: oldPassword
	    newPassword: newPassword
	    perr: perr])
    {
      didChange = YES;

      if (!currentUser)
	{
	  currentUser = [NSMutableDictionary dictionary];
	}

      // It's important to cache the password here as we might have cached the
      // user's entry in -contactInfosForUserWithUIDorEmail: and if we don't
      // set the password and recache the entry, the password would never be
      // cached for the user unless its entry expires from memcached's
      // internal cache.
      [currentUser setObject: newPassword forKey: @"password"];
      [[SOGoCache sharedCache]
        setUserAttributes: [currentUser jsonStringValue]
	forLogin: login];
    }
    else
      didChange = NO;

  return didChange;
}

- (void) _fillContactMailRecords: (NSMutableDictionary *) contact
{
  NSString *uid, *domain, *systemEmail;
  NSMutableArray *emails;
  SOGoDomainDefaults *dd;

  domain = [contact objectForKey: @"c_domain"];
  if ([domain length])
    dd = [SOGoDomainDefaults defaultsForDomain: domain];
  else
    dd = [SOGoSystemDefaults sharedSystemDefaults];
  emails = [contact objectForKey: @"emails"];
  uid = [contact objectForKey: @"c_uid"];
  if ([uid rangeOfString: @"@"].location == NSNotFound)
    systemEmail
      = [NSString stringWithFormat: @"%@@%@", uid, [dd mailDomain]];
  else
    systemEmail = uid;
  [emails addObject: systemEmail];
  [contact setObject: [emails objectAtIndex: 0] forKey: @"c_email"];
}

- (void) _fillContactInfosForUser: (NSMutableDictionary *) currentUser
		   withUIDorEmail: (NSString *) uid
{
  NSMutableArray *emails;
  NSDictionary *userEntry;
  NSEnumerator *sogoSources;
  NSObject <SOGoDNSource> *currentSource;
  NSString *sourceID, *cn, *c_domain, *c_uid, *c_imaphostname;
  NSArray *c_emails;
  BOOL access;

  emails = [NSMutableArray array];
  cn = nil;
  c_uid = nil;
  c_domain = nil;
  c_imaphostname = nil;

  [currentUser setObject: [NSNumber numberWithBool: YES]
	       forKey: @"CalendarAccess"];
  [currentUser setObject: [NSNumber numberWithBool: YES]
	       forKey: @"MailAccess"];

  sogoSources = [[self authenticationSourceIDsInDomain: nil]
                  objectEnumerator];
  while ((sourceID = [sogoSources nextObject]))
    {
      currentSource = [_sources objectForKey: sourceID];
      userEntry = [currentSource lookupContactEntryWithUIDorEmail: uid];
      if (userEntry)
	{
	  if (!cn)
	    cn = [userEntry objectForKey: @"c_cn"];
	  if (!c_uid)
	    c_uid = [userEntry objectForKey: @"c_uid"];
          if (!c_domain)
            c_domain = [userEntry objectForKey: @"c_domain"];
	  c_emails = [userEntry objectForKey: @"c_emails"];
	  if ([c_emails count])
	    [emails addObjectsFromArray: c_emails];
	  if (!c_imaphostname)
	    c_imaphostname = [userEntry objectForKey: @"c_imaphostname"];
	  access = [[userEntry objectForKey: @"CalendarAccess"] boolValue];
	  if (!access)
	    [currentUser setObject: [NSNumber numberWithBool: NO]
			 forKey: @"CalendarAccess"];
	  access = [[userEntry objectForKey: @"MailAccess"] boolValue];
	  if (!access)
	    [currentUser setObject: [NSNumber numberWithBool: NO]
			 forKey: @"MailAccess"];
	}
    }

  if (!cn)
    cn = @"";
  if (!c_uid)
    c_uid = @"";
  if (!c_domain)
    c_domain = @"";
  
  if (c_imaphostname)
    [currentUser setObject: c_imaphostname forKey: @"c_imaphostname"];
  [currentUser setObject: emails forKey: @"emails"];
  [currentUser setObject: cn forKey: @"cn"];
  [currentUser setObject: c_uid forKey: @"c_uid"];
  [currentUser setObject: c_domain forKey: @"c_domain"];

  // If our LDAP queries gave us nothing, we add at least one default
  // email address based on the default domain.
  [self _fillContactMailRecords: currentUser];
}

//
// We cache here all identities, including those
// associated with email addresses.
//
- (void) _retainUser: (NSDictionary *) newUser
{
  NSEnumerator *emails;
  NSString *key;
  
  key = [newUser objectForKey: @"c_uid"];
  if (key)
    [[SOGoCache sharedCache]
        setUserAttributes: [newUser jsonStringValue]
                 forLogin: key];

  emails = [[newUser objectForKey: @"emails"] objectEnumerator];
  while ((key = [emails nextObject]))
    [[SOGoCache sharedCache]
        setUserAttributes: [newUser jsonStringValue]
                 forLogin: key];
}

- (NSDictionary *) contactInfosForUserWithUIDorEmail: (NSString *) uid
{
  NSMutableDictionary *currentUser, *contactInfos;
  NSString *aUID, *jsonUser;
  BOOL newUser;

  if ([uid length] > 0)
    {
      // Remove the "@" prefix used to identified groups in the ACL tables.
      aUID = [uid hasPrefix: @"@"] ? [uid substringFromIndex: 1] : uid;
      contactInfos = [NSMutableDictionary dictionary];
      jsonUser = [[SOGoCache sharedCache] userAttributesForLogin: aUID];
      currentUser = [NSMutableDictionary dictionaryWithJSONString: jsonUser];
      if (!([currentUser objectForKey: @"emails"]
	    && [currentUser objectForKey: @"cn"]))
	{
	  // We make sure that we either have no occurence of a cache entry or
	  // that we have an occurence with only a cached password. In the
	  // latter case, we update the entry with the remaining information
	  // and recache the value.
	  if (!currentUser || ([currentUser count] == 1 && [currentUser objectForKey: @"password"]))
	    {
	      newUser = YES;

	      if (!currentUser)
		currentUser = [NSMutableDictionary dictionary];
	    }
	  else
	    newUser = NO;
	  [self _fillContactInfosForUser: currentUser
		withUIDorEmail: aUID];
	  if (newUser)
	    {
	      if ([[currentUser objectForKey: @"c_uid"] length] > 0)
		[self _retainUser: currentUser];
	      else
		currentUser = nil;
	    }
	}
    }
  else
    currentUser = nil;

  return currentUser;
}

- (NSArray *) _compactAndCompleteContacts: (NSEnumerator *) contacts
{
  NSMutableDictionary *compactContacts, *returnContact;
  NSDictionary *userEntry;
  NSArray *newContacts;
  NSMutableArray *emails;
  NSString *uid, *email, *info;

  compactContacts = [NSMutableDictionary dictionary];
  while ((userEntry = [contacts nextObject]))
    {
      uid = [userEntry objectForKey: @"c_uid"];
      if ([uid length])
	{
	  returnContact = [compactContacts objectForKey: uid];
	  if (!returnContact)
	    {
	      returnContact = [NSMutableDictionary dictionary];
	      [returnContact setObject: uid forKey: @"c_uid"];
	      [compactContacts setObject: returnContact forKey: uid];
	    }
	  if (![[returnContact objectForKey: @"c_name"] length])
	    [returnContact setObject: [userEntry objectForKey: @"c_name"]
			   forKey: @"c_name"];
	  if (![[returnContact objectForKey: @"cn"] length])
	    [returnContact setObject: [userEntry objectForKey: @"c_cn"]
			   forKey: @"cn"];
	  emails = [returnContact objectForKey: @"emails"];
	  if (!emails)
	    {
	      emails = [NSMutableArray array];
	      [returnContact setObject: emails forKey: @"emails"];
	    }
	  email = [userEntry objectForKey: @"mail"];
	  if (email && ![emails containsObject: email])
	    [emails addObject: email];
	  email = [userEntry objectForKey: @"mozillasecondemail"];
	  if (email && ![emails containsObject: email])
	    [emails addObject: email];
	  email = [userEntry objectForKey: @"xmozillasecondemail"];
	  if (email && ![emails containsObject: email])
	    [emails addObject: email];
          info = [userEntry objectForKey: @"c_info"];
          if ([info length] > 0
              && ![[returnContact objectForKey: @"c_info"] length])
            [returnContact setObject: info forKey: @"c_info"];
	  [self _fillContactMailRecords: returnContact];
	}
    }

  newContacts = [compactContacts allValues];

  return newContacts;
}

- (NSArray *) _fetchEntriesInSources: (NSArray *) sourcesList
			    matching: (NSString *) filter
{
  NSMutableArray *contacts;
  NSEnumerator *sources;
  NSString *sourceID;
  id currentSource;

  contacts = [NSMutableArray array];
  sources = [sourcesList objectEnumerator];
  while ((sourceID = [sources nextObject]))
    {
      currentSource = [_sources objectForKey: sourceID];
      [contacts addObjectsFromArray:
		  [currentSource fetchContactsMatching: filter]];
    }

  return [self _compactAndCompleteContacts: [contacts objectEnumerator]];
}

- (NSArray *) fetchContactsMatching: (NSString *) filter
                           inDomain: (NSString *) domain
{
  return [self
           _fetchEntriesInSources: [self addressBookSourceIDsInDomain: domain]
                         matching: filter];
}

- (NSArray *) fetchUsersMatching: (NSString *) filter
                        inDomain: (NSString *) domain
{
  return [self _fetchEntriesInSources:
                 [self authenticationSourceIDsInDomain: domain]
                             matching: filter];
}

- (NSString *) getLoginForDN: (NSString *) theDN
{
  NSEnumerator *sources;
  NSString *login;
  NSObject <SOGoDNSource> *currentSource;

  login = nil;

  sources = [[_sources allValues] objectEnumerator];
  while (!login && (currentSource = [sources nextObject]))
    if ([currentSource conformsToProtocol: @protocol (SOGoDNSource)]
        && [theDN hasSuffix: [currentSource baseDN]])
      login = [currentSource lookupLoginByDN: theDN];

  return login;
}

@end
