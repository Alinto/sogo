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

  MAPIStoreMapping *mapping;

  MAPIStoreAuthenticator *authenticator;
  WOContext *woContext;

  MAPIStoreFolder *baseFolder;
}

+ (int) openContext: (MAPIStoreContext **) contextPtr
            withURI: (const char *) newUri
     connectionInfo: (struct mapistore_connection_info *) newConnInfo
     andTDBIndexing: (struct tdb_wrap *) indexingTdb;

- (id)   initFromURL: (NSURL *) newUri
  withConnectionInfo: (struct mapistore_connection_info *) newConnInfo
      andTDBIndexing: (struct tdb_wrap *) indexingTdb;

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
       inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getRootFolder: (MAPIStoreFolder **) folderPtr
              withFID: (uint64_t) fmid;

/* util methods */
- (NSString *) extractChildNameFromURL: (NSString *) childURL
			andFolderURLAt: (NSString **) folderURL;

- (uint64_t) idForObjectWithKey: (NSString *) key
                    inFolderURL: (NSString *) folderURL;
- (uint64_t) getNewChangeNumber;

/* subclass methods */
+ (NSString *) MAPIModuleName;
- (void) setupBaseFolder: (NSURL *) newURL;

@end

#endif /* MAPISTORECONTEXT_H */
