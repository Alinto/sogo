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

#import <Foundation/NSObject.h>

#define SENSITIVITY_NONE 0
#define SENSITIVITY_PERSONAL 1
#define SENSITIVITY_PRIVATE 2
#define SENSITIVITY_COMPANY_CONFIDENTIAL 3

#define TBL_LEAF_ROW 0x00000001
#define TBL_EMPTY_CATEGORY 0x00000002
#define TBL_EXPANDED_CATEGORY 0x00000003
#define TBL_COLLAPSED_CATEGORY 0x00000004

typedef enum {
  MAPIRestrictionStateAlwaysFalse = NO,
  MAPIRestrictionStateAlwaysTrue = YES,
  MAPIRestrictionStateNeedsEval,    /* needs passing of qualifier to underlying
				       database */
} MAPIRestrictionState;

@class NSArray;
@class NSString;
@class EOQualifier;

@interface MAPIStoreTable : NSObject
{
  id context;
  struct mapistore_context *memCtx;
  void *ldbCtx;

  id folder;
  NSString *folderURL;
  uint64_t fid;

  id lastChild;
  NSString *lastChildKey;

  NSArray *cachedKeys;
  NSArray *cachedRestrictedKeys;
  EOQualifier *restriction; /* should probably be a dictionary too */
  MAPIRestrictionState restrictionState;
}

- (id) folder;

- (void) setContext: (id) newContext
	 withMemCtx: (struct mapistore_context *) newMemCtx;
- (void) setFolder: (id) newFolder
	   withURL: (NSString *) newFolderURL
	    andFID: (uint64_t) newFid;

- (void) setRestrictions: (const struct mapi_SRestriction *) res;

- (NSArray *) cachedChildKeys;
- (NSArray *) cachedRestrictedChildKeys;

- (id) lookupChild: (NSString *) childKey;

- (void) cleanupCaches;

- (enum MAPISTATUS) getChildProperty: (void **) data
			      forKey: (NSString *) childKey
			     withTag: (enum MAPITAGS) proptag;

/* helpers */

- (void) warnUnhandledProperty: (enum MAPITAGS) property
                    inFunction: (const char *) function;

/* subclasses */

- (NSArray *) childKeys;
- (NSArray *) restrictedChildKeys;

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
