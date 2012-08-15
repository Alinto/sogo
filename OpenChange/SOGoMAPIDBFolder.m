/* SOGoMAPIDBFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Inverse inc.
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
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSPropertyList.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSURL.h>

#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSNull+misc.h>
#import <GDLAccess/EOAdaptorChannel.h>
#import <GDLContentStore/GCSChannelManager.h>
// #import <GDLContentStore/EOQualifier+GCS.m>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUser.h>
#import "EOQualifier+MAPI.h"
#import "GCSSpecialQueries+OpenChange.h"
#import "SOGoMAPIDBMessage.h"

#import "SOGoMAPIDBFolder.h"

#undef DEBUG
#include <stdbool.h>
#include <talloc.h>
#include <util/time.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
#include <libmapiproxy.h>
#include <param.h>

Class SOGoMAPIDBObjectK = Nil;

@implementation SOGoMAPIDBFolder

+ (void) initialize
{
  SOGoMAPIDBObjectK = [SOGoMAPIDBObject class];
}

- (id) init
{
  if ((self = [super init]))
    {
      pathPrefix = nil;
    }

  return self;
}

- (id) initWithName: (NSString *) name inContainer: (id) newContainer
{
  if ((self = [super initWithName: name inContainer: newContainer]))
    {
      objectType = MAPIDBObjectTypeFolder;
      aclMessage = [SOGoMAPIDBObject objectWithName: @"permissions"
                                        inContainer: self];
      [aclMessage setObjectType: MAPIDBObjectTypeInternal];
      [aclMessage retain];
    }

  return self;
}

- (void) dealloc
{
  [aclMessage release];
  [pathPrefix release];
  [super dealloc];
}

- (BOOL) isFolderish
{
  return YES;
}

- (void) setPathPrefix: (NSString *) newPathPrefix
{
  ASSIGN (pathPrefix, newPathPrefix);
}

- (NSMutableString *) pathForChild: (NSString *) childName
{
  NSMutableString *path;

  path = [self path];
  [path appendFormat: @"/%@", childName];

  return path;
}

- (NSMutableString *) path
{
  NSMutableString *path;

  path = [super path];
  if (pathPrefix)
    [path insertString: pathPrefix atIndex: 0];

  return path;
}

// - (SOGoMAPIDBMessage *) newMessage
// {
//   NSString *newFilename;

//   newFilename = [NSString stringWithFormat: @"%@.plist",
//                           [SOGoObject globallyUniqueObjectId]];

//   return [SOGoMAPIDBMessage objectWithName: filename inContainer: self];
// }

- (NSArray *) childKeysOfType: (MAPIDBObjectType) type
               includeDeleted: (BOOL) includeDeleted
            matchingQualifier: (EOQualifier *) qualifier
             andSortOrderings: (NSArray *) sortOrderings
{
  NSMutableArray *childKeys;
  NSMutableString *sql// , *qualifierClause
    ;
  NSString *childPathPrefix, *childPath, *childKey;
  NSMutableArray *whereClause;
  NSArray *records;
  NSDictionary *record;
  NSUInteger childPathPrefixLen, count, max;
  SOGoMAPIDBObject *currentChild;

  /* query construction */
  sql = [NSMutableString stringWithCapacity: 256];
  [sql appendFormat: @"SELECT * FROM %@", [self tableName]];

  whereClause = [NSMutableArray arrayWithCapacity: 2];
  [whereClause addObject: [NSString stringWithFormat: @"c_parent_path = '%@'",
                                    [self path]]];
  [whereClause addObject: [NSString stringWithFormat: @"c_type = %d", type]];
  if (!includeDeleted)
    [whereClause addObject: @"c_deleted = 0"];

  [sql appendFormat: @" WHERE %@",
       [whereClause componentsJoinedByString: @" AND "]];

  childPathPrefix = [NSString stringWithFormat: @"%@/", [self path]];

  /* results */
  records = [self performSQLQuery: sql];
  if (records)
    {
      max = [records count];
      childKeys = [NSMutableArray arrayWithCapacity: max];
      childPathPrefixLen = [childPathPrefix length];
      for (count = 0; count < max; count++)
        {
          record = [records objectAtIndex: count];
          childPath = [record objectForKey: @"c_path"];
          childKey = [childPath substringFromIndex: childPathPrefixLen];
          if ([childKey rangeOfString: @"/"].location == NSNotFound)
            {
              if (qualifier)
                {
                  currentChild = [SOGoMAPIDBObject objectWithName: childKey
                                                      inContainer: self];
                  [currentChild setupFromRecord: record];
                  if ([qualifier evaluateSOGoMAPIDBObject: currentChild])
                    [childKeys addObject: childKey];
                }
              else
                [childKeys addObject: childKey];
            }
        }
    }
  else
    childKeys = nil;

  return childKeys;
}

