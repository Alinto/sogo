/* SQLSource.h - this file is part of SOGo
 *
 * Copyright (C) 2009-2012 Inverse inc.
 *
 * Authors: Ludovic Marcotte <lmarcotte@inverse.ca>
 *          Francis Lachapelle <flachapelle@inverse.ca>
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
#import <Foundation/NSException.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSURL.h>

#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/NSURL+GCS.h>
#import <GDLContentStore/EOQualifier+GCS.h>
#import <GDLAccess/EOAdaptorChannel.h>

#import "SOGoConstants.h"
#import "NSString+Utilities.h"
#import "NSString+Crypto.h"

#import "SQLSource.h"

/**
 * The view MUST contain the following columns:
 *
 * c_uid      - will be used for authentication - it's a username or username@domain.tld)
 * c_name     - which can be identical to c_uid - will be used to uniquely identify entries)
 * c_password - password of the user, can be encoded in {scheme}pass format, or when stored without
 *              scheme it uses the scheme set in userPasswordAlgorithm.
 *              Possible algorithms are:  plain, md5, crypt-md5, sha, ssha (including 256/512 variants),
 *              cram-md5, smd5, crypt, crypt-md5
 * c_cn       - the user's common name
 * mail       - the user's mail address
 *
 * Other columns can be defined - see LDAPSource.m for the complete list.
 *
 *
 * A SQL source can be defined like this:
 *
 *  {   
 *    id = zot;
 *    type = sql;
 *    viewURL = "mysql://sogo:sogo@127.0.0.1:5432/sogo/sogo_view";
 *    canAuthenticate = YES;
 *    isAddressBook = YES;
 *    userPasswordAlgorithm = md5;
 *    prependPasswordScheme = YES;
 *  }
 *
 * If prependPasswordScheme is set to YES, the generated passwords will have the format {scheme}password.
 * If it is NO (the default), the password will be written to database without encryption scheme.
 *
 */

@implementation SQLSource

+ (id) sourceFromUDSource: (NSDictionary *) udSource
                 inDomain: (NSString *) domain
{
  return [[[self alloc] initFromUDSource: udSource
                                inDomain: domain] autorelease];
}

- (id) init
{
  if ((self = [super init]))
    {
      _sourceID = nil;
      _domainField = nil;
      _authenticationFilter = nil;
      _loginFields = nil;
      _mailFields = nil;
      _userPasswordAlgorithm = nil;
      _viewURL = nil;
      _kindField = nil;
      _multipleBookingsField = nil;
      _imapHostField = nil;
    }

  return self;
}

- (void) dealloc
{
  [_sourceID release];
  [_authenticationFilter release];
  [_loginFields release];
  [_mailFields release];
  [_userPasswordAlgorithm release];
  [_viewURL release];
  [_kindField release];
  [_multipleBookingsField release];
  [_domainField release];
  [_imapHostField release];
   
  [super dealloc];
}

- (id) initFromUDSource: (NSDictionary *) udSource
               inDomain: (NSString *) sourceDomain
{
  self = [self init];

  ASSIGN(_sourceID, [udSource objectForKey: @"id"]);
  ASSIGN(_authenticationFilter, [udSource objectForKey: @"authenticationFilter"]);
  ASSIGN(_loginFields, [udSource objectForKey: @"LoginFieldNames"]);
  ASSIGN(_mailFields, [udSource objectForKey: @"MailFieldNames"]);
  ASSIGN(_userPasswordAlgorithm, [udSource objectForKey: @"userPasswordAlgorithm"]);
  ASSIGN(_imapLoginField, [udSource objectForKey: @"IMAPLoginFieldName"]);
  ASSIGN(_imapHostField, [udSource objectForKey:  @"IMAPHostFieldName"]);
  ASSIGN(_kindField, [udSource objectForKey: @"KindFieldName"]);
  ASSIGN(_multipleBookingsField, [udSource objectForKey: @"MultipleBookingsFieldName"]);
  ASSIGN(_domainField, [udSource objectForKey: @"DomainFieldName"]);
  if ([udSource objectForKey: @"prependPasswordScheme"])
    _prependPasswordScheme = [[udSource objectForKey: @"prependPasswordScheme"] boolValue];
  else
    _prependPasswordScheme = NO;
  
  if (!_userPasswordAlgorithm)
    _userPasswordAlgorithm = @"none";

  if ([udSource objectForKey: @"viewURL"])
    _viewURL = [[NSURL alloc] initWithString: [udSource objectForKey: @"viewURL"]];

#warning this domain code has no effect yet
  if ([sourceDomain length])
    ASSIGN (_domain, sourceDomain);

  if (!_viewURL)
    {
      [self autorelease];
      return nil;
    }

  return self;
}

