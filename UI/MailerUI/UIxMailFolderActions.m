/* UIxMailFolderActions.m - this file is part of SOGo
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
#import <Foundation/NSURL.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WORequest.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4Client.h>

#import <SoObjects/Mailer/SOGoMailFolder.h>
#import <SoObjects/Mailer/SOGoTrashFolder.h>
#import <SoObjects/Mailer/SOGoMailAccount.h>
#import <SoObjects/SOGo/NSObject+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>

#import <UI/Common/WODirectAction+SOGo.h>

#import "UIxMailFolderActions.h"

@implementation UIxMailFolderActions

- (WOResponse *) createFolderAction
{
  SOGoMailFolder *co;
  WOResponse *response;
  NGImap4Connection *connection;
  NSException *error;
  NSString *folderName;

  co = [self clientObject];

  folderName = [[context request] formValueForKey: @"name"];
  if ([folderName length] > 0)
    {
      connection = [co imap4Connection];
      error = [connection createMailbox: folderName atURL: [co imap4URL]];
      if (error)
	{
	  response = [self responseWithStatus: 500];
	  [response appendContentString: @"Unable to create folder."];
	}
      else
	response = [self responseWith204];
    }
  else
    {
      response = [self responseWithStatus: 500];
      [response appendContentString: @"Missing 'name' parameter."];
    }

  return response;  
}

- (NSURL *) _urlOfFolder: (NSURL *) srcURL
	       renamedTo: (NSString *) folderName
{
  NSString *path;
  NSURL *destURL;

  path = [[srcURL path] stringByDeletingLastPathComponent];
  if (![path hasSuffix: @"/"])
    path = [path stringByAppendingString: @"/"];

  destURL = [[NSURL alloc] initWithScheme: [srcURL scheme]
			   host: [srcURL host]
			   path: [NSString stringWithFormat: @"%@%@",
					   path, folderName]];
  [destURL autorelease];

  return destURL;
}

- (WOResponse *) renameFolderAction
{
  SOGoMailFolder *co, *inbox;
  WOResponse *response;
  NGImap4Connection *connection;
  NSException *error;
  NSString *folderName;
  NSURL *srcURL, *destURL;

  co = [self clientObject];

  folderName = [[context request] formValueForKey: @"name"];
  if ([folderName length] > 0)
    {
      srcURL = [co imap4URL];
      destURL = [self _urlOfFolder: srcURL renamedTo: folderName];
      connection = [co imap4Connection];
      inbox = [[co mailAccountFolder] inboxFolderInContext: context];
      [[connection client] select: [inbox absoluteImap4Name]];
      error = [connection moveMailboxAtURL: srcURL
			  toURL: destURL];
      if (error)
	{
	  response = [self responseWithStatus: 500];
	  [response appendContentString: @"Unable to rename folder."];
	}
      else
	response = [self responseWith204];
    }
  else
    {
      response = [self responseWithStatus: 500];
      [response appendContentString: @"Missing 'name' parameter."];
    }

  return response;  
}

- (NSURL *) _trashedURLOfFolder: (NSURL *) srcURL
			 withCO: (SOGoMailFolder *) co
{
  NSURL *destURL;
  NSString *trashFolderName, *folderName, *path;

  folderName = [[srcURL path] lastPathComponent];
  trashFolderName
    = [[co mailAccountFolder] trashFolderNameInContext: context];
  path = [NSString stringWithFormat: @"/%@/%@",
		   trashFolderName, folderName];
  destURL = [[NSURL alloc] initWithScheme: [srcURL scheme]
			   host: [srcURL host] path: path];
  [destURL autorelease];

  return destURL;
}

- (WOResponse *) deleteFolderAction
{
  SOGoMailFolder *co, *inbox;
  WOResponse *response;
  NGImap4Connection *connection;
  NSException *error;
  NSURL *srcURL, *destURL;

  co = [self clientObject];
  connection = [co imap4Connection];
  srcURL = [co imap4URL];
  destURL = [self _trashedURLOfFolder: srcURL
		  withCO: co];
  connection = [co imap4Connection];
  inbox = [[co mailAccountFolder] inboxFolderInContext: context];
  [[connection client] select: [inbox absoluteImap4Name]];
  error = [connection moveMailboxAtURL: srcURL
		      toURL: destURL];
  if (error)
    {
      response = [self responseWithStatus: 500];
      [response appendContentString: @"Unable to move folder."];
    }
  else
    response = [self responseWith204];

  return response;
}

- (WOResponse *) _setFolderPurpose: (NSString *) purpose
{
  SOGoMailFolder *co;
  WOResponse *response;
  NSUserDefaults *ud;
  NSMutableDictionary *mailSettings;

  co = [self clientObject];
  if ([NSStringFromClass ([co class]) isEqualToString: @"SOGoMailFolder"])
    {
      ud = [[context activeUser] userSettings];
      mailSettings = [ud objectForKey: @"Mail"];
      if (!mailSettings)
	{
	  mailSettings = [NSMutableDictionary new];
	  [mailSettings autorelease];
	}
      [ud setObject: mailSettings forKey: @"Mail"];
      [mailSettings setObject: [co traversalFromMailAccount]
		    forKey: [NSString stringWithFormat: @"%@Folder",
				      purpose]];
      [ud synchronize];
      response = [self responseWith204];
    }
  else
    {
      response = [self responseWithStatus: 500];
      [response
	appendContentString: @"Unable to change the purpose of this folder."];
    }

  return response;
}

- (WOResponse *) setAsDraftsFolderAction
{
  return [self _setFolderPurpose: @"Drafts"];
}

- (WOResponse *) setAsSentFolderAction
{
  return [self _setFolderPurpose: @"Sent"];
}

- (WOResponse *) setAsTrashFolderAction
{
  return [self _setFolderPurpose: @"Trash"];
}

- (WOResponse *) expungeAction 
{
  NSException *error;
  SOGoTrashFolder *co;
  WOResponse *response;

  co = [self clientObject];

  error = [co expunge];
  if (error)
    {
      response = [self responseWithStatus: 500];
      [response appendContentString: @"Unable to expunge folder."];
    }
  else
    {
      [co flushMailCaches];
      response = [self responseWith204];
    }

  return response;
}

- (WOResponse *) emptyTrashAction 
{
  NSException *error;
  SOGoTrashFolder *co;
  NSEnumerator *subfolders;
  WOResponse *response;
  NGImap4Connection *connection;
  NSURL *currentURL;

  co = [self clientObject];

  error = [co addFlagsToAllMessages: @"deleted"];
  if (!error)
    error = [co expunge];
  if (!error)
    {
      [co flushMailCaches];
      connection = [co imap4Connection];
      subfolders = [[co allFolderURLs] objectEnumerator];
      while ((currentURL = [subfolders nextObject]))
	[connection deleteMailboxAtURL: currentURL];
    }
  if (error)
    {
      response = [self responseWithStatus: 500];
      [response appendContentString: @"Unable to empty the trash folder."];
    }
  else
    response = [self responseWith204];

  return response;
}

#warning here should be done what should be done: IMAP subscription
- (WOResponse *) _subscriptionStubAction
{
  NSString *mailInvitationParam, *mailInvitationURL;
  WOResponse *response;
  SOGoMailFolder *clientObject;

  mailInvitationParam
    = [[context request] formValueForKey: @"mail-invitation"];
  if ([mailInvitationParam boolValue])
    {
      clientObject = [self clientObject];
      mailInvitationURL
	= [[clientObject soURLToBaseContainerForCurrentUser]
	    absoluteString];
      response = [self responseWithStatus: 302];
      [response setHeader: mailInvitationURL
		forKey: @"location"];
    }
  else
    {
      response = [self responseWithStatus: 500];
      [response appendContentString: @"How did you end up here?"];
    }

  return response;
}

- (WOResponse *) subscribeAction
{
  return [self _subscriptionStubAction];
}

- (WOResponse *) unsubscribeAction
{
  return [self _subscriptionStubAction];
}

- (WOResponse *) quotasAction
{
  SOGoMailFolder *folder;
  NSURL *folderURL;
  id infos;
  WOResponse *response;
  NGImap4Client *client;
  NSString *responseString;

  response = [self responseWithStatus: 200];
  [response setHeader: @"text/plain; charset=UTF-8"
	    forKey: @"content-type"];

  folder = [self clientObject];
  folderURL = [folder imap4URL];
  
  client = [[folder imap4Connection] client];
  infos = [client getQuotaRoot: [folder relativeImap4Name]];
  responseString = [[infos objectForKey: @"quotas"] jsonRepresentation];
  [response appendContentString: responseString];

  return response;
}

@end
