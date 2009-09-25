/* SQLSource.h - this file is part of SOGo
 *
 * Copyright (C) 2009 Inverse inc.
 *
 * Author: Ludovic Marcotte <lmarcotte@inverse.ca>
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
#import <Foundation/NSObject.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSURL.h>

#import <NGExtensions/NSObject+Logs.h>

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/NSURL+GCS.h>
#import <GDLAccess/EOAdaptorChannel.h>
#import <GDLAccess/EOAdaptorContext.h>
#import <GDLAccess/EOAttribute.h>

#include <openssl/evp.h>
#include <openssl/md5.h>

#include "SQLSource.h"

/**
 * The view MUST contain the following columns:
 *
 * c_uid      - will be used for authentication - it's a username or username@domain.tld)
 * c_name     - which can be identical to c_uid - will be used to uniquely identify entries)
 * c_password - password of the user, plain-text or md5 encoded for now
 * c_cn       - the user's common name
 * mail       - hte user's mail address
 *
 * Other columns can be defined - see LDAPSource.m for the complete list.
 *
 *
 * A SQL source can be defined like this:
 *
 *  {   
 *    id = zot;
 *    type = sql;
 *    viewURL = "http://sogo:sogo@127.0.0.1:5432/sogo/sogo_view";
 *    canAuthenticate = YES;
 *    isAddressBook = YES;
 *    userPasswordAlgorithm = md5;
 *  }
 *
 */

@implementation SQLSource

+ (id) sourceFromUDSource: (NSDictionary *) udSource
{
  return [[[self alloc] initFromUDSource: udSource] autorelease];
}

- (id) init
{
  if ((self = [super init]))
    {
      _sourceID = nil;
      _mailFields = nil;
      _userPasswordAlgorithm = nil;
      _viewURL = nil;
    }

  return self;
}

- (void) dealloc
{
  [_sourceID release];
  [_mailFields release];
  [_userPasswordAlgorithm release];
  [_viewURL release];
   
  [super dealloc];
}

- (id) initFromUDSource: (NSDictionary *) udSource
{
  self = [self init];

  ASSIGN(_sourceID, [udSource objectForKey: @"id"]);
  ASSIGN(_mailFields, [udSource objectForKey: @"MailFieldNames"]);
  ASSIGN(_userPasswordAlgorithm, [udSource objectForKey: @"userPasswordAlgorithm"]);

  if (!_userPasswordAlgorithm)
    _userPasswordAlgorithm = @"none";

  if ([udSource objectForKey: @"viewURL"])
    _viewURL = [[NSURL alloc] initWithString: [udSource objectForKey: @"viewURL"]];
  
  if (!_viewURL)
    {
      [self autorelease];
      return nil;
    }

  return self;
}

- (BOOL) _isPassword: (NSString *) plainPassword
             equalTo: (NSString *) encryptedPassword
{
  if ([_userPasswordAlgorithm caseInsensitiveCompare: @"none"] == NSOrderedSame)
    {
      return [plainPassword isEqualToString: encryptedPassword];
    }
  else if ([_userPasswordAlgorithm caseInsensitiveCompare: @"md5"] == NSOrderedSame)
    {
      NSString *s;

      unsigned char md[MD5_DIGEST_LENGTH];
      char buf[80];
      int i;

      memset(md, 0, MD5_DIGEST_LENGTH);
      memset(buf, 0, 80);

      EVP_Digest([plainPassword UTF8String], strlen([plainPassword UTF8String]), md, NULL, EVP_md5(), NULL);
      for (i = 0; i < MD5_DIGEST_LENGTH; i++)
	sprintf(&(buf[i*2]), "%02x", md[i]);

      s = [NSString stringWithUTF8String: buf];
      return [s isEqualToString: encryptedPassword];
    }


  [self errorWithFormat: @"Unsupported user-password algorithm: %@", _userPasswordAlgorithm];

  return NO;
}

