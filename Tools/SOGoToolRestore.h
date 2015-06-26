/* SOGoToolRestore.h - this file is part of SOGo
 * Header to allow subclassing of SOGoToolRestore class
 *
 * Copyright (C) 2015 Javier Amor Garcia
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


#import "SOGoTool.h"

typedef enum SOGoToolRestoreMode {
  SOGoToolRestoreFolderMode,
  SOGoToolRestoreFolderDestructiveMode,
  SOGoToolRestoreListFoldersMode,
  SOGoToolRestorePreferencesMode
} SOGoToolRestoreMode;

@interface SOGoToolRestore : SOGoTool
{
  NSString *directory;
  NSString *userID;
  NSString *filename;
  NSString *restoreFolder;
  BOOL destructive; /* destructive mode not handled */
  SOGoToolRestoreMode restoreMode;
}

- (BOOL) fetchUserID: (NSString *) identifier;
- (BOOL) createFolder: (NSString *) folder
               withFM: (GCSFolderManager *) fm;
- (BOOL) restoreDisplayName: (NSString *) newDisplayName
                   ofFolder: (GCSFolder *) gcsFolder
                     withFM: (GCSFolderManager *) fm;

@end