- (NSArray *) toManyRelationshipKeys
{
  return [self childKeysOfType: MAPIDBObjectTypeFolder
                includeDeleted: NO
             matchingQualifier: nil
              andSortOrderings: nil];
}

- (NSArray *) toOneRelationshipKeys
{
  return [self childKeysOfType: MAPIDBObjectTypeMessage
                includeDeleted: NO
             matchingQualifier: nil
              andSortOrderings: nil];
}

- (void) setNameInContainer: (NSString *) newName
{
  NSMutableString *sql;
  NSString *oldPath, *newPath, *path, *parentPath;
  NSMutableArray *queries;
  NSArray *records;
  NSDictionary *record;
  NSUInteger count, max;

  /* change the paths in children records */
  if (nameInContainer)
    oldPath = [self path];

  [super setNameInContainer: newName];

  if (nameInContainer)
    {
      newPath = [self path];

      sql = [NSMutableString stringWithFormat:
                               @"SELECT c_path, c_parent_path FROM %@"
                             @" WHERE c_path LIKE '%@/%%'",
                             [self tableName], oldPath];
      records = [self performSQLQuery: sql];
      max = [records count];
      queries = [NSMutableArray arrayWithCapacity: max + 1];
      if (max > 0)
        {
          for (count = 0; count < max; count++)
            {
              record = [records objectAtIndex: count];
              path = [record objectForKey: @"c_path"];
              sql = [NSMutableString stringWithFormat: @"UPDATE %@"
                                     @" SET c_path = '%@'",
                                     [self tableName],
                        [path stringByReplacingPrefix: oldPath
                                           withPrefix: newPath]];
              parentPath = [record objectForKey: @"c_parent_path"];
              if ([parentPath isNotNull])
                [sql appendFormat: @", c_parent_path = '%@'",
                     [parentPath stringByReplacingPrefix: oldPath
                                              withPrefix: newPath]];
              [sql appendFormat: @" WHERE c_path = '%@'", path];
              [queries addObject: sql];
            }
          [self performBatchSQLQueries: queries];
        }
    }
}

- (void) changePathTo: (NSString *) newPath
{
  NSMutableString *sql// , *qualifierClause
    ;
  NSString *oldPath, *oldPathAsPrefix, *path, *parentPath;
  NSMutableArray *queries;
  NSArray *records;
  NSDictionary *record;
  NSUInteger count, max;

  /* change the paths in children records */
  oldPath = [self path];
  oldPathAsPrefix = [NSString stringWithFormat: @"%@/", oldPath];

  sql = [NSMutableString stringWithFormat:
                           @"SELECT c_path, c_parent_path FROM %@"
                         @" WHERE c_path LIKE '%@%%'",
                         [self tableName], oldPathAsPrefix];
  records = [self performSQLQuery: sql];
  max = [records count];
  queries = [NSMutableArray arrayWithCapacity: max + 1];
  if (max > 0)
    {
      for (count = 0; count < max; count++)
        {
          record = [records objectAtIndex: count];
          path = [record objectForKey: @"c_path"];
          sql = [NSMutableString stringWithFormat: @"UPDATE %@"
                                 @" SET c_path = '%@'",
                                 [self tableName],
                                 [path stringByReplacingPrefix: oldPath
                                       withPrefix: newPath]];
          parentPath = [record objectForKey: @"c_parent_path"];
          if ([parentPath isNotNull])
            [sql appendFormat: @", c_parent_path = '%@'",
                 [parentPath stringByReplacingPrefix: oldPath
                             withPrefix: newPath]];
          [sql appendFormat: @" WHERE c_path = '%@'", path];
          [queries addObject: sql];
        }
      [self performBatchSQLQueries: queries];
    }

  /* change the path in this folder record */
  [super changePathTo: newPath];
}

