/* UIxContactsListViewContainer.m - this file is part of $PROJECT_NAME_HERE$
 *
 * Copyright (C) 2006 Inverse groupe conseil
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

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/SoObjects.h>

#import <SoObjects/Contacts/SOGoContactFolder.h>

#import "UIxContactsListViewContainer.h"

@class SOGoContactFolders;

@implementation UIxContactsListViewContainer

- (id) init
{
  if ((self = [super init]))
    {
      foldersPrefix = nil;
    }

  return self;
}

- (void) setCurrentFolder: (id) folder
{
  currentFolder = folder;
}

- (NSString *) foldersPrefix
{
  NSMutableArray *folders;
  SOGoObject *currentObject;

  if (!foldersPrefix)
    {
      folders = [NSMutableArray new];
      [folders autorelease];

      currentObject = [[self clientObject] container];
      while (![currentObject isKindOfClass: [SOGoContactFolders class]])
        {
          [folders insertObject: [currentObject nameInContainer] atIndex: 0];
          currentObject = [currentObject container];
        }

      foldersPrefix = [folders componentsJoinedByString: @"/"];
      [foldersPrefix retain];
    }

  return foldersPrefix;
}

- (NSString *) contactFolderId
{
  return [NSString stringWithFormat: @"%@/%@",
                   [self foldersPrefix],
                   [[self clientObject] nameInContainer]];
}

- (NSArray *) contactFolders
{
  SOGoContactFolders *folderContainer;

  folderContainer = [[self clientObject] container];

  return [folderContainer contactFolders];
}

- (NSString *) currentContactFolderId
{
  return [NSString stringWithFormat: @"%@/%@",
                   [self foldersPrefix],
                   [currentFolder nameInContainer]];
}

- (NSString *) currentContactFolderName
{
  return [self labelForKey: [currentFolder displayName]];
}

- (BOOL) isFolderCurrent
{
  return [[self currentContactFolderId] isEqualToString: [self contactFolderId]];
}

@end
