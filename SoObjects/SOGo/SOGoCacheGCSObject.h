/* SOGoCacheGCSObject.h - this file is part of SOGo
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

#ifndef SOGOCACHEGCSOBJECT_H
#define SOGOCACHEGCSOBJECT_H

#import "SOGoCacheObject.h"

@class NSArray;
@class NSMutableDictionary;
@class NSMutableString;
@class NSString;
@class NSURL;

@class EOAdaptor;

typedef enum {
  MAPIFolderCacheObject = 1,
  MAPIMessageCacheObject = 2,
  MAPIFAICacheObject = 3,
  MAPIInternalCacheObject = 99, /* object = property list */
  ActiveSyncGlobalCacheObject = 200,
  ActiveSyncFolderCacheObject = 201
} SOGoCacheObjectType;

@interface SOGoCacheGCSObject : SOGoCacheObject 
{
  NSURL *tableUrl;

  BOOL initialized; /* safe guard */
  SOGoCacheObjectType objectType;
  NSInteger version;
  BOOL deleted;
}

/* actions */
- (void) setupFromRecord: (NSDictionary *) record;

- (void) reloadIfNeeded;
- (void) save;

/* accessors */
- (NSMutableString *) path; /* full filename */

- (void) setTableUrl: (NSURL *) newTableUrl;
- (NSURL *) tableUrl;
- (NSString *) tableName;

- (NSArray *) performSQLQuery: (NSString *) sql;
- (NSDictionary *) lookupRecord: (NSString *) path
               newerThanVersion: (NSInteger) startVersion;

- (NSArray *) cacheEntriesForDeviceId: (NSString *) deviceId
                     newerThanVersion: (NSInteger) startVersion;

- (void) setObjectType: (SOGoCacheObjectType) newObjectType;
- (SOGoCacheObjectType) objectType; /* message, fai, folder */

/* automatically set from actions */
- (BOOL) deleted;

- (void) changePathTo: (NSString *) newPath;

/* db helpers */
- (EOAdaptor *) tableChannelAdaptor;
- (NSArray *) performSQLQuery: (NSString *) sql;
- (BOOL) performBatchSQLQueries: (NSArray *) queries;

@end

#endif /* SOGOCACHEGCSOBJECT_H */
