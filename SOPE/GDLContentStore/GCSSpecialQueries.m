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

- (NSString *) createEMailAlarmsFolderWithName: (NSString *) tableName
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSDictionary *) emailAlarmsAttributeTypes
{
  [self subclassResponsibility: _cmd];

  return nil;
}

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

- (NSString *) createSessionsFolderWithName: (NSString *) tableName
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSDictionary *) sessionsAttributeTypes
{
  [self subclassResponsibility: _cmd];
  
  return nil;
}


@end

//
// PostgreSQL database
//
@implementation GCSPostgreSQLSpecialQueries

- (NSString *) createEMailAlarmsFolderWithName: (NSString *) tableName
{
  static NSString *sqlFolderFormat
    = (@"CREATE TABLE %@ (" 
       @" c_path VARCHAR(255) NOT NULL,"
       @" c_name VARCHAR(255) NOT NULL,"
       @" c_uid VARCHAR(255) NOT NULL,"
       @" c_recurrence_id INT NULL,"
       @" c_alarm_number INT NOT NULL,"
       @" c_alarm_date INT NOT NULL)");

  return [NSString stringWithFormat: sqlFolderFormat, tableName];
}

- (NSDictionary *) emailAlarmsAttributeTypes
{
  static NSMutableDictionary *types = nil;

  if (!types)
    {
      types = [NSMutableDictionary new];
      [types setObject: @"varchar" forKey: @"c_path"];
      [types setObject: @"varchar" forKey: @"c_name"];
      [types setObject: @"varchar" forKey: @"c_uid"];
      [types setObject: @"int" forKey: @"c_recurrence_id"];
      [types setObject: @"int" forKey: @"c_alarm_number"];
      [types setObject: @"int" forKey: @"c_alarm_date"];
    }

  return types;
}

