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


/*
  GCSFolderManager
  
  Objects of this class manage the "folder_info" table, they manage the
  model and manage the tables required for a folder.
*/

@class NSString, NSArray, NSURL, NSDictionary, NSException;
@class GCSChannelManager, GCSAlarmsFolder, GCSAdminFolder, GCSFolder, GCSFolderType, GCSSessionsFolder, GCSOpenIdFolder;

@interface GCSFolderManager : NSObject
{
  GCSChannelManager *channelManager;
  NSDictionary      *nameToType;
  NSURL             *folderInfoLocation;
  NSURL             *storeLocation;
  NSURL             *aclLocation;
  NSURL             *cacheFolderLocation;
}

+ (BOOL) singleStoreMode;
+ (id)defaultFolderManager;
- (id)initWithFolderInfoLocation: (NSURL *)_infoUrl 
                andStoreLocation: (NSURL *)_storeUrl
                  andAclLocation: (NSURL *)_aclUrl
	  andCacheFolderLocation: (NSURL *)_cacheFolderUrl;

/* accessors */

- (NSURL *)folderInfoLocation;
- (NSString *)folderInfoTableName;
- (NSURL *)storeLocation;
- (NSString *)storeTableName;
- (NSURL *)aclLocation;
- (NSString *)aclTableName;
- (NSURL *)cacheFolderLocation;
- (NSString *)cacheFolderTableName;

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

- (NSDictionary *) recordAtPath: (NSString *) _path;
- (GCSFolder *)folderAtPath:(NSString *)_path;

- (NSException *)createFolderOfType:(NSString *)_type withName:(NSString *)_name atPath:(NSString *)_path;
- (NSException *)deleteFolderAtPath:(NSString *)_path;

/* alarms */
- (GCSAlarmsFolder *)alarmsFolder;

/* sessions */
- (GCSSessionsFolder *)sessionsFolder;

/* admin */
- (GCSAdminFolder *)adminFolder;

/* openid */
- (GCSOpenIdFolder *) openIdFolder;

/* folder types */

- (GCSFolderType *)folderTypeWithName:(NSString *)_name;

/* cache management */

- (void)reset;

@end

#endif /* __GDLContentStore_GCSFolderManager_H__ */
