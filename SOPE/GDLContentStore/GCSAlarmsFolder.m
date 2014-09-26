/* GCSAlarmsFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2014 Inverse inc.
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSNull+misc.h>

#import <GDLAccess/EOAdaptorChannel.h>
#import <GDLAccess/EOAdaptorContext.h>
#import <GDLAccess/EOAttribute.h>
#import <GDLAccess/EOEntity.h>
#import <GDLAccess/EOSQLQualifier.h>

#import "EOQualifier+GCS.h"
#import "GCSChannelManager.h"
#import "GCSFolderManager.h"
#import "GCSSpecialQueries.h"
#import "GCSStringFormatter.h"
#import "NSURL+GCS.h"

#import "GCSAlarmsFolder.h"

static NSString *alarmsFolderURLString = nil;

#warning GCSAlarmsFolder should share a common ancestor with GCSFolder

@implementation GCSAlarmsFolder

+ (void) initialize
{
  NSUserDefaults *ud;

  if (!alarmsFolderURLString)
    {
      ud = [NSUserDefaults standardUserDefaults];
      ASSIGN (alarmsFolderURLString,
              [ud stringForKey: @"OCSEMailAlarmsFolderURL"]);
    }
}

+ (id) alarmsFolderWithFolderManager: (GCSFolderManager *) newFolderManager
{
  GCSAlarmsFolder *newFolder;

  if (alarmsFolderURLString)
    {
      newFolder = [self new];
      [newFolder autorelease];
      [newFolder setFolderManager: newFolderManager];
    }
  else
    {
      [self errorWithFormat: @"'OCSEMailAlarmsFolderURL' is not set"];
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

  if (alarmsFolderURLString)
    location = [NSURL URLWithString: alarmsFolderURLString];
  else
    {
      [self warnWithFormat: @"'OCSEMailAlarmsFolderURL' is not set"];
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
  NSString *columns[] = { @"c_path", @"c_name", @"c_uid",
                          @"c_recurrence_id", @"c_alarm_number",
                          @"c_alarm_date", nil };
  NSString **column;
  NSMutableArray *keys;
  NSDictionary *types;
  
  if (!entity)
    {
      entity = [EOEntity new];
      tableName = [self _storeTableName];
      [entity setName: tableName];
      [entity setExternalName: tableName];

      types = [[tc specialQueries] emailAlarmsAttributeTypes];

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

      keys = [NSMutableArray arrayWithCapacity: 2];
      [keys addObject: [entity attributeNamed: @"c_path"]];
      [keys addObject: [entity attributeNamed: @"c_name"]];
      [entity setPrimaryKeyAttributes: keys];

      keys = [NSMutableArray arrayWithCapacity: 3];
      [keys addObject: [entity attributeNamed: @"c_uid"]];
      [keys addObject: [entity attributeNamed: @"c_recurrence_id"]];
      [keys addObject: [entity attributeNamed: @"c_alarm_number"]];
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
  [[self _channelManager] releaseChannel:_channel];
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

  sql = [NSString stringWithFormat: @"SELECT count(*) FROM %@",
                  [self _storeTableName]];
  if ([tc evaluateExpressionX: sql])
    {
      sql = [queries createEMailAlarmsFolderWithName: tableName];
      if (![tc evaluateExpressionX: sql])
	[self logWithFormat:
                @"email alarms folder table '%@' successfully created!",
              tableName];
    }
  else
    [tc cancelFetch];

  [self _releaseChannel: tc];
}

/* operations */

/* table has the following fields:
     c_path VARCHAR(255) NOT NULL
     c_name VARCHAR(255) NOT NULLo
     c_uid VARCHAR(255) NOT NULL
     c_recurrence_id INT NULL
     c_alarm_number INT NOT NULL
*/

- (NSDictionary *) recordForEntryWithCName: (NSString *) cname
                          inCalendarAtPath: (NSString *) path
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
                                            @"c_path='%@' AND c_name='%@'",
                                          path, cname];
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

