/* MAPIStoreGCSBaseContext.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <SOGo/SOGoGCSFolder.h>
#import <SOGo/SOGoParentFolder.h>

#import "MAPIApplication.h"
#import "MAPIStoreUserContext.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreGCSBaseContext.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <dlinklist.h>

@implementation MAPIStoreGCSBaseContext

+ (NSString *) MAPIModuleName
{
  return nil;
}

+ (NSString *) folderNameSuffix
{
  return @"";
}

+ (NSString *) getFolderDisplayName: (NSString *) sogoDisplayName
{
  NSString *suffix, *displayName;

  suffix = [self folderNameSuffix];
  if ([suffix length] > 0 && ![sogoDisplayName hasSuffix: suffix])
    displayName = [NSString stringWithFormat: @"%@ (%@)",
                            sogoDisplayName, suffix];
  else
    displayName = sogoDisplayName;

  return displayName;
}

+ (struct mapistore_contexts_list *) listContextsForUser: (NSString *) userName
                                         withTDBIndexing: (struct tdb_wrap *) indexingTdb
                                                inMemCtx: (TALLOC_CTX *) memCtx
{
  struct mapistore_contexts_list *firstContext = NULL, *context;
  NSString *moduleName, *baseUrl, *url, *nameInContainer, *displayName;
  NSArray *subfolders;
  MAPIStoreUserContext *userContext;
  SOGoParentFolder *parentFolder;
  NSUInteger count, max;
  SOGoGCSFolder *currentFolder;

  moduleName = [self MAPIModuleName];
  if (moduleName)
    {
      userContext = [MAPIStoreUserContext userContextWithUsername: userName
                                                   andTDBIndexing: indexingTdb];
      parentFolder = [[userContext rootFolders] objectForKey: moduleName];
      baseUrl = [NSString stringWithFormat: @"sogo://%@@%@/",
                          userName, moduleName];

      subfolders = [parentFolder subFolders];
      max = [subfolders count];
      for (count = 0; count < max; count++)
        {
          currentFolder = [subfolders objectAtIndex: count];
          if ([[currentFolder ownerInContext: nil] isEqualToString: userName])
            {
              context = talloc_zero (memCtx, struct mapistore_contexts_list);
              nameInContainer = [currentFolder nameInContainer];
              url = [NSString stringWithFormat: @"%@%@", baseUrl, nameInContainer];
              context->url = [url asUnicodeInMemCtx: context];
              displayName = [self getFolderDisplayName: [currentFolder displayName]];
              context->name = [displayName asUnicodeInMemCtx: context];
              context->main_folder = [nameInContainer isEqualToString: @"personal"];
              context->role = [self MAPIContextRole];
              context->tag = "tag";
              DLIST_ADD_END (firstContext, context, void);
            }
        }
    }

  return firstContext;
}

+ (NSString *)
 createRootSecondaryFolderWithFID: (uint64_t) fid
                          andName: (NSString *) folderName
                          forUser: (NSString *) userName
{
  NSString *mapistoreURI, *nameInContainer, *moduleName;
  MAPIStoreUserContext *userContext;
  SOGoParentFolder *parentFolder;

  userContext = [MAPIStoreUserContext userContextWithUsername: userName
                                               andTDBIndexing: NULL];
  [MAPIApp setUserContext: userContext];
  moduleName = [self MAPIModuleName];
  parentFolder = [[userContext rootFolders] objectForKey: moduleName];
  if (![parentFolder newFolderWithName: folderName
                       nameInContainer: &nameInContainer])
    mapistoreURI = [NSString stringWithFormat: @"sogo://%@@%@/%@/",
                             userName, moduleName, nameInContainer];
  else
    mapistoreURI = nil;
  [MAPIApp setUserContext: nil];

  return mapistoreURI;
}

- (id) rootSOGoFolder
{
  return [[userContext rootFolders] objectForKey: [isa MAPIModuleName]];
}

@end
