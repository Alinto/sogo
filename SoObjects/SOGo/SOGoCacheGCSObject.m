/* SOGoCacheGCSObject.m - this file is part of SOGo
 *
 * Copyright (C) 2012-2014 Inverse inc
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSPropertyList.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>
#import <GDLAccess/EOAdaptor.h>
#import <GDLAccess/EOAdaptorChannel.h>
#import <GDLAccess/EOAdaptorContext.h>
#import <GDLAccess/EOAttribute.h>
#import <GDLContentStore/GCSChannelManager.h>
#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <SOGo/SOGoCache.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUser.h>

#import "GCSSpecialQueries+SOGoCacheObject.h"
#import "SOGoCacheGCSFolder.h"
#import "BSONCodec.h"

#import "SOGoCacheGCSObject.h"

static EOAttribute *textColumn = nil;

@implementation SOGoCacheGCSObject 

+ (void) initialize
{
  NSDictionary *description;

  if (!textColumn)
    {
      /* TODO: this is a hack for providing an EOAttribute definition that is
         compatible with all the backends that we support. We should make use
         of EOModel instead. */
      description = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"c_textfield", @"columnName",
                                    @"VARCHAR", @"externalType",
                                  nil];
      textColumn = [EOAttribute attributeFromPropertyList: description];
      [textColumn retain];
    }
}

/*
    = (@"CREATE TABLE %@ (" 
       @" c_path VARCHAR(255) PRIMARY KEY,"
       @" c_parent_path VARCHAR(255),"
       @" c_type SMALLINT NOT NULL,"
       @" c_creationdate INT4 NOT NULL,"
       @" c_lastmodified INT4 NOT NULL,"
       @" c_version INT4 NOT NULL DEFAULT 0,"
       @" c_deleted SMALLINT NOT NULL DEFAULT 0,"
       @" c_content TEXT)");
*/
- (id) init
{
  if ((self = [super init]))
    {
      tableUrl = nil;
      initialized = NO;
      objectType = -1;
      deleted = NO;
      version = 0;
    }

  return self;
}

- (void) dealloc
{
  //NSLog(@"SOGoCacheGCSObject: -dealloc for name: %@", nameInContainer);
  [tableUrl release];
  [super dealloc];
}

+ (id) objectWithName: (NSString *) key  inContainer: (id) theContainer
{
  SOGoCache *cache;
  id o;

  cache = [SOGoCache sharedCache];
  o = [cache objectNamed: key  inContainer: theContainer];

  if (!o)
    {
      o = [super objectWithName: key  inContainer: theContainer];
      //NSLog(@"Caching object with key: %@", key);
      [cache registerObject: o withName: key inContainer: theContainer];
    }

  return o;
}

- (void) setTableUrl: (NSURL *) newTableUrl
{
  ASSIGN (tableUrl, newTableUrl);
}

- (NSURL *) tableUrl
{
  if (!tableUrl)
    {
      tableUrl = [container tableUrl];
      [tableUrl retain];
      if (!tableUrl)
        [NSException raise: @"SOGoCacheIOException"
                    format: @"table url is not set for object '%@'", self];
    }

  return tableUrl;
}

- (NSString *) tableName
{
  NSArray *parts;

  [self tableUrl];
  parts = [[tableUrl path] componentsSeparatedByString: @"/"];

  return [parts lastObject];
}

- (void) setupFromRecord: (NSDictionary *) record
{
  NSInteger intValue;
  NSString *propsValue;
  NSDictionary *newValues;

  objectType = [[record objectForKey: @"c_type"] intValue];
  intValue = [[record objectForKey: @"c_creationdate"] intValue];
  ASSIGN (creationDate,
          [NSCalendarDate
               dateWithTimeIntervalSince1970: (NSTimeInterval) intValue]);
  intValue = [[record objectForKey: @"c_lastmodified"] intValue];
  ASSIGN (lastModified,
          [NSCalendarDate
               dateWithTimeIntervalSince1970: (NSTimeInterval) intValue]);
  deleted = ([[record objectForKey: @"c_deleted"] intValue] > 0);
  version = [[record objectForKey: @"c_version"] intValue];
  propsValue = [record objectForKey: @"c_content"];
  if ([propsValue isNotNull])
    {
      newValues = [[propsValue dataByDecodingBase64] BSONValue];
      [properties addEntriesFromDictionary: newValues];
    }
  else
    [properties removeAllObjects];

  initialized = YES;
}

