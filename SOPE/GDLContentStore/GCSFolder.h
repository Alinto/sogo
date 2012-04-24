/*
  Copyright (C) 2004-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __GDLContentStore_GCSFolder_H__
#define __GDLContentStore_GCSFolder_H__

#import <Foundation/NSObject.h>

/*
  GCSFolder
  
  TODO: document
  
  Fixed Quick-Table SQL fields:
  - "c_name" (name of the file in the folder)
  
  Fixed BLOB-Table SQL fields:
  - "c_name"    (name of the file in the folder)
  - "c_content" (content of the file in the folder)
  - "c_version" (update revision of the file in the folder)
*/

@class NSString;
@class NSURL;
@class NSNumber;
@class NSArray;
@class NSMutableArray;
@class NSException;
@class NSMutableString;
@class NSDictionary;
@class EOQualifier;
@class EOFetchSpecification;
@class EOAdaptorChannel;
@class GCSFolderManager;
@class GCSFolderType;
@class GCSChannelManager;

@interface GCSFolder : NSObject
{
  GCSFolderManager *folderManager;
  GCSFolderType *folderInfo;
  
  NSNumber *folderId;
  NSString *folderName;
  NSString *path;
  NSURL *location;
  NSURL *quickLocation;
  NSURL *aclLocation;
  NSString *folderTypeName;
  NSMutableArray *quickFieldNames, *contentFieldNames;

  struct {
    int requiresFolderSelect:1;
    int sameTableForQuick:1;
    int reserved:30;
  } ofFlags;
}

- (id) initWithPath: (NSString *) _path
	 primaryKey: (id) _folderId
     folderTypeName: (NSString *) _ftname
	 folderType: (GCSFolderType *) _ftype
	   location: (NSURL *) _loc
      quickLocation: (NSURL *) _qloc
	aclLocation: (NSURL *) _aloc
      folderManager: (GCSFolderManager *) _fm;

/* accessors */

- (NSNumber *) folderId;
- (NSString *) folderName;
- (NSString *) path;
- (NSURL *) location;
- (NSURL *) quickLocation;
- (NSURL *) aclLocation;
- (NSString *) folderTypeName;

- (NSString *) storeTableName;
- (NSString *) quickTableName;
- (NSString *) aclTableName;
- (BOOL) isQuickInfoStoredInContentTable;

/* connection */

- (EOAdaptorChannel *) acquireStoreChannel;
- (EOAdaptorChannel *) acquireQuickChannel;
- (EOAdaptorChannel *) acquireAclChannel;
- (void) releaseChannel: (EOAdaptorChannel *) _channel;

- (BOOL) canConnectStore;
- (BOOL) canConnectQuick;

/* operations */

- (NSArray *) subFolderNames;
- (NSArray *) allSubFolderNames;

- (NSDictionary *) recordOfEntryWithName: (NSString *) name;

- (NSException *) writeContent: (NSString *) _content
			toName: (NSString *) _name
		   baseVersion: (unsigned int *) _baseVersion;
- (NSException *) writeContent: (NSString *) _content
			toName: (NSString *) _name;
- (NSException *) deleteContentWithName: (NSString *) _name;
- (NSException *) deleteAllContent;

- (NSException *) deleteFolder;

- (NSException *) updateQuickFields: (NSDictionary *) _fields
                        whereColumn: (NSString *) _colname
                          isEqualTo: (id) _value;

- (NSArray *) fetchFields: (NSArray *) _flds 
       fetchSpecification: (EOFetchSpecification *) _fs;
- (NSArray *) fetchFields: (NSArray *) fields
       fetchSpecification: (EOFetchSpecification *) spec
	    ignoreDeleted: (BOOL) ignoreDeleted;

- (NSArray *) fetchFields: (NSArray *) _flds
	matchingQualifier: (EOQualifier *) _q;
- (NSArray *) fetchAclMatchingQualifier: (EOQualifier *) _q;
- (void) deleteAclMatchingQualifier: (EOQualifier *) _q;
- (void) deleteAclWithSpecification: (EOFetchSpecification *) _fs;

- (unsigned int) recordsCountByExcludingDeleted: (BOOL) includeDeleted;

- (NSCalendarDate *) lastModificationDate;

@end

#endif /* __GDLContentStore_GCSFolder_H__ */
