/* LDAPSource.m - this file is part of SOGo
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
#import "SOGoSystemDefaults.h"

#import "LDAPSource.h"

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
+ (id) sourceFromUDSource: (NSDictionary *) theSource
                 inDomain: (NSString *) theDomain
{
  id source;

  source = [[self alloc] initFromUDSource: theSource
                                 inDomain: theDomain];
  [source autorelease];

  return source;
}

//
//
//
- (id) init
{
  if ((self = [super init]))
    {
      _sourceID = nil;
      _displayName = nil;

      _bindDN = nil;
      _password = nil;
      _sourceBindDN = nil;
      _sourceBindPassword = nil;
      _hostname = nil;
      _port = 389;
      _encryption = nil;
      _domain = nil;

      _baseDN = nil;
      _pristineBaseDN = nil;
      _schema = nil;
      _IDField = @"cn"; /* the first part of a user DN */
      _CNField = @"cn";
      _UIDField = @"uid";
      _mailFields = [[NSArray arrayWithObject: @"mail"] retain];
      _contactMapping = nil;
      // "mail" expands to all entries of MailFieldNames
      // "name" expands to sn, displayname and cn
      _searchFields = [[NSArray arrayWithObjects: @"name", @"mail", @"telephonenumber", nil] retain];
      _groupObjectClasses = [[NSArray arrayWithObjects: @"group", @"groupofnames", @"groupofuniquenames", @"posixgroup", nil] retain];
      _IMAPHostField = nil;
      _IMAPLoginField = nil;
      _SieveHostField = nil;
      _bindFields = nil;
      _scope = @"sub";
      _filter = nil;
      _userPasswordAlgorithm = nil;
      _listRequiresDot = YES;

      _passwordPolicy = NO;
      _updateSambaNTLMPasswords = NO;

      _kindField = nil;
      _multipleBookingsField = nil;

      _MSExchangeHostname = nil;

      _modifiers = nil;
    }

  return self;
}

//
//
//
- (void) dealloc
{
  [_schema release];
  [_bindDN release];
  [_password release];
  [_sourceBindDN release];
  [_sourceBindPassword release];
  [_hostname release];
  [_encryption release];
  [_baseDN release];
  [_pristineBaseDN release];
  [_IDField release];
  [_CNField release];
  [_UIDField release];
  [_contactMapping release];
  [_mailFields release];
  [_searchFields release];
  [_groupObjectClasses release];
  [_IMAPHostField release];
  [_IMAPLoginField release];
  [_SieveHostField release];
  [_bindFields release];
  [_filter release];
  [_userPasswordAlgorithm release];
  [_sourceID release];
  [_modulesConstraints release];
  [_scope release];
  [_domain release];
  [_kindField release];
  [_multipleBookingsField release];
  [_MSExchangeHostname release];
  [_modifiers release];
  [_displayName release];
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
      ASSIGN(_abOU, [udSource objectForKey: @"abOU"]);

      if ([sourceDomain length])
        {
          NSMutableString *s;

          dd = [SOGoDomainDefaults defaultsForDomain: sourceDomain];
          ASSIGN(_domain, sourceDomain);

          // We now look if we have a dynamic baseBN and if we have any value to swap
          if ([_baseDN rangeOfString: @"%d"].location != NSNotFound)
            {
              s = [NSMutableString stringWithString: _baseDN];
              [s replaceOccurrencesOfString: @"%d"  withString: _domain  options: 0  range: NSMakeRange(0, [s length])];
              ASSIGN(_baseDN, s);
            }
        }
      else
        dd = [SOGoSystemDefaults sharedSystemDefaults];

      _contactInfoAttribute
        = [udSource objectForKey: @"SOGoLDAPContactInfoAttribute"];
      if (!_contactInfoAttribute)
        _contactInfoAttribute = [dd ldapContactInfoAttribute];
      [_contactInfoAttribute retain];
      
      udQueryLimit = [udSource objectForKey: @"SOGoLDAPQueryLimit"];
      if (udQueryLimit)
        _queryLimit = [udQueryLimit intValue];
      else
        _queryLimit = [dd ldapQueryLimit];

      udQueryTimeout = [udSource objectForKey: @"SOGoLDAPQueryTimeout"];
      if (udQueryTimeout)
        _queryTimeout = [udQueryTimeout intValue];
      else
        _queryTimeout = [dd ldapQueryTimeout];

      ASSIGN(_modulesConstraints, [udSource objectForKey: @"ModulesConstraints"]);
      ASSIGN(_filter, [udSource objectForKey: @"filter"]);
      ASSIGN(_userPasswordAlgorithm, [udSource objectForKey: @"userPasswordAlgorithm"]);
      ASSIGN(_scope, ([udSource objectForKey: @"scope"]
                       ? [udSource objectForKey: @"scope"]
                       : (id)@"sub"));

      if (!_userPasswordAlgorithm)
        _userPasswordAlgorithm = @"none";

      if ([udSource objectForKey: @"passwordPolicy"])
        _passwordPolicy = [[udSource objectForKey: @"passwordPolicy"] boolValue];

      if ([udSource objectForKey: @"updateSambaNTLMPasswords"])
        _updateSambaNTLMPasswords = [[udSource objectForKey: @"updateSambaNTLMPasswords"] boolValue];
      
      ASSIGN(_MSExchangeHostname, [udSource objectForKey: @"MSExchangeHostname"]);
    }

  return self;
}

