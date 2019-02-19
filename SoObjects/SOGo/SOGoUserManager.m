/* SOGoUserManager.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2015 Inverse inc.
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
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import "NSArray+Utilities.h"
#import "NSString+Utilities.h"
#import "NSString+Crypto.h"
#import "NSObject+Utilities.h"
#import "SOGoSource.h"
#import "SOGoSystemDefaults.h"
#import "SOGoUserManager.h"
#import "SOGoCache.h"
#import "SOGoSource.h"

static Class NSNullK;

@implementation SOGoUserManagerRegistry

+ (void) initialize
{
  NSNullK = [NSNull class];
}

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
      if ([type caseInsensitiveCompare: @"ldap"] == NSOrderedSame)
        sourceClass = @"LDAPSource";
      else if ([type caseInsensitiveCompare: @"sql"] == NSOrderedSame)
        sourceClass = @"SQLSource";
      else if (NSClassFromString(type))
        sourceClass = type;
      else
        {
          [NSException raise: @"SOGoUserManagerRegistryException"
                      format: @"No class known for type '%@'", type];
          sourceClass = nil;
        }
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

- (BOOL) _registerSource: (NSDictionary *) udSource
                inDomain: (NSString *) domain
{
  NSString *sourceID, *value, *type;
  NSMutableDictionary *metadata;
  NSObject <SOGoSource> *sogoSource;
  BOOL isAddressBook;
  Class c;

  sourceID = [udSource objectForKey: @"id"];
  if (!sourceID || [sourceID length] == 0)
    {
      [self errorWithFormat: @"attempted to register a contact/user source "
                             @"without id (skipped)"];
      return NO;
    }
  if ([_sourcesMetadata objectForKey: sourceID])
    {
      [self errorWithFormat: @"attempted to register a contact/user source "
                             @"with duplicated id (%@)", sourceID];
      return NO;
    }

  type = [udSource objectForKey: @"type"];
  c = NSClassFromString([_registry sourceClassForType: type]);
  sogoSource = [c sourceFromUDSource: udSource inDomain: domain];
  [_sources setObject: sogoSource forKey: sourceID];

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
  else if (isAddressBook)
    [self errorWithFormat: @"addressbook source '%@' has no displayname", sourceID];

  value = [udSource objectForKey: @"MailFieldNames"];
  if (value)
    [metadata setObject: value forKey: @"MailFieldNames"];
  value = [udSource objectForKey: @"SearchFieldNames"];
  if (value)
    [metadata setObject: value forKey: @"SearchFieldNames"];

  [_sourcesMetadata setObject: metadata forKey: sourceID];

  return YES;
}

- (int) _registerSourcesInDomain: (NSString *) domain
{
  NSArray *userSources;
  unsigned int count, max, total;
  SOGoDomainDefaults *dd;

  dd = [SOGoDomainDefaults defaultsForDomain: domain];
  userSources = [dd userSources];
  max = [userSources count];
  total = 0;
  for (count = 0; count < max; count++)
    if ([self _registerSource: [userSources objectAtIndex: count]
                     inDomain: domain])
      total++;

  return total;
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
      if (![domain length] || ![sourceDomain length] || [domain isEqualToString: sourceDomain])
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

- (BOOL) isDomainDefined: (NSString *) domain
{
  NSEnumerator *allIDs;
  NSArray *ids;
  NSString *currentID, *sourceDomain;
  SOGoSystemDefaults *sd;

  if (!domain) return NO;

  ids = [_sources allKeys];
  if ([ids containsObject: domain])
    // FIXME check SOGoMailDomain?
    // Now source id is being considered as the domain
    return YES;

  sd = [SOGoSystemDefaults sharedSystemDefaults];
  if ([sd enableDomainBasedUID])
    {
      allIDs = [ids objectEnumerator];
      while ((currentID = [allIDs nextObject]))
        {
          sourceDomain = [[_sources objectForKey: currentID] domain];
          if (!sourceDomain) // source that can identify any domain
            return YES;
        }
    }

  return NO;
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

  contactInfos = [self contactInfosForUserWithUIDorEmail: uid];

  return [contactInfos objectForKey: @"c_email"];
}

- (NSString *) getFullEmailForUID: (NSString *) uid
{
  NSDictionary *contactInfos;
  NSString *cn, *email, *fullEmail;

  fullEmail = nil;
  contactInfos = [self contactInfosForUserWithUIDorEmail: uid];
  if (contactInfos)
    {
      email = [contactInfos objectForKey: @"c_email"];
      cn = [contactInfos objectForKey: @"cn"];
      if ([cn length] > 0)
        {
          if ([email length] > 0)
            fullEmail = [NSString stringWithFormat: @"%@ <%@>", cn, email];
          else
            fullEmail = cn;
        }
      else
        fullEmail = email;
    }

  return fullEmail;
}

- (NSString *) getExternalLoginForUID: (NSString *) uid
                             inDomain: (NSString *) domain
{
  NSDictionary *contactInfos;
  NSString *login;
  SOGoDomainDefaults *dd;
  SOGoSystemDefaults *sd;

  contactInfos = [self contactInfosForUserWithUIDorEmail: uid
                                                inDomain: domain];
  login = [contactInfos objectForKey: @"c_imaplogin"];
  if (login == nil)
    {
      dd = [SOGoDomainDefaults defaultsForDomain: domain];
      if ([dd forceExternalLoginWithEmail])
        {
          sd = [SOGoSystemDefaults sharedSystemDefaults];
          if ([sd enableDomainBasedUID] &&
              [uid rangeOfString: @"@"].location == NSNotFound)
            {
              // On multidomain environment we must use uid@domain
              // for getEmailForUID method
              login = [NSString stringWithFormat: @"%@@%@", uid, domain];
            }
          else
            login = uid;

          login = [self getEmailForUID: login];
        }
      else
        login = uid;
    }

  return login;
}

- (NSString *) getUIDForEmail: (NSString *) email
{
  NSDictionary *info;
  SOGoSystemDefaults *sd;
  NSString *uid, *domain, *suffix;

  info = [self contactInfosForUserWithUIDorEmail: email];
  uid = [info objectForKey: @"c_uid"];

  sd = [SOGoSystemDefaults sharedSystemDefaults];
  if ([sd enableDomainBasedUID]
      && ![[info objectForKey: @"DomainLessLogin"] boolValue])
    {
      domain = [info objectForKey: @"c_domain"];
      suffix = [NSString stringWithFormat: @"@%@", domain];

      // Don't add @domain suffix if it's already there
      if (![uid hasSuffix: suffix])
        uid = [NSString stringWithFormat: @"%@%@", uid, suffix];
    }

  return uid;
}

- (BOOL) _sourceChangePasswordForLogin: (NSString *) login
                              inDomain: (NSString *) domain
                           oldPassword: (NSString *) oldPassword
                           newPassword: (NSString *) newPassword
                           perr: (SOGoPasswordPolicyError *) perr
{
  NSObject <SOGoSource> *sogoSource;
  NSEnumerator *authIDs;
  NSString *currentID;
  BOOL didChange;

  didChange = NO;

  authIDs = [[self authenticationSourceIDsInDomain: domain] objectEnumerator];
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
                    domain: (NSString **) domain
                      perr: (SOGoPasswordPolicyError *) perr
                    expire: (int *) expire
                     grace: (int *) grace
{
  NSObject <SOGoSource> *sogoSource;
  NSEnumerator *authIDs;
  NSString *currentID;
  BOOL checkOK;

  checkOK = NO;

  authIDs = [[self authenticationSourceIDsInDomain: *domain] objectEnumerator];
  while (!checkOK && (currentID = [authIDs nextObject]))
    {
      sogoSource = [_sources objectForKey: currentID];

      checkOK = [sogoSource checkLogin: login
                              password: password
                                  perr: perr
                                expire: expire
                                 grace: grace];
    }

  if (checkOK && *domain == nil)
    {
      SOGoSystemDefaults *sd = [SOGoSystemDefaults sharedSystemDefaults];
      BOOL multidomainSource = [sd enableDomainBasedUID] &&
                               [sogoSource domain] == nil;
      if (multidomainSource)
        {
          NSArray *parts = [login componentsSeparatedByString: @"@"];
          if ([parts count] != 2)
            {
              [self errorWithFormat: @"Authenticated with multidomain source "
                                     @"but login is not an email (%@).", login];
              return NO;
            }
          *domain = [parts objectAtIndex: 1];
        }
      else
        *domain = [sogoSource domain];
    }

  return checkOK;
}

//
//
//
- (BOOL) checkLogin: (NSString *) _login
           password: (NSString *) _pwd
             domain: (NSString **) _domain
               perr: (SOGoPasswordPolicyError *) _perr
             expire: (int *) _expire
              grace: (int *) _grace
{
  return [self checkLogin: _login
                   password: _pwd
                   domain: _domain
                   perr: _perr
                   expire: _expire
                   grace: _grace
                   useCache: YES];
}

//
//
//
- (BOOL) checkLogin: (NSString *) _login
           password: (NSString *) _pwd
             domain: (NSString **) _domain
               perr: (SOGoPasswordPolicyError *) _perr
             expire: (int *) _expire
              grace: (int *) _grace
           useCache: (BOOL) useCache
{
  NSString *dictPassword, *username, *jsonUser;
  NSMutableDictionary *currentUser;
  NSDictionary *failedCount;
  SOGoSystemDefaults *sd;
  BOOL checkOK;

  if (!_login)
    return NO;

  sd = [SOGoSystemDefaults sharedSystemDefaults];

  username = _login;

  if (*_domain)
    {
      if ([_login rangeOfString: @"@"].location == NSNotFound)
        username = [NSString stringWithFormat: @"%@@%@", _login, *_domain];
    }
  else
    {
      NSRange r;

      // We try to extract the domain in use in order to avoid pounding all the authentication
      // sources if SOGoLoginDomains isn't specified. This is also true if the user is
      // using DAV or EAS.
      r = [username rangeOfString: @"@"];

      if (r.location != NSNotFound)
        {
          *_domain = [username substringFromIndex: r.location+1];

          if (![[[SOGoSystemDefaults sharedSystemDefaults] domainIds] containsObject: *_domain])
            *_domain = nil;
        }
    }

  // We check the fail count per user in memcache (per server). If the
  // fail count reaches X in Y minutes, we deny immediately the
  // authentications for Z minutes
  failedCount = [[SOGoCache sharedCache] failedCountForLogin: username];
  if (failedCount)
    {
      unsigned int current_time, last_request_time, start_time, delta_start, delta_last_request, block_time;

      current_time = [[NSCalendarDate date] timeIntervalSince1970];
      start_time = [[failedCount objectForKey: @"InitialDate"] unsignedIntValue];
      last_request_time = [[failedCount objectForKey: @"LastRequestDate"] unsignedIntValue];
      delta_start = current_time - start_time;
      delta_last_request = current_time - last_request_time;

      block_time = [sd failedLoginBlockInterval];

      if ([[failedCount objectForKey: @"FailedCount"] intValue] >= [sd maximumFailedLoginCount] &&
          delta_last_request < [sd maximumFailedLoginInterval] &&
          delta_start <= block_time )
        {
          *_perr = PolicyAccountLocked;
          return NO;
        }

      if (delta_start > block_time)
        {
          [[SOGoCache sharedCache] setFailedCount: 0
                                         forLogin: username];
        }
    }

  // We check for cached passwords. If the entry is cached, we
  // check this immediately. If not, we'll go directly at the
  // authentication source and try to validate there, then cache it.
  jsonUser = [[SOGoCache sharedCache] userAttributesForLogin: username];
  currentUser = [jsonUser objectFromJSONString];

  if ([currentUser isKindOfClass: NSNullK])
    currentUser = nil;

  //
  // If we are using multidomain and the UIDFieldName is not part of the email address
  // we must bind without the domain part since internally, SOGo will use
  // UIDFieldName @ domain as its unique identifier if the UIDFieldName is used to
  // authenticate. This can happen for example of one has in LDAP:
  //
  // dn: uid=foo,dc=example,dc=com
  // uid: foo
  // mail: broccoli@example.com
  //
  // and authenticates with "foo", using bindFields = (uid, mail) and SOGoEnableDomainBasedUID = YES;
  // Otherwise, -_sourceCheckLogin:... would have failed because SOGo would try to bind using: foo@example.com
  //
  if (currentUser && [[currentUser objectForKey: @"DomainLessLogin"] boolValue])
    {
      NSRange r;

      r = [_login rangeOfString: [NSString stringWithFormat: @"@%@", *_domain]];
      _login = [_login substringToIndex: r.location];
    }

  dictPassword = (currentUser ? [currentUser objectForKey: @"password"] : nil);
  if (useCache && currentUser && dictPassword)
    {
      checkOK = ([dictPassword isEqualToString: [_pwd asSHA1String]]);
      //NSLog(@"Password cache hit for user %@", _login);
    }
  else if ([self _sourceCheckLogin: _login
                       andPassword: _pwd
                            domain: _domain
                              perr: _perr
                            expire: _expire
                             grace: _grace])
    {
      checkOK = YES;
      if (!currentUser)
        {
          currentUser = [NSMutableDictionary dictionary];
        }

      // Before caching user attributes, we must check if SOGoEnableDomainBasedUID is enabled
      // but we don't have a domain. That would happen for example if the user authenticates
      // without the domain part. We must also cache that information, since SOGo will try
      // afterward to bind with UIDFieldName@domain, and it could potentially not exist
      // in the authentication source. See the rationale in _sourceCheckLogin: ...
      if ([sd enableDomainBasedUID] &&
          [username rangeOfString: @"@"].location == NSNotFound)
        {
          username = [NSString stringWithFormat: @"%@@%@", username, *_domain];
          [currentUser setObject: [NSNumber numberWithBool: YES]  forKey: @"DomainLessLogin"];
        }

      // It's important to cache the password here as we might have cached the
      // user's entry in -contactInfosForUserWithUIDorEmail: and if we don't
      // set the password and recache the entry, the password would never be
      // cached for the user unless its entry expires from memcached's
      // internal cache.
      [currentUser setObject: [_pwd asSHA1String] forKey: @"password"];
      [[SOGoCache sharedCache]
        setUserAttributes: [currentUser jsonRepresentation]
                 forLogin: username];
    }
  else
    {
      // If failed login "rate-limiting" is enabled, we adjust the stats
      if ([sd maximumFailedLoginCount])
        {
          [[SOGoCache sharedCache] setFailedCount: ([[failedCount objectForKey: @"FailedCount"] intValue] + 1)
                                         forLogin: username];
        }

      checkOK = NO;
    }

  // We MUST, for all LDAP sources, update the bindDN and bindPassword
  // to the user's value if bindAsCurrentUser is set to true in the
  // LDAP source configuration
  if (checkOK)
    {
      NSObject <SOGoDNSource> *currentSource;
      NSEnumerator *sources;

      sources = [[_sources allValues] objectEnumerator];
      while ((currentSource = [sources nextObject]))
        if ([currentSource conformsToProtocol: @protocol(SOGoDNSource)] &&
            [currentSource bindAsCurrentUser] &&
            [currentSource lookupDNByLogin: _login])
          {
            [currentSource setBindDN: [currentSource lookupDNByLogin: _login]];
            [currentSource setBindPassword: _pwd];
          }
    }

  return checkOK;
}

//
//
//
- (BOOL) changePasswordForLogin: (NSString *) login
                       inDomain: (NSString *) domain
                    oldPassword: (NSString *) oldPassword
                    newPassword: (NSString *) newPassword
                           perr: (SOGoPasswordPolicyError *) perr
{
  NSString *jsonUser, *userLogin;
  NSMutableDictionary *currentUser;
  BOOL didChange;
  SOGoSystemDefaults *sd;

  jsonUser = [[SOGoCache sharedCache] userAttributesForLogin: login];
  currentUser = [jsonUser objectFromJSONString];

  if ([currentUser isKindOfClass: NSNullK])
    currentUser = nil;

  if ([self _sourceChangePasswordForLogin: login
                                 inDomain: domain
                              oldPassword: oldPassword
                              newPassword: newPassword
                                     perr: perr])
    {
      didChange = YES;

      if (!currentUser)
        currentUser = [NSMutableDictionary dictionary];

      // It's important to cache the password here as we might have cached the
      // user's entry in -contactInfosForUserWithUIDorEmail: and if we don't
      // set the password and recache the entry, the password would never be
      // cached for the user unless its entry expires from memcached's
      // internal cache.
      [currentUser setObject: [newPassword asSHA1String] forKey: @"password"];
      sd = [SOGoSystemDefaults sharedSystemDefaults];
      if ([sd enableDomainBasedUID] &&
          [login rangeOfString: @"@"].location == NSNotFound)
        userLogin = [NSString stringWithFormat: @"%@@%@", login, domain];
      else
        userLogin = login;
      [[SOGoCache sharedCache] setUserAttributes: [currentUser jsonRepresentation]
                                        forLogin: userLogin];
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
  dd = [SOGoDomainDefaults defaultsForDomain: domain];
  emails = [contact objectForKey: @"emails"];
  if ([emails count] == 0)
    {
      uid = [contact objectForKey: @"c_uid"];
      if ([uid rangeOfString: @"@"].location == NSNotFound)
        systemEmail = [NSString stringWithFormat: @"%@@%@", uid, [dd mailDomain]];
      else
        systemEmail = uid;
      // We always add the system email, which will always be returned
      // by SOGoUser -systemEmail.
      [emails addObject: systemEmail];
    }
  [contact setObject: [emails objectAtIndex: 0] forKey: @"c_email"];
}

//
//
//
- (void) _fillContactInfosForUser: (NSMutableDictionary *) theCurrentUser
                   withUIDorEmail: (NSString *) theUID
                         inDomain: (NSString *) theDomain
{
  NSString *sourceID, *cn, *c_domain, *c_uid, *c_imaphostname, *c_imaplogin, *c_sievehostname;
  NSObject <SOGoSource> *currentSource;
  NSEnumerator *sogoSources;
  NSDictionary *userEntry;
  NSMutableArray *emails;
  NSNumber *isGroup;
  NSArray *c_emails;
  BOOL access;
  NSEnumerator *enumerator;
  NSString *access_type;
  NSArray *access_types_list = [NSArray arrayWithObjects: @"CalendarAccess",
                                                          @"MailAccess",
                                                          @"ActiveSyncAccess",
                                                          nil];

  emails = [NSMutableArray array];
  cn = nil;
  c_uid = nil;
  c_domain = nil;
  c_imaphostname = nil;
  c_imaplogin = nil;
  c_sievehostname = nil;

  enumerator = [access_types_list objectEnumerator];
  while ((access_type = [enumerator nextObject]) != nil)
    [theCurrentUser setObject: [NSNumber numberWithBool: YES]
                       forKey: access_type];

  // For DomainLessLogin, we MUST strip any trailing domain part before
  // doing lookups in our source (LDAP for example) as the UIDFieldName
  // or the BindFields/MailFieldNames don't necessarily contain the
  // domain in the value pair.
  if ([[theCurrentUser objectForKey: @"DomainLessLogin"] boolValue])
    {
      NSRange r;

      r = [theUID rangeOfString: @"@"];

      // We check if the range is ok here since we could be using DomainLessLogin
      if (r.location != NSNotFound)
        theUID = [theUID substringToIndex: r.location];
    }

  sogoSources = [[self authenticationSourceIDsInDomain: theDomain] objectEnumerator];
  userEntry = nil;
  while (!userEntry && (sourceID = [sogoSources nextObject]))
    {
      currentSource = [_sources objectForKey: sourceID];

      // Use the provided domain during the lookup. If none is defined, use the source's one
      // so if there's a match based on the source's domain, the user ID will be associated
      // to the right source.
      userEntry = [currentSource lookupContactEntryWithUIDorEmail: theUID
                                                         inDomain: (theDomain ? theDomain : [currentSource domain])];
      if (userEntry)
        {
          [theCurrentUser setObject: sourceID forKey: @"SOGoSource"];
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
          if (!c_imaplogin)
            c_imaplogin = [userEntry objectForKey: @"c_imaplogin"];
          if (!c_sievehostname)
            c_sievehostname = [userEntry objectForKey: @"c_sievehostname"];

          enumerator = [access_types_list objectEnumerator];
          while ((access_type = [enumerator nextObject]) != nil)
            {
              access = [[userEntry objectForKey: access_type] boolValue];
              if (!access)
                [theCurrentUser setObject: [NSNumber numberWithBool: NO]
                                   forKey: access_type];
            }

          // We check if it's a group
          isGroup = [userEntry objectForKey: @"isGroup"];
          if (isGroup)
            [theCurrentUser setObject: isGroup forKey: @"isGroup"];

          // We also fill the resource attributes, if any
          if ([userEntry objectForKey: @"isResource"])
            [theCurrentUser setObject: [userEntry objectForKey: @"isResource"]
                               forKey: @"isResource"];
          if ([userEntry objectForKey: @"numberOfSimultaneousBookings"])
            [theCurrentUser setObject: [userEntry objectForKey: @"numberOfSimultaneousBookings"]
                               forKey: @"numberOfSimultaneousBookings"];

          // This is Active Directory specific attribute (needed on OpenChange/* layer)
          if ([userEntry objectForKey: @"samaccountname"])
            [theCurrentUser setObject: [userEntry objectForKey: @"samaccountname"]
                               forKey: @"sAMAccountName"];
        }
    }

  if (!cn)
    cn = @"";
  if (!c_uid)
    c_uid = @"";
  if (!c_domain)
    c_domain = @"";

  if (c_imaphostname)
    [theCurrentUser setObject: c_imaphostname forKey: @"c_imaphostname"];
  if (c_imaplogin)
    [theCurrentUser setObject: c_imaplogin forKey: @"c_imaplogin"];
  if (c_sievehostname)
    [theCurrentUser setObject: c_sievehostname forKey: @"c_sievehostname"];

  [theCurrentUser setObject: emails forKey: @"emails"];
  [theCurrentUser setObject: cn forKey: @"cn"];
  [theCurrentUser setObject: c_uid forKey: @"c_uid"];
  [theCurrentUser setObject: c_domain forKey: @"c_domain"];

  // If our LDAP queries gave us nothing, we add at least one default
  // email address based on the default domain.
  [self _fillContactMailRecords: theCurrentUser];
}

//
// We cache here all identities, including those
// associated with email addresses.
//
- (void) _retainUser: (NSDictionary *) newUser
           withLogin: (NSString *) login
{
  NSEnumerator *emails;
  NSString *key, *user_json;

  user_json = [newUser jsonRepresentation];
  [[SOGoCache sharedCache] setUserAttributes: user_json
                                    forLogin: login];
  if (![newUser isKindOfClass: NSNullK])
    {
      emails = [[newUser objectForKey: @"emails"] objectEnumerator];
      while ((key = [emails nextObject]))
        {
          if (![key isEqualToString: login])
            [[SOGoCache sharedCache] setUserAttributes: user_json
                                              forLogin: key];
        }
    }
}

- (NSMutableDictionary *) _contactInfosForAnonymous
{
  static NSMutableDictionary *user = nil;

  if (!user)
    {
      user = [[NSMutableDictionary alloc] initWithCapacity: 7];
      [user setObject: [NSArray arrayWithObject: @"anonymous"]
               forKey: @"emails"];
      [user setObject: @"Public User" forKey: @"cn"];
      [user setObject: @"anonymous" forKey: @"c_uid"];
      [user setObject: @"" forKey: @"c_domain"];
      [user setObject: [NSNumber numberWithBool: YES]
               forKey: @"CalendarAccess"];
      [user setObject: [NSNumber numberWithBool: NO]
               forKey: @"MailAccess"];
    }

  return user;
}

/**
 *
 * @see [SOGoUser initWithLogin:roles:trust:]
 */
