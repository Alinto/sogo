/* MAPIStoreMessage.h - this file is part of SOGo
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

#ifndef MAPISTOREMESSAGE_H
#define MAPISTOREMESSAGE_H

#import <Foundation/NSObject.h>

@class NSMutableArray;
@class NSMutableDictionary;

@class MAPIStoreAttachment;
@class MAPIStoreAttachmentTable;
@class MAPIStoreFolder;

#import "MAPIStoreObject.h"

@interface MAPIStoreMessage : MAPIStoreObject
{
  NSMutableArray *attachmentKeys;
  NSMutableDictionary *attachmentParts;
  NSMutableArray *activeTables;
}

- (void) getMessageData: (struct mapistore_message **) dataPtr
               inMemCtx: (TALLOC_CTX *) memCtx;

- (int) modifyRecipientsWithRows: (struct ModifyRecipientRow *) rows
                        andCount: (NSUInteger) max;

- (int) createAttachment: (MAPIStoreAttachment **) attachmentPtr
                   inAID: (uint32_t *) aidPtr;
- (int) getAttachment: (MAPIStoreAttachment **) attachmentPtr
              withAID: (uint32_t) aid;
- (int) getAttachmentTable: (MAPIStoreAttachmentTable **) tablePtr
               andRowCount: (uint32_t *) countPtr;
- (int) saveMessage;

/* helper getters */
- (int) getSMTPAddrType: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx;
- (NSArray *) activeContainerMessageTables;

/* subclasses */
- (void) save;

/* attachments (subclasses) */
- (MAPIStoreAttachment *) createAttachment;
- (MAPIStoreAttachmentTable *) attachmentTable;

@end

#endif /* MAPISTOREMESSAGE_H */
