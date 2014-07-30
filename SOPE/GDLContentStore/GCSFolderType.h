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

#ifndef __GDLContentStore_GCSFolderType_H__
#define __GDLContentStore_GCSFolderType_H__

/*
  GCSFolderType

  This is the "model" of a folder, it specifies what quick attributes are
  available, in which tables it is stored and how it is retrieved.
  
  For now, we only support one 'quick' table (we might want to have multiple
  ones in the future).
  
  Note: using the 'folderQualifier' we are actually prepared for 'multiple
        folders in a single table' setups. So in case we want to go that
        route later, we can still do it :-)
*/

#import <Foundation/NSObject.h>

@class NSString, NSArray, NSDictionary;
@class EOQualifier;
@class NGResourceLocator;
@class GCSFolder;

@interface GCSFolderType : NSObject
{
  NSString     *blobTablePattern;      // eg 'SOGo_$folderId$_blob
  NSString     *quickTablePattern;     // eg 'SOGo_$folderId$_quick
  NSArray      *fields, *quickFields;  // GCSFieldInfo objects
  EOQualifier  *folderQualifier;       // to further limit the table set
  NSString     *extractorClassName;
}

+ (id)folderTypeWithName:(NSString *)_type;

- (id)initWithPropertyList:(id)_plist;
- (id)initWithContentsOfFile:(NSString *)_path;

/* operations */

- (NSString *)blobTableNameForFolder:(GCSFolder *)_folder;
- (NSString *)quickTableNameForFolder:(GCSFolder *)_folder;

/* generating SQL */

- (NSString *)sqlQuickCreateWithTableName:(NSString *)_tabName;

/* locator used to find .ocs files */

+ (NGResourceLocator *)resourceLocator;

- (NSArray *) fields;
- (NSArray *) quickFields;
@end

#endif /* __GDLContentStore_GCSFolderType_H__ */
