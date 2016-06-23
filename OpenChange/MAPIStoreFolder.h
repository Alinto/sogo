/* MAPIStoreFolder.h - this file is part of SOGo
 *
 * Copyright (C) 2011-2014 Inverse inc
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
#import <Foundation/NSString.h>

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
@class SOGoCacheGCSFolder;
@class SOGoMAPIDBMessage;

#import "MAPIStoreSOGoObject.h"

/* MAPI Permissions

   This set has only sogo-openchange library scope
 */
extern NSString *MAPIStoreRightReadItems;
extern NSString *MAPIStoreRightCreateItems;
extern NSString *MAPIStoreRightEditOwn;
extern NSString *MAPIStoreRightEditAll;
extern NSString *MAPIStoreRightDeleteOwn;
extern NSString *MAPIStoreRightDeleteAll;
extern NSString *MAPIStoreRightCreateSubfolders;
extern NSString *MAPIStoreRightFolderOwner;
extern NSString *MAPIStoreRightFolderContact;

@interface MAPIStoreFolder : MAPIStoreSOGoObject
{
  MAPIStoreContext *context;
  // NSArray *messageKeys;
  // NSArray *faiMessageKeys;
  // NSArray *folderKeys;

  SOGoCacheGCSFolder *dbFolder;
  // SOGoMAPIDBFolder *faiFolder;
  // SOGoMAPIDBFolder *propsFolder;
  // SOGoMAPIDBMessage *propsMessage;
}

- (void) setContext: (MAPIStoreContext *) newContext;

- (void) setupAuxiliaryObjects;

- (SOGoCacheGCSFolder *) dbFolder;

- (NSArray *) activeMessageTables;
- (NSArray *) activeFAIMessageTables;

// - (SOGoMAPIDBMessage *) propertiesMessage;

- (NSString *) childKeyFromURL: (NSString *) childURL;

- (id) lookupMessageByURL: (NSString *) messageURL;
- (id) lookupFolderByURL: (NSString *) folderURL;

/* permissions */
- (MAPIStorePermissionsTable *) permissionsTable;
- (NSArray *) permissionEntries;

- (NSArray *) expandRoles: (NSArray *) roles;

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

- (enum mapistore_error) openFolder: (MAPIStoreFolder **) childFolderPtr
                            withFID: (uint64_t) fid;
- (enum mapistore_error) createFolder: (MAPIStoreFolder **) childFolderPtr
                              withRow: (struct SRow *) aRow
                               andFID: (uint64_t) fid;
- (enum mapistore_error) deleteFolder;
- (enum mapistore_error) getChildCount: (uint32_t *) rowCount
                           ofTableType: (enum mapistore_table_type) tableType;

- (enum mapistore_error) createMessage: (MAPIStoreMessage **) messagePtr
                               withMID: (uint64_t) mid
                          isAssociated: (BOOL) isAssociated;

- (enum mapistore_error) openMessage: (MAPIStoreMessage **) messagePtr
                             withMID: (uint64_t) mid
                          forWriting: (BOOL) readWrite
                            inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) deleteMessageWithMID: (uint64_t) mid
                                     andFlags: (uint8_t) flags;

- (enum mapistore_error) moveCopyMessagesWithMIDs: (uint64_t *) srcMids
                                         andCount: (uint32_t) count
                                       fromFolder: (MAPIStoreFolder *) sourceFolder
                                         withMIDs: (uint64_t *) targetMids
                                    andChangeKeys: (struct Binary_r **) targetChangeKeys
                        andPredecessorChangeLists: (struct Binary_r **) targetPredecessorChangeLists
                                         wantCopy: (uint8_t) want_copy
                                         inMemCtx: (TALLOC_CTX *) memCtx;

- (enum mapistore_error) moveCopyToFolder: (MAPIStoreFolder *) targetFolder
                              withNewName: (NSString *) newFolderName
                                   isMove: (BOOL) isMove
                              isRecursive: (BOOL) isRecursive
                          inMemCtx: (TALLOC_CTX *) memCtx;

- (enum mapistore_error) getDeletedFMIDs: (struct UI8Array_r **) fmidsPtr
                                   andCN: (uint64_t *) cnPtr
                        fromChangeNumber: (uint64_t) changeNum
                             inTableType: (enum mapistore_table_type) tableType
                                inMemCtx: (TALLOC_CTX *) mem_ctx;

- (enum mapistore_error) getTable: (MAPIStoreTable **) tablePtr
                      andRowCount: (uint32_t *) count
                        tableType: (enum mapistore_table_type) tableType
                      andHandleId: (uint32_t) handleId;

- (enum mapistore_error) modifyPermissions: (struct PermissionData *) permissions
                                 withCount: (uint16_t) pcount
                                  andFlags: (int8_t) flags;
- (enum mapistore_error) preloadMessageBodiesWithMIDs: (const struct UI8Array_r *) mids
                                          ofTableType: (enum mapistore_table_type) tableType;


/* helpers */
- (uint64_t) idForObjectWithKey: (NSString *) childKey;
- (MAPIStoreFolder *) rootContainer;

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

- (enum mapistore_error) preloadMessageBodiesWithKeys: (NSArray *) keys
                                          ofTableType: (enum mapistore_table_type) tableType;

/* subclass helpers */
- (void) setupVersionsMessage;
- (void) ensureIDsForChildKeys: (NSArray *) keys;

@end

#endif /* MAPISTOREFOLDER_H */