- (void) setBindDN: (NSString *) theDN
{
  //NSLog(@"Setting bind DN to %@", theDN);
  ASSIGN(_bindDN, theDN);
}

- (NSString *) bindDN
{
  return _bindDN;
}

- (void) setBindPassword: (NSString *) thePassword
{
  ASSIGN(_password, thePassword);
}

- (NSString *) bindPassword
{
  return _password;
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
  ASSIGN(_bindDN, newBindDN);
  ASSIGN(_password, newBindPassword);
  ASSIGN(_sourceBindDN, newBindDN);
  ASSIGN(_sourceBindPassword, newBindPassword);

  ASSIGN(_encryption, [newEncryption uppercaseString]);
  if ([_encryption isEqualToString: @"SSL"])
    _port = 636;
  ASSIGN(_hostname, newBindHostname);
  if (newBindPort)
    _port = [newBindPort intValue];
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
  ASSIGN(_baseDN, [newBaseDN lowercaseString]);
  ASSIGN(_pristineBaseDN, [newBaseDN lowercaseString]);
  if (newIDField)
    ASSIGN(_IDField, [newIDField lowercaseString]);
  if (newCNField)
    ASSIGN(_CNField, [newCNField lowercaseString]);
  if (newUIDField)
    ASSIGN(_UIDField, [newUIDField lowercaseString]);
  if (newIMAPHostField)
    ASSIGN(_IMAPHostField, [newIMAPHostField lowercaseString]);
  if (newIMAPLoginField)
    ASSIGN(_IMAPLoginField, [newIMAPLoginField lowercaseString]);
  if (newSieveHostField)
    ASSIGN(_SieveHostField, [newSieveHostField lowercaseString]);
  if (newMailFields)
    ASSIGN(_mailFields, newMailFields);
  if (newSearchFields)
    ASSIGN(_searchFields, newSearchFields);
  if (newGroupObjectClasses)
    ASSIGN(_groupObjectClasses, newGroupObjectClasses);
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
        ASSIGN(_bindFields, newBindFields);
      else
        {
          [self logWithFormat: @"WARNING: using old bindFields format - please update it"];
          ASSIGN(_bindFields, [newBindFields componentsSeparatedByString: @","]);
        }
    }
  if (newKindField)
    ASSIGN(_kindField, [newKindField lowercaseString]);
  if (newMultipleBookingsField)
    ASSIGN(_multipleBookingsField, [newMultipleBookingsField lowercaseString]);
}

- (void) setListRequiresDot: (BOOL) theBool
{
  _listRequiresDot = theBool;
}

- (BOOL) listRequiresDot
{
  return _listRequiresDot;
}

- (NSArray *) searchFields
{
  return _searchFields;
}

- (void) setContactMapping: (NSDictionary *) theMapping
          andObjectClasses: (NSArray *) theObjectClasses
{
  ASSIGN(_contactMapping, theMapping);
  ASSIGN(_contactObjectClasses, theObjectClasses);
}

//
//
//
- (BOOL) _setupEncryption: (NGLdapConnection *) theConnection
{
  BOOL rc;

  if ([_encryption isEqualToString: @"SSL"])
    rc = [theConnection useSSL];
  else if ([_encryption isEqualToString: @"STARTTLS"])
    rc = [theConnection startTLS];
  else
    {
      [self errorWithFormat:
        @"encryption scheme '%@' not supported:"
        @" use 'SSL' or 'STARTTLS'", _encryption];
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
      NSLog(@"Creating NGLdapConnection instance for bindDN '%@'", _bindDN);
      ldapConnection = [[NGLdapConnection alloc] initWithHostName: _hostname
                                                             port: _port];
      [ldapConnection autorelease];
      if (![_encryption length] || [self _setupEncryption: ldapConnection])
        {
          [ldapConnection bindWithMethod: @"simple"
                                  binddn: _bindDN
                             credentials: _password];
          if (_queryLimit > 0)
            [ldapConnection setQuerySizeLimit: _queryLimit];
          if (_queryTimeout > 0)
            [ldapConnection setQueryTimeLimit: _queryTimeout];
          if (!_schema)
            {
              _schema = [LDAPSourceSchema new];
              [_schema readSchemaFromConnection: ldapConnection];
            }
        }
      else
        ldapConnection = nil;
    }
  NS_HANDLER
    {
      [self errorWithFormat: @"Could not bind to the LDAP server %@ (%d) "
                             @"using the bind DN: %@", _hostname, _port, _bindDN];
      [self errorWithFormat: @"%@", localException];
      ldapConnection = nil;
    }
  NS_ENDHANDLER;

  return ldapConnection;
}

