/* MAPIStoreGCSMessage.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
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
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSObject+Values.h>
#import <SOGo/SOGoContentObject.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>

#import "MAPIStoreContext.h"
#import "MAPIStoreGCSFolder.h"
#import "MAPIStoreTypes.h"
#import "MAPIStoreUserContext.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreGCSMessage.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreGCSMessage

- (NSDate *) creationTime
{
  return [sogoObject creationDate];
}

- (NSDate *) lastModificationTime
{
  return [sogoObject lastModified];
}

- (enum mapistore_error) getPidTagCreatorName: (void **) data
                                     inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc;
  NSString *creator;

  creator = [self creator];
  if (creator)
    {
      *data = [creator asUnicodeInMemCtx: memCtx];
      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (enum mapistore_error) getPidTagChangeKey: (void **) data
                                   inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc = MAPISTORE_SUCCESS;
  NSData *changeKey;
  MAPIStoreGCSFolder *parentFolder;
  NSString *nameInContainer;

  if (isNew)
    rc = MAPISTORE_ERR_NOT_FOUND;
  else
    {
      parentFolder = (MAPIStoreGCSFolder *)[self container];
      nameInContainer = [self nameInContainer];
      changeKey = [parentFolder changeKeyForMessageWithKey: nameInContainer];
      if (!changeKey)
        {
          [parentFolder synchroniseCache];
          changeKey = [parentFolder changeKeyForMessageWithKey: nameInContainer];
        }
      if (changeKey)
        *data = [changeKey asBinaryInMemCtx: memCtx];
      else
        {
          [self warnWithFormat: @"No change key for %@ in folder %@",
                nameInContainer,
                [parentFolder url]
           ];
          rc = MAPISTORE_ERR_NOT_FOUND;
        }
    }

  return rc;
}

- (enum mapistore_error) getPidTagPredecessorChangeList: (void **) data
                                               inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc = MAPISTORE_SUCCESS;
  NSData *changeList;
  MAPIStoreGCSFolder *parentFolder;

  if (isNew)
    rc = MAPISTORE_ERR_NOT_FOUND;
  else
    {
      parentFolder = (MAPIStoreGCSFolder *)[self container];
      changeList = [parentFolder
                     predecessorChangeListForMessageWithKey: [self nameInContainer]];
      if (!changeList)
        {
          [parentFolder synchroniseCache];
          changeList = [parentFolder
                         predecessorChangeListForMessageWithKey: [self nameInContainer]];
        }
      if (!changeList)
        abort ();
      *data = [changeList asBinaryInMemCtx: memCtx];
    }

  return rc;
}

- (uint64_t) objectVersion
{
  uint64_t version = ULLONG_MAX;
  NSString *changeNumber;
  BOOL synced;

  if (!isNew)
    {
      changeNumber = [(MAPIStoreGCSFolder *) container
                        changeNumberForMessageWithKey: [self nameInContainer]];
      if (!changeNumber)
        {
          [self warnWithFormat: @"attempting to get change number"
                @" by synchronising folder..."];
          synced = [(MAPIStoreGCSFolder *) container synchroniseCache];
          if (synced)
            {
              changeNumber = [(MAPIStoreGCSFolder *) container
                                changeNumberForMessageWithKey: [self nameInContainer]];
            }
          if (!changeNumber)
            {
              [self warnWithFormat: @"attempting to get change number"
                    @" by synchronising this specific message..."];
              synced = [(MAPIStoreGCSFolder *) container
                        synchroniseCacheFor: [self nameInContainer]];
              if (synced)
                {
                  changeNumber = [(MAPIStoreGCSFolder *) container
                                  changeNumberForMessageWithKey: [self nameInContainer]];
                }
              if (!changeNumber)
                {
                  [self errorWithFormat: @"still nothing. We crash!"];
                  abort();
                }
            }
        }
      version = [changeNumber unsignedLongLongValue] >> 16;
    }

  return version;
}

- (void) updateVersions
{
  /* Update ChangeKey and PredecessorChangeList on message's save */
  NSData *newChangeKey, *predecessorChangeList;

  newChangeKey = [properties objectForKey: MAPIPropertyKey (PR_CHANGE_KEY)];
  predecessorChangeList = [properties objectForKey: MAPIPropertyKey (PR_PREDECESSOR_CHANGE_LIST)];

  [(MAPIStoreGCSFolder *) container
      updateVersionsForMessageWithKey: [self nameInContainer]
                        withChangeKey: newChangeKey
             andPredecessorChangeList: predecessorChangeList];
}

//----------------------
// Sharing
//----------------------

- (NSString *) creator
{
  return [self owner];
}

- (NSString *) owner
{
  return [sogoObject ownerInContext: nil];
}

- (SOGoUser *) ownerUser
{
  NSString *ownerName;
  SOGoUser *owner = nil;

  ownerName = [self owner];
  if ([ownerName length] != 0)
    owner = [SOGoUser userWithLogin: ownerName];

  return owner;
}

- (BOOL) subscriberCanModifyMessage
{
  BOOL rc;
  NSArray *roles;

  roles = [self activeUserRoles];

  if (isNew)
    rc = [roles containsObject: SOGoRole_ObjectCreator];
  else
    rc = [roles containsObject: SOGoRole_ObjectEditor];

  /* Check if the message is owned and it has permission to edit it */
  if (!rc && [roles containsObject: MAPIStoreRightEditOwn])
    rc = [[[container context] activeUser] isEqual: [self ownerUser]];

  return rc;
}

- (BOOL) subscriberCanDeleteMessage
{
  BOOL rc;
  NSArray *roles;

  roles = [self activeUserRoles];
  rc = [roles containsObject: SOGoRole_ObjectEraser];

  /* Check if the message is owned and it has permission to delete it */
  if (!rc && [roles containsObject: MAPIStoreRightDeleteOwn])
    {
      NSString *currentUser;

      currentUser = [[container context] activeUser];
      rc = [currentUser isEqual: [self ownerUser]];
    }

  return rc;
}

@end
