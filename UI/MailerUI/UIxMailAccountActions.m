/* UIxMailAccountActions.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2011 Inverse inc.
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
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4Client.h>
#import <NGExtensions/NSString+misc.h>

#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoDraftObject.h>
#import <Mailer/SOGoDraftsFolder.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserManager.h>

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
      otherUsersFolderName = nil;
      sharedFoldersName = nil;
    }

  return self;
}

- (void) dealloc
{
  [inboxFolderName release];
  [draftsFolderName release];
  [sentFolderName release];
  [trashFolderName release];
  [otherUsersFolderName release];
  [sharedFoldersName release];
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
				 [co otherUsersFolderNameInContext: context],
				 [co sharedFoldersNameInContext: context],
				 nil] stringsWithFormat: @"/%@"];
      ASSIGN(inboxFolderName, [specialFolders objectAtIndex: 0]);
      ASSIGN(draftsFolderName, [specialFolders objectAtIndex: 1]);
      ASSIGN(sentFolderName, [specialFolders objectAtIndex: 2]);
      ASSIGN(trashFolderName, [specialFolders objectAtIndex: 3]);
      ASSIGN(otherUsersFolderName, [specialFolders objectAtIndex: 4]);
      ASSIGN(sharedFoldersName, [specialFolders objectAtIndex: 5]);
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
  NSString *currentFolder, *currentDisplayName, *currentFolderType, *login;
  NSMutableArray *pathComponents;
  SOGoUserManager *userManager;
  NSDictionary *folderData;
  NSMutableArray *folders;

  folders = [NSMutableArray array];
  while ((currentFolder = [rawFolders nextObject]))
    {
      currentFolderType = [self _folderType: currentFolder];

      // We translate the "Other Users" and "Shared Folders" namespaces.
      // While we're at it, we also translate the user's mailbox names
      // to the full name of the person.
      if ([currentFolder hasPrefix: otherUsersFolderName])
	{
	  // We have a string like /Other Users/lmarcotte/...
	  pathComponents = [NSMutableArray arrayWithArray: [currentFolder pathComponents]];
	  login = [pathComponents objectAtIndex: 2];
	  userManager = [SOGoUserManager sharedUserManager];
	  [pathComponents removeObjectsInRange: NSMakeRange(0,1)];
	  
	  currentDisplayName = [NSString stringWithFormat: @"/%@/%@/%@", 
					 [self labelForKey: @"OtherUsersFolderName"],
					 [userManager getCNForUID: login],
					 [pathComponents componentsJoinedByString: @"/"]];
				    
	}
      else if ([currentFolder hasPrefix: sharedFoldersName])
	currentDisplayName = [NSString stringWithFormat: @"/%@%@", [self labelForKey: @"SharedFoldersName"],
				       [currentFolder substringFromIndex: [sharedFoldersName length]]];
      else
	currentDisplayName = currentFolder;
      
      folderData = [NSDictionary dictionaryWithObjectsAndKeys:
				   currentFolder, @"path",
				 currentFolderType, @"type",
				 currentDisplayName, @"displayName",
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
  NSDictionary *data;
  WOResponse *response;
  id inboxQuota;

  co = [self clientObject];

  rawFolders = [[co allFolderPaths] objectEnumerator];
  folders = [self _jsonFolders: rawFolders];
  inboxQuota = nil;

  // The parameters order is important here, as if the server doesn't support
  // quota, inboxQuota will be nil and it'll terminate the list of objects/keys.
  data = [NSDictionary dictionaryWithObjectsAndKeys: folders, @"mailboxes",
		       [co getInboxQuota], @"quotas",
		       nil];
  response = [self responseWithStatus: 200
                            andString: [data jsonRepresentation]];
  [response setHeader: @"application/json"
	    forKey: @"content-type"];

  return response;
}

/* compose */

- (WOResponse *) composeAction
{
  SOGoDraftsFolder *drafts;
  SOGoDraftObject *newDraftMessage;
  NSString *urlBase, *url, *value, *signature;
  NSArray *mailTo;
  NSMutableDictionary *headers;
  BOOL save;

  drafts = [[self clientObject] draftsFolderInContext: context];
  newDraftMessage = [drafts newDraft];
  headers = [NSMutableDictionary dictionary];
  
  save = NO;

  value = [[self request] formValueForKey: @"mailto"];
  if ([value length] > 0)
    {
      mailTo = [[value stringByUnescapingURL] componentsSeparatedByString: @","];
      [headers setObject: mailTo forKey: @"to"];
      save = YES;
    }

  value = [[self request] formValueForKey: @"subject"];
  if ([value length] > 0)
    {
      [headers setObject: [value stringByUnescapingURL] forKey: @"subject"];
      save = YES;
    }

  if (save)
    [newDraftMessage setHeaders: headers];

  signature = [[self clientObject] signature];
  if ([signature length])
    {
      [newDraftMessage
	setText: [NSString stringWithFormat: @"\n\n-- \n%@", signature]];
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

- (WOResponse *) _performDelegationAction: (SEL) action
{
  SOGoMailAccount *co;
  WOResponse *response;
  NSString *uid;

  co = [self clientObject];
  if ([[co nameInContainer] isEqualToString: @"0"])
    {
      uid = [[context request] formValueForKey: @"uid"];
      if ([uid length] > 0)
        {
          [co performSelector: action
                   withObject: [NSArray arrayWithObject: uid]];
          response = [self responseWith204];
        }
      else
        response = [self responseWithStatus: 500
                                  andString: @"Missing 'uid' parameter."];
    }
  else
    response = [self responseWithStatus: 403
                              andString: @"This action cannot be performed on secondary accounts."];

  return response;
}

- (WOResponse *) addDelegateAction
{
  return [self _performDelegationAction: @selector (addDelegates:)];
}

- (WOResponse *) removeDelegateAction
{
  return [self _performDelegationAction: @selector (removeDelegates:)];
}

@end