/* accessors */
- (NSMutableString *) path
{
  NSMutableString *path;

  if (container)
    path = [container pathForChild: nameInContainer];
  else
    path = [NSMutableString stringWithFormat: @"/%@", nameInContainer];

  if ([path rangeOfString: @"//"].location != NSNotFound)
    [NSException raise: @"SOGoCacheIOException"
                format: @"object path has not been properly set for"
                 " folder '%@' (%@)",
                 self, path];

  return path;
}

- (void) setObjectType: (SOGoCacheObjectType) newObjectType
{
  objectType = newObjectType;
}

- (SOGoCacheObjectType) objectType /* message, fai, folder */
{
  return objectType;
}

- (NSCalendarDate *) creationDate
{
  if (!initialized)
    [NSException raise: @"SOGoCacheIOException"
                format: @"record has not been initialized: %@", self];

  return creationDate;
}

- (NSCalendarDate *) lastModified
{
  if (!initialized)
    [NSException raise: @"SOGoCacheIOException"
                format: @"record has not been initialized: %@", self];

  return lastModified;
}

- (BOOL) deleted
{
  return deleted;
}

/* actions */
- (void) setNameInContainer: (NSString *) newNameInContainer
{
  NSMutableString *sql;
  NSString *oldPath, *newPath;

  if (nameInContainer)
    oldPath = [self path];

  [super setNameInContainer: newNameInContainer];

  if (nameInContainer)
    {
      newPath = [self path];
      
      sql = [NSMutableString stringWithFormat: @"UPDATE %@"
                             @" SET c_path = '%@'",
                             [self tableName],
                             newPath];
      [sql appendFormat: @" WHERE c_path = '%@'", oldPath];
      [self performBatchSQLQueries: [NSArray arrayWithObject: sql]];
    }
}

- (void) changePathTo: (NSString *) newPath
{
  NSMutableString *sql;
  NSString *oldPath, *newParentPath;
  NSRange slashRange;

  oldPath = [self path];

  slashRange = [newPath rangeOfString: @"/"
                              options: NSBackwardsSearch];
  if (slashRange.location != NSNotFound)
    newParentPath = [newPath substringToIndex: slashRange.location];
  else
    newParentPath = NULL;

  sql = [NSMutableString stringWithFormat: @"UPDATE %@"
                         @" SET c_path = '/%@'",
                         [self tableName],
                         newPath];
  if (newParentPath)
    [sql appendFormat: @", c_parent_path = '%@'", newParentPath];
  else
    [sql appendString: @", c_parent_path = NULL"];
  [sql appendFormat: @" WHERE c_path = '%@'", oldPath];
  [self performBatchSQLQueries: [NSArray arrayWithObject: sql]];
}

- (EOAdaptor *) tableChannelAdaptor
{
  GCSChannelManager *cm;
  EOAdaptor *adaptor;
  EOAdaptorChannel *channel;

  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: [self tableUrl]];
  adaptor = [[channel adaptorContext] adaptor];
  [cm releaseChannel: channel];
  
  return adaptor;
}

- (NSArray *) performSQLQuery: (NSString *) sql
{
  NSMutableArray *records;
  GCSChannelManager *cm;
  EOAdaptorChannel *channel;
  NSException *error;
  NSArray *attrs;
  NSDictionary *record;

  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: [self tableUrl]];

  error = [channel evaluateExpressionX: sql];
  if (error)
    {
      records = nil;
      [self logWithFormat:
              @"an exception occurred when executing query '%@'",
            sql];
      [self logWithFormat: @"exception is '%@'", error];
    }
  else
    {
      records = [NSMutableArray arrayWithCapacity: 256];
      attrs = [channel describeResults: NO];
      while ((record = [channel fetchAttributes: attrs withZone: NULL]))
        [records addObject: record];
    }
  [cm releaseChannel: channel];
  
  return records;
}

