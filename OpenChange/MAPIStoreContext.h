/* MAPIStoreContext.h - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc. 
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

#ifndef MAPISTORECONTEXT_H
#define MAPISTORECONTEXT_H

#include <talloc.h>

#import <Foundation/NSObject.h>

@class NSArray;
@class NSFileHandle;
@class NSMutableArray;
@class NSMutableDictionary;
@class NSString;
@class NSURL;

@class EOQualifier;

@class WOContext;

@class SOGoFolder;
@class SOGoMAPIFSFolder;
@class SOGoObject;

@class MAPIStoreAuthenticator;
@class MAPIStoreAttachment;
@class MAPIStoreAttachmentTable;
@class MAPIStoreFolder;
@class MAPIStoreMapping;
@class MAPIStoreMessage;
@class MAPIStoreTable;

@interface MAPIStoreContext : NSObject
{
  struct mapistore_context *mstoreCtx;
  struct mapistore_connection_info *connInfo;

  NSURL *contextUrl;
  uint64_t contextFid;

  MAPIStoreMapping *mapping;

  MAPIStoreAuthenticator *authenticator;
  WOContext *woContext;

  MAPIStoreFolder *baseFolder;

  /* for active folders (NSDictionary instances) */
  NSMutableDictionary *folders;

  /* hackish table cache */
  MAPIStoreTable *cachedTable;
  MAPIStoreFolder *cachedFolder;
  uint64_t cachedTableFID;
  uint8_t cachedTableType;
}

+ (id) contextFromURI: (const char *) newUri
   withConnectionInfo: (struct mapistore_connection_info *) newConnInfo
               andFID: (uint64_t) fid
             inMemCtx: (struct mapistore_context *) newMemCtx;

- (id)   initFromURL: (NSURL *) newUri
  withConnectionInfo: (struct mapistore_connection_info *) newConnInfo
              andFID: (uint64_t) fid
            inMemCtx: (struct mapistore_context *) newMemCtx;

- (void) setAuthenticator: (MAPIStoreAuthenticator *) newAuthenticator;
- (MAPIStoreAuthenticator *) authenticator;

- (NSURL *) url;
- (struct mapistore_connection_info *) connectionInfo;

- (WOContext *) woContext;
- (MAPIStoreMapping *) mapping;

- (void) setupRequest;
- (void) tearDownRequest;

// - (id) lookupObject: (NSString *) objectURLString;

/* backend methods */
- (int) getPath: (char **) path
         ofFMID: (uint64_t) fmid
  withTableType: (uint8_t) tableType
       inMemCtx: (TALLOC_CTX *) memCtx;

- (int) mkDir: (struct SRow *) aRow
      withFID: (uint64_t) fid
  inParentFID: (uint64_t) parentFID;
- (int) rmDirWithFID: (uint64_t) fid
         inParentFID: (uint64_t) parentFid;
- (int) openDir: (uint64_t) fid;
- (int) closeDir;
- (int) readCount: (uint32_t *) rowCount
      ofTableType: (uint8_t) tableType
            inFID: (uint64_t) fid;
- (int) openMessage: (MAPIStoreMessage **) messagePtr
     andMessageData: (struct mapistore_message **) dataPtr
            withMID: (uint64_t) mid
              inFID: (uint64_t) fid
           inMemCtx: (TALLOC_CTX *) memCtx;
- (int) createMessage: (MAPIStoreMessage **) messagePtr
              withMID: (uint64_t) mid
                inFID: (uint64_t) fid
         isAssociated: (BOOL) isAssociated;
- (int) getProperties: (struct SPropTagArray *) SPropTagArray
          ofTableType: (uint8_t) tableType
                inRow: (struct SRow *) aRow
              withMID: (uint64_t) fmid
             inMemCtx: (TALLOC_CTX *) memCtx;
- (int) setPropertiesWithFMID: (uint64_t) fmid
                  ofTableType: (uint8_t) tableType
                        inRow: (struct SRow *) aRow;
- (int) deleteMessageWithMID: (uint64_t) mid
                       inFID: (uint64_t) fid
                   withFlags: (uint8_t) flags;

/* util methods */
- (NSString *) extractChildNameFromURL: (NSString *) childURL
			andFolderURLAt: (NSString **) folderURL;

- (uint64_t) idForObjectWithKey: (NSString *) key
                    inFolderURL: (NSString *) folderURL;

/* subclass methods */
+ (NSString *) MAPIModuleName;
- (void) setupBaseFolder: (NSURL *) newURL;

/* proof of concept */
- (int) getTable: (MAPIStoreTable **) tablePtr
     andRowCount: (uint32_t *) count
         withFID: (uint64_t) fid
       tableType: (uint8_t) tableType
     andHandleId: (uint32_t) handleId;

@end

#endif /* MAPISTORECONTEXT_H */