// - (NSArray *) toOneRelationshipKeysMatchingQualifier: (EOQualifier *) qualifier
//                                     andSortOrderings: (NSArray *) sortOrderings
// {
//   NSArray *allKeys;
//   NSMutableArray *keys;
//   NSUInteger count, max;
//   NSString *messageKey;
//   SOGoMAPIDBMessage *message;

//   if (sortOrderings)
//     [self warnWithFormat: @"sorting is not handled yet"];

//   allKeys = [self toOneRelationshipKeys];
//   if (qualifier)
//     {
//       [self logWithFormat: @"%s: getting restricted FAI keys", __PRETTY_FUNCTION__];
//       max = [allKeys count];
//       keys = [NSMutableArray arrayWithCapacity: max];
//       for (count = 0; count < max; count++)
//         {
//           messageKey = [allKeys objectAtIndex: count];
//           message = [self lookupName: messageKey
//                            inContext: nil
//                              acquire: NO];
//           if ([qualifier evaluateMAPIVolatileMessage: message])
//             [keys addObject: messageKey];
// 	}
//     }
//   else
//     keys = (NSMutableArray *) allKeys;

//   return keys;
// }

- (id) lookupName: (NSString *) childName
	inContext: (WOContext *) woContext
	  acquire: (BOOL) acquire
{
  id object;
  Class objectClass;
  NSString *childPath;
  NSDictionary *record;

  childPath = [self pathForChild: childName];
  record = [self lookupRecord: childPath newerThanVersion: -1];
  if (record)
    {
      if ([[record objectForKey: @"c_type"] intValue] == MAPIDBObjectTypeFolder)
        objectClass = isa;
      else
        objectClass = SOGoMAPIDBObjectK;

      object = [objectClass objectWithName: childName
                               inContainer: self];
      [object setupFromRecord: record];
    }
  else
    object = nil;

  return object;
}

- (id) lookupFolder: (NSString *) folderName
          inContext: (WOContext *) woContext
{
  id object;

  object = [SOGoMAPIDBFolder objectWithName: folderName
                                inContainer: self];
  [object reloadIfNeeded];

  return object;
}

// - (id) _fileAttributeForKey: (NSString *) key
// {
//   NSDictionary *attributes;

//   attributes = [[NSFileManager defaultManager]
//                    fileAttributesAtPath: directory
//                            traverseLink: NO];
  
//   return [attributes objectForKey: key];
// }

// - (NSCalendarDate *) creationTime
// {
//   return [self _fileAttributeForKey: NSFileCreationDate];
// }

// - (NSCalendarDate *) lastModificationTime
// {
//   return [self _fileAttributeForKey: NSFileModificationDate];
// }

/* acl */
- (NSString *) defaultUserID
{
  return @"default";
}

- (NSMutableDictionary *) _aclEntries
{
  NSMutableDictionary *aclEntries;

  [aclMessage reloadIfNeeded];
  aclEntries = [aclMessage properties];
  if (![aclEntries objectForKey: @"users"])
    [aclEntries setObject: [NSMutableArray array] forKey: @"users"];
  if (![aclEntries objectForKey: @"entries"])
    [aclEntries setObject: [NSMutableDictionary dictionary]
                   forKey: @"entries"];

  return aclEntries;
}

- (void) addUserInAcls: (NSString *) user
{
  NSMutableDictionary *acl;
  NSMutableArray *users;

  acl = [self _aclEntries];
  users = [acl objectForKey: @"users"];
  [users addObjectUniquely: user];
  [aclMessage save];
}

- (void) removeAclsForUsers: (NSArray *) oldUsers
{
  NSDictionary *acl;
  NSMutableDictionary *entries;
  NSMutableArray *users;

  acl = [self _aclEntries];
  entries = [acl objectForKey: @"entries"];
  [entries removeObjectsForKeys: oldUsers];
  users = [acl objectForKey: @"users"];
  [users removeObjectsInArray: oldUsers];
  [aclMessage save];
}

- (NSArray *) aclUsers
{
  return [[self _aclEntries] objectForKey: @"users"];
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  NSDictionary *entries;

  entries = [[self _aclEntries] objectForKey: @"entries"];

  return [entries objectForKey: uid];
}

- (void) setRoles: (NSArray *) roles
          forUser: (NSString *) uid
{
  NSMutableDictionary *acl;
  NSMutableDictionary *entries;

  acl = [self _aclEntries];
  entries = [acl objectForKey: @"entries"];
  [entries setObject: roles forKey: uid];
  [aclMessage save];
}

@end