- (BOOL) performBatchSQLQueries: (NSArray *) queries
{
  GCSChannelManager *cm;
  EOAdaptorChannel *channel;
  EOAdaptorContext *dbContext;
  NSException *error;
  NSUInteger count, max;
  NSString *sql;

  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: [self tableUrl]];
  dbContext = [channel adaptorContext];

  [dbContext beginTransaction];

  error = nil;

  max = [queries count];
  for (count = 0; error == nil && count < max; count++)
    {
      sql = [queries objectAtIndex: count];
      error = [channel evaluateExpressionX: sql];
      if (error)
        [dbContext rollbackTransaction];
    }
  if (!error)
    [dbContext commitTransaction];
  [cm releaseChannel: channel];
  
  return (error == nil);
}

- (NSDictionary *) lookupRecord: (NSString *) path
               newerThanVersion: (NSInteger) startVersion
{
  NSDictionary *record;
  NSArray *records;
  NSString *tableName, *pathValue;
  NSMutableString *sql;
  EOAdaptor *adaptor;

  if ([path hasSuffix: @"/"])
    [NSException raise: @"SOGoCacheIOException"
                format: @"path ends with a slash: %@", path];

  tableName = [self tableName];
  adaptor = [self tableChannelAdaptor];
  pathValue = [adaptor formatValue: path
                      forAttribute: textColumn];

  /* query */
  sql = [NSMutableString stringWithFormat:
                           @"SELECT * FROM %@ WHERE c_path = %@",
                         tableName, pathValue];
  if (startVersion > -1)
    [sql appendFormat: @" AND c_version > %d", startVersion];

  /* execution */
  records = [self performSQLQuery: sql];
  if ([records count] > 0)
    record = [records objectAtIndex: 0];
  else
    record = nil;

  return record;
}

- (NSArray *) cacheEntriesForDeviceId: (NSString *) deviceId
                     newerThanVersion: (NSInteger) startVersion
{
  NSMutableArray *recordsOut;
  NSArray *records;
  NSString *tableName, *pathValue;
  NSMutableString *sql;
  EOAdaptor *adaptor;
  NSUInteger count, max;

  if ([deviceId hasSuffix: @"/"])
    [NSException raise: @"SOGoCacheIOException"
                format: @"path ends with a slash: %@", deviceId];

  tableName = [self tableName];
  adaptor = [self tableChannelAdaptor];
  pathValue = [adaptor formatValue: [NSString stringWithFormat: @"/%@", deviceId]
                      forAttribute: textColumn];

  /* query */
  sql = [NSMutableString stringWithFormat:
                           @"SELECT * FROM %@ WHERE c_type = %d AND c_deleted <> 1", tableName, objectType];

  if (startVersion > -1)
    [sql appendFormat: @" AND c_version > %d", startVersion];

  if (deviceId) {
    pathValue = [adaptor formatValue: [NSString stringWithFormat: @"/%@%", deviceId]
                      forAttribute: textColumn];
    [sql appendFormat: @" AND c_path like %@", pathValue];
  }

  /* execution */
  records = [self performSQLQuery: sql];

  max = [records count];
  recordsOut = [[NSMutableArray alloc] init];
  for (count = 0; count < max; count++)
    {
      [recordsOut addObject: [[records objectAtIndex: count] objectForKey: @"c_path"]];
    }

  return recordsOut;
}


- (void) reloadIfNeeded
{
  /* if object is uninitialized: reload without condition, otherwise, load if
     c_version > :version */
  NSDictionary *record;

  if (initialized)
    {
      if (!isNew)
        {
          record = [self lookupRecord: [self path]
                     newerThanVersion: version];
          if (record)
            [self setupFromRecord: record];
        }
    }
  else
    {
      record = [self lookupRecord: [self path]
                 newerThanVersion: -1];
      if (record)
        {
          [self setupFromRecord: record];
          isNew = NO;
        }
      else
        isNew = YES;
      initialized = YES;
    }
}

