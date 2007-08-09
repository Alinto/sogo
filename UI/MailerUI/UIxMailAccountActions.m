/* UIxMailAccountActions.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOResponse.h>
#import <NGImap4/NGImap4Connection.h>
#import <SoObjects/Mailer/SOGoMailAccount.h>
#import <SoObjects/SOGo/NSObject+Utilities.h>

#import "UIxMailAccountActions.h"

@implementation UIxMailAccountActions

- (NSString *) _folderType: (NSString *) baseName
{
  NSString *folderType;

  if ([baseName isEqualToString: @"INBOX"])
    folderType = @"inbox";
  else if ([baseName isEqualToString: draftFolderName])
    folderType = @"draft";
  else if ([baseName isEqualToString: sentFolderName])
    folderType = @"sent";
  else if ([baseName isEqualToString: trashFolderName])
    folderType = @"trash";
  else
    folderType = @"folder";

  return folderType;
}

- (NSDictionary *) _lineForFolder: (NSString *) folder
{
  NSArray *parts;
  NSMutableDictionary *folderData;
  NSString *baseName;

  folderData = [NSMutableDictionary dictionary];
  parts = [folder componentsSeparatedByString: @"/"];
  baseName = [parts lastObject];
  [folderData setObject: folder forKey: @"path"];
  [folderData setObject: [self _folderType: baseName]
	      forKey: @"type"];

  return folderData;
}

- (NSArray *) _jsonFolders: (NSEnumerator *) rawFolders
{
  NSMutableArray *folders;
  NSString *currentFolder;

  folders = [NSMutableArray array];

  currentFolder = [rawFolders nextObject];
  while (currentFolder)
    {
      [folders addObject: [self _lineForFolder: currentFolder]];
      currentFolder = [rawFolders nextObject];
    }

  return folders;
}

- (WOResponse *) listMailboxesAction
{
  SOGoMailAccount *co;
  NSArray *rawFolders, *folders;
  WOResponse *response;

  co = [self clientObject];
  draftFolderName = [[co draftsFolderNameInContext: context]
		      substringFromIndex: 6];
  sentFolderName = [[co sentFolderNameInContext: context]
		     substringFromIndex: 6];
  trashFolderName = [[co trashFolderNameInContext: context]
		      substringFromIndex: 6];

  rawFolders = [co allFolderPaths];
  folders = [self _jsonFolders: [rawFolders objectEnumerator]];

  response = [context response];
  [response setStatus: 200];
  [response setHeader: @"text/plain; charset=utf-8"
	    forKey: @"content-type"];
  [response appendContentString: [folders jsonRepresentation]];

  return response;
}

@end
