/* GCSSessionsFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2011 Inverse inc.
 *
 * Author: Ludovic Marcotte  <lmarcotte@inverse.ca>
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

#import "GCSSessionsFolder.h"

static NSString *sessionsFolderURLString = nil;

#warning GCSSessionsFolder should share a common ancestor with GCSFolder

@implementation GCSSessionsFolder

+ (void) initialize
{
  NSUserDefaults *ud;

  if (!sessionsFolderURLString)
    {
      ud = [NSUserDefaults standardUserDefaults];
      ASSIGN(sessionsFolderURLString, [ud stringForKey: @"OCSSessionsFolderURL"]);
    }
}

+ (id) sessionsFolderWithFolderManager: (GCSFolderManager *) newFolderManager
{
  GCSSessionsFolder *newFolder;

  if (sessionsFolderURLString)
    {
      newFolder = [self new];
      [newFolder autorelease];
      [newFolder setFolderManager: newFolderManager];
    }
  else
    {
      [self errorWithFormat: @"'OCSSessionsFolderURL' is not set"];
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

  if (sessionsFolderURLString)
    location = [NSURL URLWithString: sessionsFolderURLString];
  else
    {
      [self warnWithFormat: @"'OCSSessionsFolderURL' is not set"];
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
  NSString *columns[] = { @"c_id", @"c_value", @"c_creationdate",
                          @"c_lastseen", nil };
  NSString **column;
  NSMutableArray *keys;
  NSDictionary *types;
  
  if (!entity)
    {
      entity = [EOEntity new];
      tableName = [self _storeTableName];
      [entity setName: tableName];
      [entity setExternalName: tableName];

      types = [[tc specialQueries] sessionsAttributeTypes];

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
      [keys addObject: [entity attributeNamed: @"c_id"]];
      [entity setPrimaryKeyAttributes: keys];

      keys = [NSMutableArray arrayWithCapacity: 3];
      [keys addObject: [entity attributeNamed: @"c_value"]];
      [keys addObject: [entity attributeNamed: @"c_creationdate"]];
      [keys addObject: [entity attributeNamed: @"c_lastseen"]];
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

  sql = [NSString stringWithFormat: @"SELECT count(*) FROM %@", tableName];
  if ([tc evaluateExpressionX: sql])
    {
      sql = [queries createSessionsFolderWithName: tableName];
      if (![tc evaluateExpressionX: sql])
	[self logWithFormat:
                @"sessions folder table '%@' successfully created!",
              tableName];
    }
  else
    [tc cancelFetch];

  [self _releaseChannel: tc];
}

/* operations */

- (NSDictionary *) recordForEntryWithID: (NSString *) theID
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
                                            @"c_id='%@'",
                                          theID];
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



- (NSDictionary *) _newRecordWithID: (NSString *) theID
			     value: (NSString *) theValue
		      creationDate: (NSCalendarDate *) theCreationDate
		      lastSeenDate: (NSCalendarDate *) theLastSeenDate
{
  NSNumber *cd, *ls;

  // We check if recId and alarmDate are nil prior calling -timeIntervalSince1970
  // Weird gcc optimizations can cause issue here.
  cd = [NSNumber numberWithInt: (theCreationDate ? (int)[theCreationDate timeIntervalSince1970] : 0)];
  ls = [NSNumber numberWithInt: (theLastSeenDate ? (int)[theLastSeenDate timeIntervalSince1970] : 0)];

  return [NSDictionary dictionaryWithObjectsAndKeys: theID, @"c_id",
                       theValue, @"c_value",
                       cd, @"c_creationdate",
                       ls, @"c_lastseen",
                       nil];
}

- (void) writeRecordForEntryWithID: (NSString *) theID
			     value: (NSString *) theValue
		      creationDate: (NSCalendarDate *) theCreationDate
		      lastSeenDate: (NSCalendarDate *) theLastSeenDate
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
      newRecord = [self _newRecordWithID: theID
			value: theValue
			creationDate: theCreationDate
			lastSeenDate: theLastSeenDate];
      record = [self recordForEntryWithID: theID];
      entity = [self _storeTableEntityForChannel: tc];
      [context beginTransaction];
      if (record)
        {
          qualifier = [[EOSQLQualifier alloc] initWithEntity: entity
                                             qualifierFormat:
                                                @"c_id='%@'",
                                              theID];
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

- (void) deleteRecordForEntryWithID: (NSString *) theID
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
                                            @"c_id='%@'",
                                          theID];
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
