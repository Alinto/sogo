/* GCSSpecialQueries+OpenChange.m - this file is part of SOGo
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

#import <Foundation/NSString.h>

#import "GCSSpecialQueries+OpenChange.h"

@interface GCSPostgreSQLSpecialQueries (OpenChangeHelpers)
@end

@interface GCSMySQLSpecialQueries (OpenChangeHelpers)
@end

@interface GCSOracleSpecialQueries (OpenChangeHelpers)
@end

@implementation GCSSpecialQueries (OpenChangeHelpers)

/* FIXME: c_parent_path should be indexed */

- (NSString *) createOpenChangeFSTableWithName: (NSString *) tableName
{
  [self subclassResponsibility: _cmd];

  return nil;
}

@end

@implementation GCSPostgreSQLSpecialQueries (OpenChangeHelpers)

- (NSString *) createOpenChangeFSTableWithName: (NSString *) tableName
{
  static NSString *sqlFolderFormat
    = (@"CREATE TABLE %@ (" 
       @" c_path VARCHAR(255) PRIMARY KEY,"
       @" c_parent_path VARCHAR(255),"
       @" c_type SMALLINT NOT NULL,"
       @" c_creationdate INT4 NOT NULL,"
       @" c_lastmodified INT4 NOT NULL,"
       @" c_version INT4 NOT NULL DEFAULT 0,"
       @" c_deleted SMALLINT NOT NULL DEFAULT 0,"
       @" c_content TEXT)");

  return [NSString stringWithFormat: sqlFolderFormat, tableName];
}

@end

@implementation GCSMySQLSpecialQueries (OpenChangeHelpers)

- (NSString *) createOpenChangeFSTableWithName: (NSString *) tableName
{
  static NSString *sqlFolderFormat
    = (@"CREATE TABLE %@ (" 
       @" c_path VARCHAR(255) PRIMARY KEY,"
       @" c_parent_path VARCHAR(255),"
       @" c_type TINYINT NOT NULL,"
       @" c_creationdate INT NOT NULL,"
       @" c_lastmodified INT NOT NULL,"
       @" c_version INT NOT NULL DEFAULT 0,"
       @" c_deleted TINYINT NOT NULL DEFAULT 0,"
       @" c_content TEXT)");

  return [NSString stringWithFormat: sqlFolderFormat, tableName];
}

@end

@implementation GCSOracleSpecialQueries (OpenChangeHelpers)

- (NSString *) createOpenChangeFSTableWithName: (NSString *) tableName
{
  static NSString *sqlFolderFormat
    = (@"CREATE TABLE %@ (" 
       @" c_path VARCHAR2(255) PRIMARY KEY,"
       @" c_parent_path VARCHAR2(255),"
       @" c_type SMALLINT NOT NULL,"
       @" c_creationdate INT4 NOT NULL,"
       @" c_lastmodified INT4 NOT NULL,"
       @" c_version INT4 NOT NULL DEFAULT 0,"
       @" c_deleted SMALLINT NOT NULL DEFAULT 0,"
       @" c_content CLOB)");

  return [NSString stringWithFormat: sqlFolderFormat, tableName];
}

@end