- (NSString *) createFolderTableWithName: (NSString *) tableName
{
  static NSString *sqlFolderFormat
    = (@"CREATE TABLE %@ (\n"
       @"  c_name VARCHAR (255) NOT NULL PRIMARY KEY,\n"
       @"  c_content TEXT NOT NULL,\n"
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

- (NSString *) createSessionsFolderWithName: (NSString *) tableName
{
  static NSString *sqlFolderFormat
    = (@"CREATE TABLE %@ (" 
       @" c_id VARCHAR(255) NOT NULL PRIMARY KEY,"
       @" c_value VARCHAR(255) NOT NULL,"
       @" c_creationdate INT4 NOT NULL,"
       @" c_lastseen INT4 NOT NULL)");

  return [NSString stringWithFormat: sqlFolderFormat, tableName];
}

- (NSDictionary *) sessionsAttributeTypes
{
  static NSMutableDictionary *types = nil;

  if (!types)
    {
      types = [NSMutableDictionary new];
      [types setObject: @"varchar" forKey: @"c_id"];
      [types setObject: @"varchar" forKey: @"c_value"];
      [types setObject: @"int" forKey: @"c_creationdate"];
      [types setObject: @"int" forKey: @"c_lastseen"];
    }

  return types;
}

@end

//
// MySQL database
//
@implementation GCSMySQLSpecialQueries

- (NSString *) createEMailAlarmsFolderWithName: (NSString *) tableName
{
  static NSString *sqlFolderFormat
    = (@"CREATE TABLE %@ (" 
       @" c_path VARCHAR(255) NOT NULL,"
       @" c_name VARCHAR(255) NOT NULL,"
       @" c_uid VARCHAR(255) NOT NULL,"
       @" c_recurrence_id INT NULL,"
       @" c_alarm_number INT NOT NULL,"
       @" c_alarm_date INT NOT NULL)");

  return [NSString stringWithFormat: sqlFolderFormat, tableName];
}

- (NSDictionary *) emailAlarmsAttributeTypes
{
  static NSMutableDictionary *types = nil;

  if (!types)
    {
      types = [NSMutableDictionary new];
      [types setObject: @"varchar" forKey: @"c_path"];
      [types setObject: @"varchar" forKey: @"c_name"];
      [types setObject: @"varchar" forKey: @"c_uid"];
      [types setObject: @"int" forKey: @"c_recurrence_id"];
      [types setObject: @"int" forKey: @"c_alarm_number"];
      [types setObject: @"int" forKey: @"c_alarm_date"];
    }

  return types;
}

- (NSString *) createFolderTableWithName: (NSString *) tableName
{
  static NSString *sqlFolderFormat
    = (@"CREATE TABLE %@ (\n"
       @"  c_name VARCHAR (255) NOT NULL PRIMARY KEY,\n"
       @"  c_content MEDIUMTEXT NOT NULL,\n"
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

- (NSString *) createSessionsFolderWithName: (NSString *) tableName
{
  static NSString *sqlFolderFormat
    = (@"CREATE TABLE %@ (" 
       @" c_id VARCHAR(255) NOT NULL PRIMARY KEY,"
       @" c_value VARCHAR(255) NOT NULL,"
       @" c_creationdate INT NOT NULL,"
       @" c_lastseen INT NOT NULL)");

  return [NSString stringWithFormat: sqlFolderFormat, tableName];
}

- (NSDictionary *) sessionsAttributeTypes
{
  static NSMutableDictionary *types = nil;

  if (!types)
    {
      types = [NSMutableDictionary new];
      [types setObject: @"varchar" forKey: @"c_id"];
      [types setObject: @"varchar" forKey: @"c_value"];
      [types setObject: @"int" forKey: @"c_creationdate"];
      [types setObject: @"int" forKey: @"c_lastseen"];
    }

  return types;
}

@end

//
// Oracle database
//
@implementation GCSOracleSpecialQueries

- (NSString *) createEMailAlarmsFolderWithName: (NSString *) tableName
{
  static NSString *sqlFolderFormat
    = (@"CREATE TABLE %@ (" 
       @" c_path VARCHAR2(255) NOT NULL,"
       @" c_name VARCHAR2(255) NOT NULL,"
       @" c_uid VARCHAR2(255) NOT NULL,"
       @" c_recurrence_id INTEGER NULL,"
       @" c_alarm_number INTEGER NOT NULL,"
       @" c_alarm_date INTEGER NOT NULL)");

  return [NSString stringWithFormat: sqlFolderFormat, tableName];
}

- (NSDictionary *) emailAlarmsAttributeTypes
{
  static NSMutableDictionary *types = nil;

  if (!types)
    {
      types = [NSMutableDictionary new];
      [types setObject: @"varchar2" forKey: @"c_path"];
      [types setObject: @"varchar2" forKey: @"c_name"];
      [types setObject: @"varchar2" forKey: @"c_uid"];
      [types setObject: @"integer" forKey: @"c_recurrence_id"];
      [types setObject: @"integer" forKey: @"c_alarm_number"];
      [types setObject: @"integer" forKey: @"c_alarm_date"];
    }

  return types;
}

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

- (NSString *) createSessionsFolderWithName: (NSString *) tableName
{
  static NSString *sqlFolderFormat
    = (@"CREATE TABLE %@ (" 
       @" c_id VARCHAR2(255) NOT NULL PRIMARY KEY,"
       @" c_value VARCHAR2(255) NOT NULL,"
       @" c_creationdate INTEGER NOT NULL,"
       @" c_lastseen INTEGER NOT NULL)");

  return [NSString stringWithFormat: sqlFolderFormat, tableName];
}

- (NSDictionary *) sessionsAttributeTypes
{
  static NSMutableDictionary *types = nil;

  if (!types)
    {
      types = [NSMutableDictionary new];
      [types setObject: @"varchar2" forKey: @"c_id"];
      [types setObject: @"varchar2" forKey: @"c_value"];
      [types setObject: @"integer" forKey: @"c_creationdate"];
      [types setObject: @"integer" forKey: @"c_lastseen"];
    }

  return types;
}

@end
