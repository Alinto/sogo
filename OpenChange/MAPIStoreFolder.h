/* MAPIStoreFolder.h - this file is part of SOGo
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

#ifndef MAPISTOREFOLDER_H
#define MAPISTOREFOLDER_H

#import <Foundation/NSObject.h>

#import "MAPIStoreTable.h"

@class NSArray;
@class NSMutableArray;
@class NSNumber;
@class NSURL;

@class EOQualifier;

@class MAPIStoreContext;
@class MAPIStoreMessage;
@class MAPIStoreFAIMessageTable;
@class MAPIStoreFolderTable;
@class MAPIStoreMessageTable;
@class MAPIStorePermissionsTable;
@class SOGoMAPIFSFolder;
@class SOGoMAPIFSMessage;

#import "MAPIStoreObject.h"

@interface MAPIStoreFolder : MAPIStoreObject
{
  NSURL *folderURL;
  MAPIStoreContext *context;
  NSArray *messageKeys;
  NSArray *faiMessageKeys;
  NSArray *folderKeys;

  NSDictionary *properties;

  SOGoMAPIFSFolder *faiFolder;
  SOGoMAPIFSFolder *propsFolder;
  SOGoMAPIFSMessage *propsMessage;
}

+ (id) baseFolderWithURL: (NSURL *) newURL
               inContext: (MAPIStoreContext *) newContext;
- (id) initWithURL: (NSURL *) newURL
         inContext: (MAPIStoreContext *) newContext;

- (NSArray *) activeMessageTables;
- (NSArray *) activeFAIMessageTables;

- (id) lookupMessageByURL: (NSString *) messageURL;
- (id) lookupFolderByURL: (NSString *) folderURL;

/* permissions */
- (MAPIStorePermissionsTable *) permissionsTable;

/* message objects and tables */
- (id) lookupMessage: (NSString *) messageKey;
- (NSArray *) messageKeys;

/* FAI message objects and tables */
- (id) lookupFAIMessage: (NSString *) messageKey;
- (MAPIStoreFAIMessageTable *) faiMessageTable;
- (NSArray *) faiMessageKeys;
- (NSArray *) faiMessageKeysMatchingQualifier: (EOQualifier *) qualifier
                             andSortOrderings: (NSArray *) sortOrderings;

/* folder objects and tables */
- (id) lookupFolder: (NSString *) folderKey;
- (MAPIStoreFolderTable *) folderTable;
- (NSArray *) folderKeys;
- (NSArray *) folderKeysMatchingQualifier: (EOQualifier *) qualifier
                         andSortOrderings: (NSArray *) sortOrderings;

- (MAPIStoreMessage *) createMessage: (BOOL) isAssociated;

/* backend interface */

- (int) openFolder: (MAPIStoreFolder **) childFolderPtr
           withFID: (uint64_t) fid;
- (int) createFolder: (MAPIStoreFolder **) childFolderPtr
             withRow: (struct SRow *) aRow
              andFID: (uint64_t) fid;
- (int) deleteFolderWithFID: (uint64_t) fid;
- (int) getChildCount: (uint32_t *) rowCount
          ofTableType: (uint8_t) tableType;

- (int) createMessage: (MAPIStoreMessage **) messagePtr
              withMID: (uint64_t) mid
         isAssociated: (BOOL) isAssociated;
- (int) openMessage: (MAPIStoreMessage **) messagePtr
     andMessageData: (struct mapistore_message **) dataPtr
            withMID: (uint64_t) mid
           inMemCtx: (TALLOC_CTX *) memCtx;
- (int) deleteMessageWithMID: (uint64_t) mid
                    andFlags: (uint8_t) flags;
- (int) getDeletedFMIDs: (struct I8Array_r **) fmidsPtr
                  andCN: (uint64_t *) cnPtr
       fromChangeNumber: (uint64_t) changeNum
            inTableType: (uint8_t) tableType
               inMemCtx: (TALLOC_CTX *) mem_ctx;

- (int) getTable: (MAPIStoreTable **) tablePtr
     andRowCount: (uint32_t *) count
       tableType: (uint8_t) tableType
     andHandleId: (uint32_t) handleId;

/* helpers */
- (uint64_t) idForObjectWithKey: (NSString *) childKey;

/* subclasses */
- (Class) messageClass;
- (MAPIStoreMessage *) createMessage;
- (MAPIStoreMessageTable *) messageTable;
- (NSArray *) messageKeysMatchingQualifier: (EOQualifier *) qualifier
                          andSortOrderings: (NSArray *) sortOrderings;
- (NSArray *) getDeletedKeysFromChangeNumber: (uint64_t) changeNum
                                       andCN: (NSNumber **) cnNbr
                                 inTableType: (uint8_t) tableType;

- (NSString *) createFolder: (struct SRow *) aRow
                    withFID: (uint64_t) newFID;

- (NSCalendarDate *) lastMessageModificationTime;

@end

#endif /* MAPISTOREFOLDER_H */