- (NSString *) domain
{
  return _domain;
}

- (BOOL) _isPassword: (NSString *) plainPassword
             equalTo: (NSString *) encryptedPassword
{
  if (!plainPassword || !encryptedPassword)
    return NO;

  return [plainPassword isEqualToCrypted: encryptedPassword
                       withDefaultScheme: _userPasswordAlgorithm];
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
  NSString* result;
  
  pass = [plainPassword asCryptedPassUsingScheme: _userPasswordAlgorithm];

  if (pass == nil)
    [self errorWithFormat: @"Unsupported user-password algorithm: %@", _userPasswordAlgorithm];

  if (_prependPasswordScheme)
    result = [NSString stringWithFormat: @"{%@}%@", _userPasswordAlgorithm, pass];
  else
    result = pass;

  return result;
}

//
// SQL sources don't support right now all the password policy
// stuff supported by OpenLDAP (and others). If we want to support
// this for SQL sources, we'll have to implement the same
// kind of logic in this module.
//
- (BOOL) checkLogin: (NSString *) _login
	   password: (NSString *) _pwd
	       perr: (SOGoPasswordPolicyError *) _perr
	     expire: (int *) _expire
	      grace: (int *) _grace
{
  EOAdaptorChannel *channel;
  EOQualifier *qualifier;
  GCSChannelManager *cm;
  NSException *ex;
  NSMutableString *sql;
  BOOL rc;

  rc = NO;

  _login = [_login stringByReplacingString: @"'"  withString: @"''"];
  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: _viewURL];
  if (channel)
    {
      if (_loginFields)
        {
          NSMutableArray *qualifiers;
          NSString *field;
          EOQualifier *loginQualifier;
          int i;

          qualifiers = [NSMutableArray arrayWithCapacity: [_loginFields count]];
          for (i = 0; i < [_loginFields count]; i++)
            {
              field = [_loginFields objectAtIndex: i];
              loginQualifier = [[EOKeyValueQualifier alloc] initWithKey: field
                                              operatorSelector: EOQualifierOperatorEqual
                                                         value: _login];
              [loginQualifier autorelease];
              [qualifiers addObject: loginQualifier];
            }
          qualifier = [[EOOrQualifier alloc] initWithQualifierArray: qualifiers];
        }
      else
        {
          qualifier = [[EOKeyValueQualifier alloc] initWithKey: @"c_uid"
                                              operatorSelector: EOQualifierOperatorEqual
                                                         value: _login];
        }
      [qualifier autorelease];
      sql = [NSMutableString stringWithFormat: @"SELECT c_password"
                             @" FROM %@"
                             @" WHERE ",
                             [_viewURL gcsTableName]];
      if (_authenticationFilter)
        {          
          qualifier = [[EOAndQualifier alloc] initWithQualifiers:
                                                qualifier,
                       [EOQualifier qualifierWithQualifierFormat: _authenticationFilter],
                                              nil];
          [qualifier autorelease];
        }
      [qualifier _gcsAppendToString: sql];
      
      ex = [channel evaluateExpressionX: sql];
      if (!ex)
        {
          NSDictionary *row;
          NSArray *attrs;
          NSString *value;
          
          attrs = [channel describeResults: NO];
          row = [channel fetchAttributes: attrs  withZone: NULL];
          value = [row objectForKey: @"c_password"];
      
          rc = [self _isPassword: _pwd  equalTo: value];
	  [channel cancelFetch];
        }
      else
        [self errorWithFormat: @"could not run SQL '%@': %@", qualifier, ex];

      [cm releaseChannel: channel];
    }
  else
    [self errorWithFormat:@"failed to acquire channel for URL: %@",
          [_viewURL absoluteString]];

  return rc;
}

/**
 * Change a user's password.
 * @param login the user's login name.
 * @param oldPassword the previous password.
 * @param newPassword the new password.
 * @param perr is not used.
 * @return YES if the password was successfully changed.
 */