- (NSString *) domain
{
  return _domain;
}

/* user management */
- (EOQualifier *) _qualifierForBindFilter: (NSString *) theUID
{
  NSMutableString *qs;
  NSString *escapedUid;
  NSEnumerator *fields;
  NSString *currentField;

  qs = [NSMutableString string];

  escapedUid = SafeLDAPCriteria(theUID);

  fields = [_bindFields objectEnumerator];
  while ((currentField = [fields nextObject]))
    [qs appendFormat: @" OR (%@='%@')", currentField, escapedUid];

  if (_filter && [_filter length])
    [qs appendFormat: @" AND %@", _filter];

  [qs deleteCharactersInRange: NSMakeRange(0, 4)];

  return [EOQualifier qualifierWithQualifierFormat: qs];
}

- (NSString *) _fetchUserDNForLogin: (NSString *) theLogin
{
  NGLdapConnection *ldapConnection;
  EOQualifier *qualifier;
  NSEnumerator *entries;
  NSArray *attributes;
  NSString *userDN;

  ldapConnection = [self _ldapConnection];
  qualifier = [self _qualifierForBindFilter: theLogin];
  attributes = [NSArray arrayWithObject: @"dn"];

  if ([_scope caseInsensitiveCompare: @"BASE"] == NSOrderedSame)
    entries = [ldapConnection baseSearchAtBaseDN: _baseDN
                                       qualifier: qualifier
                                      attributes: attributes];
  else if ([_scope caseInsensitiveCompare: @"ONE"] == NSOrderedSame)
    entries = [ldapConnection flatSearchAtBaseDN: _baseDN
                                       qualifier: qualifier
                                      attributes: attributes];
  else
    entries = [ldapConnection deepSearchAtBaseDN: _baseDN
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
  NSMutableString *s;
  NSString *userDN;
  BOOL didBind;
  NSRange r;

  didBind = NO;

  NS_DURING
    if ([_login length] > 0 && [_pwd length] > 0)
      {
        // We check if SOGo admins have deviced a top-level SOGoUserSources with a dynamic base DN.
        // This is a supported multi-domain configuration. We alter the baseDN in this case by extracting
        // the domain from the login.
        r = [_login rangeOfString: @"@"];
        if (r.location != NSNotFound &&
            [_pristineBaseDN rangeOfString: @"%d"].location != NSNotFound)
          {
              s = [NSMutableString stringWithString: _pristineBaseDN];
              [s replaceOccurrencesOfString: @"%d"  withString: [_login substringFromIndex: r.location+1]  options: 0  range: NSMakeRange(0, [s length])];
              ASSIGN(_baseDN, s);
            }

        bindConnection = [[NGLdapConnection alloc] initWithHostName: _hostname
                                                               port: _port];
        if (![_encryption length] || [self _setupEncryption: bindConnection])
          {
            if (_queryTimeout > 0)
              [bindConnection setQueryTimeLimit: _queryTimeout];

            userDN = [[SOGoCache sharedCache] distinguishedNameForLogin: _login];

            if (!userDN)
              {
                if (_bindFields)
                  {
                    // We MUST always use the source's bindDN/password in
                    // order to lookup the user's DN. This is important since
                    // if we use bindAsCurrentUser, we could stay bound and
                    // lookup the user's DN (for an other user that is trying
                    // to log in) but not be able to do so due to ACLs in LDAP.
                    [self setBindDN: _sourceBindDN];
                    [self setBindPassword: _sourceBindPassword];
                    userDN = [self _fetchUserDNForLogin: _login];
                  }
                else
                  userDN = [NSString stringWithFormat: @"%@=%@,%@",
                                     _IDField, [_login escapedForLDAPDN], _baseDN];
              }

            if (userDN)
              {
                if (!_passwordPolicy)
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
- (NSString *) _encryptPassword: (NSString *) thePassword
{
  NSString *pass;
  pass = [thePassword asCryptedPassUsingScheme: _userPasswordAlgorithm];

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
        bindConnection = [[NGLdapConnection alloc] initWithHostName: _hostname
                                                               port: _port];
        if (![_encryption length] || [self _setupEncryption: bindConnection])
          {
            if (_queryTimeout > 0)
              [bindConnection setQueryTimeLimit: _queryTimeout];
            if (_bindFields)
              userDN = [self _fetchUserDNForLogin: login];
            else
              {
                userDN = [NSString stringWithFormat: @"%@=%@,%@",
                                   _IDField, [login escapedForLDAPDN], _baseDN];
              }
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
                else if (_passwordPolicy)
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
                if (didChange && _updateSambaNTLMPasswords)
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
      if ([[localException name] isEqual: @"LDAPException"] &&
          ([[[localException userInfo] objectForKey: @"error_code"] intValue] == LDAP_CONSTRAINT_VIOLATION))
        {
          *perr = PolicyInsufficientPasswordQuality;
        }
      else
        {
          [self logWithFormat: @"%@", localException];
        }
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
                           onCriteria: (NSArray *) criteria
{
  NSEnumerator *criteriaList;
  NSMutableArray *fields;
  NSString *fieldFormat, *currentCriteria, *searchFormat, *escapedFilter;
  EOQualifier *qualifier;
  NSMutableString *qs;

  escapedFilter = SafeLDAPCriteria(filter);
  qs = [NSMutableString string];

  if (([escapedFilter length] == 0 && !_listRequiresDot) || [escapedFilter isEqualToString: @"."])
    {
      [qs appendFormat: @"(%@='*')", _CNField];
    }
  else
    {
      fieldFormat = [NSString stringWithFormat: @"(%%@='*%@*')", escapedFilter];
      if (criteria)
        criteriaList = [criteria objectEnumerator];
      else
        criteriaList = [[self searchFields] objectEnumerator];

      fields = [NSMutableArray array];
      while (( currentCriteria = [criteriaList nextObject] ))
        {
          if ([currentCriteria isEqualToString: @"name"])
            {
              [fields addObject: @"sn"];
              [fields addObject: @"displayname"];
              [fields addObject: @"cn"];
            }
          else if ([currentCriteria isEqualToString: @"mail"])
            {
              // Expand to all mail fields
              [fields addObject: currentCriteria];
              [fields addObjectsFromArray: _mailFields];
            }
          else if ([[self searchFields] containsObject: currentCriteria])
            [fields addObject: currentCriteria];
        }

      searchFormat = [[[fields uniqueObjects] stringsWithFormat: fieldFormat] componentsJoinedByString: @" OR "];
      [qs appendString: searchFormat];
    }

  if (_filter && [_filter length])
    [qs appendFormat: @" AND %@", _filter];

  if ([qs length])
    qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
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
  mailFormat = [[_mailFields stringsWithFormat: fieldFormat]
                     componentsJoinedByString: @" OR "];
  qs = [NSMutableString stringWithFormat: @"(%@='%@') OR %@",
                        _UIDField, escapedUid, mailFormat];
  if (_bindFields)
    {
      bindFieldsEnum = [_bindFields objectEnumerator];
      while ((currentField = [bindFieldsEnum nextObject]))
        {
          if ([currentField caseInsensitiveCompare: _UIDField] != NSOrderedSame
              && ![_mailFields containsObject: currentField])
            [qs appendFormat: @" OR (%@='%@')", [currentField stringByTrimmingSpaces], escapedUid];
        }
    }

  if (_filter && [_filter length])
    [qs appendFormat: @" AND %@", _filter];

  return [EOQualifier qualifierWithQualifierFormat: qs];
}

/*
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
*/

/* This is required for SQL sources when DomainFieldName is enabled.
 * For LDAP, simply discard the domain and call the original method */
- (NSArray *) allEntryIDsVisibleFromDomain: (NSString *) theDomain
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
  attributes = [NSArray arrayWithObject: _IDField];

  qs = [NSMutableString stringWithFormat: @"(%@='*')", _CNField];
  if ([_filter length])
    [qs appendFormat: @" AND %@", _filter];
  qualifier = [EOQualifier qualifierWithQualifierFormat: qs];

  if ([_scope caseInsensitiveCompare: @"BASE"] == NSOrderedSame) 
    entries = [ldapConnection baseSearchAtBaseDN: _baseDN
                                       qualifier: qualifier
                                      attributes: attributes];
  else if ([_scope caseInsensitiveCompare: @"ONE"] == NSOrderedSame) 
    entries = [ldapConnection flatSearchAtBaseDN: _baseDN
                                       qualifier: qualifier
                                      attributes: attributes];
  else
    entries = [ldapConnection deepSearchAtBaseDN: _baseDN
                                       qualifier: qualifier
                                      attributes: attributes];

  while ((currentEntry = [entries nextObject]))
    {
      value = [[currentEntry attributeWithName: _IDField]
                            stringValueAtIndex: 0];
      if ([value length] > 0)
        [ids addObject: value];
    }

  return ids;
}

- (void) _fillEmailsOfEntry: (NGLdapEntry *) ldapEntry
             intoLDIFRecord: (NSMutableDictionary *) ldifRecord
{
  NSString *currentFieldName, *ldapValue;
  NSEnumerator *emailFields;
  NSMutableArray *emails;
  NSArray *allValues;

  emails = [[NSMutableArray alloc] init];
  emailFields = [_mailFields objectEnumerator];
  while ((currentFieldName = [emailFields nextObject]))
    {
      allValues = [[ldapEntry attributeWithName: currentFieldName]
                    allStringValues];

      // Special case handling for Microsoft Active Directory. proxyAddresses
      // is generally prefixed with smtp: - if we find this (or any value preceeding
      // the semi-colon), we strip it. See https://msdn.microsoft.com/en-us/library/ms679424(v=vs.85).aspx
      if ([currentFieldName caseInsensitiveCompare: @"proxyAddresses"] == NSOrderedSame)
	{
	  NSRange r;
	  int i;

	  for (i = 0; i < [allValues count]; i++)
	    {
	      ldapValue = [allValues objectAtIndex: i];
	      r = [ldapValue rangeOfString: @":"];

	      if (r.length)
		{
		  // We only keep "smtp" ones
		  if ([[ldapValue lowercaseString] hasPrefix: @"smtp"])
		    [emails addObject: [ldapValue substringFromIndex: r.location+1]];
		}
	      else
		[emails addObject: ldapValue];
	    }
	}
      else
	[emails addObjectsFromArray: allValues];
    }
  [ldifRecord setObject: emails forKey: @"c_emails"];
  [emails release];

  if (_IMAPHostField)
    {
      ldapValue = [[ldapEntry attributeWithName: _IMAPHostField] stringValueAtIndex: 0];
      if ([ldapValue length] > 0)
        [ldifRecord setObject: ldapValue forKey: @"c_imaphostname"];
    }

  if (_IMAPLoginField)
    {
      ldapValue = [[ldapEntry attributeWithName: _IMAPLoginField] stringValueAtIndex: 0];
      if ([ldapValue length] > 0)
        [ldifRecord setObject: ldapValue forKey: @"c_imaplogin"];
    }

  if (_SieveHostField)
    {
      ldapValue = [[ldapEntry attributeWithName: _SieveHostField] stringValueAtIndex: 0];
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

  constraints = [_modulesConstraints objectForKey: module];
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
- (void) applyContactMappingToResult: (NSMutableDictionary *) ldifRecord
{
  NSArray *sourceFields;
  NSArray *keys;
  NSString *key, *field, *value;
  NSUInteger count, max, fieldCount, fieldMax;
  BOOL filled;

  keys = [_contactMapping allKeys];
  max = [keys count];
  for (count = 0; count < max; count++)
    {
      key = [keys objectAtIndex: count];
      sourceFields = [_contactMapping objectForKey: key];
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
- (void) applyContactMappingToOutput: (NSMutableDictionary *) ldifRecord
{
  NSArray *sourceFields;
  NSArray *keys;
  NSString *key, *lowerKey, *field, *value;
  NSUInteger count, max, fieldCount, fieldMax;

  if (_contactObjectClasses)
    [ldifRecord setObject: _contactObjectClasses
                   forKey: @"objectclass"];

  keys = [_contactMapping allKeys];
  max = [keys count];
  for (count = 0; count < max; count++)
    {
      key = [keys objectAtIndex: count];
      lowerKey = [key lowercaseString];
      value = [ldifRecord objectForKey: lowerKey];
      if ([value length] > 0)
        {
          sourceFields = [_contactMapping objectForKey: key];
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
        gclasses = [_groupObjectClasses objectEnumerator];
        while ((gclass = [gclasses nextObject]))
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
  if ([_kindField length] > 0)
    {
      value = [ldifRecord objectForKey: [_kindField lowercaseString]];
      if ([value isKindOfClass: NSStringK]
          && [resourceKinds containsObject: value])
        [ldifRecord setObject: [NSNumber numberWithInt: 1]
                       forKey: @"isResource"];
    }

  // We check for the number of simultanous bookings that is allowed.
  // A value of 0 means that there's no limit.
  if ([_multipleBookingsField length] > 0)
    {
      value = [ldifRecord objectForKey: [_multipleBookingsField lowercaseString]];
      [ldifRecord setObject: [NSNumber numberWithInt: [value intValue]]
                     forKey: @"numberOfSimultaneousBookings"];
    }

  value = [[ldapEntry attributeWithName: _IDField] stringValueAtIndex: 0];
  if (!value)
    value = @"";
  [ldifRecord setObject: value forKey: @"c_name"];
  value = [[ldapEntry attributeWithName: _UIDField] stringValueAtIndex: 0];
  if (!value)
    value = @"";
//  else
//    {
//      Eventually, we could check at this point if the entry is a group
//      and prefix the UID with a "@"
//    }
  [ldifRecord setObject: value forKey: @"c_uid"];
  value = [[ldapEntry attributeWithName: _CNField] stringValueAtIndex: 0];
  if (!value)
    value = @"";
  [ldifRecord setObject: value forKey: @"c_cn"];
  /* if "displayName" is not set, we use CNField because it must exist */
  if (![ldifRecord objectForKey: @"displayname"])
    [ldifRecord setObject: value forKey: @"displayname"];

  if (_contactInfoAttribute)
    {
      value = [[ldapEntry attributeWithName: _contactInfoAttribute]
                stringValueAtIndex: 0];
      if (!value)
        value = @"";
    }
  else
    value = @"";
  [ldifRecord setObject: value forKey: @"c_info"];

  if (_domain)
    value = _domain;
  else
    value = @"";
  [ldifRecord setObject: value forKey: @"c_domain"];

  [self _fillEmailsOfEntry: ldapEntry intoLDIFRecord: ldifRecord];
  [self _fillConstraints: ldapEntry forModule: @"Calendar"
          intoLDIFRecord: (NSMutableDictionary *) ldifRecord];
  [self _fillConstraints: ldapEntry forModule: @"Mail"
          intoLDIFRecord: (NSMutableDictionary *) ldifRecord];
  [self _fillConstraints: ldapEntry forModule: @"ActiveSync"
          intoLDIFRecord: (NSMutableDictionary *) ldifRecord];

  if (_contactMapping)
    [self applyContactMappingToResult: ldifRecord];

  return ldifRecord;
}

- (NSArray *) fetchContactsMatching: (NSString *) match
                       withCriteria: (NSArray *) criteria
                           inDomain: (NSString *) theDomain
{
  NGLdapConnection *ldapConnection;
  NGLdapEntry *currentEntry;
  NSEnumerator *entries;
  NSMutableArray *contacts;
  EOQualifier *qualifier;
  NSArray *attributes;

  contacts = [NSMutableArray array];

  if ([match length] > 0 || !_listRequiresDot)
    {
      ldapConnection = [self _ldapConnection];
      qualifier = [self _qualifierForFilter: match onCriteria: criteria];
      attributes = [NSArray arrayWithObject: @"*"];

      if ([_scope caseInsensitiveCompare: @"BASE"] == NSOrderedSame)
        entries = [ldapConnection baseSearchAtBaseDN: _baseDN
                                           qualifier: qualifier
                                          attributes: attributes];
      else if ([_scope caseInsensitiveCompare: @"ONE"] == NSOrderedSame)
        entries = [ldapConnection flatSearchAtBaseDN: _baseDN
                                           qualifier: qualifier
                                          attributes: attributes];
      else /* we do it like before */ 
        entries = [ldapConnection deepSearchAtBaseDN: _baseDN
                                           qualifier: qualifier
                                          attributes: attributes];
      while ((currentEntry = [entries nextObject]))
        [contacts addObject:
                    [self _convertLDAPEntryToContact: currentEntry]];
    }

  return contacts;
}

- (NGLdapEntry *) _lookupLDAPEntry: (EOQualifier *) theQualifier
{
  NGLdapConnection *ldapConnection;
  NSEnumerator *entries;
  NSArray *attributes;

  ldapConnection = [self _ldapConnection];
  attributes = [NSArray arrayWithObject: @"*"];

  if ([_scope caseInsensitiveCompare: @"BASE"] == NSOrderedSame)
    entries = [ldapConnection baseSearchAtBaseDN: _baseDN
                                       qualifier: theQualifier
                                      attributes: attributes];
  else if ([_scope caseInsensitiveCompare: @"ONE"] == NSOrderedSame)
    entries = [ldapConnection flatSearchAtBaseDN: _baseDN
                                       qualifier: theQualifier
                                      attributes: attributes];
  else
    entries = [ldapConnection deepSearchAtBaseDN: _baseDN
                                       qualifier: theQualifier
                                      attributes: attributes];

  return [entries nextObject];
}

- (NSDictionary *) lookupContactEntry: (NSString *) theID
                             inDomain: (NSString *) theDomain
{
  NGLdapEntry *ldapEntry;
  EOQualifier *qualifier;
  NSString *s;
  NSDictionary *ldifRecord;

  ldifRecord = nil;

  if ([theID length] > 0)
    {
      s = [NSString stringWithFormat: @"(%@='%@')",
                    _IDField, SafeLDAPCriteria(theID)];
      qualifier = [EOQualifier qualifierWithQualifierFormat: s];
      ldapEntry = [self _lookupLDAPEntry: qualifier];
      if (ldapEntry)
        ldifRecord = [self _convertLDAPEntryToContact: ldapEntry];
    }

  return ldifRecord;
}

- (NSDictionary *) lookupContactEntryWithUIDorEmail: (NSString *) uid
                                           inDomain: (NSString *) theDomain
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
  EOQualifier *qualifier;
  NSString *login;
  
  login = nil;
  qualifier = nil;

  ldapConnection = [self _ldapConnection];

  if (_filter)
    qualifier = [EOQualifier qualifierWithQualifierFormat: _filter];

  entry = [ldapConnection entryAtDN: theDN
			  qualifier: qualifier
                         attributes: [NSArray arrayWithObject: _UIDField]];
  if (entry)
    login = [[entry attributeWithName: _UIDField] stringValueAtIndex: 0];

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
                               inDomain: (NSString *) theDomain
{
  return [self _lookupGroupEntryByAttributes: [NSArray arrayWithObject: _UIDField]
				    andValue: theUID];
}

- (NGLdapEntry *) lookupGroupEntryByEmail: (NSString *) theEmail
                                 inDomain: (NSString *) theDomain
{
  return [self _lookupGroupEntryByAttributes: _mailFields
				    andValue: theEmail];
}

- (void) setSourceID: (NSString *) newSourceID
{
  ASSIGN(_sourceID, newSourceID);
}

- (NSString *) sourceID
{
  return _sourceID;
}

- (void) setDisplayName: (NSString *) newDisplayName
{
  ASSIGN(_displayName, newDisplayName);
}

- (NSString *) displayName
{
  return _displayName;
}

- (NSString *) baseDN
{
  return _baseDN;
}

- (NSString *) MSExchangeHostname
{
  return _MSExchangeHostname;
}

- (void) setModifiers: (NSArray *) newModifiers
{
  ASSIGN(_modifiers, newModifiers);
}

- (NSArray *) modifiers
{
  return _modifiers;
}

- (NSArray *) groupObjectClasses
{
  return _groupObjectClasses;
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

- (NSException *) addContactEntry: (NSDictionary *) theEntry
                           withID: (NSString *) theId
{
  NGLdapConnection *ldapConnection;
  NSMutableDictionary *ldifRecord;
  NSString *dn, *cnValue;
  NGLdapEntry *newEntry;
  NSException *result;
  NSArray *attributes;

  result = nil;

  if ([theId length] > 0)
    {
      ldapConnection = [self _ldapConnection];
      ldifRecord = [theEntry mutableCopy];
      [ldifRecord autorelease];
      [ldifRecord setObject: theId forKey: _UIDField];

      /* if CN is not set, we use aId because it must exist */
      if (![ldifRecord objectForKey: _CNField])
        {
          cnValue = [ldifRecord objectForKey: @"displayname"];
          if ([cnValue length] == 0)
            cnValue = theId;
          [ldifRecord setObject: theId forKey: @"cn"];
        }

      [self applyContactMappingToOutput: ldifRecord];

      /* since the id might have changed due to the mapping above, we
         reload the record ID */
      theId = [ldifRecord objectForKey: _UIDField];
      dn = [NSString stringWithFormat: @"%@=%@,%@", _IDField,
                     [theId escapedForLDAPDN], _baseDN];
      attributes = _convertRecordToLDAPAttributes(_schema, ldifRecord);

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
    [self errorWithFormat: @"no value for id field '%@'", _IDField];

  return result;
}

static NSArray *
_makeLDAPChanges (NGLdapConnection *ldapConnection,
                  NSString *dn, NSArray *attributes)
{
  NSMutableArray *changes, *attributeNames, *origAttributeNames;
  NGLdapAttribute *attribute, *origAttribute;
  NSDictionary *origAttributes;
  NGLdapEntry *origEntry;
  NSString *name;

  NSUInteger count, max;

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

- (NSException *) updateContactEntry: (NSDictionary *) theEntry
{
  NGLdapConnection *ldapConnection;
  NSMutableDictionary *ldifRecord;
  NSArray *attributes, *changes;
  NSException *result;
  NSString *dn;

  dn = [theEntry objectForKey: @"dn"];
  result = nil;

  if ([dn length] > 0)
    {
      ldapConnection = [self _ldapConnection];
      ldifRecord = [theEntry mutableCopy];
      [ldifRecord autorelease];
      [self applyContactMappingToOutput: ldifRecord];
      attributes = _convertRecordToLDAPAttributes(_schema, ldifRecord);

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

- (NSException *) removeContactEntryWithID: (NSString *) theId
{
  NGLdapConnection *ldapConnection;
  NSException *result;
  NSString *dn;

  ldapConnection = [self _ldapConnection];
  dn = [NSString stringWithFormat: @"%@=%@,%@", _IDField,
                 [theId escapedForLDAPDN], _baseDN];
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
  return ([_abOU length] > 0);
}

- (NSArray *) addressBookSourcesForUser: (NSString *) theUser
{
  NGLdapConnection *ldapConnection;
  NSMutableDictionary *entryRecord;
  NSArray *attributes, *modifier;
  NSMutableArray *sources;
  NSDictionary *sourceRec;
  NSEnumerator *entries;
  NGLdapEntry *entry;
  NSString *abBaseDN;
  LDAPSource *ab;

  if ([self hasUserAddressBooks])
    {
      /* list subentries */
      sources = [NSMutableArray array];

      ldapConnection = [self _ldapConnection];
      abBaseDN = [NSString stringWithFormat: @"ou=%@,%@=%@,%@",
                           [_abOU escapedForLDAPDN], _IDField,
                           [theUser escapedForLDAPDN], _baseDN];

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
          modifier = [NSArray arrayWithObject: theUser];
          while ((entry = [entries nextObject]))
            {
              sourceRec = [entry asDictionary];
              ab = [LDAPSource new];
              [ab setSourceID: [sourceRec objectForKey: @"ou"]];
              [ab setDisplayName: [sourceRec objectForKey: @"description"]];
              [ab setBindDN: _bindDN
		   password: _password
		   hostname: _hostname
		       port: [NSString stringWithFormat: @"%d", _port]
		 encryption: _encryption
		  bindAsCurrentUser: [NSString stringWithFormat: @"%d", NO]];
              [ab setBaseDN: [entry dn]
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
          attributes = _convertRecordToLDAPAttributes(_schema, entryRecord);
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
                       [newId escapedForLDAPDN], [_abOU escapedForLDAPDN],
                       _IDField, [user escapedForLDAPDN], _baseDN];
      entryRecord = [NSMutableDictionary dictionary];
      [entryRecord setObject: @"organizationalUnit" forKey: @"objectclass"];
      [entryRecord setObject: newId forKey: @"ou"];
      if ([newDisplayName length] > 0)
        [entryRecord setObject: newDisplayName forKey: @"description"];
      ldapConnection = [self _ldapConnection];
      attributes = _convertRecordToLDAPAttributes(_schema, entryRecord);
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
  NGLdapConnection *ldapConnection;
  NSMutableDictionary *entryRecord;
  NSArray *attributes, *changes;
  NSException *result;
  NSString *abDN;

  if ([self hasUserAddressBooks])
    {
      abDN = [NSString stringWithFormat: @"ou=%@,ou=%@,%@=%@,%@",
                       [newId escapedForLDAPDN], [_abOU escapedForLDAPDN],
                       _IDField, [user escapedForLDAPDN], _baseDN];
      entryRecord = [NSMutableDictionary dictionary];
      [entryRecord setObject: @"organizationalUnit" forKey: @"objectclass"];
      [entryRecord setObject: newId forKey: @"ou"];
      if ([newDisplayName length] > 0)
        [entryRecord setObject: newDisplayName forKey: @"description"];
      ldapConnection = [self _ldapConnection];
      attributes = _convertRecordToLDAPAttributes(_schema, entryRecord);
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
  NGLdapConnection *ldapConnection;
  NSEnumerator *entries;
  NSException *result;
  NGLdapEntry *entry;
  NSString *abDN;

  if ([self hasUserAddressBooks])
    {
      abDN = [NSString stringWithFormat: @"ou=%@,ou=%@,%@=%@,%@",
                       [newId escapedForLDAPDN], [_abOU escapedForLDAPDN],
                       _IDField, [user escapedForLDAPDN], _baseDN];
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
