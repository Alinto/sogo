/* MAPIStoreContext.h - this file is part of $PROJECT_NAME_HERE$
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

#import <Foundation/NSObject.h>

#define SENSITIVITY_NONE 0
#define SENSITIVITY_PERSONAL 1
#define SENSITIVITY_PRIVATE 2
#define SENSITIVITY_COMPANY_CONFIDENTIAL 3

#define TBL_LEAF_ROW 0x00000001
#define TBL_EMPTY_CATEGORY 0x00000002
#define TBL_EXPANDED_CATEGORY 0x00000003
#define TBL_COLLAPSED_CATEGORY 0x00000004

@class NSArray;
@class NSMutableDictionary;
@class NSString;

@class WOContext;

@class SOGoFolder;
@class SOGoObject;

@class MAPIStoreAuthenticator;
@class MAPIStoreMapping;

@interface MAPIStoreContext : NSObject
{
  struct mapistore_context *memCtx;
  void *ldbCtx;

  BOOL baseContextSet;

  NSString *uri;

  NSMutableDictionary *objectCache;
  NSMutableDictionary *messages;
  MAPIStoreAuthenticator *authenticator;
  WOContext *woContext;
  NSMutableDictionary *messageCache;
  NSMutableDictionary *subfolderCache;
  SOGoFolder *moduleFolder;
}

+ (id) contextFromURI: (const char *) newUri
             inMemCtx: (struct mapistore_context *) newMemCtx;

- (void) setURI: (NSString *) newUri
      andMemCtx: (struct mapistore_context *) newMemCtx;

- (void) setupModuleFolder;

- (void) setAuthenticator: (MAPIStoreAuthenticator *) newAuthenticator;
- (MAPIStoreAuthenticator *) authenticator;

- (void) setupRequest;
- (void) tearDownRequest;

- (id) lookupObject: (NSString *) objectURLString;

/* backend methods */
- (int) getPath: (char **) path
         ofFMID: (uint64_t) fmid
  withTableType: (uint8_t) tableType;

- (int) getFID: (uint64_t *) fid
        byName: (const char *) foldername
   inParentFID: (uint64_t) parent_fid;

- (int) getTableProperty: (void **) data
                 withTag: (uint32_t) proptag
              atPosition: (uint32_t) pos
           withTableType: (uint8_t) tableType
                   inFID: (uint64_t) fid;

- (int) mkDir: (struct SRow *) aRow
      withFID: (uint64_t) fid
  inParentFID: (uint64_t) parentFID;
- (int) rmDirWithFID: (uint64_t) fid
         inParentFID: (uint64_t) parentFid;
- (int) openDir: (uint64_t) fid
    inParentFID: (uint64_t) parentFID;
- (int) closeDir;
- (int) readCount: (uint32_t *) rowCount
      ofTableType: (uint8_t) tableType
            inFID: (uint64_t) fid;
- (int) openMessage: (struct mapistore_message *) msg
            withMID: (uint64_t) mid
              inFID: (uint64_t) fid;
- (int) createMessagePropertiesWithMID: (uint64_t) mid
                                 inFID: (uint64_t) fid;
- (int) saveChangesInMessageWithMID: (uint64_t) mid
                           andFlags: (uint8_t) flags;
- (int) submitMessageWithMID: (uint64_t) mid
                    andFlags: (uint8_t) flags;
- (int) getProperties: (struct SPropTagArray *) SPropTagArray
          ofTableType: (uint8_t) tableType
                inRow: (struct SRow *) aRow
              withMID: (uint64_t) fmid;
- (int) setPropertiesWithFMID: (uint64_t) fmid
                  ofTableType: (uint8_t) tableType
                        inRow: (struct SRow *) aRow;
- (int) deleteMessageWithMID: (uint64_t) mid
                   withFlags: (uint8_t) flags;

/* subclass methods */
+ (void) registerFixedMappings: (MAPIStoreMapping *) storeMapping;

- (NSArray *) getFolderMessageKeys: (SOGoFolder *) folder;

- (int) getCommonTableChildproperty: (void **) data
                              atURL: (NSString *) childURL
                            withTag: (uint32_t) proptag
                           inFolder: (SOGoFolder *) folder
                            withFID: (uint64_t) fid;

- (int) getMessageTableChildproperty: (void **) data
                               atURL: (NSString *) childURL
                             withTag: (uint32_t) proptag
                            inFolder: (SOGoFolder *) folder
                             withFID: (uint64_t) fid;

- (int) getFolderTableChildproperty: (void **) data
                              atURL: (NSString *) childURL
                            withTag: (uint32_t) proptag
                           inFolder: (SOGoFolder *) folder
                            withFID: (uint64_t) fid;

- (int) getFoldersList: (struct indexing_folders_list **) folders_list
              withFMID: (uint64_t) fmid;

- (int) openMessage: (struct mapistore_message *) msg
              atURL: (NSString *) childURL;

- (int) getMessageProperties: (struct SPropTagArray *) sPropTagArray
                       inRow: (struct SRow *) aRow
                       atURL: (NSString *) childURL;

@end

#endif /* MAPISTORECONTEXT_H */
