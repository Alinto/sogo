/* MAPIStoreFolderTable.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2012 Inverse inc
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

#import <NGExtensions/NSObject+Logs.h>

#import "MAPIStoreFolder.h"
#import "MAPIStoreTypes.h"

#import "MAPIStoreFolderTable.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_nameid.h>
#include <libmapiproxy.h>

@implementation MAPIStoreFolderTable

- (id) init
{
  if ((self = [super init]))
    {
      tableType = MAPISTORE_FOLDER_TABLE;
    }

  return self;
}

- (NSArray *) childKeys
{
  if (!childKeys)
    {
      childKeys = [(MAPIStoreFolder *)
                    container folderKeysMatchingQualifier: nil
                                         andSortOrderings: sortOrderings];
      [childKeys retain];
    }

  return childKeys;
}

- (NSArray *) restrictedChildKeys
{
  NSArray *keys;

  /* FIXME: restrictions are ignored on folder tables */

  if (!restrictedChildKeys)
    {
      if (restrictionState != MAPIRestrictionStateAlwaysTrue)
        {
          if (restrictionState == MAPIRestrictionStateNeedsEval)
            keys = [(MAPIStoreFolder *)
                     container folderKeysMatchingQualifier: restriction
                                          andSortOrderings: sortOrderings];
          else
            keys = [NSArray array];
        }
      else
        keys = [self childKeys];

      ASSIGN (restrictedChildKeys, keys);
    }

  return restrictedChildKeys;
}

- (MAPIRestrictionState) evaluatePropertyRestriction: (struct mapi_SPropertyRestriction *) res
				       intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState rc;

  switch ((uint32_t) res->ulPropTag)
    {
      /* HACK: we cheat here as we current have no mechanism for searching
         folders based on PR_CHANGE_NUM, which is used by the oxcfxics
         mechanism... */
    case PidTagChangeNumber:
      rc = MAPIRestrictionStateAlwaysTrue;
      break;
    default:
      rc = [super evaluatePropertyRestriction: res intoQualifier: qualifier];
    }

  return rc;
}

- (id) lookupChild: (NSString *) childKey
{
  return [(MAPIStoreFolder *) container lookupFolder: childKey];
}

- (NSString *) backendIdentifierForProperty: (enum MAPITAGS) property
{
  return nil;
}

@end