- (BOOL) changePasswordForLogin: (NSString *) login
		    oldPassword: (NSString *) oldPassword
		    newPassword: (NSString *) newPassword
			   perr: (SOGoPasswordPolicyError *) perr
{
  EOAdaptorChannel *channel;
  GCSChannelManager *cm;
  NSException *ex;
  NSString *sqlstr;
  BOOL didChange;
  BOOL isOldPwdOk;
  
  isOldPwdOk = NO;
  didChange = NO;
  
  // Verify current password
  isOldPwdOk = [self checkLogin:login password:oldPassword perr:perr expire:0 grace:0];
  
  if (isOldPwdOk)
    {
      // Encrypt new password
      NSString *encryptedPassword = [self _encryptPassword: newPassword];
      
      // Save new password
      login = [login stringByReplacingString: @"'"  withString: @"''"];
      cm = [GCSChannelManager defaultChannelManager];
      channel = [cm acquireOpenChannelForURL: _viewURL];
      if (channel)
	{
	  sqlstr = [NSString stringWithFormat: (@"UPDATE %@"
						@" SET c_password = '%@'"
						@" WHERE c_uid = '%@'"),
			     [_viewURL gcsTableName], encryptedPassword, login];
	  
	  ex = [channel evaluateExpressionX: sqlstr];
	  if (!ex)
	    {
	      didChange = YES;
	    }
	  else
	    {
	      [self errorWithFormat: @"could not run SQL '%@': %@", sqlstr, ex];
	    }
	  [cm releaseChannel: channel];
	}
    }
  
  return didChange;
}

- (NSString *) _whereClauseFromArray: (NSArray *) theArray
                               value: (NSString *) theValue
			       exact: (BOOL) theBOOL
{
  NSMutableString *s;
  int i;

  s = [NSMutableString string];

  for (i = 0; i < [theArray count]; i++)
    {
      if (theBOOL)
	[s appendFormat: @" OR LOWER(%@) = '%@'", [theArray objectAtIndex: i], theValue];
      else
	[s appendFormat: @" OR LOWER(%@) LIKE '%%%@%%'", [theArray objectAtIndex: i], theValue];
    }

  return s;
}

