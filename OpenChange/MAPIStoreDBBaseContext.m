/* MAPIStoreDBBaseContext.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Inverse inc.
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

/* A generic parent class for all context that will store their data on the
   disk in the form of a plist. */

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#import <NGExtensions/NSObject+Logs.h>

#import "MAPIStoreDBFolder.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreUserContext.h"
#import "SOGoMAPIDBFolder.h"

#import "MAPIStoreDBBaseContext.h"

#undef DEBUG
#include <mapistore/mapistore.h>

static Class MAPIStoreDBFolderK;

@implementation MAPIStoreDBBaseContext

+ (void) initialize
{
  MAPIStoreDBFolderK = [MAPIStoreDBFolder class];
}

+ (NSString *) MAPIModuleName
{
  return nil;
}

- (Class) MAPIStoreFolderClass
{
  return MAPIStoreDBFolderK;
}

- (void) ensureContextFolder
{
  SOGoMAPIDBFolder *currentFolder;
  NSArray *parts;
  NSMutableArray *folders;
  NSString *folderName;
  NSUInteger count, max;

  parts = [[contextUrl path] componentsSeparatedByString: @"/"];
  max = [parts count];
  folders = [NSMutableArray arrayWithCapacity: max];

  /* build the folder chain */
  currentFolder = [self rootSOGoFolder];
  [folders addObject: currentFolder];
  for (count = 1; count < max; count++)
    {
      folderName = [parts objectAtIndex: count];
      if ([folderName length] > 0)
        {
          currentFolder = [SOGoMAPIDBFolder objectWithName: folderName
                                               inContainer: currentFolder];
          [folders addObject: currentFolder];
        }
    }

  /* ensure each folder in the chain actually exists, so that it becomes
     "listable" in further operations */
  max = [folders count];
  for (count = 0; count < max; count++)
    {
      currentFolder = [folders objectAtIndex: count];
      [currentFolder reloadIfNeeded];
      if ([currentFolder isNew])
        [currentFolder save];
    }
}

- (id) rootSOGoFolder
{
  SOGoMAPIDBFolder *folder;

  [userContext ensureFolderTableExists];

  folder = [SOGoMAPIDBFolder objectWithName: [isa MAPIModuleName]
                                inContainer: nil];
  [folder setTableUrl: [userContext folderTableURL]];
  // [folder reloadIfNeeded];

  /* we don't need to set the "path prefix" of the folder since the module
     name is used as the label for the top folder */

  return folder;
}

@end
