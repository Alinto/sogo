/* MAPIStoreAttachment.m - this file is part of SOGo
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

#import <Foundation/NSData.h>

#import "MAPIStoreAttachment.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreMessage.h"
#import "MAPIStoreTypes.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreAttachment

- (void) setAID: (uint32_t) newAID
{
  aid = newAID;
}

- (uint32_t) AID
{
  return aid;
}

- (NSString *) nameInContainer
{
  return [NSString stringWithFormat: @"%d", aid];
}

- (NSData *) mimeAttachTag
{
  static NSData *mimeAttachTag = nil;
  char tagBytes[] = {0x2a, 0x86, 0x48, 0x86, 0xf7, 0x14, 0x03, 0x0a, 0x04};

  if (!mimeAttachTag)
    {
      mimeAttachTag = [NSData dataWithBytes: tagBytes length: 9];
      [mimeAttachTag retain];
    }

  return mimeAttachTag;
}

- (int) getPidTagMid: (void **) data
            inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongLongValue (memCtx, [container objectId]);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagAttachNumber: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, aid);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagRenderingPosition: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0xffffffff);

  return MAPISTORE_SUCCESS;
}

- (int) openEmbeddedMessage: (MAPIStoreAttachmentMessage **) messagePtr
                    withMID: (uint64_t *) mid
           withMAPIStoreMsg: (struct mapistore_message **) mapistoreMsgPtr
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  MAPIStoreAttachmentMessage *attMessage;
  MAPIStoreMapping *mapping;
  struct mapistore_message *mapistoreMsg;
  
  mapistoreMsg = talloc_zero (memCtx, struct mapistore_message);

  mapping = [self mapping];

  attMessage = [self openEmbeddedMessage];
  if (attMessage)
    {
      *mid = [mapping idFromURL: [attMessage url]];
      *messagePtr = attMessage;
      *mapistoreMsgPtr = mapistoreMsg;
    }
  // else if (flags == MAPI_CREATE)
  //   {
  //     attMessage = [self createEmbeddedMessage];
  //     if (attMessage)
  //       [mapping registerURL: [attMessage url]
  //                     withID: *mid];
  //   }

  return (attMessage ? MAPISTORE_SUCCESS : MAPISTORE_ERROR);
}

- (NSDate *) creationTime
{
  return [container creationTime];
}

- (NSDate *) lastModificationTime
{
  return [container lastModificationTime];
}

- (uint64_t) objectVersion
{
  /* attachments have no version number */
  return ULLONG_MAX;
}

/* subclasses */
- (MAPIStoreAttachmentMessage *) openEmbeddedMessage
{
  // [self subclassResponsibility: _cmd];

  return nil;
}

- (MAPIStoreAttachmentMessage *) createEmbeddedMessage
{
  [self subclassResponsibility: _cmd];

  return nil;
}

@end
