/* MAPIStoreEmbeddedMessage.m - this file is part of SOGo
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

#import <Foundation/NSString.h>

#import "MAPIStoreAttachment.h"
#import "MAPIStoreFolder.h"
#import "NSObject+MAPIStore.h"

#import "MAPIStoreEmbeddedMessage.h"

#include <mapistore/mapistore_errors.h>

static Class MAPIStoreAttachmentK;

@implementation MAPIStoreEmbeddedMessage

+ (void) initialize
{
  MAPIStoreAttachmentK = [MAPIStoreAttachment class];
}

- (uint64_t) objectId
{
  NSString *objectKey;
  MAPIStoreMessage *grandParent;

  grandParent = (MAPIStoreMessage *) [container container];

  /* FIXME: this is a hack */
  objectKey = [NSString stringWithFormat: @"%@/%@/as-message",
                        [grandParent nameInContainer],
                        [container nameInContainer], 
                        [self nameInContainer]];

  return [(MAPIStoreFolder *) [grandParent container]
           idForObjectWithKey: objectKey];
}

- (int) getPidTagAccessLevel: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

/* disabled properties */
- (int) getPidTagFolderId: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidTagChangeKey: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidTagSourceKey: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidTagParentSourceKey: (void **) data
                        inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidTagChangeNumber: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidTagInstID: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidTagInstanceNum: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidTagRowType: (void **) data
                inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidTagDepth: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidTagIconIndex: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidTagGenerateExchangeViews: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidTagOriginalMessageClass: (void **) dataa
                             inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

/* common methods */
- (NSString *) nameInContainer
{
  return @"as-message";
}

- (uint64_t) objectVersion
{
  return ULLONG_MAX;
}

- (void) save
{
  [self subclassResponsibility: _cmd];
}

@end