- (NSDictionary *) contactInfosForUserWithUIDorEmail: (NSString *) uid
{
  NSRange r;
  NSString *username, *domain;
  NSDictionary *infos;
  SOGoSystemDefaults *sd;

  domain = nil;
  infos = nil;

  sd = [SOGoSystemDefaults sharedSystemDefaults];
  if ([sd enableDomainBasedUID])
    {
      r = [uid rangeOfString: @"@" options: NSBackwardsSearch];
      if (r.location != NSNotFound)
        {
          // The domain is probably appended to the username;
          // make sure it is a defined domain in the configuration.
          domain = [uid substringFromIndex: (r.location + r.length)];
          if ([self isDomainDefined: domain])
            username = [uid substringToIndex: r.location];
          else
            domain = nil;
        }
      if (domain != nil)
        infos = [self contactInfosForUserWithUIDorEmail: username
                                               inDomain: domain];
    }

  if (infos == nil)
    // If the user was not found using the domain or if no domain was detected,
    // search using the original uid.
    infos = [self contactInfosForUserWithUIDorEmail: uid
                                           inDomain: nil];

  return infos;
}

- (NSDictionary *) contactInfosForUserWithUIDorEmail: (NSString *) uid
                                            inDomain: (NSString *) domain
{
  NSString *aUID, *cacheUid, *jsonUser;
  NSMutableDictionary *currentUser;

  BOOL newUser;

  if ([uid isEqualToString: @"anonymous"])
    currentUser = [self _contactInfosForAnonymous];
  else if ([uid length] > 0)
    {
      // Remove the "@" prefix used to identified groups in the ACL tables.
      aUID = [uid hasPrefix: @"@"] ? [uid substringFromIndex: 1] : uid;
      if (domain && [aUID rangeOfString: @"@"].location == NSNotFound)
        cacheUid = [NSString stringWithFormat: @"%@@%@", aUID, domain];
      else
        cacheUid = aUID;

      jsonUser = [[SOGoCache sharedCache] userAttributesForLogin: cacheUid];
      currentUser = [jsonUser objectFromJSONString];

      if ([currentUser isKindOfClass: NSNullK])
        currentUser = nil;
      else if (!([currentUser objectForKey: @"emails"]
            && [currentUser objectForKey: @"cn"]))
        {
          // We make sure that we either have no occurence of a cache entry or
          // that we have an occurence with only a cached password. In the
          // latter case, we update the entry with the remaining information
          // and recache the value.
          if (!currentUser ||
              ([currentUser count] == 1 && [currentUser objectForKey: @"password"]) ||
              ([currentUser count] == 2 && [currentUser objectForKey: @"password"] &&  [currentUser objectForKey: @"DomainLessLogin"]))
              {
              newUser = YES;

              if (!currentUser)
                currentUser = [NSMutableDictionary dictionary];
            }
          else
            newUser = NO;
          [self _fillContactInfosForUser: currentUser
                          withUIDorEmail: aUID
                                inDomain: domain];
          if (newUser)
            {
              if ([[currentUser objectForKey: @"c_uid"] length] == 0)
                {
                  [self _retainUser: (NSDictionary *) [NSNull null]
                          withLogin: cacheUid];
                  currentUser = nil;
                }
              else
                {
                  SOGoSystemDefaults *sd;

                  sd = [SOGoSystemDefaults sharedSystemDefaults];

                  // SOGoEnableDomainBasedUID is set to YES but we don't have a domain part. This happens in
                  // multi-domain environments authenticating only with the UIDFieldName
                  if ([sd enableDomainBasedUID] && !domain)
                    {
                      NSString *suffix;

                      suffix = [NSString stringWithFormat: @"@%@", [currentUser objectForKey: @"c_domain"]];

                      if (![cacheUid hasSuffix: suffix])
                        {
                          cacheUid = [NSString stringWithFormat: @"%@%@", cacheUid, suffix];
                          [currentUser setObject: [NSNumber numberWithBool: YES]  forKey: @"DomainLessLogin"];
                        }
                    }

                  [self _retainUser: currentUser  withLogin: cacheUid];
                }
            }
        }
    }
  else
    currentUser = nil;

  return currentUser;
}

