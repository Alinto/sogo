/* MAPIStoreObject.h - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
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

#ifndef MAPISTOREOBJECT_H
#define MAPISTOREOBJECT_H

#import <Foundation/NSObject.h>

@class NSString;
@class NSMutableArray;
@class NSMutableDictionary;

@class EOQualifier;

@class MAPIStoreFolder;
@class MAPIStoreTable;

@interface MAPIStoreObject : NSObject
{
  NSMutableArray *parentContainersBag;
  MAPIStoreObject *container;
  id sogoObject;
  NSMutableDictionary *newProperties;
  void *memCtx;
  BOOL isNew;
}

+ (id) mapiStoreObjectWithSOGoObject: (id) newSOGoObject
                         inContainer: (MAPIStoreObject *) newContainer;
- (id) initWithSOGoObject: (id) newSOGoObject
              inContainer: (MAPIStoreObject *) newFolder;

- (void) setIsNew: (BOOL) newIsNew;
- (BOOL) isNew;

- (NSString *) nameInContainer;

- (id) sogoObject;
- (MAPIStoreObject *) container;

- (id) context;

- (void) cleanupCaches;

- (uint64_t) objectId;
- (NSString *) url;

- (void) addActiveTable: (MAPIStoreTable *) activeTable;
- (void) removeActiveTable: (MAPIStoreTable *) activeTable;

/* properties */

- (void) addNewProperties: (NSDictionary *) newNewProperties;
- (NSDictionary *) newProperties;
- (void) resetNewProperties;

/* ops */
- (int) getProperties: (struct mapistore_property_data *) data
             withTags: (enum MAPITAGS *) tags
             andCount: (uint16_t) columnCount;

- (int) setProperties: (struct SRow *) aRow;

- (int) getProperty: (void **) data
            withTag: (enum MAPITAGS) propTag;

/* subclasses */
- (id) lookupChild: (NSString *) childKey;
- (NSArray *) childKeysMatchingQualifier: (EOQualifier *) qualifier
                        andSortOrderings: (NSArray *) sortOrderings;

@end

#endif /* MAPISTOREOBJECT_H */