- (NSException *) delete
{
  deleted = YES;
  [properties removeAllObjects];
  [self save];

  return nil;
}

- (NSException *) destroy
{
  NSString *tableName, *pathValue, *sql;
  EOAdaptorChannel *channel;
  GCSChannelManager *cm;
  NSException *result;
  EOAdaptor *adaptor;

  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: [self tableUrl]];
  tableName = [self tableName];

  adaptor = [[channel adaptorContext] adaptor];
  pathValue = [adaptor formatValue: [self path]
                      forAttribute: textColumn];
  result = nil;

  sql = [NSString stringWithFormat:
                    (@"DELETE FROM %@"
                     @" WHERE c_path = %@"),
                  tableName,
                  pathValue];

  result = [channel evaluateExpressionX: sql];
  
  if (result)
    [self errorWithFormat: @"could not delete record %@"
                 @" in %@: %@", pathValue, tableName, result];
  
  [cm releaseChannel: channel];

  return result;
}

- (void) save
{
  NSString *sql;
  NSData *content;
  NSCalendarDate *now;
  GCSChannelManager *cm;
  EOAdaptor *adaptor;
  EOAdaptorChannel *channel;
  NSInteger creationDateValue, lastModifiedValue, deletedValue;
  NSString *tableName, *pathValue, *parentPathValue, *propsValue;
  NSException *result;

  if (!initialized)
    [NSException raise: @"SOGoCacheIOException"
                format: @"record has not been initialized: %@", self];

  cm = [GCSChannelManager defaultChannelManager];

  channel = [cm acquireOpenChannelForURL: [self tableUrl]];

  tableName = [self tableName];

  now = [NSCalendarDate date];
  ASSIGN (lastModified, now);

  adaptor = [[channel adaptorContext] adaptor];
  pathValue = [adaptor formatValue: [self path]
                      forAttribute: textColumn];
  
  lastModifiedValue = (NSInteger) [lastModified timeIntervalSince1970];
  
  if (objectType == -1)
    [NSException raise: @"SOGoCacheIOException"
                format: @"object type has not been set for object '%@'",
                 self];

  if ([properties count] > 0)
    {
      content = [properties BSONRepresentation];
      propsValue = [adaptor formatValue: [content stringByEncodingBase64]
                           forAttribute: textColumn];
    }
  else
    propsValue = @"NULL";

  if (isNew)
    {
      ASSIGN (creationDate, now);
      creationDateValue = (NSInteger) [creationDate timeIntervalSince1970];
      parentPathValue = [adaptor formatValue: [container path]
                                 forAttribute: textColumn];
      if (!parentPathValue)
        parentPathValue = @"NULL";
      sql = [NSString stringWithFormat:
                        (@"INSERT INTO %@"
                         @"  (c_path, c_parent_path, c_type, c_creationdate, c_lastmodified,"
                         @"   c_deleted, c_version, c_content)"
                         @" VALUES (%@, %@, %d, %d, %d, 0, 0, %@"
                         @")"),
                      tableName,
                      pathValue, parentPathValue, objectType,
                      creationDateValue, lastModifiedValue,
                      propsValue];
      isNew = NO;
    }
  else
    {
      version++;
      deletedValue = (deleted ? 1 : 0);
      sql = [NSString stringWithFormat:
                        (@"UPDATE %@"
                         @"  SET c_lastmodified = %d, c_deleted = %d,"
                         @"      c_version = %d, c_content = %@"
                         @" WHERE c_path = %@"),
                      tableName,
                      lastModifiedValue, deletedValue, version, propsValue,
                    pathValue];
    }

  result = [channel evaluateExpressionX: sql];
  if (result)
    [self errorWithFormat: @"could not insert/update record for record %@"
                 @" in %@: %@", pathValue, tableName, result];

  [cm releaseChannel: channel];
}

@end
