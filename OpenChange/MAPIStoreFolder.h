/* MAPIStoreFolder.h - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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

#ifndef MAPISTOREFOLDER_H
#define MAPISTOREFOLDER_H

#import <Foundation/NSObject.h>

#import "MAPIStoreTable.h"

@class NSMutableArray;
@class NSURL;

@class EOQualifier;

@class MAPIStoreContext;
@class MAPIStoreMessage;
@class MAPIStoreFSMessageTable;
@class MAPIStoreFolderTable;
@class MAPIStoreMessageTable;
@class SOGoMAPIFSFolder;

#import "MAPIStoreObject.h"

@interface MAPIStoreFolder : MAPIStoreObject
{
  NSURL *folderURL;
  MAPIStoreContext *context;
  MAPIStoreMessageTable *messageTable;
  NSArray *messageKeys;
  MAPIStoreFSMessageTable *faiMessageTable;
  NSArray *faiMessageKeys;
  MAPIStoreFolderTable *folderTable;
  NSMutableArray *folderKeys;

  SOGoMAPIFSFolder *faiFolder;
}

+ (id) baseFolderWithURL: (NSURL *) newURL
               inContext: (MAPIStoreContext *) newContext;
- (id) initWithURL: (NSURL *) newURL
         inContext: (MAPIStoreContext *) newContext;

- (MAPIStoreMessageTable *) messageTable;
- (NSArray *) messageKeys;

- (MAPIStoreFSMessageTable *) faiMessageTable;
- (NSArray *) faiMessageKeys;

- (MAPIStoreFolderTable *) folderTable;
- (NSArray *) folderKeys;

- (MAPIStoreMessage *) createMessage: (BOOL) isAssociated;
- (NSString *) createFolder: (struct SRow *) aRow;

/* helpers */
- (uint64_t) idForObjectWithKey: (NSString *) childKey;

/* subclasses */
- (Class) messageClass;
- (MAPIStoreMessage *) createMessage;

@end

#endif /* MAPISTOREFOLDER_H */
