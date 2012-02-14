/* MAPIStoreFSBaseContext.m - this file is part of SOGo
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

/* A generic parent class for all context that will store their data on the
   disk in the form of a plist. */

#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#import <NGExtensions/NSObject+Logs.h>

#import "MAPIStoreFSFolder.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreUserContext.h"
#import "SOGoMAPIFSFolder.h"

#import "MAPIStoreFSBaseContext.h"

#undef DEBUG
#include <mapistore/mapistore.h>

static Class MAPIStoreFSFolderK;

@implementation MAPIStoreFSBaseContext

+ (void) initialize
{
  MAPIStoreFSFolderK = [MAPIStoreFSFolder class];
}

+ (NSString *) MAPIModuleName
{
  return nil;
}

- (Class) MAPIStoreFolderClass
{
  return MAPIStoreFSFolderK;
}

- (void) ensureContextFolder
{
  SOGoMAPIFSFolder *contextFolder;

  contextFolder = [SOGoMAPIFSFolder folderWithURL: contextUrl
                                     andTableType: MAPISTORE_MESSAGE_TABLE];
  [contextFolder ensureDirectory];
}

- (id) rootSOGoFolder
{
  NSString *urlString;

  urlString = [NSString stringWithFormat: @"sogo://%@@%@/",
                        [userContext username], [isa MAPIModuleName]];
  return [SOGoMAPIFSFolder folderWithURL: [NSURL URLWithString: urlString]
                            andTableType: MAPISTORE_MESSAGE_TABLE];
}

@end
