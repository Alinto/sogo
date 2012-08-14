/* SOGoMAPIDBObject.h - this file is part of SOGo
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

#ifndef SOGOMAPIDBOBJECT_H
#define SOGOMAPIDBOBJECT_H

#import "SOGoMAPIObject.h"

@class NSArray;
@class NSMutableDictionary;
@class NSMutableString;
@class NSString;
@class NSURL;

@class EOAdaptor;

typedef enum {
  MAPIDBObjectTypeFolder = 1,
  MAPIDBObjectTypeMessage = 2,
  MAPIDBObjectTypeFAI = 3,
  MAPIDBObjectTypeInternal = 99 /* object = property list */
} MAPIDBObjectType;

@interface SOGoMAPIDBObject : SOGoMAPIObject
{
  NSURL *tableUrl;

  BOOL initialized; /* safe guard */
  MAPIDBObjectType objectType;
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

- (void) setObjectType: (MAPIDBObjectType) newObjectType;
- (MAPIDBObjectType) objectType; /* message, fai, folder */

/* automatically set from actions */
- (BOOL) deleted;

- (void) changePathTo: (NSString *) newPath;

/* db helpers */
- (EOAdaptor *) tableChannelAdaptor;
- (NSArray *) performSQLQuery: (NSString *) sql;
- (BOOL) performBatchSQLQueries: (NSArray *) queries;

@end

#endif /* SOGOMAPIDBOBJECT_H */
