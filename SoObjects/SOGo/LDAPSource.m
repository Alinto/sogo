/* LDAPSource.m - this file is part of SOGo
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

#include <ldap.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSObject+Logs.h>
#import <EOControl/EOControl.h>
#import <NGLdap/NGLdapConnection.h>
#import <NGLdap/NGLdapAttribute.h>
#import <NGLdap/NGLdapEntry.h>
#import <NGLdap/NGLdapModification.h>
#import <NGLdap/NSString+DN.h>

#import "LDAPSourceSchema.h"
#import "NSArray+Utilities.h"
#import "NSString+Utilities.h"
#import "NSString+Crypto.h"
#import "SOGoCache.h"
#import "SOGoDomainDefaults.h"
#import "SOGoSystemDefaults.h"

#import "LDAPSource.h"
#import "../../Main/SOGo.h"

static Class NSStringK;

#define SafeLDAPCriteria(x) [[[x stringByReplacingString: @"\\" withString: @"\\\\"] \
                                 stringByReplacingString: @"'" withString: @"\\'"] \
                                 stringByReplacingString: @"%" withString: @"%%"]

@implementation LDAPSource

+ (void) initialize
{
  NSStringK = [NSString class];
}

//
//
//
+ (id) sourceFromUDSource: (NSDictionary *) udSource
                 inDomain: (NSString *) sourceDomain
{
  id newSource;

  newSource = [[self alloc] initFromUDSource: udSource
                                    inDomain: sourceDomain];
  [newSource autorelease];

  return newSource;
}

//
//
//
- (id) init
{
  if ((self = [super init]))
    {
      sourceID = nil;
      displayName = nil;

      bindDN = nil;
      password = nil;
      sourceBindDN = nil;
      sourceBindPassword = nil;
      hostname = nil;
      port = 389;
      encryption = nil;
      domain = nil;

      baseDN = nil;
      schema = nil;
      IDField = @"cn"; /* the first part of a user DN */
      CNField = @"cn";
      UIDField = @"uid";
      mailFields = [NSArray arrayWithObject: @"mail"];
      [mailFields retain];
      contactMapping = nil;
      searchFields = [NSArray arrayWithObjects: @"sn", @"displayname", @"telephonenumber", nil];
      [searchFields retain];
      groupObjectClasses = [NSArray arrayWithObjects: @"group", @"groupofnames", @"groupofuniquenames", @"posixgroup", nil];
      [groupObjectClasses retain];
      IMAPHostField = nil;
      IMAPLoginField = nil;
      SieveHostField = nil;
      bindFields = nil;
      _scope = @"sub";
      _filter = nil;
      _userPasswordAlgorithm = nil;
      listRequiresDot = YES;

      searchAttributes = nil;
      passwordPolicy = NO;
      updateSambaNTLMPasswords = NO;

      kindField = nil;
      multipleBookingsField = nil;

      MSExchangeHostname = nil;

      modifiers = nil;
    }

  return self;
}

//
//
//
- (void) dealloc
{
  [schema release];
  [bindDN release];
  [password release];
  [sourceBindDN release];
  [sourceBindPassword release];
  [hostname release];
  [encryption release];
  [baseDN release];
  [IDField release];
  [CNField release];
  [UIDField release];
  [contactMapping release];
  [mailFields release];
  [searchFields release];
  [groupObjectClasses release];
  [IMAPHostField release];
  [IMAPLoginField release];
  [SieveHostField release];
  [bindFields release];
  [_filter release];
  [_userPasswordAlgorithm release];
  [sourceID release];
  [modulesConstraints release];
  [_scope release];
  [searchAttributes release];
  [domain release];
  [kindField release];
  [multipleBookingsField release];
  [MSExchangeHostname release];
  [modifiers release];
  [super dealloc];
}

//
//
//
- (id) initFromUDSource: (NSDictionary *) udSource
               inDomain: (NSString *) sourceDomain
{
  SOGoDomainDefaults *dd;
  NSNumber *udQueryLimit, *udQueryTimeout, *dotValue;

  if ((self = [self init]))
    {
      [self setSourceID: [udSource objectForKey: @"id"]];
      [self setDisplayName: [udSource objectForKey: @"displayName"]];

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
   groupObjectClasses: [udSource objectForKey: @"GroupObjectClasses"]
        IMAPHostField: [udSource objectForKey: @"IMAPHostFieldName"]
       IMAPLoginField: [udSource objectForKey: @"IMAPLoginFieldName"]
       SieveHostField: [udSource objectForKey: @"SieveHostFieldName"]
           bindFields: [udSource objectForKey: @"bindFields"]
            kindField: [udSource objectForKey: @"KindFieldName"]
            andMultipleBookingsField: [udSource objectForKey: @"MultipleBookingsFieldName"]];

      dotValue = [udSource objectForKey: @"listRequiresDot"];
      if (dotValue)
        [self setListRequiresDot: [dotValue boolValue]];
      [self setContactMapping: [udSource objectForKey: @"mapping"]
             andObjectClasses: [udSource objectForKey: @"objectClasses"]];

      [self setModifiers: [udSource objectForKey: @"modifiers"]];
      ASSIGN (abOU, [udSource objectForKey: @"abOU"]);

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

      ASSIGN(modulesConstraints,
          [udSource objectForKey: @"ModulesConstraints"]);
      ASSIGN(_filter, [udSource objectForKey: @"filter"]);
      ASSIGN(_userPasswordAlgorithm, [udSource objectForKey: @"userPasswordAlgorithm"]);
      ASSIGN(_scope, ([udSource objectForKey: @"scope"]
                       ? [udSource objectForKey: @"scope"]
                       : (id)@"sub"));

      if (!_userPasswordAlgorithm)
        _userPasswordAlgorithm = @"none";

      if ([udSource objectForKey: @"passwordPolicy"])
        passwordPolicy = [[udSource objectForKey: @"passwordPolicy"] boolValue];

      if ([udSource objectForKey: @"updateSambaNTLMPasswords"])
        updateSambaNTLMPasswords = [[udSource objectForKey: @"updateSambaNTLMPasswords"] boolValue];
      
      ASSIGN(MSExchangeHostname, [udSource objectForKey: @"MSExchangeHostname"]);
    }

  return self;
}