- (NSDictionary *) _lookupContactEntry: (NSString *) theID
                         considerEmail: (BOOL) b
                              inDomain: (NSString *) domain
{
  NSMutableDictionary *response;
  NSMutableArray *qualifiers;
  NSArray *fieldNames;
  EOAdaptorChannel *channel;
  EOQualifier *loginQualifier, *domainQualifier, *qualifier;
  GCSChannelManager *cm;
  NSMutableString *sql;
  NSString *value, *field;
  NSException *ex;
  int i;

  response = nil;

  theID = [theID stringByReplacingString: @"'"  withString: @"''"];
  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: _viewURL];
  if (channel)
    {
      qualifiers = [NSMutableArray arrayWithCapacity: [_loginFields count] + 1];

      // Always compare against the c_uid field
      loginQualifier = [[EOKeyValueQualifier alloc] initWithKey: @"c_uid"
                                               operatorSelector: EOQualifierOperatorEqual
                                                          value: theID];
      [loginQualifier autorelease];
      [qualifiers addObject: loginQualifier];

      if (_loginFields)
        {
          for (i = 0; i < [_loginFields count]; i++)
            {
              field = [_loginFields objectAtIndex: i];
              if ([field caseInsensitiveCompare: @"c_uid"] != NSOrderedSame)
                {
                  loginQualifier = [[EOKeyValueQualifier alloc] initWithKey: field
                                                           operatorSelector: EOQualifierOperatorEqual
                                                                      value: theID];
                  [loginQualifier autorelease];
                  [qualifiers addObject: loginQualifier];
                }
            }
        }
      
      domainQualifier = nil;
      if (_domainField && domain)
        {
          domainQualifier = [[EOKeyValueQualifier alloc] initWithKey: _domainField
                                                    operatorSelector: EOQualifierOperatorEqual
                                                               value: domain];
          [domainQualifier autorelease];
        }

      if (b)
        {
          // Always compare againts the mail field
          loginQualifier = [[EOKeyValueQualifier alloc] initWithKey: @"mail"
                                                   operatorSelector: EOQualifierOperatorEqual
                                                              value: [theID lowercaseString]];
          [loginQualifier autorelease];
          [qualifiers addObject: loginQualifier];
          
	  if (_mailFields)
	    {
              for (i = 0; i < [_mailFields count]; i++)
                {
                  field = [_mailFields objectAtIndex: i];
                  if ([field caseInsensitiveCompare: @"mail"] != NSOrderedSame
                      && ![_loginFields containsObject: field])
                    {
                      loginQualifier = [[EOKeyValueQualifier alloc] initWithKey: field
                                                               operatorSelector: EOQualifierOperatorEqual
                                                                          value: [theID lowercaseString]];
                      [loginQualifier autorelease];
                      [qualifiers addObject: loginQualifier];
                    }
                }
            }
	}
      
      sql = [NSMutableString stringWithFormat: @"SELECT *"
                             @" FROM %@"
                             @" WHERE ",
                             [_viewURL gcsTableName]];
      qualifier = [[EOOrQualifier alloc] initWithQualifierArray: qualifiers];
      if (domainQualifier)
        qualifier = [[EOAndQualifier alloc] initWithQualifiers: domainQualifier, qualifier, nil];
      [qualifier _gcsAppendToString: sql];

      ex = [channel evaluateExpressionX: sql];
      if (!ex)
        {
	  NSMutableArray *emails;

          response = [[channel fetchAttributes: [channel describeResults: NO]
                                      withZone: NULL] mutableCopy];
          [response autorelease];
	  [channel cancelFetch];

          /* Convert all c_ fields to obtain their ldif equivalent */
          fieldNames = [response allKeys];
          for (i = 0; i < [fieldNames count]; i++)
            {
              field = [fieldNames objectAtIndex: i];
              if ([field hasPrefix: @"c_"])
                [response setObject: [response objectForKey: field]
                             forKey: [field substringFromIndex: 2]];
            }

          // We have to do this here since we do not manage modules
          // constraints right now over a SQL backend.
          [response setObject: [NSNumber numberWithBool: YES] forKey: @"CalendarAccess"];
          [response setObject: [NSNumber numberWithBool: YES] forKey: @"MailAccess"];

	  // We set the domain, if any
          value = nil;
	  if (_domain)
	    value = _domain;
	  else if (_domainField)
            value = [response objectForKey: _domainField];
          if (![value isNotNull])
	    value = @"";
	  [response setObject: value forKey: @"c_domain"];

	  // We populate all mail fields
	  emails = [NSMutableArray array];
	  
	  if ([response objectForKey: @"mail"])
	    [emails addObject: [response objectForKey: @"mail"]];

	  if (_mailFields && [_mailFields count] > 0)
	    {
	      NSString *s;
	      int i;

	      for (i = 0; i < [_mailFields count]; i++)
		if ((s = [response objectForKey: [_mailFields objectAtIndex: i]]) &&
		    [[s stringByTrimmingSpaces] length] > 0)
		  [emails addObject: s];
	    }
	  
	  [response setObject: emails  forKey: @"c_emails"];
          if (_imapHostField)
            {
              value = [response objectForKey: _imapHostField];
              if ([value isNotNull])
                [response setObject: value forKey: @"c_imaphostname"];
            }

          // We check if the user can authenticate
          if (_authenticationFilter)
            {
              EOQualifier *q_uid, *q_auth;

              sql = [NSMutableString stringWithFormat: @"SELECT c_uid"
                                     @" FROM %@"
                                     @" WHERE ",
                                     [_viewURL gcsTableName]];

              q_auth = [EOQualifier qualifierWithQualifierFormat: _authenticationFilter];

              q_uid = [[EOKeyValueQualifier alloc] initWithKey: @"c_uid"
                                              operatorSelector: EOQualifierOperatorEqual
                                                         value: theID];
              [q_uid autorelease];

              qualifier = [[EOAndQualifier alloc] initWithQualifiers: q_uid, q_auth, nil];
              [qualifier autorelease];
              [qualifier _gcsAppendToString: sql];

              ex = [channel evaluateExpressionX: sql];
              if (!ex)
                {
                  NSDictionary *authResponse;

                  authResponse = [channel fetchAttributes: [channel describeResults: NO]  withZone: NULL];
                  [response setObject: [NSNumber numberWithBool: [authResponse count] > 0] forKey: @"canAuthenticate"];
                  [channel cancelFetch];
                }
              else
                [self errorWithFormat: @"could not run SQL '%@': %@", sql, ex];
            }
          else
            [response setObject: [NSNumber numberWithBool: YES] forKey: @"canAuthenticate"];
        
          // We check if we should use a different login for IMAP
          if (_imapLoginField)
            {
              if ([[response objectForKey: _imapLoginField] isNotNull])
                [response setObject: [response objectForKey: _imapLoginField] forKey: @"c_imaplogin"];
            }

	  // We check if it's a resource of not
	  if (_kindField)
	    {	      
	      if ((value = [response objectForKey: _kindField]) && [value isNotNull])
		{
		  if ([value caseInsensitiveCompare: @"location"] == NSOrderedSame ||
		      [value caseInsensitiveCompare: @"thing"] == NSOrderedSame ||
		      [value caseInsensitiveCompare: @"group"] == NSOrderedSame) 
		    {
		      [response setObject: [NSNumber numberWithInt: 1]
				forKey: @"isResource"];
		    }
		}
	    }

	  if (_multipleBookingsField)
	    {
	      if ((value = [response objectForKey: _multipleBookingsField]))
		{
		  [response setObject: [NSNumber numberWithInt: [value intValue]]
			    forKey: @"numberOfSimultaneousBookings"];
		}
	    }

          [response setObject: self forKey: @"source"];
        }
      else
        [self errorWithFormat: @"could not run SQL '%@': %@", sql, ex];
      [cm releaseChannel: channel];
    }
  else
    [self errorWithFormat:@"failed to acquire channel for URL: %@",
          [_viewURL absoluteString]];

  return response;
}


