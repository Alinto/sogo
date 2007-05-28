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

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WORequest.h>
#import <NGImap4/NGImap4Connection.h>

#import <SoObjects/Mailer/SOGoMailFolder.h>
#import <SoObjects/Mailer/SOGoTrashFolder.h>
#import <SoObjects/Mailer/SOGoMailAccount.h>

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
  response = [context response];

  folderName = [[context request] formValueForKey: @"name"];
  if ([folderName length] > 0)
    {
      connection = [co imap4Connection];
      error = [connection createMailbox: folderName atURL: [co imap4URL]];
      if (error)
	{
	  [response setStatus: 403];
	  [response appendContentString: @"Unable to create folder."];
	}
      else
	[response setStatus: 204];
    }
  else
    {
      [response setStatus: 403];
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

  destURL = [[NSURL alloc] initWithScheme: [srcURL scheme]
			   host: [srcURL host]
			   path: [NSString stringWithFormat: @"%@%@",
					   path, folderName]];
  [destURL autorelease];

  return destURL;
}

- (WOResponse *) renameFolderAction
{
  SOGoMailFolder *co;
  WOResponse *response;
  NGImap4Connection *connection;
  NSException *error;
  NSString *folderName;
  NSURL *srcURL, *destURL;

  co = [self clientObject];
  response = [context response];

  folderName = [[context request] formValueForKey: @"name"];
  if ([folderName length] > 0)
    {
      srcURL = [co imap4URL];
      destURL = [self _urlOfFolder: srcURL renamedTo: folderName];
      connection = [co imap4Connection];
      error = [connection moveMailboxAtURL: srcURL
			  toURL: destURL];
      if (error)
	{
	  [response setStatus: 403];
	  [response appendContentString: @"Unable to rename folder."];
	}
      else
	[response setStatus: 204];
    }
  else
    {
      [response setStatus: 403];
      [response appendContentString: @"Missing 'name' parameter."];
    }

  return response;  
}

- (NSURL *) _trashedURLOfFolder: (NSURL *) srcURL
			 withCO: (SOGoMailFolder *) co
{
  NSURL *destURL;
  NSString *trashFolderName, *folderName;

  folderName = [[srcURL path] lastPathComponent];
  trashFolderName
    = [[co mailAccountFolder] trashFolderNameInContext: context];

  destURL = [[NSURL alloc] initWithScheme: [srcURL scheme]
			   host: [srcURL host]
			   path: [NSString stringWithFormat: @"/%@/%@",
					   trashFolderName, folderName]];
  [destURL autorelease];

  return destURL;
}

- (WOResponse *) deleteFolderAction
{
  SOGoMailFolder *co;
  WOResponse *response;
  NGImap4Connection *connection;
  NSException *error;
  NSURL *srcURL, *destURL;

  co = [self clientObject];
  response = [context response];
  connection = [co imap4Connection];
  srcURL = [co imap4URL];
  destURL = [self _trashedURLOfFolder: srcURL
		  withCO: co];
  connection = [co imap4Connection];
  error = [connection moveMailboxAtURL: srcURL
		      toURL: destURL];
  if (error)
    {
      [response setStatus: 403];
      [response appendContentString: @"Unable to move folder."];
    }
  else
    [response setStatus: 204];

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
  response = [context response];

  error = [co addFlagsToAllMessages: @"deleted"];
  if (!error)
    error = [co expunge];
  if (!error)
    {
      [co flushMailCaches];
      connection = [co imap4Connection];
      subfolders = [[co subfoldersURL] objectEnumerator];
      currentURL = [subfolders nextObject];
      while (currentURL)
	{
	  [connection deleteMailboxAtURL: currentURL];
	  currentURL = [subfolders nextObject];
	}
    }
  if (error)
    {
      [response setStatus: 403];
      [response appendContentString: @"Unable to empty the trash folder."];
    }
  else
    [response setStatus: 204];

  return response;
}

@end