- (void) setBindDN: (NSString *) theDN
{
  //NSLog(@"Setting bind DN to %@", theDN);
  ASSIGN(bindDN, theDN);
}

- (NSString *) bindDN
{
  return bindDN;
}

- (void) setBindPassword: (NSString *) thePassword
{
  ASSIGN (password, thePassword);
}

- (NSString *) bindPassword
{
  return password;
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
  ASSIGN(bindDN, newBindDN);
  ASSIGN(password, newBindPassword);
  ASSIGN(sourceBindDN, newBindDN);
  ASSIGN(sourceBindPassword, newBindPassword);

  ASSIGN(encryption, [newEncryption uppercaseString]);
  if ([encryption isEqualToString: @"SSL"])
    port = 636;
  ASSIGN(hostname, newBindHostname);
  if (newBindPort)
    port = [newBindPort intValue];
  _bindAsCurrentUser = [bindAsCurrentUser boolValue];
}

//
//
//
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
  andMultipleBookingsField: (NSString *) newMultipleBookingsField
{
  ASSIGN(baseDN, [newBaseDN lowercaseString]);
  if (newIDField)
    ASSIGN(IDField, [newIDField lowercaseString]);
  if (newCNField)
    ASSIGN(CNField, [newCNField lowercaseString]);
  if (newUIDField)
    ASSIGN(UIDField, [newUIDField lowercaseString]);
  if (newIMAPHostField)
    ASSIGN(IMAPHostField, [newIMAPHostField lowercaseString]);
  if (newIMAPLoginField)
    ASSIGN(IMAPLoginField, [newIMAPLoginField lowercaseString]);
  if (newSieveHostField)
    ASSIGN(SieveHostField, [newSieveHostField lowercaseString]);
  if (newMailFields)
    ASSIGN(mailFields, newMailFields);
  if (newSearchFields)
    ASSIGN(searchFields, newSearchFields);
  if (newGroupObjectClasses)
    ASSIGN(groupObjectClasses, newGroupObjectClasses);
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
    ASSIGN(kindField, [newKindField lowercaseString]);
  if (newMultipleBookingsField)
    ASSIGN(multipleBookingsField, [newMultipleBookingsField lowercaseString]);
}

- (void) setListRequiresDot: (BOOL) aBool
{
  listRequiresDot = aBool;
}

- (BOOL) listRequiresDot
{
  return listRequiresDot;
}

- (void) setContactMapping: (NSDictionary *) newMapping
          andObjectClasses: (NSArray *) newObjectClasses
{
  ASSIGN (contactMapping, newMapping);
  ASSIGN (contactObjectClasses, newObjectClasses);
}

//
//
//
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

//
//
//
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
          if (!schema)
            {
              schema = [LDAPSourceSchema new];
              [schema readSchemaFromConnection: ldapConnection];
            }
        }
      else
        ldapConnection = nil;
    }
  NS_HANDLER
    {
      [self errorWithFormat: @"Could not bind to the LDAP server %@ (%d) "
                             @"using the bind DN: %@", hostname, port, bindDN];
      [self errorWithFormat: @"%@", localException];
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

//
//
//
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

  NS_DURING
    if ([_login length] > 0 && [_pwd length] > 0)
      {
        bindConnection = [[NGLdapConnection alloc] initWithHostName: hostname
                                                             port: port];
        if (![encryption length] || [self _setupEncryption: bindConnection])
          {
            if (queryTimeout > 0)
              [bindConnection setQueryTimeLimit: queryTimeout];

            userDN = [[SOGoCache sharedCache] distinguishedNameForLogin: _login];

            if (!userDN)
              {
                if (bindFields)
                  {
                    // We MUST always use the source's bindDN/password in
                    // order to lookup the user's DN. This is important since
                    // if we use bindAsCurrentUser, we could stay bound and
                    // lookup the user's DN (for an other user that is trying
                    // to log in) but not be able to do so due to ACLs in LDAP.
                    [self setBindDN: sourceBindDN];
                    [self setBindPassword: sourceBindPassword];
                    userDN = [self _fetchUserDNForLogin: _login];
                  }
                else
                  userDN = [NSString stringWithFormat: @"%@=%@,%@",
                                   IDField, [_login escapedForLDAPDN], baseDN];
              }

            if (userDN)
              {
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

                if (didBind)
                  // We cache the _login <-> userDN entry to speed up things
                  [[SOGoCache sharedCache] setDistinguishedName: userDN
                                                       forLogin: _login];
              }
          }
      }
  NS_HANDLER
    {
      [self logWithFormat: @"%@", localException];
    }
  NS_ENDHANDLER;

  [bindConnection release];
  return didBind;
}

/**
 * Encrypts a string using this source password algorithm.
 * @param plainPassword the unencrypted password.
 * @return a new encrypted string.
 * @see _isPassword:equalTo:
 */
