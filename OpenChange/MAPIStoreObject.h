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

#include <talloc.h>

#import <Foundation/NSObject.h>

@class NSDate;
@class NSData;
@class NSString;
@class NSMutableArray;
@class NSMutableDictionary;

@class EOQualifier;

@class MAPIStoreContext;
@class MAPIStoreFolder;
@class MAPIStoreMapping;
@class MAPIStoreTable;
@class MAPIStoreUserContext;

@interface MAPIStoreObject : NSObject
{
  const IMP *classGetters;

  NSMutableArray *parentContainersBag;
  MAPIStoreObject *container;
  id sogoObject;
  NSMutableDictionary *properties;
  BOOL isNew;
}

+ (id) mapiStoreObjectWithSOGoObject: (id) newSOGoObject
                         inContainer: (MAPIStoreObject *) newContainer;
+ (int) getAvailableProperties: (struct SPropTagArray **) propertiesP
                      inMemCtx: (TALLOC_CTX *) memCtx;

- (id) initWithSOGoObject: (id) newSOGoObject
              inContainer: (MAPIStoreObject *) newFolder;

- (void) setIsNew: (BOOL) newIsNew;
- (BOOL) isNew;

- (NSString *) nameInContainer;

- (id) sogoObject;
- (MAPIStoreObject *) container;

- (MAPIStoreContext *) context;
- (MAPIStoreUserContext *) userContext;
- (MAPIStoreMapping *) mapping;

- (void) cleanupCaches;

- (uint64_t) objectId;
- (NSString *) url;

- (NSTimeZone *) ownerTimeZone;

/* properties */

- (BOOL) canGetProperty: (enum MAPITAGS) propTag;

- (void) addProperties: (NSDictionary *) newProperties;
- (NSDictionary *) properties;

/* ops */
- (int) getAvailableProperties: (struct SPropTagArray **) propertiesP
                      inMemCtx: (TALLOC_CTX *) localMemCtx;
- (int) getProperties: (struct mapistore_property_data *) data
             withTags: (enum MAPITAGS *) tags
             andCount: (uint16_t) columnCount
             inMemCtx: (TALLOC_CTX *) localMemCtx;

- (int) addPropertiesFromRow: (struct SRow *) aRow;

- (int) getProperty: (void **) data
            withTag: (enum MAPITAGS) propTag
           inMemCtx: (TALLOC_CTX *) localMemCtx;

/* helper getters */
- (NSData *) getReplicaKeyFromGlobCnt: (uint64_t) objectCnt;
- (int) getReplicaKey: (void **) data
          fromGlobCnt: (uint64_t) objectCnt
             inMemCtx: (TALLOC_CTX *) memCtx;

/* implemented getters */
- (int) getPidTagDisplayName: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagSearchKey: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagGenerateExchangeViews: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagParentSourceKey: (void **) data
                        inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagSourceKey: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagChangeKey: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagCreationTime: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagLastModificationTime: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx;

/* subclasses */
- (uint64_t) objectVersion;
- (NSDate *) creationTime;
- (NSDate *) lastModificationTime;

@end

#endif /* MAPISTOREOBJECT_H */
