/* MAPIStoreGCSMessage.m - this file is part of SOGo
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

#import <Foundation/NSValue.h>
#import <NGExtensions/NSObject+Logs.h>
#import <SOGo/SOGoContentObject.h>

#import "MAPIStoreContext.h"
#import "MAPIStoreGCSFolder.h"
#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"

#import "MAPIStoreGCSMessage.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreGCSMessage

- (NSCalendarDate *) creationTime
{
  return [sogoObject creationDate];
}

- (NSCalendarDate *) lastModificationTime
{
  return [sogoObject lastModified];
}

- (int) getPrChangeKey: (void **) data
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

- (int) getPrPredecessorChangeList: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;
  NSData *changeList;

  if (isNew)
    rc = MAPISTORE_ERR_NOT_FOUND;
  else
    {
      changeList = [(MAPIStoreGCSFolder *)[self container]
                                          predecessorChangeListForMessageWithKey: [self nameInContainer]];
      if (!changeList)
        abort ();
      *data = [changeList asBinaryInMemCtx: memCtx];
    }

  return rc;
}

- (uint64_t) objectVersion
{
  uint64_t version = 0xffffffffffffffffLL;
  NSNumber *changeNumber;
 
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

@end