- (NSString *) _encryptPassword: (NSString *) plainPassword
{
  NSString *pass;
  pass = [plainPassword asCryptedPassUsingScheme: _userPasswordAlgorithm];

  if (pass == nil)
    {
      [self errorWithFormat: @"Unsupported user-password algorithm: %@", _userPasswordAlgorithm];
      return nil;
    }

  return [NSString stringWithFormat: @"{%@}%@", _userPasswordAlgorithm, pass];
}

- (BOOL)  _ldapModifyAttribute: (NSString *) theAttribute
                     withValue: (NSString *) theValue
                        userDN: (NSString *) theUserDN
                      password: (NSString *) theUserPassword
                    connection: (NGLdapConnection *) bindConnection
{
  NGLdapModification *mod;
  NGLdapAttribute *attr;
  NSArray *changes;

  BOOL didChange;
  
  attr = [[NGLdapAttribute alloc] initWithAttributeName: theAttribute];
  [attr addStringValue: theValue];
  
  mod = [NGLdapModification replaceModification: attr];
  
  changes = [NSArray arrayWithObject: mod];
  
  if ([bindConnection bindWithMethod: @"simple"
                              binddn: theUserDN
                         credentials: theUserPassword])
    {
      didChange = [bindConnection modifyEntryWithDN: theUserDN
                                            changes: changes];
    }
  else
    didChange = NO;
  
  RELEASE(attr);

  return didChange;
}

//
//
//
- (BOOL) changePasswordForLogin: (NSString *) login
                    oldPassword: (NSString *) oldPassword
                    newPassword: (NSString *) newPassword
                           perr: (SOGoPasswordPolicyError *) perr
  
