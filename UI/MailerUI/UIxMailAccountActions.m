/* UIxMailAccountActions.m - this file is part of SOGo
 *
 * Copyright (C) 2007, 2008 Inverse inc.
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
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4Client.h>

#import <EOControl/EOQualifier.h>

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

- (NSDictionary *) _statusFolders
{
  EOQualifier *searchQualifier;
  NSArray *searchResult;
  NSDictionary *imapResult;
  NGImap4Client *client;
  NSNumber *unseen;
  SOGoMailFolder *inbox;
  SOGoMailAccount *co;  

  co = [self clientObject];
  inbox = [co inboxFolderInContext: context];
  client = [[inbox imap4Connection] client];

  if ([client select: [inbox relativeImap4Name]])
    {
      searchQualifier = [EOQualifier qualifierWithQualifierFormat: @"flags = %@ AND not flags = %@", @"unseen", @"deleted"];
      imapResult = [client searchWithQualifier: searchQualifier];
      searchResult = [[imapResult objectForKey: @"RawResponse"] objectForKey: @"search"];
      unseen = [NSNumber numberWithInt: [searchResult count]];
    }
  
  if (!unseen)
    unseen = [NSNumber numberWithInt: 0];
  
  return [NSDictionary dictionaryWithObjectsAndKeys: unseen, @"unseen", nil];
}

- (WOResponse *) statusFoldersAction
{
  WOResponse *response;
  NSDictionary *data;
  
  response = [self responseWithStatus: 200];
  data = [self _statusFolders];

  [response setHeader: @"text/plain; charset=utf-8"
	    forKey: @"content-type"];
  [response appendContentString: [data jsonRepresentation]];

  return response;
}

- (WOResponse *) listMailboxesAction
{
  id infos, inboxQuota;  
  SOGoMailAccount *co;
  SOGoMailFolder *inbox;
  NGImap4Client *client;
  NSEnumerator *rawFolders;
  NSArray *folders;
  NSDictionary *data;
  NSString *inboxName;
  NSUserDefaults *ud;
  WOResponse *response;
  float quota;

  ud = [NSUserDefaults standardUserDefaults];
  co = [self clientObject];

  rawFolders = [[co allFolderPaths] objectEnumerator];
  folders = [self _jsonFolders: rawFolders];

  // Retrieve INBOX quota
  quota = [ud floatForKey: @"SOGoSoftQuotaRatio"];
  inbox = [co inboxFolderInContext: context];
  inboxName = [NSString stringWithFormat: @"/%@", [inbox relativeImap4Name]];
  client = [[inbox imap4Connection] client];
  infos = [[client getQuotaRoot: [inbox relativeImap4Name]] objectForKey: @"quotas"];
  inboxQuota = [infos objectForKey: inboxName];
  if (quota != 0 && inboxQuota != nil)
    {
      // A soft quota ration is imposed for all users
      quota = quota * [(NSNumber*)[inboxQuota objectForKey: @"maxQuota"] intValue];
      inboxQuota = [NSDictionary dictionaryWithObjectsAndKeys:
				 [NSNumber numberWithFloat: (long)(quota+0.5)], @"maxQuota",
				 [inboxQuota objectForKey: @"usedSpace"], @"usedSpace",
				 nil];
    }
  data = [NSDictionary dictionaryWithObjectsAndKeys: folders, @"mailboxes",
		       [self _statusFolders], @"status",
		       inboxQuota, @"quotas",
		       nil];
  response = [self responseWithStatus: 200];
  [response setHeader: @"text/plain; charset=utf-8"
	    forKey: @"content-type"];
  [response appendContentString: [data jsonRepresentation]];

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
      mailTo = [value componentsSeparatedByString: @","];
      [headers setObject: mailTo forKey: @"to"];
      save = YES;
    }

  value = [[self request] formValueForKey: @"subject"];
  if ([value length] > 0)
    {
      [headers setObject: value forKey: @"subject"];
      save = YES;
    }

  if (save)
    [newDraftMessage setHeaders: headers];

  signature = [[context activeUser] signature];
  if ([signature length])
    {
      [newDraftMessage
	setText: [NSString stringWithFormat: @"\n-- \n%@", signature]];
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
