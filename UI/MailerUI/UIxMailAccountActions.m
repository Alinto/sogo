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

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGImap4/NGImap4Connection.h>

#import <SoObjects/Mailer/SOGoMailAccount.h>
#import <SoObjects/Mailer/SOGoDraftObject.h>
#import <SoObjects/Mailer/SOGoDraftsFolder.h>
#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/NSObject+Utilities.h>
#import <SoObjects/SOGo/NSString+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>

#import "../Common/WODirectAction+SOGo.h"

#import "UIxMailAccountActions.h"

@implementation UIxMailAccountActions

- (id) init
{
  if ((self = [super init]))
    {
      inboxFolderName = nil;
      draftsFolderName = nil;
      sentFolderName = nil;
      trashFolderName = nil;
    }

  return self;
}

- (void) dealloc
{
  [inboxFolderName release];
  [draftsFolderName release];
  [sentFolderName release];
  [trashFolderName release];
  [super dealloc];
}

- (NSString *) _folderType: (NSString *) folderName
{
  NSString *folderType;
  SOGoMailAccount *co;
  NSArray *specialFolders;

  if (!inboxFolderName)
    {
      co = [self clientObject];
      specialFolders = [[NSArray arrayWithObjects:
				   [co inboxFolderNameInContext: context],
				 [co draftsFolderNameInContext: context],
				 [co sentFolderNameInContext: context],
				 [co trashFolderNameInContext: context],
				 nil] stringsWithFormat: @"/%@"];
      ASSIGN (inboxFolderName, [specialFolders objectAtIndex: 0]);
      ASSIGN (draftsFolderName, [specialFolders objectAtIndex: 1]);
      ASSIGN (sentFolderName, [specialFolders objectAtIndex: 2]);
      ASSIGN (trashFolderName, [specialFolders objectAtIndex: 3]);
    }

  if ([folderName isEqualToString: inboxFolderName])
    folderType = @"inbox";
  else if ([folderName isEqualToString: draftsFolderName])
    folderType = @"draft";
  else if ([folderName isEqualToString: sentFolderName])
    folderType = @"sent";
  else if ([folderName isEqualToString: trashFolderName])
    folderType = @"trash";
  else
    folderType = @"folder";

  return folderType;
}

- (NSArray *) _jsonFolders: (NSEnumerator *) rawFolders
{
  NSMutableArray *folders;
  NSString *currentFolder;
  NSDictionary *folderData;

  folders = [NSMutableArray array];
  while ((currentFolder = [rawFolders nextObject]))
    {
      folderData = [NSDictionary dictionaryWithObjectsAndKeys:
				   currentFolder, @"path",
				 [self _folderType: currentFolder], @"type",
				 nil];
      [folders addObject: folderData];
    }

  return folders;
}

- (WOResponse *) listMailboxesAction
{
  SOGoMailAccount *co;
  NSEnumerator *rawFolders;
  NSArray *folders;
  WOResponse *response;

  co = [self clientObject];

  rawFolders = [[co allFolderPaths] objectEnumerator];
  folders = [self _jsonFolders: rawFolders];

  response = [self responseWithStatus: 200];
  [response setHeader: @"text/plain; charset=utf-8"
	    forKey: @"content-type"];
  [response appendContentString: [folders jsonRepresentation]];

  return response;
}

/* compose */

- (WOResponse *) composeAction
{
  SOGoDraftsFolder *drafts;
  SOGoDraftObject *newDraftMessage;
  NSString *urlBase, *url, *value, *signature;
  NSArray *mailTo;
  BOOL save;

  drafts = [[self clientObject] draftsFolderInContext: context];
  newDraftMessage = [drafts newDraft];

  save = NO;

  value = [[self request] formValueForKey: @"mailto"];
  if ([value length] > 0)
    {
      mailTo = [NSArray arrayWithObject: value];
      [newDraftMessage
	setHeaders: [NSDictionary dictionaryWithObject: mailTo
				  forKey: @"to"]];
      save = YES;
    }

  signature = [[context activeUser] signature];
  if ([signature length])
    {
      [newDraftMessage
	setText: [NSString stringWithFormat: @"\r\n--\r\n%@", signature]];
      save = YES;
    }
  if (save)
    [newDraftMessage storeInfo];

  urlBase = [newDraftMessage baseURLInContext: context];
  url = [urlBase composeURLWithAction: @"edit"
		 parameters: nil
		 andHash: NO];

  return [self redirectToLocation: url];  
}

@end