{
  NGLdapConnection *bindConnection;
  NSString *userDN;
  BOOL didChange;

  didChange = NO;

  NS_DURING
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
                     IDField, [login escapedForLDAPDN], baseDN];
            if (userDN)
              {
                if ([bindConnection isADCompatible])
                  {
                    if ([bindConnection bindWithMethod: @"simple"
                                                binddn: userDN
                                           credentials: oldPassword])
                      {
                        didChange = [bindConnection changeADPasswordAtDn: userDN
                                                             oldPassword: oldPassword
                                                             newPassword: newPassword];
                      }
                  }
                else if (passwordPolicy)
                  {
                    didChange = [bindConnection changePasswordAtDn: userDN
                                                       oldPassword: oldPassword
                                                       newPassword: newPassword
                                                              perr: (void *)perr];
                  }
                else
                  {
                    // We don't use a password policy - we simply use
                    // a modify-op to change the password
                    NSString* encryptedPass;
                    
                    if ([_userPasswordAlgorithm isEqualToString: @"none"])
                      {
                        encryptedPass = newPassword;
                      }
                    else
                      {
                        encryptedPass = [self _encryptPassword: newPassword];
                      }
                    
                    if (encryptedPass != nil)
                      {
                        *perr = PolicyNoError;
                        didChange = [self _ldapModifyAttribute: @"userPassword"
                                                     withValue: encryptedPass
                                                        userDN: userDN
                                                      password: oldPassword
                                                    connection: bindConnection];
                      }
                  }

                // We must check if we must update the Samba NT/LM password hashes
                if (didChange && updateSambaNTLMPasswords)
                  {
                    [self _ldapModifyAttribute: @"sambaNTPassword"
                                     withValue: [newPassword asNTHash]
                                        userDN: userDN
                                      password: newPassword
                                    connection: bindConnection];
                    
                    [self _ldapModifyAttribute: @"sambaLMPassword"
                                     withValue: [newPassword asLMHash]
                                        userDN: userDN
                                      password: newPassword
                                    connection: bindConnection];
                  }
              }
          }
      }
  NS_HANDLER
    {
      [self logWithFormat: @"%@", localException];
    }
  NS_ENDHANDLER ;
  
  [bindConnection release];
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
          fieldFormat = [NSString stringWithFormat: @"(%%@='*%@*')", escapedFilter];
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
  else if (!listRequiresDot)
    {
      qs = [NSMutableString stringWithFormat: @"(%@='*')", CNField];
      if ([_filter length])
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

/* This is required for SQL sources when DomainFieldName is enabled.
 * For LDAP, simply discard the domain and call the original method */
- (NSArray *) allEntryIDsVisibleFromDomain: (NSString *) domain
{
  return [self allEntryIDs];
}

- (NSArray *) allEntryIDs
{
  NSEnumerator *entries;
  NGLdapEntry *currentEntry;
  NGLdapConnection *ldapConnection;
  EOQualifier *qualifier;
  NSMutableString *qs;
  NSString *value;
  NSArray *attributes;
  NSMutableArray *ids;

  ids = [NSMutableArray array];

  ldapConnection = [self _ldapConnection];
  attributes = [NSArray arrayWithObject: IDField];

  qs = [NSMutableString stringWithFormat: @"(%@='*')", CNField];
  if ([_filter length])
    [qs appendFormat: @" AND %@", _filter];
  qualifier = [EOQualifier qualifierWithQualifierFormat: qs];

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
             intoLDIFRecord: (NSMutableDictionary *) ldifRecord
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
  [ldifRecord setObject: emails forKey: @"c_emails"];
  [emails release];

  if (IMAPHostField)
    {
      ldapValue = [[ldapEntry attributeWithName: IMAPHostField] stringValueAtIndex: 0];
      if ([ldapValue length] > 0)
        [ldifRecord setObject: ldapValue forKey: @"c_imaphostname"];
    }

  if (IMAPLoginField)
    {
      ldapValue = [[ldapEntry attributeWithName: IMAPLoginField] stringValueAtIndex: 0];
      if ([ldapValue length] > 0)
        [ldifRecord setObject: ldapValue forKey: @"c_imaplogin"];
    }

  if (SieveHostField)
    {
      ldapValue = [[ldapEntry attributeWithName: SieveHostField] stringValueAtIndex: 0];
      if ([ldapValue length] > 0)
        [ldifRecord setObject: ldapValue forKey: @"c_sievehostname"];
    }
}

- (void) _fillConstraints: (NGLdapEntry *) ldapEntry
                forModule: (NSString *) module
           intoLDIFRecord: (NSMutableDictionary *) ldifRecord
{
  NSDictionary *constraints;
  NSEnumerator *matches, *ldapValues;
  NSString *currentMatch, *currentValue, *ldapValue;
  BOOL result;

  result = YES;

  constraints = [modulesConstraints objectForKey: module];
  if (constraints)
    {
      matches = [[constraints allKeys] objectEnumerator];
      while (result == YES && (currentMatch = [matches nextObject]))
        {
          ldapValues = [[[ldapEntry attributeWithName: currentMatch] allStringValues] objectEnumerator];
          currentValue = [constraints objectForKey: currentMatch];
          result = NO;

          while (result == NO && (ldapValue = [ldapValues nextObject]))
            if ([ldapValue caseInsensitiveMatches: currentValue])
              result = YES;
        }
    }

  [ldifRecord setObject: [NSNumber numberWithBool: result]
                 forKey: [NSString stringWithFormat: @"%@Access", module]];
}

/* conversion LDAP -> SOGo inetOrgPerson entry */
- (void) _applyContactMappingToResult: (NSMutableDictionary *) ldifRecord
{
  NSArray *sourceFields;
  NSArray *keys;
  NSString *key, *field, *value;
  NSUInteger count, max, fieldCount, fieldMax;
  BOOL filled;

  keys = [contactMapping allKeys];
  max = [keys count];
  for (count = 0; count < max; count++)
    {
      key = [keys objectAtIndex: count];
      sourceFields = [contactMapping objectForKey: key];
      if ([sourceFields isKindOfClass: NSStringK])
        sourceFields = [NSArray arrayWithObject: sourceFields];
      fieldMax = [sourceFields count];
      filled = NO;
      for (fieldCount = 0;
           !filled && fieldCount < fieldMax;
           fieldCount++)
        {
          field = [[sourceFields objectAtIndex: fieldCount] lowercaseString];
          value = [ldifRecord objectForKey: field];
          if (value)
            {
              [ldifRecord setObject: value forKey: [key lowercaseString]];
              filled = YES;
            }
        }
    }
}

/* conversion SOGo inetOrgPerson entry -> LDAP */
- (void) _applyContactMappingToOutput: (NSMutableDictionary *) ldifRecord
{
  NSArray *sourceFields;
  NSArray *keys;
  NSString *key, *lowerKey, *field, *value;
  NSUInteger count, max, fieldCount, fieldMax;

  if (contactObjectClasses)
    [ldifRecord setObject: contactObjectClasses
                   forKey: @"objectclass"];

  keys = [contactMapping allKeys];
  max = [keys count];
  for (count = 0; count < max; count++)
    {
      key = [keys objectAtIndex: count];
      lowerKey = [key lowercaseString];
      value = [ldifRecord objectForKey: lowerKey];
      if ([value length] > 0)
        {
          sourceFields = [contactMapping objectForKey: key];
          if ([sourceFields isKindOfClass: NSStringK])
            sourceFields = [NSArray arrayWithObject: sourceFields];

          fieldMax = [sourceFields count];
          for (fieldCount = 0; fieldCount < fieldMax; fieldCount++)
            {
              field = [[sourceFields objectAtIndex: fieldCount]
                        lowercaseString];
              [ldifRecord setObject: value forKey: field];
            }
        }
    }
}

- (NSDictionary *) _convertLDAPEntryToContact: (NGLdapEntry *) ldapEntry
{
  NSMutableDictionary *ldifRecord;
  NSString *value;
  static NSArray *resourceKinds = nil;
  NSMutableArray *classes;
  NSEnumerator *gclasses;
  NSString *gclass;
  id o;

  if (!resourceKinds)
    resourceKinds = [[NSArray alloc] initWithObjects: @"location", @"thing",
                                     @"group", nil];

  ldifRecord = [ldapEntry asDictionary];
  [ldifRecord setObject: self forKey: @"source"];
  [ldifRecord setObject: [ldapEntry dn] forKey: @"dn"];
  
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
      // We check if our entry is a resource. We also support
      // determining resources based on the KindFieldName attribute
      // value - see below.
      if ([classes containsObject: @"calendarresource"])
        {
          [ldifRecord setObject: [NSNumber numberWithInt: 1]
                         forKey: @"isResource"];
        }
      else
        {
        // We check if our entry is a group. If so, we set the
        // 'isGroup' custom attribute.
        gclasses = [groupObjectClasses objectEnumerator];
        while (gclass = [gclasses nextObject])
         if ([classes containsObject: [gclass lowercaseString]])
           {
             [ldifRecord setObject: [NSNumber numberWithInt: 1]
                            forKey: @"isGroup"];
             break;
           }
        }
    }

  // We check if that entry corresponds to a resource. For this,
  // kindField must be defined and it must hold one of those values
  //
  // location
  // thing
  // group
  //
  if ([kindField length] > 0)
    {
      value = [ldifRecord objectForKey: [kindField lowercaseString]];
      if ([value isKindOfClass: NSStringK]
          && [resourceKinds containsObject: value])
        [ldifRecord setObject: [NSNumber numberWithInt: 1]
                       forKey: @"isResource"];
    }

  // We check for the number of simultanous bookings that is allowed.
  // A value of 0 means that there's no limit.
  if ([multipleBookingsField length] > 0)
    {
      value = [ldifRecord objectForKey: [multipleBookingsField lowercaseString]];
      [ldifRecord setObject: [NSNumber numberWithInt: [value intValue]]
                     forKey: @"numberOfSimultaneousBookings"];
    }

  value = [[ldapEntry attributeWithName: IDField] stringValueAtIndex: 0];
  if (!value)
    value = @"";
  [ldifRecord setObject: value forKey: @"c_name"];
  value = [[ldapEntry attributeWithName: UIDField] stringValueAtIndex: 0];
  if (!value)
    value = @"";
//  else
//    {
//      Eventually, we could check at this point if the entry is a group
//      and prefix the UID with a "@"
//    }
  [ldifRecord setObject: value forKey: @"c_uid"];
  value = [[ldapEntry attributeWithName: CNField] stringValueAtIndex: 0];
  if (!value)
    value = @"";
  [ldifRecord setObject: value forKey: @"c_cn"];
  /* if "displayName" is not set, we use CNField because it must exist */
  if (![ldifRecord objectForKey: @"displayname"])
    [ldifRecord setObject: value forKey: @"displayname"];

  if (contactInfoAttribute)
    {
      value = [[ldapEntry attributeWithName: contactInfoAttribute]
                stringValueAtIndex: 0];
      if (!value)
        value = @"";
    }
  else
    value = @"";
  [ldifRecord setObject: value forKey: @"c_info"];

  if (domain)
    value = domain;
  else
    value = @"";
  [ldifRecord setObject: value forKey: @"c_domain"];

  [self _fillEmailsOfEntry: ldapEntry intoLDIFRecord: ldifRecord];
  [self _fillConstraints: ldapEntry forModule: @"Calendar"
          intoLDIFRecord: (NSMutableDictionary *) ldifRecord];
  [self _fillConstraints: ldapEntry forModule: @"Mail"
          intoLDIFRecord: (NSMutableDictionary *) ldifRecord];

  if (contactMapping)
    [self _applyContactMappingToResult: ldifRecord];

  return ldifRecord;
}