/**
 * Fetch the contact information identified by the specified UID in the global addressbooks.
 */
- (NSDictionary *) fetchContactWithUID: (NSString *) uid
                              inDomain: (NSString *) domain
{
  NSDictionary *contact;
  NSMutableArray *contacts;
  NSEnumerator *sources;
  NSString *sourceID;
  id currentSource;

  contacts = [NSMutableArray array];
  contact = nil;
  sources = [[self addressBookSourceIDsInDomain: domain] objectEnumerator];
  while ((sourceID = [sources nextObject]))
    {
      currentSource = [_sources objectForKey: sourceID];
      contact = [currentSource lookupContactEntry: uid inDomain: domain];
      if (contact)
        [contacts addObject: contact];
    }

  if ([contacts count])
    contact = [[self _compactAndCompleteContacts: [contacts objectEnumerator]] lastObject];
  else
    contact = nil;

  return contact;
}

- (NSArray *) _compactAndCompleteContacts: (NSEnumerator *) contacts
{
  NSMutableDictionary *compactContacts, *returnContact;
  NSDictionary *userEntry;
  NSArray *newContacts, *allEmails;
  NSMutableArray *emails;
  NSString *uid, *email, *info;
  NSNumber *isGroup;
  id <SOGoSource> source;
  NSUInteger count, max;

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
              source = [userEntry objectForKey: @"source"];
              if (source)
                [returnContact setObject: source forKey: @"source"];
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
          if ([email isKindOfClass: [NSArray class]])
            {
              allEmails = (NSArray *) email;
              max = [allEmails count];
              for (count = 0; count < max; count++)
                {
                  email = [allEmails objectAtIndex: count];
                  [emails addObjectUniquely: email];
                }
            }
          else if (email && ![emails containsObject: email])
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
          isGroup = [userEntry objectForKey: @"isGroup"];
          if (isGroup)
            [returnContact setObject: isGroup forKey: @"isGroup"];
        }
    }

  newContacts = [compactContacts allValues];

  return newContacts;
}

- (NSArray *) _fetchEntriesInSources: (NSArray *) sourcesList
                            matching: (NSString *) filter
                            inDomain: (NSString *) domain
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
                  [currentSource fetchContactsMatching: filter
                                          withCriteria: nil
                                              inDomain: domain]];
    }

  return [self _compactAndCompleteContacts: [contacts objectEnumerator]];
}

- (NSArray *) fetchContactsMatching: (NSString *) filter
                           inDomain: (NSString *) domain
{
  return [self
           _fetchEntriesInSources: [self addressBookSourceIDsInDomain: domain]
                         matching: filter
                         inDomain: domain];
}

- (NSArray *) fetchUsersMatching: (NSString *) filter
                        inDomain: (NSString *) domain
{
  return [self
           _fetchEntriesInSources: [self authenticationSourceIDsInDomain: domain]
                         matching: filter
                         inDomain: domain];
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