- (NSArray *) recordsForEntriesFromDate: (NSCalendarDate *) fromDate
                                 toDate: (NSCalendarDate *) toDate
{
  EOAdaptorChannel *tc;
  EOAdaptorContext *context;
  NSException *error;
  NSArray *attrs;
  NSDictionary *record;
  EOEntity *entity;
  EOSQLQualifier *qualifier;
  NSMutableArray *records;

  records = nil;

  tc = [self _acquireStoreChannel];
  if (tc)
    {
      context = [tc adaptorContext];
      entity = [self _storeTableEntityForChannel: tc];
      qualifier
        = [[EOSQLQualifier alloc] initWithEntity: entity
                                 qualifierFormat:
                                    @"c_alarm_date >= %d AND c_alarm_date <= %d",
                                  (int) [fromDate timeIntervalSince1970],
                                  (int) [toDate timeIntervalSince1970]];
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
          records = [NSMutableArray array];
	  attrs = [tc describeResults: NO];
          while ((record = [tc fetchAttributes: attrs withZone: NULL]))
            [records addObject: record];
        }
      [context rollbackTransaction];
      [self _releaseChannel: tc];
    }

  return records;
}

- (NSDictionary *) _newRecordWithCName: (NSString *) cname
                      inCalendarAtPath: (NSString *) path
                                forUID: (NSString *) uid
                          recurrenceId: (NSCalendarDate *) recId
                           alarmNumber: (NSNumber *) alarmNbr
                          andAlarmDate: (NSCalendarDate *) alarmDate
{
  NSNumber *tRecId, *tADate;

  // We check if recId and alarmDate are nil prior calling -timeIntervalSince1970
  // Weird gcc optimizations can cause issue here.
  tRecId = [NSNumber numberWithInt: (recId ? (int)[recId timeIntervalSince1970] : 0)];
  tADate = [NSNumber numberWithInt: (alarmDate ? (int)[alarmDate timeIntervalSince1970] : 0)];

  return [NSDictionary dictionaryWithObjectsAndKeys: cname, @"c_name",
                       path, @"c_path",
                       uid, @"c_uid",
                       tRecId, @"c_recurrence_id",
                       alarmNbr, @"c_alarm_number",
                       tADate, @"c_alarm_date",
                       nil];
}

- (void) writeRecordForEntryWithCName: (NSString *) cname
                     inCalendarAtPath: (NSString *) path
                               forUID: (NSString *) uid
                         recurrenceId: (NSCalendarDate *) recId
                          alarmNumber: (NSNumber *) alarmNbr
                         andAlarmDate: (NSCalendarDate *) alarmDate
{
  NSDictionary *record, *newRecord;
  NSException *error;
  EOAdaptorChannel *tc;
  EOAdaptorContext *context;
  EOEntity *entity;
  EOSQLQualifier *qualifier;

  tc = [self _acquireStoreChannel];
  if (tc)
    {
      context = [tc adaptorContext];
      newRecord = [self _newRecordWithCName: cname
                           inCalendarAtPath: path
                                     forUID: uid
                               recurrenceId: recId
                                alarmNumber: alarmNbr
                               andAlarmDate: alarmDate];
      record = [self recordForEntryWithCName: cname
                            inCalendarAtPath: path];
      entity = [self _storeTableEntityForChannel: tc];
      [context beginTransaction];
      if (record)
        {
          qualifier = [[EOSQLQualifier alloc] initWithEntity: entity
                                             qualifierFormat:
                                                @"c_path='%@' AND c_name='%@'",
                                              path, cname];
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
}

- (void) deleteRecordForEntryWithCName: (NSString *) cname
                      inCalendarAtPath: (NSString *) path
{
  EOAdaptorChannel *tc;
  EOAdaptorContext *context;
  EOEntity *entity;
  EOSQLQualifier *qualifier;
  NSException *error;

  tc = [self _acquireStoreChannel];
  if (tc)
    {
      context = [tc adaptorContext];
      entity = [self _storeTableEntityForChannel: tc];
      qualifier = [[EOSQLQualifier alloc] initWithEntity: entity
                                         qualifierFormat:
                                            @"c_path='%@' AND c_name='%@'",
                                          path, cname];
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
}

- (void) deleteRecordsForEntriesUntilDate: (NSCalendarDate *) date
{
  EOAdaptorChannel *tc;
  EOAdaptorContext *context;
  EOEntity *entity;
  EOSQLQualifier *qualifier;
  NSException *error;

  tc = [self _acquireStoreChannel];
  if (tc)
    {
      context = [tc adaptorContext];
      entity = [self _storeTableEntityForChannel: tc];
      qualifier = [[EOSQLQualifier alloc] initWithEntity: entity
                                         qualifierFormat:
                                            @"c_alarm_date <= %d",
                                          (int) [date timeIntervalSince1970]];
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
}

@end