- (NSArray *) fetchContactsMatching: (NSString *) match
                           inDomain: (NSString *) domain
{
  NGLdapConnection *ldapConnection;
  NGLdapEntry *currentEntry;
  NSEnumerator *entries;
  NSMutableArray *contacts;
  EOQualifier *qualifier;
  NSArray *attributes;

  contacts = [NSMutableArray array];

  if ([match length] > 0 || !listRequiresDot)
    {
      ldapConnection = [self _ldapConnection];
      qualifier = [self _qualifierForFilter: match];
      // attributes = [self _searchAttributes];
      attributes = [NSArray arrayWithObject: @"*"];

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

- (NGLdapEntry *) _lookupLDAPEntry: (EOQualifier *) qualifier
{
  NGLdapConnection *ldapConnection;
  NSArray *attributes;
  NSEnumerator *entries;

  // attributes = [self _searchAttributes];
  ldapConnection = [self _ldapConnection];
  attributes = [NSArray arrayWithObject: @"*"];

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

  return [entries nextObject];
}

- (NSDictionary *) lookupContactEntry: (NSString *) theID
{
  NGLdapEntry *ldapEntry;
  EOQualifier *qualifier;
  NSString *s;
  NSDictionary *ldifRecord;

  ldifRecord = nil;

  if ([theID length] > 0)
    {
      s = [NSString stringWithFormat: @"(%@='%@')",
                    IDField, SafeLDAPCriteria(theID)];
      qualifier = [EOQualifier qualifierWithQualifierFormat: s];
      ldapEntry = [self _lookupLDAPEntry: qualifier];
      if (ldapEntry)
        ldifRecord = [self _convertLDAPEntryToContact: ldapEntry];
    }

  return ldifRecord;
}

- (NSDictionary *) lookupContactEntryWithUIDorEmail: (NSString *) uid
                                           inDomain: (NSString *) domain
{
  NGLdapEntry *ldapEntry;
  EOQualifier *qualifier;
  NSDictionary *ldifRecord;

  ldifRecord = nil;

  if ([uid length] > 0)
    {
      qualifier = [self _qualifierForUIDFilter: uid];
      ldapEntry = [self _lookupLDAPEntry: qualifier];
      if (ldapEntry)
        ldifRecord = [self _convertLDAPEntryToContact: ldapEntry];
    }

  return ldifRecord;
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
  return [[SOGoCache sharedCache] distinguishedNameForLogin: theLogin];
}

- (NGLdapEntry *) _lookupGroupEntryByAttributes: (NSArray *) theAttributes
                                       andValue: (NSString *) theValue
{
  EOQualifier *qualifier;
  NGLdapEntry *ldapEntry;
  NSString *s;
    
  if ([theValue length] > 0 && [theAttributes count] > 0)
    {
      if ([theAttributes count] == 1)
	{
	    s = [NSString stringWithFormat: @"(%@='%@')",
			  [theAttributes lastObject], SafeLDAPCriteria(theValue)];
	    
	}
      else
	{
	  NSString *fieldFormat;
	  
	  fieldFormat = [NSString stringWithFormat: @"(%%@='%@')", SafeLDAPCriteria(theValue)];
	  s = [[theAttributes stringsWithFormat: fieldFormat]
			 componentsJoinedByString: @" OR "];
	}
      
      qualifier = [EOQualifier qualifierWithQualifierFormat: s];
      ldapEntry = [self _lookupLDAPEntry: qualifier];
    }
  else
    ldapEntry = nil;

  return ldapEntry;
}

- (NGLdapEntry *) lookupGroupEntryByUID: (NSString *) theUID
{
  return [self _lookupGroupEntryByAttributes: [NSArray arrayWithObject: UIDField]
				    andValue: theUID];
}

- (NGLdapEntry *) lookupGroupEntryByEmail: (NSString *) theEmail
{
  return [self _lookupGroupEntryByAttributes: mailFields
				    andValue: theEmail];
}

- (void) setSourceID: (NSString *) newSourceID
{
  ASSIGN (sourceID, newSourceID);
}

- (NSString *) sourceID
{
  return sourceID;
}

- (void) setDisplayName: (NSString *) newDisplayName
{
  ASSIGN (displayName, newDisplayName);
}

- (NSString *) displayName
{
  return displayName;
}

- (NSString *) baseDN
{
  return baseDN;
}

- (NSString *) MSExchangeHostname
{
  return MSExchangeHostname;
}

- (void) setModifiers: (NSArray *) newModifiers
{
  ASSIGN (modifiers, newModifiers);
}

- (NSArray *) modifiers
{
  return modifiers;
}

- (NSArray *) groupObjectClasses
{
  return groupObjectClasses;
}

static NSArray *
_convertRecordToLDAPAttributes (LDAPSourceSchema *schema, NSDictionary *ldifRecord)
{
  /* convert resulting record to NGLdapEntry:
     - strip non-existing object classes
     - ignore fields with empty values
     - ignore extra fields
     - use correct case for LDAP attribute matching classes */
  NSMutableArray *validClasses, *validFields, *attributes;
  NGLdapAttribute *attribute;
  NSArray *classes, *fields, *values;
  NSString *objectClass, *field, *lowerField, *value;
  NSUInteger count, max, valueCount, valueMax;

  classes = [ldifRecord objectForKey: @"objectclass"];
  if ([classes isKindOfClass: NSStringK])
    classes = [NSArray arrayWithObject: classes];
  max = [classes count];
  validClasses = [NSMutableArray array];
  validFields = [NSMutableArray array];
  for (count = 0; count < max; count++)
    {
      objectClass = [classes objectAtIndex: count];
      fields = [schema fieldsForClass: objectClass];
      if ([fields count] > 0)
        {
          [validClasses addObject: objectClass];
          [validFields addObjectsFromArray: fields];
        }
    }
  [validFields removeDoubles];

  attributes = [NSMutableArray new];
  max = [validFields count];
  for (count = 0; count < max; count++)
    {
      attribute = nil;
      field = [validFields objectAtIndex: count];
      lowerField = [field lowercaseString];
      if (![lowerField isEqualToString: @"dn"])
        {
          if ([lowerField isEqualToString: @"objectclass"])
            values = validClasses;
          else
            {
              values = [ldifRecord objectForKey: lowerField];
              if ([values isKindOfClass: NSStringK])
                values = [NSArray arrayWithObject: values];
            }
          valueMax = [values count];
          for (valueCount = 0; valueCount < valueMax; valueCount++)
            {
              value = [values objectAtIndex: valueCount];
              if ([value length] > 0)
                {
                  if (!attribute)
                    {
                      attribute = [[NGLdapAttribute alloc]
                                    initWithAttributeName: field];
                      [attributes addObject: attribute];
                      [attribute release];
                    }
                  [attribute addStringValue: value];
                }
            }
        }
    }

  return attributes;
}

- (NSException *) addContactEntry: (NSDictionary *) roLdifRecord
                           withID: (NSString *) aId
{
  NSException *result;
  NGLdapEntry *newEntry;
  NSMutableDictionary *ldifRecord;
  NSArray *attributes;
  NSString *dn, *cnValue;
  NGLdapConnection *ldapConnection;

  if ([aId length] > 0)
    {
      ldapConnection = [self _ldapConnection];
      ldifRecord = [roLdifRecord mutableCopy];
      [ldifRecord autorelease];
      [ldifRecord setObject: aId forKey: UIDField];

      /* if CN is not set, we use aId because it must exist */
      if (![ldifRecord objectForKey: CNField])
        {
          cnValue = [ldifRecord objectForKey: @"displayname"];
          if ([cnValue length] == 0)
            cnValue = aId;
          [ldifRecord setObject: aId forKey: @"cn"];
        }

      [self _applyContactMappingToOutput: ldifRecord];

      /* since the id might have changed due to the mapping above, we
         reload the record ID */
      aId = [ldifRecord objectForKey: UIDField];
      dn = [NSString stringWithFormat: @"%@=%@,%@", IDField,
                     [aId escapedForLDAPDN], baseDN];
      attributes = _convertRecordToLDAPAttributes (schema, ldifRecord);

      newEntry = [[NGLdapEntry alloc] initWithDN: dn
                                      attributes: attributes];
      [newEntry autorelease];
      [attributes release];
      NS_DURING
        {
          [ldapConnection addEntry: newEntry];
          result = nil;
        }
      NS_HANDLER
        {
          result = localException;
          [result retain];
        }
      NS_ENDHANDLER;
      [result autorelease];
    }
  else
    [self errorWithFormat: @"no value for id field '%@'", IDField];

  return result;
}

static NSArray *
_makeLDAPChanges (NGLdapConnection *ldapConnection,
                  NSString *dn, NSArray *attributes)
{
  NSMutableArray *changes, *attributeNames, *origAttributeNames;
  NGLdapEntry *origEntry;
  // NSArray *values;
  NGLdapAttribute *attribute, *origAttribute;
  NSString *name;
  NSDictionary *origAttributes;
  NSUInteger count, max/* , valueCount, valueMax */;
  // BOOL allStrings;

  /* additions and modifications */
  origEntry = [ldapConnection entryAtDN: dn
                             attributes: [NSArray arrayWithObject: @"*"]];
  origAttributes = [origEntry attributes];

  max = [attributes count];
  changes = [NSMutableArray arrayWithCapacity: max];
  attributeNames = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      attribute = [attributes objectAtIndex: count];
      name = [attribute attributeName];
      [attributeNames addObject: name];
      origAttribute = [origAttributes objectForKey: name];
      if (origAttribute)
        {
          if (![origAttribute isEqual: attribute])
            [changes
              addObject: [NGLdapModification replaceModification: attribute]];
        }
      else
        [changes addObject: [NGLdapModification addModification: attribute]];
    }

  /* deletions */
  origAttributeNames = [[origAttributes allKeys] mutableCopy];
  [origAttributeNames autorelease];
  [origAttributeNames removeObjectsInArray: attributeNames];
  max = [origAttributeNames count];
  for (count = 0; count < max; count++)
    {
      name = [origAttributeNames objectAtIndex: count];
      origAttribute = [origAttributes objectForKey: name];
      /* the attribute must only have string values, otherwise it will anyway
         be missing from the new record */
      // allStrings = YES;
      // values = [origAttribute allValues];
      // valueMax = [values count];
      // for (valueCount = 0; allStrings && valueCount < valueMax; valueCount++)
      //   if (![[values objectAtIndex: valueCount] isKindOfClass: NSStringK])
      //     allStrings = NO;
      // if (allStrings)
      [changes
        addObject: [NGLdapModification deleteModification: origAttribute]];
    }

  return changes;
}

- (NSException *) updateContactEntry: (NSDictionary *) roLdifRecord
{
  NSException *result;
  NSString *dn;
  NSMutableDictionary *ldifRecord;
  NSArray *attributes, *changes;
  NGLdapConnection *ldapConnection;

  dn = [roLdifRecord objectForKey: @"dn"];
  if ([dn length] > 0)
    {
      ldapConnection = [self _ldapConnection];
      ldifRecord = [roLdifRecord mutableCopy];
      [ldifRecord autorelease];
      [self _applyContactMappingToOutput: ldifRecord];
      attributes = _convertRecordToLDAPAttributes (schema, ldifRecord);

      changes = _makeLDAPChanges (ldapConnection, dn, attributes);

      NS_DURING
        {
          [ldapConnection modifyEntryWithDN: dn
                                    changes: changes];
          result = nil;
        }
      NS_HANDLER
        {
          result = localException;
          [result retain];
        }
      NS_ENDHANDLER;
      [result autorelease];
    }
  else
    [self errorWithFormat: @"expected dn for modified record"];

  return result;
}

- (NSException *) removeContactEntryWithID: (NSString *) aId
{
  NSException *result;
  NGLdapConnection *ldapConnection;
  NSString *dn;

  ldapConnection = [self _ldapConnection];
  dn = [NSString stringWithFormat: @"%@=%@,%@", IDField,
                 [aId escapedForLDAPDN], baseDN];
  NS_DURING
    {
      [ldapConnection removeEntryWithDN: dn];
      result = nil;
    }
  NS_HANDLER
    {
      result = localException;
      [result retain];
    }
  NS_ENDHANDLER;

  [result autorelease];

  return result;
}

/* user addressbooks */
- (BOOL) hasUserAddressBooks
{
  return ([abOU length] > 0);
}

- (NSArray *) addressBookSourcesForUser: (NSString *) user
{
  NSMutableArray *sources;
  NSString *abBaseDN;
  NGLdapConnection *ldapConnection;
  NSArray *attributes, *modifier;
  NSEnumerator *entries;
  NGLdapEntry *entry;
  NSMutableDictionary *entryRecord;
  NSDictionary *sourceRec;
  LDAPSource *ab;

  if ([self hasUserAddressBooks])
    {
      /* list subentries */
      sources = [NSMutableArray array];

      ldapConnection = [self _ldapConnection];
      abBaseDN = [NSString stringWithFormat: @"ou=%@,%@=%@,%@",
                           [abOU escapedForLDAPDN], IDField,
                           [user escapedForLDAPDN], baseDN];

      /* test ou=addressbooks entry */
      attributes = [NSArray arrayWithObject: @"*"];
      entries = [ldapConnection baseSearchAtBaseDN: abBaseDN
                                         qualifier: nil
                                        attributes: attributes];
      entry = [entries nextObject];
      if (entry)
        {
          attributes = [NSArray arrayWithObjects: @"ou", @"description", nil];
          entries = [ldapConnection flatSearchAtBaseDN: abBaseDN
                                             qualifier: nil
                                            attributes: attributes];
          modifier = [NSArray arrayWithObject: user];
          while ((entry = [entries nextObject]))
            {
              sourceRec = [entry asDictionary];
              ab = [LDAPSource new];
              [ab setSourceID: [sourceRec objectForKey: @"ou"]];
              [ab setDisplayName: [sourceRec objectForKey: @"description"]];
              [ab          setBindDN: bindDN
                            password: password
                            hostname: hostname
                                port: [NSString stringWithFormat: @"%d", port]
                          encryption: encryption
                   bindAsCurrentUser: NO];
              [ab                     setBaseDN: [entry dn]
                                        IDField: @"cn"
                                        CNField: @"displayName"
                                       UIDField: @"cn"
                                     mailFields: nil
                                   searchFields: nil
                             groupObjectClasses: nil
                                  IMAPHostField: nil
                                 IMAPLoginField: nil
                                 SieveHostField: nil
                                     bindFields: nil
                                      kindField: nil
                       andMultipleBookingsField: nil];
              [ab setListRequiresDot: NO];
              [ab setModifiers: modifier];
              [sources addObject: ab];
              [ab release];
            }
        }
      else
        {
          entryRecord = [NSMutableDictionary dictionary];
          [entryRecord setObject: @"organizationalUnit" forKey: @"objectclass"];
          [entryRecord setObject: @"addressbooks" forKey: @"ou"];
          attributes = _convertRecordToLDAPAttributes (schema, entryRecord);
          entry = [[NGLdapEntry alloc] initWithDN: abBaseDN
                                       attributes: attributes];
          [entry autorelease];
          [attributes release];
          NS_DURING
            {
              [ldapConnection addEntry: entry];
            }
          NS_HANDLER
            {
              [self errorWithFormat: @"failed to create ou=addressbooks"
                    @" entry for user"];
            }
          NS_ENDHANDLER;
        }
    }
  else
    sources = nil;

  return sources;
}

- (NSException *) addAddressBookSource: (NSString *) newId
                       withDisplayName: (NSString *) newDisplayName
                               forUser: (NSString *) user
{
  NSException *result;
  NSString *abDN;
  NGLdapConnection *ldapConnection;
  NSArray *attributes;
  NGLdapEntry *entry;
  NSMutableDictionary *entryRecord;

  if ([self hasUserAddressBooks])
    {
      abDN = [NSString stringWithFormat: @"ou=%@,ou=%@,%@=%@,%@",
                       [newId escapedForLDAPDN], [abOU escapedForLDAPDN],
                       IDField, [user escapedForLDAPDN], baseDN];
      entryRecord = [NSMutableDictionary dictionary];
      [entryRecord setObject: @"organizationalUnit" forKey: @"objectclass"];
      [entryRecord setObject: newId forKey: @"ou"];
      if ([newDisplayName length] > 0)
        [entryRecord setObject: newDisplayName forKey: @"description"];
      ldapConnection = [self _ldapConnection];
      attributes = _convertRecordToLDAPAttributes (schema, entryRecord);
      entry = [[NGLdapEntry alloc] initWithDN: abDN
                                   attributes: attributes];
      [entry autorelease];
      [attributes release];
      NS_DURING
        {
          [ldapConnection addEntry: entry];
          result = nil;
        }
      NS_HANDLER
        {
          [self errorWithFormat: @"failed to create addressbook entry"];
          result = localException;
          [result retain];
        }
      NS_ENDHANDLER;
      [result autorelease];
    }
  else
    result = [NSException exceptionWithName: @"LDAPSourceIOException"
                                     reason: @"user addressbooks"
                          @" are not supported"
                                   userInfo: nil];

  return result;
}

- (NSException *) renameAddressBookSource: (NSString *) newId
                          withDisplayName: (NSString *) newDisplayName
                                  forUser: (NSString *) user
{
  NSException *result;
  NSString *abDN;
  NGLdapConnection *ldapConnection;
  NSArray *attributes, *changes;
  NSMutableDictionary *entryRecord;

  if ([self hasUserAddressBooks])
    {
      abDN = [NSString stringWithFormat: @"ou=%@,ou=%@,%@=%@,%@",
                       [newId escapedForLDAPDN], [abOU escapedForLDAPDN],
                       IDField, [user escapedForLDAPDN], baseDN];
      entryRecord = [NSMutableDictionary dictionary];
      [entryRecord setObject: @"organizationalUnit" forKey: @"objectclass"];
      [entryRecord setObject: newId forKey: @"ou"];
      if ([newDisplayName length] > 0)
        [entryRecord setObject: newDisplayName forKey: @"description"];
      ldapConnection = [self _ldapConnection];
      attributes = _convertRecordToLDAPAttributes (schema, entryRecord);
      changes = _makeLDAPChanges (ldapConnection, abDN, attributes);
      [attributes release];
      NS_DURING
        {
          [ldapConnection modifyEntryWithDN: abDN
                                    changes: changes];
          result = nil;
        }
      NS_HANDLER
        {
          [self errorWithFormat: @"failed to rename addressbook entry"];
          result = localException;
          [result retain];
        }
      NS_ENDHANDLER;
      [result autorelease];
    }
  else
    result = [NSException exceptionWithName: @"LDAPSourceIOException"
                                     reason: @"user addressbooks"
                          @" are not supported"
                                   userInfo: nil];
  
  return result;
}

- (NSException *) removeAddressBookSource: (NSString *) newId
                                  forUser: (NSString *) user
{
  NSException *result;
  NSString *abDN;
  NGLdapConnection *ldapConnection;
  NSEnumerator *entries;
  NGLdapEntry *entry;

  if ([self hasUserAddressBooks])
    {
      abDN = [NSString stringWithFormat: @"ou=%@,ou=%@,%@=%@,%@",
                       [newId escapedForLDAPDN], [abOU escapedForLDAPDN],
                       IDField, [user escapedForLDAPDN], baseDN];
      ldapConnection = [self _ldapConnection];
      NS_DURING
        {
          /* we must remove the ab sub=entries prior to the ab entry */
          entries = [ldapConnection flatSearchAtBaseDN: abDN
                                             qualifier: nil
                                            attributes: nil];
          while ((entry = [entries nextObject]))
            [ldapConnection removeEntryWithDN: [entry dn]];
          [ldapConnection removeEntryWithDN: abDN];
          result = nil;
        }
      NS_HANDLER
        {
          [self errorWithFormat: @"failed to remove addressbook entry"];
          result = localException;
          [result retain];
        }
      NS_ENDHANDLER;
      [result autorelease];
    }
  else
    result = [NSException exceptionWithName: @"LDAPSourceIOException"
                                     reason: @"user addressbooks"
                          @" are not supported"
                                   userInfo: nil];

  return result;
}

@end