- (NSDictionary *) lookupContactEntry: (NSString *) theID
{
  return [self _lookupContactEntry: theID  considerEmail: NO inDomain: nil];
}

- (NSDictionary *) lookupContactEntryWithUIDorEmail: (NSString *) entryID
                                           inDomain: (NSString *) domain
{
  return [self _lookupContactEntry: entryID  considerEmail: YES inDomain: domain];
}

- (NSArray *) allEntryIDs
{
  EOAdaptorChannel *channel;
  NSMutableArray *results;
  GCSChannelManager *cm;
  NSException *ex;
  NSString *sql;
  
  results = [NSMutableArray array];

  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: _viewURL];
  if (channel)
    {
      sql = [NSString stringWithFormat: @"SELECT c_uid FROM %@",
                      [_viewURL gcsTableName]];

      ex = [channel evaluateExpressionX: sql];
      if (!ex)
        {
          NSDictionary *row;
          NSArray *attrs;
          NSString *value;

          attrs = [channel describeResults: NO];
          
          while ((row = [channel fetchAttributes: attrs withZone: NULL]))
            {
              value = [row objectForKey: @"c_uid"];
              if (value)
                [results addObject: value];
            }
        }
      else
        [self errorWithFormat: @"could not run SQL '%@': %@", sql, ex];
      [cm releaseChannel: channel];
    }
  else
    [self errorWithFormat:@"failed to acquire channel for URL: %@",
          [_viewURL absoluteString]];

  
  return results;
}

- (NSArray *) fetchContactsMatching: (NSString *) filter
                           inDomain: (NSString *) domain
{
  EOAdaptorChannel *channel;
  NSMutableArray *results;
  GCSChannelManager *cm;
  NSException *ex;
  NSMutableString *sql;
  NSString *lowerFilter;
  
  results = [NSMutableArray array];

  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: _viewURL];
  if (channel)
    {
      lowerFilter = [filter lowercaseString];
      lowerFilter = [lowerFilter stringByReplacingString: @"'"  withString: @"''"];

      sql = [NSMutableString stringWithFormat: (@"SELECT *"
                                         @" FROM %@"
                                         @" WHERE"
                                         @" (LOWER(c_cn) LIKE '%%%@%%'"
                                         @" OR LOWER(mail) LIKE '%%%@%%'"),
                      [_viewURL gcsTableName],
                      lowerFilter, lowerFilter];
      
      if (_mailFields && [_mailFields count] > 0)
	{
	  [sql appendString: [self _whereClauseFromArray: _mailFields  value: lowerFilter  exact: NO]];
	}

      [sql appendString: @")"];

      if (_domainField)
        {
          if ([domain length])
            [sql appendFormat: @" AND %@ = '%@'", _domainField, domain];
          else
            [sql appendFormat: @" AND %@ IS NULL", _domainField];
        }

      ex = [channel evaluateExpressionX: sql];
      if (!ex)
        {
          NSDictionary *row;
          NSArray *attrs;

          attrs = [channel describeResults: NO];

          while ((row = [channel fetchAttributes: attrs withZone: NULL]))
            {
              row = [row mutableCopy];
              [(NSMutableDictionary *) row setObject: self forKey: @"source"];
              [results addObject: row];
              [row release];
            }
        }
      else
        [self errorWithFormat: @"could not run SQL '%@': %@", sql, ex];
      [cm releaseChannel: channel];
    }
  else
    [self errorWithFormat:@"failed to acquire channel for URL: %@",
          [_viewURL absoluteString]];
  
  return results;
}