- (BOOL) checkLogin: (NSString *) login
	andPassword: (NSString *) password
{
  EOAdaptorChannel *channel;
  GCSChannelManager *cm;
  NSException *ex;
  NSString *sql;

  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: _viewURL];
  
  sql = [NSString stringWithFormat: (@"SELECT c_password"
				     @" FROM %@"
				     @" WHERE c_uid = '%@'"),
		  [_viewURL gcsTableName], login];

  ex = [channel evaluateExpressionX: sql];

  if (!ex)
    {
      NSDictionary *row;
      NSArray *attrs;
      NSString *value;

      attrs = [channel describeResults: NO];
      row = [channel fetchAttributes: attrs  withZone: NULL];
      value = [row objectForKey: @"c_password"];
      
      return [self _isPassword: password  equalTo: value];
    }
  else
    [self errorWithFormat: @"could not run SQL '%@': %@", sql, ex];

  return NO;
}

- (NSDictionary *) _lookupContactEntry: (NSString *) theID
                         considerEmail: (BOOL) b
{
  EOAdaptorChannel *channel;
  GCSChannelManager *cm;
  NSException *ex;
  NSString *sql;

  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: _viewURL];
  
  if (!b)
    sql = [NSString stringWithFormat: (@"SELECT *"
				       @" FROM %@"
				       @" WHERE c_uid = '%@'"),
		    [_viewURL gcsTableName], theID];
  else
    sql = [NSString stringWithFormat: (@"SELECT *"
				       @" FROM %@"
				       @" WHERE c_uid = '%@' OR"
				       @" LOWER(mail) = '%@'"),
		    [_viewURL gcsTableName], theID, [theID lowercaseString]];

  ex = [channel evaluateExpressionX: sql];

  if (!ex)
    {
      NSMutableDictionary *d;

      d = [NSMutableDictionary dictionaryWithDictionary: [channel fetchAttributes: 
								       [channel describeResults: NO]
								     withZone: NULL]];

      // We have to do this here since we do not manage modules constraints right
      // now over a SQL backend.
      [d setObject: [NSNumber numberWithBool: YES]  forKey: @"CalendarAccess"];
      [d setObject: [NSNumber numberWithBool: YES]  forKey: @"MailAccess"];

      return d;
    }
  else
    [self errorWithFormat: @"could not run SQL '%@': %@", sql, ex];

  return nil;
}


- (NSDictionary *) lookupContactEntry: (NSString *) theID
{
  return [self _lookupContactEntry: theID  considerEmail: NO];
}

- (NSDictionary *) lookupContactEntryWithUIDorEmail: (NSString *) entryID
{
  return [self _lookupContactEntry: entryID  considerEmail: YES];
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
  
  sql = [NSString stringWithFormat: (@"SELECT c_uid"
				     @"  FROM %@"),
		  [_viewURL gcsTableName]];

  ex = [channel evaluateExpressionX: sql];

  if (!ex)
    {
      NSDictionary *row;
      NSArray *attrs;
      NSString *value;

      attrs = [channel describeResults: NO];

      while ((row = [channel fetchAttributes: attrs  withZone: NULL]))
	{
	  value = [row objectForKey: @"c_uid"];
	  if (value)
	    [results addObject: value];
	}
    }
  else
    [self errorWithFormat: @"could not run SQL '%@': %@", sql, ex];
  
  return results;
}

- (NSArray *) fetchContactsMatching: (NSString *) filter
{
  EOAdaptorChannel *channel;
  NSMutableArray *results;
  GCSChannelManager *cm;
  NSException *ex;
  NSString *sql;
  
  results = [NSMutableArray array];

  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: _viewURL];
 
  sql = [NSString stringWithFormat: (@"SELECT *"
				     @" FROM %@"
				     @" WHERE LOWER(c_cn) LIKE '%%%@%%' OR LOWER(mail) LIKE '%%%@%%'"),
		  [_viewURL gcsTableName], [filter lowercaseString], [filter lowercaseString]];

  ex = [channel evaluateExpressionX: sql];

  if (!ex)
    {
      NSDictionary *row;
      NSArray *attrs;

      attrs = [channel describeResults: NO];

      while ((row = [channel fetchAttributes: attrs  withZone: NULL]))
	{
	  [results addObject: row];
	}
    }
  else
    [self errorWithFormat: @"could not run SQL '%@': %@", sql, ex];
  
  return results;
}

- (NSString *) sourceID
{
  return _sourceID;
}

@end
