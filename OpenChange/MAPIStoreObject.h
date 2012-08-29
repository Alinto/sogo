/* MAPIStoreObject.h - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
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

@class MAPIStoreContext;
@class MAPIStoreMapping;
@class MAPIStoreObjectProxy;
@class MAPIStoreUserContext;
@class MAPIStoreSOGoObject;

@interface MAPIStoreObject : NSObject
{
  const IMP *classGetters;

  NSMutableArray *parentContainersBag;
  NSMutableArray *proxies;
  id container;
  NSMutableDictionary *properties;
}

+ (id) mapiStoreObjectInContainer: (MAPIStoreObject *) newContainer;
- (id) initInContainer: (MAPIStoreObject *) newContainer;

- (void) addProxy: (MAPIStoreObjectProxy *) newProxy;

- (MAPIStoreObject *) container;

- (MAPIStoreContext *) context;
- (MAPIStoreUserContext *) userContext;
- (MAPIStoreMapping *) mapping;

- (NSString *) url;

/* properties */

- (void) addProperties: (NSDictionary *) newProperties;
- (NSMutableDictionary *) properties;

/* ops */
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

- (int) getPidTagCreationTime: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagLastModificationTime: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx;

/* move and copy operations */
- (void) copyPropertiesToObject: (MAPIStoreObject *) newObject;

/* subclasses */
- (NSString *) nameInContainer;
- (NSDate *) creationTime;
- (NSDate *) lastModificationTime;

@end

#endif /* MAPISTOREOBJECT_H */