- (void) setSourceID: (NSString *) newSourceID
{
}

- (NSString *) sourceID
{
  return _sourceID;
}

- (void) setDisplayName: (NSString *) newDisplayName
{
}

- (NSString *) displayName
{
  /* This method is only used when supporting user "source" addressbooks,
     which is only supported by the LDAP backend for now. */
  return _sourceID;
}

- (void) setListRequiresDot: (BOOL) newListRequiresDot
{
}

- (BOOL) listRequiresDot
{
  /* This method is not implemented for SQLSource. It must enable a mechanism
     where using "." is not required to list the content of addressbooks. */
  return YES;
}

/* card editing */
- (void) setModifiers: (NSArray *) newModifiers
{
}

- (NSArray *) modifiers
{
  /* This method is only used when supporting card editing,
     which is only supported by the LDAP backend for now. */
  return nil;
}

- (NSException *) addContactEntry: (NSDictionary *) roLdifRecord
                           withID: (NSString *) aId
{
  NSString *reason;

  reason = [NSString stringWithFormat: @"method '%@' is not available"
                     @" for class '%@'", NSStringFromSelector (_cmd),
                     NSStringFromClass (isa)];

  return [NSException exceptionWithName: @"SQLSourceIOException"
                                 reason: reason
                               userInfo: nil];
}

- (NSException *) updateContactEntry: (NSDictionary *) roLdifRecord
{
  NSString *reason;

  reason = [NSString stringWithFormat: @"method '%@' is not available"
                     @" for class '%@'", NSStringFromSelector (_cmd),
                     NSStringFromClass (isa)];

  return [NSException exceptionWithName: @"SQLSourceIOException"
                                 reason: reason
                               userInfo: nil];
}

- (NSException *) removeContactEntryWithID: (NSString *) aId
{
  NSString *reason;

  reason = [NSString stringWithFormat: @"method '%@' is not available"
                     @" for class '%@'", NSStringFromSelector (_cmd),
                     NSStringFromClass (isa)];

  return [NSException exceptionWithName: @"SQLSourceIOException"
                                 reason: reason
                               userInfo: nil];
}

/* user addressbooks */
- (BOOL) hasUserAddressBooks
{
  return NO;
}

- (NSArray *) addressBookSourcesForUser: (NSString *) user
{
  return nil;
}

- (NSException *) addAddressBookSource: (NSString *) newId
                       withDisplayName: (NSString *) newDisplayName
                               forUser: (NSString *) user
{
  NSString *reason;

  reason = [NSString stringWithFormat: @"method '%@' is not available"
                     @" for class '%@'", NSStringFromSelector (_cmd),
                     NSStringFromClass (isa)];

  return [NSException exceptionWithName: @"SQLSourceIOException"
                                 reason: reason
                               userInfo: nil];
}

- (NSException *) renameAddressBookSource: (NSString *) newId
                          withDisplayName: (NSString *) newDisplayName
                                  forUser: (NSString *) user
{
  NSString *reason;

  reason = [NSString stringWithFormat: @"method '%@' is not available"
                     @" for class '%@'", NSStringFromSelector (_cmd),
                     NSStringFromClass (isa)];

  return [NSException exceptionWithName: @"SQLSourceIOException"
                                 reason: reason
                               userInfo: nil];
}

- (NSException *) removeAddressBookSource: (NSString *) newId
                                  forUser: (NSString *) user
{
  NSString *reason;

  reason = [NSString stringWithFormat: @"method '%@' is not available"
                     @" for class '%@'", NSStringFromSelector (_cmd),
                     NSStringFromClass (isa)];

  return [NSException exceptionWithName: @"SQLSourceIOException"
                                 reason: reason
                               userInfo: nil];
}

@end
