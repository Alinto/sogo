/* UIxMailFolderActions.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2011 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Francis Lachapelle <flachapelle@inverse.ca>
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
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WORequest.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4Client.h>
#import <EOControl/EOQualifier.h>

#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailFolder.h>
#import <Mailer/SOGoMailObject.h>
#import <Mailer/SOGoTrashFolder.h>

#import <SOGo/NSObject+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserSettings.h>

#import <UI/Common/WODirectAction+SOGo.h>

#import "UIxMailFolderActions.h"

@implementation UIxMailFolderActions

- (WOResponse *) createFolderAction
{
  SOGoMailFolder *co, *newFolder;
  WOResponse *response;
  NSString *folderName;

  co = [self clientObject];

  folderName = [[context request] formValueForKey: @"name"];
  if ([folderName length] > 0)
    {
      newFolder
        = [co lookupName: [NSString stringWithFormat: @"folder%@", folderName]
               inContext: context
                 acquire: NO];
      if ([newFolder create])
        response = [self responseWith204];
      else
        {
          response = [self responseWithStatus: 500];
          [response appendContentString: @"Unable to create folder."];
        }
    }
  else
    {
      response = [self responseWithStatus: 500];
      [response appendContentString: @"Missing 'name' parameter."];
    }

  return response;  
}

- (WOResponse *) renameFolderAction
{
  SOGoMailFolder *co;
  WOResponse *response;
  NSException *error;
  NSString *folderName;

  co = [self clientObject];

  folderName = [[context request] formValueForKey: @"name"];
  error = [co renameTo: folderName];
  if (error)
    {
      response = [self responseWithStatus: 500];
      [response appendContentString: @"Unable to rename folder."];
    }
  else
    response = [self responseWith204];

  return response;
}

- (NSURL *) _trashedURLOfFolder: (NSURL *) srcURL
			 withCO: (SOGoMailFolder *) co
{
  NSURL *destURL;
  NSString *trashFolderName, *folderName, *path, *testPath;
  NGImap4Connection *connection;
  int i = 1;
  id test;

  connection = [co imap4Connection];

  folderName = [[srcURL path] lastPathComponent];
  trashFolderName
    = [[co mailAccountFolder] trashFolderNameInContext: context];
  path = [NSString stringWithFormat: @"/%@/%@",
		   trashFolderName, folderName];
  testPath = path;
  while ( i < 10 )
    {
      test = [[connection client] select: testPath];
      if (test && [[test objectForKey: @"result"] boolValue])
        {
          testPath = [NSString stringWithFormat: @"%@%x", path, i];
          i++;
        }
      else
        {
          path = testPath;
          break;
        }
    }
  destURL = [[NSURL alloc] initWithScheme: [srcURL scheme]
			   host: [srcURL host] path: path];
  [destURL autorelease];

  return destURL;
}

- (WOResponse *) deleteAction
{
  SOGoMailFolder *co, *inbox;
  WOResponse *response;
  NGImap4Connection *connection;
  NSException *error;
  NSURL *srcURL, *destURL;

  co = [self clientObject];
  if ([co ensureTrashFolder])
  {
    connection = [co imap4Connection];
    srcURL = [co imap4URL];
    destURL = [self _trashedURLOfFolder: srcURL withCO: co];
    connection = [co imap4Connection];
    inbox = [[co mailAccountFolder] inboxFolderInContext: context];
    [[connection client] select: [inbox absoluteImap4Name]];
    error = [connection moveMailboxAtURL: srcURL toURL: destURL];
    if (error)
      {
        response = [self responseWithStatus: 500];
        [response appendContentString: @"Unable to move folder."];
      }
    else
      {
        // We unsubscribe to the old one, and subscribe back to the new one
        [[connection client] subscribe: [destURL path]];
        [[connection client] unsubscribe: [srcURL path]];
        
        response = [self responseWith204];
      }
  }
  else
  {
    response = [self responseWithStatus: 500];
    [response appendContentString: @"Unable to move folder."];
  }

  return response;
}

- (WOResponse *) batchDeleteAction
{
  SOGoMailFolder *co;
  SOGoMailAccount *account;
  WOResponse *response;
  NSArray *uids;
  NSString *value;
  NSDictionary *data;
  BOOL withTrash;

  co = [self clientObject];
  value = [[context request] formValueForKey: @"uid"];
  withTrash = ![[[context request] formValueForKey: @"withoutTrash"] boolValue];
  response = nil;

  if ([value length] > 0)
    {
      uids = [value componentsSeparatedByString: @","];
      response = (WOResponse *) [co deleteUIDs: uids useTrashFolder: &withTrash inContext: context];
      if (!response)
        {
          if (!withTrash)
            {
              // When not using a trash folder, return the quota
              account = [co mailAccountFolder];
              data = [NSDictionary dictionaryWithObjectsAndKeys: [account getInboxQuota], @"quotas", nil];
              response = [self responseWithStatus: 200
                                        andString: [data jsonRepresentation]];
            }
          else
            response = [self responseWith204];
        }
    }
  else
    {
      response = [self responseWithStatus: 500];
      [response appendContentString: @"Missing 'uid' parameter."];
    }

  return response;
}

- (WOResponse *) saveMessagesAction
{
  SOGoMailFolder *co;
  WOResponse *response;
  NSArray *uids;
  NSString *value;

  co = [self clientObject];
  value = [[context request] formValueForKey: @"uid"];
  response = nil;

  if ([value length] > 0)
  {
    uids = [value componentsSeparatedByString: @","];
    response = [co archiveUIDs: uids
                inArchiveNamed: [self labelForKey: @"Saved Messages.zip"]
                     inContext: context];
    if (!response)
      response = [self responseWith204];
  }
  else
  {
    response = [self responseWithStatus: 500];
    [response appendContentString: @"Missing 'uid' parameter."];
  }

  return response;
}

- (WOResponse *) exportFolderAction
{
  WOResponse *response;

  response = [[self clientObject] archiveAllMessagesInContext: context];

  return response;
}

- (WOResponse *) copyMessagesAction
{
  SOGoMailFolder *co;
  SOGoMailAccount *account;
  WOResponse *response;
  NSArray *uids;
  NSString *value, *destinationFolder;
  NSDictionary *data;

  co = [self clientObject];
  value = [[context request] formValueForKey: @"uid"];
  destinationFolder = [[context request] formValueForKey: @"folder"];
  response = nil;

  if ([value length] > 0)
  {
    uids = [value componentsSeparatedByString: @","];
    response = [co copyUIDs: uids  toFolder: destinationFolder inContext: context];
    if (!response)
      {
	// We return the inbox quota
	account = [co mailAccountFolder];
	data = [NSDictionary dictionaryWithObjectsAndKeys: [account getInboxQuota], @"quotas", nil];
	response = [self responseWithStatus: 200
				  andString: [data jsonRepresentation]];
      }
  }
  else
  {
    response = [self responseWithStatus: 500];
    [response appendContentString: @"Missing 'uid' parameter."];
  }

  return response;
}

- (WOResponse *) moveMessagesAction
{
  SOGoMailFolder *co;
  WOResponse *response;
  NSArray *uids;
  NSString *value, *destinationFolder;

  co = [self clientObject];
  value = [[context request] formValueForKey: @"uid"];
  destinationFolder = [[context request] formValueForKey: @"folder"];
  response = nil;

  if ([value length] > 0)
  {
    uids = [value componentsSeparatedByString: @","];
    response = [co moveUIDs: uids  toFolder: destinationFolder inContext: context];
    if (!response)
      response = [self responseWith204];
  }
  else
  {
    response = [self responseWithStatus: 500];
    [response appendContentString: @"Missing 'uid' parameter."];
  }

  return response;
}

- (void) _setFolderPurposeOnMainAccount: (NSString *) purpose
                         inUserDefaults: (SOGoUserDefaults *) ud
                                     to: (NSString *) value
{
  NSString *selName;
  SEL setter;

  selName = [NSString stringWithFormat: @"set%@FolderName:", purpose];
  setter = NSSelectorFromString (selName);
  [ud performSelector: setter withObject: value];
}

- (WOResponse *) _setFolderPurpose: (NSString *) purpose
                      onAuxAccount: (int) accountIdx
                    inUserDefaults: (SOGoUserDefaults *) ud
                                to: (NSString *) value
{
  NSArray *accounts;
  int realIdx;
  NSMutableDictionary *account, *mailboxes;
  WOResponse *response;

  if (accountIdx > 0)
    {
      realIdx = accountIdx - 1;
      accounts = [ud auxiliaryMailAccounts];
      if ([accounts count] > realIdx)
        {
          account = [accounts objectAtIndex: realIdx];
          mailboxes = [account objectForKey: @"mailboxes"];
          if (!mailboxes)
            {
              mailboxes = [NSMutableDictionary new];
              [account setObject: mailboxes forKey: @"mailboxes"];
              [mailboxes release];
            }
          [mailboxes setObject: value forKey: purpose];
          [ud setAuxiliaryMailAccounts: accounts];
          response = [self responseWith204];
        }
      else
        response
          = [self responseWithStatus: 500
                           andString: @"You reached an impossible end."];
    }
  else
    response
      = [self responseWithStatus: 500
                       andString: @"You reached an impossible end."];

  return response;
}

- (WOResponse *) _setFolderPurpose: (NSString *) purpose
{
  SOGoMailFolder *co;
  WOResponse *response;
  SOGoUser *owner;
  SOGoUserDefaults *ud;
  NSString *accountIdx, *traversal;

  co = [self clientObject];
  if ([co isKindOfClass: [SOGoMailFolder class]])
    {
      accountIdx = [[co mailAccountFolder] nameInContainer];
      owner = [SOGoUser userWithLogin: [co ownerInContext: nil]];
      ud = [owner userDefaults];
      traversal = [co traversalFromMailAccount];
      if ([accountIdx isEqualToString: @"0"])
        {
          /* default account: we directly set the corresponding pref in the ud
           */
          [self _setFolderPurposeOnMainAccount: purpose
                                inUserDefaults: ud
                                            to: traversal];
          response = [self responseWith204];
        }
      else if ([[owner domainDefaults] mailAuxiliaryUserAccountsEnabled])
        response = [self _setFolderPurpose: purpose
                              onAuxAccount: [accountIdx intValue]
                            inUserDefaults: ud
                                        to: traversal];
      else
        response
          = [self responseWithStatus: 500
                           andString: @"You reached an impossible end."];
      if ([response status] == 204)
        [ud synchronize];
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
  SOGoMailAccount *account;
  NSDictionary *data;
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

      // We return the inbox quota
      account = [co mailAccountFolder];
      data = [NSDictionary dictionaryWithObjectsAndKeys: [account getInboxQuota], @"quotas", nil];
      response = [self responseWithStatus: 200
				andString: [data jsonRepresentation]];
    }

  return response;
}

