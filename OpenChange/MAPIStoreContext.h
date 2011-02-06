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

#import <Foundation/NSObject.h>

@class NSArray;
@class NSFileHandle;
@class NSMutableArray;
@class NSMutableDictionary;
@class NSString;

@class EOQualifier;

@class WOContext;

@class SOGoFolder;
@class SOGoMAPIFSFolder;
@class SOGoObject;

@class MAPIStoreAuthenticator;
@class MAPIStoreMapping;
@class MAPIStoreTable;

@interface MAPIStoreContext : NSObject
{
  struct mapistore_context *memCtx;

  NSString *uri;

  NSMutableArray *parentFoldersBag;

  MAPIStoreAuthenticator *authenticator;
  WOContext *woContext;

  id moduleFolder;
  SOGoMAPIFSFolder *faiModuleFolder;

  MAPIStoreTable *folderTable;
  MAPIStoreTable *messageTable;
  MAPIStoreTable *faiTable;

  /* for active messages (NSDictionary instances) */
  NSMutableDictionary *messages;
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

- (int) setRestrictions: (const struct mapi_SRestriction *) res
		withFID: (uint64_t) fid
	   andTableType: (uint8_t) tableType
	 getTableStatus: (uint8_t *) tableStatus;
- (int) setSortOrder: (const struct SSortOrderSet *) set
             withFID: (uint64_t) fid andTableType: (uint8_t) type
      getTableStatus: (uint8_t *) tableStatus;

- (enum MAPISTATUS) getTableProperty: (void **) data
			     withTag: (enum MAPITAGS) proptag
			  atPosition: (uint32_t) pos
		       withTableType: (uint8_t) tableType
			andQueryType: (enum table_query_type) queryType
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
                                 inFID: (uint64_t) fid
			  isAssociated: (BOOL) isAssociated;
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
- (int) setProperty: (enum MAPITAGS) property
	   withFMID: (uint64_t) fmid
	ofTableType: (uint8_t) tableType
	   fromFile: (NSFileHandle *) aFile;
- (int) getProperty: (enum MAPITAGS) property
	   withFMID: (uint64_t) fmid
	ofTableType: (uint8_t) tableType
	   intoFile: (NSFileHandle *) aFile;
- (int) modifyRecipientsWithMID: (uint64_t) mid
			 inRows: (struct ModifyRecipientRow *) rows
		      withCount: (NSUInteger) max;
- (int) deleteMessageWithMID: (uint64_t) mid
                       inFID: (uint64_t) fid
                   withFlags: (uint8_t) flags;
- (int) releaseRecordWithFMID: (uint64_t) fmid
		  ofTableType: (uint8_t) tableType;
- (int) getFoldersList: (struct indexing_folders_list **) folders_list
              withFMID: (uint64_t) fmid;


/* util methods */
- (NSString *) extractChildNameFromURL: (NSString *) childURL
			andFolderURLAt: (NSString **) folderURL;

- (void) registerValue: (id) value
	    asProperty: (enum MAPITAGS) property
		forURL: (NSString *) url;

/* subclass methods */
+ (NSString *) MAPIModuleName;
+ (void) registerFixedMappings: (MAPIStoreMapping *) storeMapping;

- (Class) messageTableClass;
- (Class) folderTableClass;

- (id) createMessageOfClass: (NSString *) messageClass
	      inFolderAtURL: (NSString *) folderURL;

- (int) openMessage: (struct mapistore_message *) msg
	     forKey: (NSString *) childKey
	    inTable: (MAPIStoreTable *) table;

@end

#endif /* MAPISTORECONTEXT_H */
