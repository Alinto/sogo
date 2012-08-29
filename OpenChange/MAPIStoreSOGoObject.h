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

#ifndef MAPISTORESOGOOBJECT_H
#define MAPISTORESOGOOBJECT_H

#include <talloc.h>

#import "MAPIStoreObject.h"

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

@interface MAPIStoreSOGoObject : MAPIStoreObject
{
  id sogoObject;
  BOOL isNew;
}

+ (id) mapiStoreObjectWithSOGoObject: (id) newSOGoObject
                         inContainer: (MAPIStoreObject *) newContainer;

- (id) initWithSOGoObject: (id) newSOGoObject
              inContainer: (MAPIStoreObject *) newFolder;

- (void) setIsNew: (BOOL) newIsNew;
- (BOOL) isNew;

- (id) sogoObject;

- (MAPIStoreObject *) container;

- (void) cleanupCaches;

- (uint64_t) objectId;

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

/* subclasses */
- (uint64_t) objectVersion;

@end

#endif /* MAPISTORESOGOOBJECT_H */
