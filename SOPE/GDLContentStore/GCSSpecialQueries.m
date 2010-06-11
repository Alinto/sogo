/* GCSSpecialQueries.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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

#import <NGExtensions/NSObject+Logs.h>

#import "GCSSpecialQueries.h"

@interface GCSPostgreSQLSpecialQueries : GCSSpecialQueries
@end

@interface GCSMySQLSpecialQueries : GCSSpecialQueries
@end

@interface GCSOracleSpecialQueries : GCSSpecialQueries
@end

@implementation EOAdaptorChannel (GCSSpecialQueries)

- (GCSSpecialQueries *) specialQueries
{
  static NSMutableDictionary *queries = nil;
  GCSSpecialQueries *specialQueries;
  NSString *specialQueriesClass, *thisClass;

  if (!queries)
    {
      queries = [NSMutableDictionary new];
      [queries setObject: @"GCSPostgreSQLSpecialQueries"
                  forKey: @"PostgreSQL72Channel"];
      [queries setObject: @"GCSMySQLSpecialQueries"
                  forKey: @"MySQL4Channel"];
      [queries setObject: @"GCSOracleSpecialQueries"
                  forKey: @"OracleAdaptorChannel"];
    }

  thisClass = NSStringFromClass ([self class]);
  specialQueriesClass = [queries objectForKey: thisClass];
  if (specialQueriesClass)
    {
      specialQueries = [NSClassFromString (specialQueriesClass) new];
      [specialQueries autorelease];
    }
  else
    {
      specialQueries = nil;
      [self errorWithFormat:
              @"No GCSSpecialQueries subclass defined for channel class '%@'",
            thisClass];
    }

  return specialQueries;
}

@end

@implementation GCSSpecialQueries

- (NSString *) createFolderTableWithName: (NSString *) tableName
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSString *) createFolderACLTableWithName: (NSString *) tableName
{
  [self subclassResponsibility: _cmd];

  return nil;
}

@end

@implementation GCSPostgreSQLSpecialQueries

- (NSString *) createFolderTableWithName: (NSString *) tableName
{
  static NSString *sqlFolderFormat
    = (@"CREATE TABLE %@ (\n"
       @"  c_name VARCHAR (255) NOT NULL PRIMARY KEY,\n"
       @"  c_content VARCHAR (100000) NOT NULL,\n"
       @"  c_creationdate INT4 NOT NULL,\n"
       @"  c_lastmodified INT4 NOT NULL,\n"
       @"  c_version INT4 NOT NULL,\n"
       @"  c_deleted INT4 NULL\n"
       @")");

  return [NSString stringWithFormat: sqlFolderFormat, tableName];
}

- (NSString *) createFolderACLTableWithName: (NSString *) tableName
{
  static NSString *sqlFolderACLFormat
    = (@"CREATE TABLE %@ (\n"
       @"  c_uid VARCHAR (255) NOT NULL,\n"
       @"  c_object VARCHAR (255) NOT NULL,\n"
       @"  c_role VARCHAR (80) NOT NULL\n"
       @")");

  return [NSString stringWithFormat: sqlFolderACLFormat, tableName];
}

@end

@implementation GCSMySQLSpecialQueries

- (NSString *) createFolderTableWithName: (NSString *) tableName
{
  static NSString *sqlFolderFormat
    = (@"CREATE TABLE %@ (\n"
       @"  c_name VARCHAR (255) NOT NULL PRIMARY KEY,\n"
       @"  c_content VARCHAR (100000) NOT NULL,\n"
       @"  c_creationdate INT NOT NULL,\n"
       @"  c_lastmodified INT NOT NULL,\n"
       @"  c_version INT NOT NULL,\n"
       @"  c_deleted INT NULL\n"
       @")");

  return [NSString stringWithFormat: sqlFolderFormat, tableName];
}

- (NSString *) createFolderACLTableWithName: (NSString *) tableName
{
  static NSString *sqlFolderACLFormat
    = (@"CREATE TABLE %@ (\n"
       @"  c_uid VARCHAR (255) NOT NULL,\n"
       @"  c_object VARCHAR (255) NOT NULL,\n"
       @"  c_role VARCHAR (80) NOT NULL\n"
       @")");
  
  return [NSString stringWithFormat: sqlFolderACLFormat, tableName];
}

@end

@implementation GCSOracleSpecialQueries

- (NSString *) createFolderTableWithName: (NSString *) tableName
{
  static NSString *sqlFolderFormat
    = (@"CREATE TABLE %@ (\n"
       @"  c_name VARCHAR2 (255) NOT NULL PRIMARY KEY,\n"
       @"  c_content CLOB NOT NULL,\n"
       @"  c_creationdate INTEGER NOT NULL,\n"
       @"  c_lastmodified INTEGER NOT NULL,\n"
       @"  c_version INTEGER NOT NULL,\n"
       @"  c_deleted INTEGER DEFAULT 0 NOT NULL\n"
       @")");

  return [NSString stringWithFormat: sqlFolderFormat, tableName];
}

- (NSString *) createFolderACLTableWithName: (NSString *) tableName
{
  static NSString *sqlFolderACLFormat
    = (@"CREATE TABLE %@ (\n"
       @"  c_uid VARCHAR (255) NOT NULL,\n"
       @"  c_object VARCHAR (255) NOT NULL,\n"
       @"  c_role VARCHAR (80) NOT NULL\n"
       @")");
  return [NSString stringWithFormat: sqlFolderACLFormat, tableName];
}

@end
