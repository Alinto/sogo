/* MAPIStoreAttachment.h - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
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

#ifndef MAPISTOREATTACHMENT_H
#define MAPISTOREATTACHMENT_H

#import "MAPIStoreObject.h"

@class NSData;
@class MAPIStoreEmbeddedMessage;

@interface MAPIStoreAttachment : MAPIStoreObject
{
  uint32_t aid;
}

- (void) setAID: (uint32_t) newAID;
- (uint32_t) AID;

- (int) openEmbeddedMessage: (MAPIStoreEmbeddedMessage **) messagePtr
                    withMID: (uint64_t *) mid
           withMAPIStoreMsg: (struct mapistore_message **) mapistoreMsgPtr
                   inMemCtx: (TALLOC_CTX *) memCtx;
- (int) createEmbeddedMessage: (MAPIStoreEmbeddedMessage **) messagePtr
             withMAPIStoreMsg: (struct mapistore_message **) mapistoreMsgPtr
                     inMemCtx: (TALLOC_CTX *) memCtx;

/* helpers */
- (NSData *) mimeAttachTag;

/* move & copy operations */
- (void) copyToAttachment: (MAPIStoreAttachment *) newAttachment;

/* subclasses */
- (MAPIStoreEmbeddedMessage *) openEmbeddedMessage;
- (MAPIStoreEmbeddedMessage *) createEmbeddedMessage;

@end

#endif /* MAPISTOREATTACHMENT_H */
