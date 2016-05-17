/* MAPIStoreMessage.h - this file is part of SOGo
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

#ifndef MAPISTOREMESSAGE_H
#define MAPISTOREMESSAGE_H

#import <Foundation/NSObject.h>

@class NSArray;
@class NSMutableArray;
@class NSMutableDictionary;

@class EOQualifier;

@class MAPIStoreAttachment;
@class MAPIStoreAttachmentTable;
@class MAPIStoreFolder;

#import "MAPIStoreSOGoObject.h"

@interface MAPIStoreMessage : MAPIStoreSOGoObject
{
  NSArray *attachmentKeys;
  NSMutableDictionary *attachmentParts;
  NSMutableArray *activeTables;
  NSArray *activeUserRoles;
}

- (void) getMessageData: (struct mapistore_message **) dataPtr
               inMemCtx: (TALLOC_CTX *) memCtx;

- (enum mapistore_error) modifyRecipientsWithRecipients: (struct mapistore_message_recipient *) recipients
                                               andCount: (NSUInteger) max
                                             andColumns: (struct SPropTagArray *) columns;
- (NSArray *) attachmentKeys;
- (NSArray *) attachmentKeysMatchingQualifier: (EOQualifier *) qualifier
                             andSortOrderings: (NSArray *) sortOrderings;
- (id) lookupAttachment: (NSString *) childKey;

/* backend methods */
- (enum mapistore_error) createAttachment: (MAPIStoreAttachment **) attachmentPtr
                                    inAID: (uint32_t *) aidPtr;
- (enum mapistore_error) getAttachment: (MAPIStoreAttachment **) attachmentPtr
                               withAID: (uint32_t) aid;
- (enum mapistore_error) getAttachmentTable: (MAPIStoreAttachmentTable **) tablePtr
                                andRowCount: (uint32_t *) countPtr;
- (enum mapistore_error) setReadFlag: (uint8_t) flag;
- (enum mapistore_error) saveMessage: (TALLOC_CTX *) memCtx;

- (NSArray *) activeContainerMessageTables;

- (NSArray *) activeUserRoles;
- (NSArray *) expandRoles: (NSArray *) roles;

/* move & copy internal ops */
- (void) copyToMessage: (MAPIStoreMessage *) newMessage  inMemCtx: (TALLOC_CTX *) memCtx;

/* subclasses */
- (void) save: (TALLOC_CTX *) memCtx;

/* attachments (subclasses) */
- (MAPIStoreAttachment *) createAttachment;
- (MAPIStoreAttachmentTable *) attachmentTable;

- (BOOL) subscriberCanReadMessage;
- (BOOL) subscriberCanModifyMessage;
- (BOOL) subscriberCanDeleteMessage;

@end

#endif /* MAPISTOREMESSAGE_H */
