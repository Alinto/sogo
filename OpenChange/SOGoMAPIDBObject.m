/* SOGoMAPIDBObject.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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
#import <Foundation/NSValue.h>
#import <GDLAccess/EOAdaptor.h>
#import <GDLAccess/EOAdaptorChannel.h>
#import <GDLAccess/EOAdaptorContext.h>
#import <GDLAccess/EOAttribute.h>
#import <GDLContentStore/GCSChannelManager.h>
#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUser.h>

#import "GCSSpecialQueries+OpenChange.h"
#import "MAPIStoreTypes.h"
#import "SOGoMAPIDBFolder.h"

#import "SOGoMAPIDBObject.h"

static EOAttribute *textColumn = nil;

@implementation SOGoMAPIDBObject

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
       @" c_type VARCHAR(20) NOT NULL,"
       @" c_creationdate INT4 NOT NULL,"
       @" c_lastmodified INT4 NOT NULL,"
       @" c_version INT4 NOT NULL DEFAULT 0,"
       @" c_deleted SMALLINT NOT NULL DEFAULT 0,"
*/

/* indexes:
   c_path (primary key)
   c_counter
   c_path, c_type
   c_path, c_creationdate */

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
  [tableUrl release];
  [super dealloc];
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
        [NSException raise: @"MAPIStoreIOException"
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
  NSString *propsValue, *error;
  NSDictionary *newValues;
  NSPropertyListFormat format;

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
      newValues = [NSPropertyListSerialization propertyListFromData: [propsValue dataByDecodingBase64]
                                                   mutabilityOption: NSPropertyListMutableContainers
                                                             format: &format
                                                   errorDescription: &error];
      [properties addEntriesFromDictionary: newValues];
      // [properties addEntriesFromDictionary: [propsValue
      // objectFromJSONString]];
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
    [NSException raise: @"MAPIStoreIOException"
                format: @"object path has not been properly set for"
                 " folder '%@' (%@)",
                 self, path];

  return path;
}

- (void) setObjectType: (MAPIDBObjectType) newObjectType
{
  objectType = newObjectType;
}

- (MAPIDBObjectType) objectType /* message, fai, folder */
{
  return objectType;
}

- (NSCalendarDate *) creationDate
{
  if (!initialized)
    [NSException raise: @"MAPIStoreIOException"
                format: @"record has not been initialized: %@", self];

  return creationDate;
}

- (NSCalendarDate *) lastModified
{
  if (!initialized)
    [NSException raise: @"MAPIStoreIOException"
                format: @"record has not been initialized: %@", self];

  return lastModified;
}

- (BOOL) deleted
{
  return deleted;
}

- (Class) mapistoreMessageClass
{
  NSString *className, *mapiMsgClass;

  switch (objectType)
    {
    case MAPIDBObjectTypeMessage:
      mapiMsgClass = [properties
                       objectForKey: MAPIPropertyKey (PidTagMessageClass)];
      if (mapiMsgClass)
        {
          if ([mapiMsgClass isEqualToString: @"IPM.StickyNote"])
            className = @"MAPIStoreNotesMessage";
          else
            className = @"MAPIStoreDBMessage";
          [self logWithFormat: @"PidTagMessageClass = '%@', returning '%@'",
                mapiMsgClass, className];
        }
      else
        {
          [self warnWithFormat: @"PidTagMessageClass is not set, falling back"
                @" to 'MAPIStoreDBMessage'"];
          className = @"MAPIStoreDBMessage";
        }
      break;
    case MAPIDBObjectTypeFAI:
      className = @"MAPIStoreFAIMessage";
      break;
    default:
      [NSException raise: @"MAPIStoreIOException"
                  format: @"message class should not be queried for objects"
                   @" of type '%d'", objectType];
    }

  return NSClassFromString (className);
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
                         @" SET c_path = '%@'",
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
    [NSException raise: @"MAPIStoreIOException"
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
    [NSException raise: @"MAPIStoreIOException"
                format: @"record has not been initialized: %@", self];

  cm = [GCSChannelManager defaultChannelManager];

  channel = [cm acquireOpenChannelForURL: [self tableUrl]];

  tableName = [self tableName];

  now = [NSCalendarDate date];
  ASSIGN (lastModified, now);

  /*
- (NSException *)insertRowX:(NSDictionary *)_row forEntity:(EOEntity *)_entity;
- (NSException *)updateRowX:(NSDictionary*)aRow
  describedByQualifier:(EOSQLQualifier*)aQualifier;
  */

  adaptor = [[channel adaptorContext] adaptor];
  pathValue = [adaptor formatValue: [self path]
                      forAttribute: textColumn];
  
  lastModifiedValue = (NSInteger) [lastModified timeIntervalSince1970];
  
  if (objectType == -1)
    [NSException raise: @"MAPIStoreIOException"
                format: @"object type has not been set for object '%@'",
                 self];

  if ([properties count] > 0)
    {
      content = [NSPropertyListSerialization
                      dataFromPropertyList: properties
                                    format: NSPropertyListGNUstepBinaryFormat
                          errorDescription: NULL];
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
  // @" c_path VARCHAR(255) PRIMARY KEY,"
  // @" c_type SMALLINT NOT NULL,"
  // @" c_creationdate INT4 NOT NULL,"
  // @" c_lastmodified INT4 NOT NULL,"
  // @" c_deleted SMALLINT NOT NULL DEFAULT 0,"
  // @" c_content BLOB");

  [cm releaseChannel: channel];
}

@end
