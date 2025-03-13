/* GCSAdminFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2023 Alinto
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
#import <NGExtensions/NSNull+misc.h>

#import <GDLAccess/EOAdaptorContext.h>
#import <GDLAccess/EOAttribute.h>
#import <GDLAccess/EOEntity.h>
#import <GDLAccess/EOSQLQualifier.h>

#import "EOQualifier+GCS.h"
#import "GCSChannelManager.h"
#import "GCSFolderManager.h"
#import "GCSSpecialQueries.h"
#import "NSURL+GCS.h"

#import "GCSOpenIdFolder.h"

static NSString *openIdFolderURLString = nil;

#warning GCSOpenIdFolder should share a common ancestor with GCSFolder

@implementation GCSOpenIdFolder

+ (void) initialize
{
  NSUserDefaults *ud;

  if (!openIdFolderURLString)
  {
    ud = [NSUserDefaults standardUserDefaults];
    ASSIGN (openIdFolderURLString, [ud stringForKey: @"OCSOpenIdURL"]);
  }
}
  
+ (id) openIdFolderWithFolderManager: (GCSFolderManager *) newFolderManager
{
  GCSOpenIdFolder *newFolder;

  if (openIdFolderURLString)
    {
      newFolder = [self new];
      [newFolder autorelease];
      [newFolder setFolderManager: newFolderManager];
    }
  else
    {
      [self errorWithFormat: @"'OCSOpenIdURL' is not set"];
      newFolder = nil;
    }

  return newFolder;
}

- (void) setFolderManager: (GCSFolderManager *) newFolderManager
{
  ASSIGN (folderManager, newFolderManager);
}

/* accessors */

- (NSURL *) _location
{
  NSURL *location;

  if (openIdFolderURLString)
    location = [NSURL URLWithString: openIdFolderURLString];
  else
    {
      [self warnWithFormat: @"'OCSOpenIdURL' is not set"];
      location = nil;
    }

  return location;
}

- (GCSChannelManager *) _channelManager
{
  return [folderManager channelManager];
}

- (NSString *) _storeTableName
{
  return [[self _location] gcsTableName];
}

- (EOEntity *) _storeTableEntityForChannel: (EOAdaptorChannel *) tc
{
  static EOEntity *entity = nil;
  EOAttribute *attribute;
  NSString *tableName;
  NSString *columns[] = {@"c_user_session", @"c_old_session", @"c_session_started", @"c_refresh_token", @"c_access_token_expires_in", @"c_refresh_token_expires_in", nil };
  NSString **column;
  NSMutableArray *keys;
  NSDictionary *types;
  
  if (!entity)
    {
      entity = [EOEntity new];
      tableName = [self _storeTableName];
      [entity setName: tableName];
      [entity setExternalName: tableName];

      types = [[tc specialQueries] openIdAttributeTypes];

      column = columns;
      while (*column)
        {
          attribute = [EOAttribute new];
          [attribute setName: *column];
          [attribute setColumnName: *column];
          [attribute setExternalType: [types objectForKey: *column]];
          [entity addAttribute: attribute];
          [attribute release];
          column++;
        }

      keys = [NSMutableArray arrayWithCapacity: 1];
      [keys addObject: [entity attributeNamed: @"c_user_session"]];
      [entity setPrimaryKeyAttributes: keys];

      keys = [NSMutableArray arrayWithCapacity: 5];
      [keys addObject: [entity attributeNamed: @"c_old_session"]];
      [keys addObject: [entity attributeNamed: @"c_session_started"]];
      [keys addObject: [entity attributeNamed: @"c_refresh_token"]];
      [keys addObject: [entity attributeNamed: @"c_access_token_expires_in"]];
      [keys addObject: [entity attributeNamed: @"c_refresh_token_expires_in"]];
      [entity setClassProperties: keys];
      [entity setAttributesUsedForLocking: [NSArray array]];
    }

  return entity;
}

/* connection */

- (EOAdaptorChannel *) _acquireStoreChannel
{
  return [[self _channelManager] acquireOpenChannelForURL: [self _location]];
}

- (void) _releaseChannel: (EOAdaptorChannel *) _channel
{
  [[self _channelManager] releaseChannel:_channel  immediately: YES];
}

- (BOOL) canConnectStore
{
  return [[self _channelManager] canConnect:[self _location]];
}

- (void) createFolderIfNotExists
{
  EOAdaptorChannel *tc;
  NSString *sql, *tableName;
  GCSSpecialQueries *queries;

  tc = [self _acquireStoreChannel];
  tableName = [self _storeTableName];

  queries = [tc specialQueries];

  sql = [NSString stringWithFormat: @"SELECT 1 FROM %@ WHERE 1 = 2", tableName];
  if ([tc evaluateExpressionX: sql])
  {
    sql = [queries createOpenIdFolderWithName: tableName];
    if (![tc evaluateExpressionX: sql])
      [self logWithFormat: @"openid folder table '%@' successfully created!", tableName];
  }
  else
    [tc cancelFetch];

  [self _releaseChannel: tc];
}

/* operations */

/* table has the following fields:
    c_user_session              varchar(255)  NOT NULL,
    c_session_started           int(11)       NOT NULL,
    c_refresh_token             varchar(4096) DEFAULT '',
    c_access_token_expires_in    int(11)       NOT NULL,
    c_refresh_token_expires_in  int(11)       DEFAULT NULL,
*/

