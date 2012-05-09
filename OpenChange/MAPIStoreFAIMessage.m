/* MAPIStoreFAIMessage.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
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

#import "MAPIStoreActiveTables.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreUserContext.h"
#import "NSObject+MAPIStore.h"

#import "MAPIStoreFAIMessage.h"

#undef DEBUG
#include <stdbool.h>
#include <talloc.h>
#include <util/time.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreFAIMessage

- (NSArray *) activeContainerMessageTables
{
  return [[MAPIStoreActiveTables activeTables]
             activeTablesForFMID: [container objectId]
                         andType: MAPISTORE_FAI_TABLE];
}

- (int) getPidTagAssociated: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getYes: data inMemCtx: memCtx];
}

- (enum mapistore_error) saveMessage
{
  enum mapistore_error rc;
  MAPIStoreContext *context;
  SOGoUser *ownerUser;

  context = [self context];
  ownerUser = [[self userContext] sogoUser];
  if ([[context activeUser] isEqual: ownerUser])
    rc = [super saveMessage];
  else
    rc = MAPISTORE_ERR_DENIED;

  return rc;
}

- (BOOL) subscriberCanReadMessage
{
  return NO;
}

- (BOOL) subscriberCanModifyMessage
{
  return NO;
}

@end
