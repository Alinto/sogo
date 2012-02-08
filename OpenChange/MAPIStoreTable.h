/* MAPIStoreTable.h - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc
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

#ifndef MAPISTORETABLE_H
#define MAPISTORETABLE_H

#include <talloc.h>

#import <Foundation/NSObject.h>

#undef DEBUG
#include <mapistore/mapistore.h>

#define SENSITIVITY_NONE 0
#define SENSITIVITY_PERSONAL 1
#define SENSITIVITY_PRIVATE 2
#define SENSITIVITY_COMPANY_CONFIDENTIAL 3

typedef enum {
  MAPIRestrictionStateAlwaysFalse = NO,
  MAPIRestrictionStateAlwaysTrue = YES,
  MAPIRestrictionStateNeedsEval,    /* needs passing of qualifier to underlying
				       database */
} MAPIRestrictionState;

@class NSArray;
@class NSMutableArray;
@class NSString;
@class EOQualifier;

@class MAPIStoreObject;

@interface MAPIStoreTable : NSObject
{
  MAPIStoreObject *container;

  uint32_t handleId; /* hack for identifying tables during notifications */

  NSArray *childKeys;
  NSArray *restrictedChildKeys;

  EOQualifier *restriction; /* should probably be a dictionary too */
  MAPIRestrictionState restrictionState;
  NSMutableArray *sortOrderings;

  uint32_t currentRow;
  MAPIStoreObject *currentChild;

  enum mapistore_table_type tableType; /* mapistore */

  /* proof of concept */
  uint16_t columnsCount;
  enum MAPITAGS *columns;
}

+ (id) tableForContainer: (MAPIStoreObject *) newContainer;
+ (Class) childObjectClass;

- (id) initForContainer: (MAPIStoreObject *) newContainer;

- (id) container;
- (enum mapistore_table_type) tableType;

- (void) setHandleId: (uint32_t) newHandleId;
- (void) destroyHandle: (uint32_t) handleId;

- (id) childAtRowID: (uint32_t) rowId
       forQueryType: (enum mapistore_query_type) queryType;

- (void) cleanupCaches;

- (int) getAvailableProperties: (struct SPropTagArray **) propertiesP
                      inMemCtx: (TALLOC_CTX *) localMemCtx;
- (void) setRestrictions: (const struct mapi_SRestriction *) res;
- (int) setColumns: (enum MAPITAGS *) newColumns
         withCount: (uint16_t) newColumCount;
- (int) getRow: (struct mapistore_property_data **) dataP
     withRowID: (uint32_t) rowId
  andQueryType: (enum mapistore_query_type) queryType
      inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getRowCount: (uint32_t *) countP
      withQueryType: (enum mapistore_query_type) queryType;

- (void) notifyChangesForChild: (MAPIStoreObject *) child;

/* helpers */

- (SEL) operatorFromRestrictionOperator: (uint32_t) resOp;
- (void) warnUnhandledProperty: (enum MAPITAGS) property
                    inFunction: (const char *) function;

/* subclasses */
- (NSArray *) childKeys;
- (NSArray *) restrictedChildKeys;

- (id) lookupChild: (NSString *) childKey;

- (void) setSortOrder: (const struct SSortOrderSet *) set;

- (NSString *) backendIdentifierForProperty: (enum MAPITAGS) property;
- (MAPIRestrictionState) evaluateContentRestriction: (const struct mapi_SContentRestriction *) res
				      intoQualifier: (EOQualifier **) qualifier;
- (MAPIRestrictionState) evaluatePropertyRestriction: (const struct mapi_SPropertyRestriction *) res
				       intoQualifier: (EOQualifier **) qualifier;
- (MAPIRestrictionState) evaluateBitmaskRestriction: (const struct mapi_SBitmaskRestriction *) res
				      intoQualifier: (EOQualifier **) qualifier;
- (MAPIRestrictionState) evaluateExistRestriction: (const struct mapi_SExistRestriction *) res
				    intoQualifier: (EOQualifier **) qualifier;

@end

#endif /* MAPISTORETABLE_H */
