/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#ifndef __GDLContentStore_GCSFolderManager_H__
#define __GDLContentStore_GCSFolderManager_H__

#import <Foundation/NSObject.h>

/*
  GCSFolderManager
  
  Objects of this class manage the "folder_info" table, they manage the
  model and manage the tables required for a folder.
*/

@class NSString, NSArray, NSURL, NSDictionary, NSException;
@class GCSChannelManager, GCSFolder, GCSFolderType;

@interface GCSFolderManager : NSObject
{
  GCSChannelManager *channelManager;
  NSDictionary      *nameToType;
  NSURL             *folderInfoLocation;
}

+ (id)defaultFolderManager;
- (id)initWithFolderInfoLocation:(NSURL *)_url;

/* accessors */

- (NSURL *)folderInfoLocation;
- (NSString *)folderInfoTableName;

/* connection */

- (GCSChannelManager *)channelManager;
- (BOOL)canConnect;

/* handling folder names */

- (NSString *)internalNameFromPath:(NSString *)_path;
- (NSArray *)internalNamesFromPath:(NSString *)_path;
- (NSString *)pathFromInternalName:(NSString *)_name;

/* operations */

- (BOOL)folderExistsAtPath:(NSString *)_path;
- (NSArray *)listSubFoldersAtPath:(NSString *)_path recursive:(BOOL)_flag;

- (GCSFolder *)folderAtPath:(NSString *)_path;

- (NSException *)createFolderOfType:(NSString *)_type withName:(NSString *)_name atPath:(NSString *)_path;
- (NSException *)deleteFolderAtPath:(NSString *)_path;

/* folder types */

- (GCSFolderType *)folderTypeWithName:(NSString *)_name;

/* cache management */

- (void)reset;

@end

#endif /* __GDLContentStore_GCSFolderManager_H__ */
