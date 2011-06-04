/* MAPIStoreAttachment.m - this file is part of $PROJECT_NAME_HERE$
 *
 * Copyright (C) 2011 Inverse inc
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

- (int) getProperty: (void **) data
            withTag: (enum MAPITAGS) propTag
{
  int rc;

  rc = MAPISTORE_SUCCESS;
  switch (propTag)
    {
    case PR_MID:
      *data = MAPILongLongValue (memCtx, [container objectId]);
      break;
    case PR_ATTACH_NUM:
      *data = MAPILongValue (memCtx, aid);
      break;
    case PR_RENDERING_POSITION:
      *data = MAPILongValue (memCtx, 0xffffffff);
      break;

    default:
      rc = MAPISTORE_ERR_NOT_FOUND;
    }

  return rc;
}

- (int) openEmbeddedMessage: (void **) message
                    withMID: (uint64_t *) mid
           withMAPIStoreMsg: (struct mapistore_message *) mapistoreMsg
                   andFlags: (enum OpenEmbeddedMessage_OpenModeFlags) flags
{
  MAPIStoreAttachmentMessage *attMessage;
  MAPIStoreMapping *mapping;

  memset (mapistoreMsg, 0, sizeof (struct mapistore_message));

  mapping = [[self context] mapping];

  attMessage = [self openEmbeddedMessage];
  if (attMessage)
    *mid = [mapping idFromURL: [attMessage url]];
  else if (flags == MAPI_CREATE)
    {
      attMessage = [self createEmbeddedMessage];
      if (attMessage)
        [mapping registerURL: [attMessage url]
                      withID: *mid];
    }
  *message = attMessage;
  [attMessage retain];

  return (attMessage ? MAPISTORE_SUCCESS : MAPISTORE_ERROR);
}

/* subclasses */
- (MAPIStoreAttachmentMessage *) openEmbeddedMessage
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (MAPIStoreAttachmentMessage *) createEmbeddedMessage
{
  [self subclassResponsibility: _cmd];

  return nil;
}

@end
