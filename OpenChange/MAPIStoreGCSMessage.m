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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>
#import <NGObjWeb/SoSecurityManager.h>
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

- (int) getPidTagAccess: (void **) data // TODO
               inMemCtx: (TALLOC_CTX *) memCtx
{
  MAPIStoreContext *context;
  WOContext *woContext;
  SoSecurityManager *sm;
  MAPIStoreUserContext *userContext;
  uint32_t access;

  context = [self context];
  userContext = [self userContext];
  if ([[context activeUser] isEqual: [userContext sogoUser]])
    access = 0x03;
  else
    {
      sm = [SoSecurityManager sharedSecurityManager];
      woContext = [userContext woContext];

      access = 0;
      if (![sm validatePermission: SoPerm_ChangeImagesAndFiles
                         onObject: sogoObject
                        inContext: woContext])
        access |= 1;
      if (![sm validatePermission: SoPerm_AccessContentsInformation
                         onObject: sogoObject
                        inContext: woContext])
        access |= 2;
      if (![sm validatePermission: SOGoPerm_DeleteObject
                         onObject: sogoObject
                        inContext: woContext])
        access |= 4;
    }
  *data = MAPILongValue (memCtx, access);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagAccessLevel: (void **) data // TODO
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  MAPIStoreContext *context;
  MAPIStoreUserContext *userContext;
  WOContext *woContext;
  SoSecurityManager *sm;
  uint32_t accessLvl;

  context = [self context];
  userContext = [self userContext];
  if ([[context activeUser] isEqual: [userContext sogoUser]])
    accessLvl = 1;
  else
    {
      sm = [SoSecurityManager sharedSecurityManager];
      woContext = [userContext woContext];
      if (![sm validatePermission: SoPerm_ChangeImagesAndFiles
                         onObject: sogoObject
                        inContext: woContext])
        accessLvl = 1;
      else
        accessLvl = 0;
    }
  *data = MAPILongValue (memCtx, accessLvl);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagChangeKey: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;
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
      if (!changeKey)
        abort ();
      *data = [changeKey asBinaryInMemCtx: memCtx];
    }

  return rc;
}

- (int) getPidTagPredecessorChangeList: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;
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
 
  if (!isNew)
    {
      changeNumber = [(MAPIStoreGCSFolder *) container
                        changeNumberForMessageWithKey: [self nameInContainer]];
      if (!changeNumber)
        {
          [self warnWithFormat: @"attempting to get change number"
                @" by synchronising folder..."];
          [(MAPIStoreGCSFolder *) container synchroniseCache];
          changeNumber = [(MAPIStoreGCSFolder *) container
                            changeNumberForMessageWithKey: [self nameInContainer]];
          
          if (changeNumber)
            [self logWithFormat: @"got one"];
          else
            {
              [self errorWithFormat: @"still nothing. We crash!"];
              abort();
            }
        }
      version = [changeNumber unsignedLongLongValue] >> 16;
    }

  return version;
}

- (void) updateVersions
{
  NSData *newChangeKey;

  newChangeKey = [properties objectForKey: MAPIPropertyKey (PR_CHANGE_KEY)];

  [(MAPIStoreGCSFolder *) container
    updateVersionsForMessageWithKey: [self nameInContainer]
                      withChangeKey: newChangeKey];
}

@end