- (NSDictionary *) recordForSession: (NSString *) _user_session useOldSession: (BOOL) use_old_session
{
  EOAdaptorChannel *tc;
  EOAdaptorContext *context;
  NSException *error;
  NSArray *attrs;
  NSDictionary *record;
  EOEntity *entity;
  EOSQLQualifier *qualifier;

  record = nil;

  tc = [self _acquireStoreChannel];
  if (tc)
  {
    context   = [tc adaptorContext];
    entity    = [self _storeTableEntityForChannel: tc];
    if(!use_old_session)
      qualifier = [[EOSQLQualifier alloc] initWithEntity: entity
                                         qualifierFormat: @"c_user_session='%@'", _user_session];
    else
      qualifier = [[EOSQLQualifier alloc] initWithEntity: entity
                                         qualifierFormat: @"c_old_session='%@'", _user_session];
    [qualifier autorelease];

    [context beginTransaction];
    error = [tc selectAttributesX: [entity attributesUsedForFetch]
              describedByQualifier: qualifier
                        fetchOrder: nil
                              lock: NO];
    if (error)
      [self errorWithFormat:@"%s: cannot execute fetch: %@", __PRETTY_FUNCTION__, error];
    else
    {
      attrs = [tc describeResults: NO];
      record = [tc fetchAttributes: attrs withZone: NULL];
      [tc cancelFetch];
    }
    [context rollbackTransaction];
    [self _releaseChannel: tc];
  }

  return record;
}

- (NSString *) getRefreshToken: (NSString *) _user_session
{
  NSDictionary *r;

  r = [self recordForSession: _user_session useOldSession: NO];
  if (r && [r objectForKey:@"c_refresh_token"])
    return [r objectForKey:@"c_refresh_token"];

  return nil;
}

- (NSString *) getNewToken: (NSString *) _old_session
{
  NSDictionary *r;
  r = [self recordForSession: _old_session useOldSession: YES];
  if (r && [r objectForKey:@"c_user_session"])
    return [r objectForKey:@"c_user_session"];

  return nil;
}


- (NSException *) writeOpenIdSession: (NSString *) _user_session
                  withOldSession: (NSString *) _old_session
                  withRefreshToken: (NSString *) _refresh_token
                  withExpire: (NSNumber *) _expire
                  withRefreshExpire: (NSNumber *) _refresh_expire
{
  NSDictionary *record, *newRecord;
  NSException *error;
  NSCalendarDate *nowDate;
  int now, nowExpire, nowRefreshExpire;
  EOAdaptorChannel *tc;
  EOAdaptorContext *context;
  EOEntity *entity;
  EOSQLQualifier *qualifier;

  error = nil;
  tc = [self _acquireStoreChannel];
  if (tc)
  {
    context = [tc adaptorContext];

    nowDate = [NSCalendarDate date];
    now = (nowDate ? (int)[nowDate timeIntervalSince1970] : 0);
    nowExpire = now + [_expire intValue];
    if(_refresh_expire)
      nowRefreshExpire = now + [_refresh_expire intValue];
    else
      nowRefreshExpire = -1;
    if(!_old_session)
      _old_session = @"";

    newRecord = [NSDictionary dictionaryWithObjectsAndKeys: _user_session, @"c_user_session",
                      _old_session, @"c_old_session",
                      [NSNumber numberWithInt:now], @"c_session_started",
                      _refresh_token, @"c_refresh_token",
                      [NSNumber numberWithInt:nowExpire] , @"c_access_token_expires_in",
                      [NSNumber numberWithInt:nowRefreshExpire] , @"c_refresh_token_expires_in",
                      nil];
    record = [self recordForSession: _user_session useOldSession: NO];
    entity = [self _storeTableEntityForChannel: tc];
    [context beginTransaction];
    if (!record)
    {
      //If the session already exist no need to update it as it is unique
      error = [tc insertRowX: newRecord forEntity: entity];
    }
      
    if (error)
    {
      [context rollbackTransaction];
      [self errorWithFormat:@"%s: cannot write record: %@",  __PRETTY_FUNCTION__, error];
    }
    else
      [context commitTransaction];
    [self _releaseChannel: tc];
  }
  return error;
}

- (NSException *) deleteOpenIdSessionFor: (NSString *) _user_session
{
  EOAdaptorChannel *tc;
  EOAdaptorContext *context;
  EOEntity *entity;
  EOSQLQualifier *qualifier;
  NSException *error;

  error = nil;
  tc = [self _acquireStoreChannel];
  if (tc)
  {
    context = [tc adaptorContext];
    entity = [self _storeTableEntityForChannel: tc];
    qualifier = [[EOSQLQualifier alloc] initWithEntity: entity
                                        qualifierFormat: @"c_user_session='%@'",_user_session];
    [qualifier autorelease];
    [context beginTransaction];
    error = [tc deleteRowsDescribedByQualifierX: qualifier];
    if (error)
    {
      [context rollbackTransaction];
      [self errorWithFormat:@"%s: cannot delete record: %@", __PRETTY_FUNCTION__, error];
    }
    else
      [context commitTransaction];
    [self _releaseChannel: tc];
  }
  
  return error;
}

@end
