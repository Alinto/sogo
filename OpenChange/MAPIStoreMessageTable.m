/* MAPIStoreMessageTable.m - this file is part of SOGo
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

#import <SOGo/SOGoFolder.h>
#import <SOGo/SOGoObject.h>

#import "MAPIStoreContext.h"
#import "MAPIStoreFolder.h"
#import "MAPIStoreMessage.h"
#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreMessageTable.h"

@implementation MAPIStoreMessageTable

- (void) setSortOrder: (const struct SSortOrderSet *) set
{
  [self logWithFormat: @"unimplemented method: %@", NSStringFromSelector (_cmd)];
}

- (NSArray *) childKeys
{
  if (!childKeys)
    {
      childKeys = [(MAPIStoreFolder *)
                    container messageKeysMatchingQualifier: nil
                                          andSortOrderings: sortOrderings];
      [childKeys retain];
    }

  return childKeys;
}

- (NSArray *) restrictedChildKeys
{
  NSArray *keys;

  if (!restrictedChildKeys)
    {
      if (restrictionState != MAPIRestrictionStateAlwaysTrue)
        {
          if (restrictionState == MAPIRestrictionStateNeedsEval)
            keys = [(MAPIStoreFolder *)
                     container messageKeysMatchingQualifier: restriction
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

- (id) lookupChild: (NSString *) childKey
{
  return [(MAPIStoreFolder *) container lookupMessage: childKey];
}

- (void) notifyChangesForChild: (MAPIStoreMessage *) child
{
  NSUInteger currentChildRow, newChildRow;
  NSArray *list;
  NSString *childName;
  struct mapistore_table_notification_parameters notif_parameters;
  struct mapistore_context *mstoreCtx;

  mstoreCtx = [[(MAPIStoreFolder *) container context]
                connectionInfo]->mstore_ctx;

  notif_parameters.table_type = tableType;
  notif_parameters.handle = handleId;
  notif_parameters.folder_id = [(MAPIStoreFolder *) container objectId];
  notif_parameters.object_id = [child objectId];
  notif_parameters.instance_id = 0; /* TODO: always 0 ? */

  childName = [child nameInContainer];
  list = [self restrictedChildKeys];
  currentChildRow = [list indexOfObject: childName];
  notif_parameters.row_id = currentChildRow;

  [self cleanupCaches];
  list = [self restrictedChildKeys];
  newChildRow = [list indexOfObject: childName];

  if (currentChildRow == NSNotFound)
    {
      if (newChildRow != NSNotFound)
        {
          notif_parameters.row_id = newChildRow;
          mapistore_push_notification (mstoreCtx,
                                       MAPISTORE_TABLE,
                                       MAPISTORE_OBJECT_CREATED,
                                       &notif_parameters);
        }
    }
  else
    {
      if (newChildRow == NSNotFound)
        mapistore_push_notification (mstoreCtx,
                                     MAPISTORE_TABLE,
                                     MAPISTORE_OBJECT_DELETED,
                                     &notif_parameters);
      else
        {
          /* the fact that the row order has changed has no impact here */
          notif_parameters.row_id = newChildRow;
          mapistore_push_notification (mstoreCtx,
                                       MAPISTORE_TABLE,
                                       MAPISTORE_OBJECT_MODIFIED,
                                       &notif_parameters);
        }
    }
}

@end