- (WOResponse *) emptyTrashAction
{
  NSException *error;
  SOGoTrashFolder *co;
  SOGoMailAccount *account;
  NSEnumerator *subfolders;
  WOResponse *response;
  NGImap4Connection *connection;
  NSURL *currentURL;
  NSDictionary *data;

  co = [self clientObject];

  error = [co addFlagsToAllMessages: @"deleted"];
  if (!error)
    error = [co expunge];
  if (!error)
    {
      [co flushMailCaches];

      // Delete folders within the trash
      connection = [co imap4Connection];
      subfolders = [[co allFolderURLs] objectEnumerator];
      while ((currentURL = [subfolders nextObject]))
        {
          [[connection client] unsubscribe: [currentURL path]];
          [connection deleteMailboxAtURL: currentURL];
        }
    }
  if (error)
    {
      response = [self responseWithStatus: 500];
      [response appendContentString: @"Unable to empty the trash folder."];
    }
  else
    {
      // We return the inbox quota
      account = [co mailAccountFolder];
      data = [NSDictionary dictionaryWithObjectsAndKeys: [account getInboxQuota], @"quotas", nil];
      response = [self responseWithStatus: 200
				andString: [data jsonRepresentation]];
    }

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

- (NSDictionary *) _unseenCount
{
  EOQualifier *searchQualifier;
  NSArray *searchResult;
  NSDictionary *imapResult;
//  NSMutableDictionary *data;
  NGImap4Connection *connection;
  NGImap4Client *client;
  int unseen;
  SOGoMailFolder *folder;

  folder = [self clientObject];

  connection = [folder imap4Connection];
  client = [connection client];

  if ([connection selectFolder: [folder imap4URL]])
    {
      searchQualifier
        = [EOQualifier qualifierWithQualifierFormat: @"flags = %@ AND not flags = %@",
                       @"unseen", @"deleted"];
      imapResult = [client searchWithQualifier: searchQualifier];
      searchResult = [[imapResult objectForKey: @"RawResponse"] objectForKey: @"search"];
      unseen = [searchResult count];
    }
  else
    unseen = 0;

  return [NSDictionary
           dictionaryWithObject: [NSNumber numberWithInt: unseen]
                         forKey: @"unseen"];
}

- (WOResponse *) unseenCountAction
{
  WOResponse *response;
  NSDictionary *data;
  
  response = [self responseWithStatus: 200];
  data = [self _unseenCount];

  [response setHeader: @"text/plain; charset=utf-8"
	    forKey: @"content-type"];
  [response appendContentString: [data jsonRepresentation]];

  return response;
}

@end
