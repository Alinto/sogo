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
  SOGoMailAccount *clientObject;
  NSArray *rawFolders, *folders, *mainFolders;
  NSMutableArray *newFolders;
  WOResponse *response;

  clientObject = [self clientObject];
  rawFolders = [[clientObject imap4Connection]
		 allFoldersForURL: [clientObject imap4URL]];

  draftFolderName = [clientObject draftsFolderNameInContext: context];
  sentFolderName = [clientObject sentFolderNameInContext: context];
  trashFolderName = [clientObject trashFolderNameInContext: context];
  sharedFolderName = [clientObject sharedFolderName];
  otherUsersFolderName = [clientObject otherUsersFolderName];
  mainFolders = [NSArray arrayWithObjects: @"INBOX", draftFolderName,
			 sentFolderName, trashFolderName, nil];

  newFolders = [NSMutableArray arrayWithArray: rawFolders];
  [newFolders removeObjectsInArray: mainFolders];
  [newFolders sortUsingSelector: @selector (caseInsensitiveCompare:)];
  [newFolders replaceObjectsInRange: NSMakeRange (0, 0)
	      withObjectsFromArray: mainFolders];

  folders = [self _jsonFolders: [newFolders objectEnumerator]];

  response = [context response];
  [response appendContentString: [folders jsonRepresentation]];

  return response;
}

@end
