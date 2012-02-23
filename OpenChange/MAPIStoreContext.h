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
@class SOGoUser;

@class MAPIStoreAuthenticator;
@class MAPIStoreAttachment;
@class MAPIStoreAttachmentTable;
@class MAPIStoreFolder;
@class MAPIStoreMessage;
@class MAPIStoreTable;
@class MAPIStoreUserContext;

@interface MAPIStoreContext : NSObject
{
  struct mapistore_connection_info *connInfo;
  NSMutableArray *containersBag;
  SOGoUser *activeUser;
  MAPIStoreUserContext *userContext;
  NSURL *contextUrl;
}

+ (struct mapistore_contexts_list *) listAllContextsForUser: (NSString *)  userName
                                            withTDBIndexing: (struct tdb_wrap *) indexingTdb
                                                   inMemCtx: (TALLOC_CTX *) memCtx;
+ (struct mapistore_contexts_list *) listContextsForUser: (NSString *)  userName
                                         withTDBIndexing: (struct tdb_wrap *) indexingTdb
                                                inMemCtx: (TALLOC_CTX *) memCtx;
+ (enum mapistore_error) createRootFolder: (NSString **) mapistoreUriP
                                  withFID: (uint64_t ) fid
                                  andName: (NSString *) folderName
                                  forUser: (NSString *) username
                                 withRole: (enum mapistore_context_role) role;

+ (int) openContext: (MAPIStoreContext **) contextPtr
            withURI: (const char *) newUri
     connectionInfo: (struct mapistore_connection_info *) newConnInfo
     andTDBIndexing: (struct tdb_wrap *) indexingTdb;

- (id)   initFromURL: (NSURL *) newUri
  withConnectionInfo: (struct mapistore_connection_info *) newConnInfo
      andTDBIndexing: (struct tdb_wrap *) indexingTdb;

- (NSURL *) url;
- (struct mapistore_connection_info *) connectionInfo;

- (MAPIStoreUserContext *) userContext;

- (SOGoUser *) activeUser;

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
+ (enum mapistore_context_role) MAPIContextRole;
+ (NSString *)
 createRootSecondaryFolderWithFID: (uint64_t) fid
                          andName: (NSString *) folderName
                          forUser: (NSString *) userName;
- (Class) MAPIStoreFolderClass;

/* the top-most parent of the context folder: SOGoMailAccount,
   SOGoCalendarFolders, ... */
- (id) rootSOGoFolder;

@end

#endif /* MAPISTORECONTEXT_H */
