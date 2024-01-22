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

#import "GCSAdminFolder.h"

static NSString *adminFolderURLString = nil;

#warning GCSAdminFolder should share a common ancestor with GCSFolder

@implementation GCSAdminFolder

+ (void) initialize
{
  NSUserDefaults *ud;

  if (!adminFolderURLString)
    {
      ud = [NSUserDefaults standardUserDefaults];
      ASSIGN (adminFolderURLString,
              [ud stringForKey: @"OCSAdminURL"]);
    }
}

+ (id) alarmsFolderWithFolderManager: (GCSFolderManager *) newFolderManager
{
  GCSAlarmsFolder *newFolder;

  if (adminFolderURLString)
    {
      newFolder = [self new];
      [newFolder autorelease];
      [newFolder setFolderManager: newFolderManager];
    }
  else
    {
      [self errorWithFormat: @"'OCSAdminURL' is not set"];
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

  if (adminFolderURLString)
    location = [NSURL URLWithString: adminFolderURLString];
  else
    {
      [self warnWithFormat: @"'OCSAdminURL' is not set"];
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
  NSString *columns[] = { @"c_key", @"c_content", nil };
  NSString **column;
  NSMutableArray *keys;
  NSDictionary *types;
  
  if (!entity)
    {
      entity = [EOEntity new];
      tableName = [self _storeTableName];
      [entity setName: tableName];
      [entity setExternalName: tableName];

      types = [[tc specialQueries] adminAttributeTypes];

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
      [keys addObject: [entity attributeNamed: @"c_key"]];
      [entity setPrimaryKeyAttributes: keys];

      keys = [NSMutableArray arrayWithCapacity: 1];
      [keys addObject: [entity attributeNamed: @"c_content"]];
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

  sql = [NSString stringWithFormat: @"SELECT 1 FROM %@ WHERE 1 = 2",
                  [self _storeTableName]];
  if ([tc evaluateExpressionX: sql])
    {
      sql = [queries createAdminFolderWithName: tableName];
      if (![tc evaluateExpressionX: sql])
	[self logWithFormat:
                @"admin folder table '%@' successfully created!",
              tableName];
    }
  else
    [tc cancelFetch];

  [self _releaseChannel: tc];
}

/* operations */

/* table has the following fields:
     c_key VARCHAR(255) NOT NULL
     c_content MEDIUMTEXT NOT NULL
*/

- (NSDictionary *) recordForEntryWithKey: (NSString *) key
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
      context = [tc adaptorContext];
      entity = [self _storeTableEntityForChannel: tc];
      qualifier = [[EOSQLQualifier alloc] initWithEntity: entity
                                         qualifierFormat:
                                            @"c_key='%@'",
                                          key];
      [qualifier autorelease];

      [context beginTransaction];
      error = [tc selectAttributesX: [entity attributesUsedForFetch]
               describedByQualifier: qualifier
                         fetchOrder: nil
                               lock: NO];
      if (error)
        [self errorWithFormat:@"%s: cannot execute fetch: %@", 
              __PRETTY_FUNCTION__, error];
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

- (NSString *) getMotd {
  NSDictionary *r;

  r = [self recordForEntryWithKey: @"motd"];
  if (r && [r objectForKey:@"c_content"]) {
    return [r objectForKey:@"c_content"];
  }

  return nil;
}

- (NSDictionary *) _newRecordWithKey: (NSString *) key
                      content: (NSString *) content
{
  return [NSDictionary dictionaryWithObjectsAndKeys: key, @"c_key",
                       content, @"c_content",
                       nil];
}

- (NSException *) writeMotd: (NSString *)motd
{
  NSDictionary *record, *newRecord;
  NSException *error;
  EOAdaptorChannel *tc;
  EOAdaptorContext *context;
  EOEntity *entity;
  EOSQLQualifier *qualifier;

  error = nil;
  tc = [self _acquireStoreChannel];
  if (tc)
    {
      context = [tc adaptorContext];
      newRecord = [self _newRecordWithKey: @"motd" content: motd];
      record = [self recordForEntryWithKey: @"motd"];
      entity = [self _storeTableEntityForChannel: tc];
      [context beginTransaction];
      if (record)
        {
          qualifier = [[EOSQLQualifier alloc] initWithEntity: entity
                                             qualifierFormat:
                                                @"c_key='motd'"];
          [qualifier autorelease];
          error = [tc updateRowX: newRecord describedByQualifier: qualifier];
        }
      else
        error = [tc insertRowX: newRecord forEntity: entity];
      if (error)
        {
          [context rollbackTransaction];
          [self errorWithFormat:@"%s: cannot write record: %@", 
                __PRETTY_FUNCTION__, error];
        }
      else
        [context commitTransaction];
      [self _releaseChannel: tc];
    }
  return error;
}

- (NSException *) deleteRecordForKey: (NSString *) key
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
                                         qualifierFormat:
                                            @"c_key='%@'",
                                          key];
      [qualifier autorelease];
      [context beginTransaction];
      error = [tc deleteRowsDescribedByQualifierX: qualifier];
      if (error)
        {
          [context rollbackTransaction];
          [self errorWithFormat:@"%s: cannot delete record: %@", 
                __PRETTY_FUNCTION__, error];
        }
      else
        [context commitTransaction];
      [self _releaseChannel: tc];
    }
  
  return error;
}

- (NSException *) deleteMotd
{
  return [self deleteRecordForKey:@"motd"];
}

@end
