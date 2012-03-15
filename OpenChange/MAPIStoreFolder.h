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

@class NSArray;
@class NSMutableArray;
@class NSNumber;

@class EOQualifier;

@class MAPIStoreContext;
@class MAPIStoreMessage;
@class MAPIStoreFAIMessageTable;
@class MAPIStoreFolderTable;
@class MAPIStoreMessageTable;
@class MAPIStorePermissionsTable;
@class SOGoFolder;
@class SOGoMAPIFSFolder;
@class SOGoMAPIFSMessage;

#import "MAPIStoreObject.h"

@interface MAPIStoreFolder : MAPIStoreObject
{
  MAPIStoreContext *context;
  // NSArray *messageKeys;
  // NSArray *faiMessageKeys;
  // NSArray *folderKeys;

  SOGoMAPIFSFolder *faiFolder;
  SOGoMAPIFSFolder *propsFolder;
  SOGoMAPIFSMessage *propsMessage;
}

- (void) setContext: (MAPIStoreContext *) newContext;

- (NSArray *) activeMessageTables;
- (NSArray *) activeFAIMessageTables;

- (SOGoMAPIFSMessage *) propertiesMessage;

- (id) lookupMessageByURL: (NSString *) messageURL;
- (id) lookupFolderByURL: (NSString *) folderURL;

/* permissions */
- (MAPIStorePermissionsTable *) permissionsTable;
- (NSArray *) permissionEntries;

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
- (int) deleteFolder;
- (int) getChildCount: (uint32_t *) rowCount
          ofTableType: (enum mapistore_table_type) tableType;

- (int) createMessage: (MAPIStoreMessage **) messagePtr
              withMID: (uint64_t) mid
         isAssociated: (BOOL) isAssociated;

- (int) openMessage: (MAPIStoreMessage **) messagePtr
            withMID: (uint64_t) mid
         forWriting: (BOOL) readWrite
           inMemCtx: (TALLOC_CTX *) memCtx;
- (int) deleteMessageWithMID: (uint64_t) mid
                    andFlags: (uint8_t) flags;

- (int) moveCopyMessagesWithMIDs: (uint64_t *) srcMids
                        andCount: (uint32_t) count
                      fromFolder: (MAPIStoreFolder *) sourceFolder
                        withMIDs: (uint64_t *) targetMids
                   andChangeKeys: (struct Binary_r **) targetChangeKeys
                        wantCopy: (uint8_t) want_copy;

- (int) getDeletedFMIDs: (struct I8Array_r **) fmidsPtr
                  andCN: (uint64_t *) cnPtr
       fromChangeNumber: (uint64_t) changeNum
            inTableType: (enum mapistore_table_type) tableType
               inMemCtx: (TALLOC_CTX *) mem_ctx;

- (int) getTable: (MAPIStoreTable **) tablePtr
     andRowCount: (uint32_t *) count
       tableType: (enum mapistore_table_type) tableType
     andHandleId: (uint32_t) handleId;

- (int) modifyPermissions: (struct PermissionData *) permissions
                withCount: (uint16_t) pcount
                 andFlags: (int8_t) flags;

/* helpers */
- (uint64_t) idForObjectWithKey: (NSString *) childKey;

/* subclasses */
- (MAPIStoreMessage *) createMessage;
- (MAPIStoreMessageTable *) messageTable;
- (NSArray *) messageKeysMatchingQualifier: (EOQualifier *) qualifier
                          andSortOrderings: (NSArray *) sortOrderings;
- (NSArray *) getDeletedKeysFromChangeNumber: (uint64_t) changeNum
                                       andCN: (NSNumber **) cnNbr
                                 inTableType: (enum mapistore_table_type) tableType;

- (enum mapistore_error) createFolder: (struct SRow *) aRow
                              withFID: (uint64_t) newFID
                               andKey: (NSString **) newKeyP;

- (NSCalendarDate *) lastMessageModificationTime;

- (SOGoFolder *) aclFolder;
- (NSArray *) rolesForExchangeRights: (uint32_t) rights;
- (uint32_t) exchangeRightsForRoles: (NSArray *) roles;

- (BOOL) subscriberCanCreateMessages;
- (BOOL) subscriberCanModifyMessages;
- (BOOL) subscriberCanReadMessages;
- (BOOL) subscriberCanDeleteMessages;
- (BOOL) subscriberCanCreateSubFolders;

- (BOOL) supportsSubFolders; /* capability */

/* subclass helpers */
- (void) setupVersionsMessage;
- (void) postNotificationsForMoveCopyMessagesWithMIDs: (uint64_t *) srcMids
                                       andMessageURLs: (NSArray *) oldMessageURLs
                                             andCount: (uint32_t) midCount
                                           fromFolder: (MAPIStoreFolder *) sourceFolder
                                             withMIDs: (uint64_t *) targetMids
                                             wantCopy: (uint8_t) wantCopy;

@end

#endif /* MAPISTOREFOLDER_H */
