/* SOGoAclsFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse groupe conseil
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

#import <Foundation/NSArray.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/SoObjects.h>
#import <NGObjWeb/SoObjects.h>
#import <EOControl/EOQualifier.h>
#import <GDLAccess/EOAdaptorChannel.h>
#import <GDLContentStore/GCSFolder.h>

#import "SOGoAclsFolder.h"

static NSArray *fields = nil;

@implementation SOGoAclsFolder

+ (void) initialize
{
  if (!fields)
    {
      fields = [NSArray arrayWithObjects: @"uid", @"object", @"role", nil];
      [fields retain];
    }
}

+ (id) aclsFolder
{
  id aclsFolder;

  aclsFolder = [self new];
  [aclsFolder autorelease];

  return aclsFolder;
}

- (NSString *) _ocsPathForObject: (SOGoObject *) object
{
  NSString *pathForObject;
  id currentObject;

  pathForObject = nil;
  currentObject = object;
  while (currentObject && !pathForObject)
    if ([currentObject isKindOfClass: [SOGoFolder class]])
      pathForObject = [NSString stringWithFormat: @"%@/acls",
                                [(SOGoFolder *) currentObject ocsPath]];
    else
      currentObject = [currentObject container];

  return pathForObject;
}

- (NSArray *) aclsForObject: (SOGoObject *) object
{
  EOQualifier *qualifier;
  NSString *objectPath;

  [self setOCSPath: [self _ocsPathForObject: object]];

  objectPath
    = [NSString stringWithFormat: @"/%@",
                [[object pathArrayToSoObject] componentsJoinedByString: @"/"]];
  qualifier
    = [EOQualifier qualifierWithQualifierFormat: @"object = %@", objectPath];

  return [[self ocsFolder] fetchFields: fields matchingQualifier: qualifier];
}

- (NSArray *) aclsForObject: (SOGoObject *) object
                    forUser: (NSString *) uid
{
  EOQualifier *qualifier;
  NSString *objectPath;
  NSArray *records;

  [self setOCSPath: [self _ocsPathForObject: object]];

  objectPath
    = [NSString stringWithFormat: @"/%@",
                [[object pathArrayToSoObject] componentsJoinedByString: @"/"]];
  qualifier = [EOQualifier
                qualifierWithQualifierFormat: @"(object = %@) AND (uid = %@)",
                objectPath, uid];

  records = [[self ocsFolder] fetchFields: fields matchingQualifier: qualifier];

  return [records valueForKey: @"role"];
}

- (void) removeUsersWithRole: (NSString *) role
             forObjectAtPath: (NSString *) objectPath
                    inFolder: (GCSFolder *) folder
{
  NSString *deleteSQL;
  EOAdaptorChannel *channel;

  channel = [folder acquireQuickChannel];

  deleteSQL = [NSString stringWithFormat: @"DELETE FROM %@"
                        @" WHERE object = '%@'"
                        @" AND role = '%@'",
                        [folder quickTableName], objectPath, role];
  [channel evaluateExpressionX: deleteSQL];
}

- (void) setRoleForObjectAtPath: (NSString *) objectPath
                        forUser: (NSString *) uid
                             to: (NSString *) role
                       inFolder: (GCSFolder *) folder
{
  NSString *SQL;
  EOAdaptorChannel *channel;

  channel = [folder acquireQuickChannel];

  SQL = [NSString stringWithFormat: @"DELETE FROM %@"
                  @" WHERE object = '%@'"
                  @" AND uid = '%@'",
                  [folder quickTableName], objectPath, uid];
  [channel evaluateExpressionX: SQL];
  SQL = [NSString stringWithFormat: @"INSERT INTO %@"
                  @" (object, uid, role)"
                  @" VALUES ('%@', '%@', '%@')", [folder quickTableName],
                  objectPath, uid, role];
  [channel evaluateExpressionX: SQL];
}

/* FIXME: part of this code should be moved to sope-gdl/GCSFolder.m */
- (void) setRoleForObject: (SOGoObject *) object
                 forUsers: (NSArray *) uids
                       to: (NSString *) role
{
  GCSFolder *aclsFolder;
  NSString *objectPath, *currentUID;
  NSEnumerator *userUIDs;

  [self setOCSPath: [self _ocsPathForObject: object]];
  aclsFolder = [self ocsFolder];

  objectPath
    = [NSString stringWithFormat: @"/%@",
                [[object pathArrayToSoObject] componentsJoinedByString: @"/"]];
  [self removeUsersWithRole: role
        forObjectAtPath: objectPath
        inFolder: aclsFolder];

  userUIDs = [uids objectEnumerator];
  currentUID = [userUIDs nextObject];
  while (currentUID)
    {
      if ([currentUID length] > 0)
        [self setRoleForObjectAtPath: objectPath
              forUser: currentUID
              to: role
              inFolder: aclsFolder];
      currentUID = [userUIDs nextObject];
    }
}

@end
