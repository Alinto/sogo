/* UIxMailFolderActions.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2016 Inverse inc.
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSURL.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>

#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4Client.h>
#import <NGImap4/NSString+Imap4.h>


#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoTrashFolder.h>

#import <SOGo/NSObject+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>

#import "UIxMailFolderActions.h"

@implementation UIxMailFolderActions

/**
 * @api {post} /so/:username/Mail/:accountId/:parentMailboxPath/createFolder Create mailbox
 * @apiVersion 1.0.0
 * @apiName PostCreateMailbox
 * @apiGroup Mail
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Mail/0/folderINBOX/createFolder \
 *          -H "Content-Type: application/json" \
 *          -d '{ "name": "test" }'
 *
 * @apiParam {String} name Name of the mailbox
 *
 * @apiError (Error 500) {Object} error The error message
 */
- (id <WOActionResults>) createFolderAction
{
  SOGoMailFolder *co, *newFolder;
  WORequest *request;
  WOResponse *response;
  NSDictionary *params, *jsonResponse;
  NSString *folderName, *encodedFolderName, *errorFormat;

  co = [self clientObject];

  request = [context request];
  params = [[request contentAsString] objectFromJSONString];
  folderName = [params objectForKey: @"name"];
  if ([folderName length] > 0)
    {
      encodedFolderName = [folderName stringByEncodingImap4FolderName];
      newFolder = [co lookupName: [NSString stringWithFormat: @"folder%@", encodedFolderName]
                       inContext: context
                         acquire: NO];
      if ([newFolder create])
        {
          response = [self responseWith204];
        }
      else
        {
          errorFormat = [self labelForKey: @"The folder with name \"%@\" could not be created." inContext: context];
          jsonResponse = [NSDictionary dictionaryWithObject: [NSString stringWithFormat: errorFormat, folderName]
                                                     forKey: @"error"];
          response = [self responseWithStatus: 500 andJSONRepresentation: jsonResponse];
        }
    }
  else
    {
      jsonResponse = [NSDictionary dictionaryWithObject: [self labelForKey: @"Missing 'name' parameter."  inContext: context]
                                                 forKey: @"error"];
      response = [self responseWithStatus: 500 andJSONRepresentation: jsonResponse];
    }

  return response;  
}

/**
 * @api {post} /so/:username/Mail/:accountId/:mailboxPath/renameFolder Rename mailbox
 * @apiVersion 1.0.0
 * @apiName PostRenameFolder
 * @apiGroup Mail
 *
 * @apiParam {String} name Name of the mailbox
 *
 * @apiSuccess (Success 200) {String} path  New mailbox path relative to account
 * @apiError   (Error 500) {Object} error   The error message
 */
- (WOResponse *) renameFolderAction
{
  SOGoMailFolder *co;
  SOGoUserSettings *us;
  WORequest *request;
  WOResponse *response;
  NSException *error;
  NSString *newFolderName, *newFolderPath, *currentMailbox, *currentAccount, *keyForMsgUIDs, *newKeyForMsgUIDs;
  NSMutableDictionary *params, *moduleSettings, *threadsCollapsed, *message;
  NSArray *values;

  co = [self clientObject];

  // Prepare the variables need to verify if the current folder have any collapsed threads saved in userSettings
  us = [[context activeUser] userSettings];
  moduleSettings = [us objectForKey: @"Mail"];
  threadsCollapsed = [moduleSettings objectForKey:@"threadsCollapsed"];
  currentMailbox = [co nameInContainer];
  currentAccount = [[co container] nameInContainer];
  keyForMsgUIDs = [NSString stringWithFormat:@"/%@/%@", currentAccount, currentMailbox];

  // Retrieve new folder name from JSON payload
  request = [context request];
  params = [[request contentAsString] objectFromJSONString];
  newFolderName = [params objectForKey: @"name"];

  if (!newFolderName || [newFolderName length] == 0)
    {
      message = [NSDictionary dictionaryWithObject: [self labelForKey: @"Missing name parameter" inContext: context]
                                            forKey: @"message"];
      response = [self responseWithStatus: 500 andJSONRepresentation: message];
    }
  else
    {
      newKeyForMsgUIDs = [NSString stringWithFormat:@"/%@/folder%@", [currentAccount asCSSIdentifier], [newFolderName asCSSIdentifier]];
      error = [co renameTo: newFolderName];
      if (error)
        {
          message = [NSDictionary dictionaryWithObject: [self labelForKey: @"Unable to rename folder." inContext: context]
                                                forKey: @"message"];
          response = [self responseWithStatus: 500 andJSONRepresentation: message];
        }
      else
        {
          // Verify if the current folder have any collapsed threads save under it old name and adjust the folderName
          if (threadsCollapsed)
            {
              if ([threadsCollapsed objectForKey:keyForMsgUIDs])
                {
                  values = [NSArray arrayWithArray:[threadsCollapsed objectForKey:keyForMsgUIDs]];
                  [threadsCollapsed setObject:values forKey:newKeyForMsgUIDs];
                  [threadsCollapsed removeObjectForKey:keyForMsgUIDs];
                  [us synchronize];
                }
            }
          newFolderPath = [[[co imap4URL] path] substringFromIndex: 1]; // remove slash at beginning of path
          message = [NSDictionary dictionaryWithObject: newFolderPath
                                                forKey: @"path"];
          response = [self responseWithStatus: 200 andJSONRepresentation: message];
        }
    }

  return response;
}

- (NSURL *) _trashedURLOfFolder: (NSURL *) srcURL
                     withObject: (SOGoMailFolder *) co
{
  NSString *trashFolderName, *folderName, *path, *testPath;
  NGImap4Connection *connection;
  NSURL *destURL;
  id test;
  int i;

  connection = [co imap4Connection];
  folderName = [[srcURL path] lastPathComponent];
  trashFolderName
    = [[co mailAccountFolder] trashFolderNameInContext: context];
  path = [NSString stringWithFormat: @"/%@/%@",
		   trashFolderName, folderName];
  testPath = path;
  i = 1;

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
  NSString *currentMailbox, *currentAccount, *keyForMsgUIDs;
  NSMutableDictionary *moduleSettings, *threadsCollapsed;
  NGImap4Connection *connection;
  SOGoMailFolder *co, *inbox;
  NSDictionary *jsonResponse;
  NSURL *srcURL, *destURL;
  SOGoUserSettings *us;
  WOResponse *response;
  NSException *error;
  BOOL moved;

  co = [self clientObject];
  moved = YES;

  if ([co ensureTrashFolder])
    {
      connection = [co imap4Connection];
      srcURL = [co imap4URL];
      destURL = [self _trashedURLOfFolder: srcURL withObject: co];
      connection = [co imap4Connection];
      inbox = [[co mailAccountFolder] inboxFolderInContext: context];
      [[connection client] select: [inbox absoluteImap4Name]];

      // If srcURL is a prefix of destURL, that means we are deleting
      // the folder within the 'Trash' folder, as it's getting renamed
      // over and over with an integer suffix (in trashedURLOfFolder:...)
      // If that is the case, we simple delete the folder, instead of renaming it
      if ([[destURL path] hasPrefix: [srcURL path]])
        {
          error = [connection deleteMailboxAtURL: srcURL];
          moved = NO;
        }
      else
        error = [connection moveMailboxAtURL: srcURL toURL: destURL];
      if (error)
        {
          jsonResponse = [NSDictionary dictionaryWithObject: [self labelForKey: @"Unable to move/delete folder." inContext: context]
                                                     forKey: @"error"];
          response = [self responseWithStatus: 500 andJSONRepresentation: jsonResponse];
        }
      else
        {
          // We unsubscribe to the old one, and subscribe back to the new one
          if (moved)
            [[connection client] subscribe: [destURL path]];
          [[connection client] unsubscribe: [srcURL path]];

          // Verify if the current folder have any collapsed threads save under it name and erase it
          us = [[context activeUser] userSettings];
          moduleSettings = [us objectForKey: @"Mail"];
          threadsCollapsed = [moduleSettings objectForKey: @"threadsCollapsed"];
          currentMailbox = [co nameInContainer];
          currentAccount = [[co container] nameInContainer];
          keyForMsgUIDs = [NSString stringWithFormat:@"/%@/%@", currentAccount, currentMailbox];

          if (threadsCollapsed)
            {
              if ([threadsCollapsed objectForKey: keyForMsgUIDs])
                {
                  [threadsCollapsed removeObjectForKey: keyForMsgUIDs];
                  [us synchronize];
                }
            }
          response = [self responseWith204];
        }
    }
  else
    {
      jsonResponse = [NSDictionary dictionaryWithObject: [self labelForKey: @"Unable to move/delete folder." inContext: context]
                                                 forKey: @"message"];
      response = [self responseWithStatus: 500 andJSONRepresentation: jsonResponse];
    }

  return response;
}

- (WOResponse *) batchDeleteAction
{
  NSMutableDictionary *moduleSettings, *threadsCollapsed;
  NSString *currentMailbox, *currentAccount, *keyForMsgUIDs;
  NSMutableArray *mailboxThreadsCollapsed;
  SOGoMailAccount *account;
  SOGoUserSettings *us;
  WOResponse *response;
  SOGoMailFolder *co;
  NSDictionary *data;
  WORequest *request;

  id uids, quota;

  BOOL withTrash;
  int i;

  response = nil;
  request = [context request];
  co = [self clientObject];
  data = [[request contentAsString] objectFromJSONString];
  withTrash = ![[data objectForKey: @"withoutTrash"] boolValue];

  if ((uids = [data objectForKey: @"uids"]) && [uids isKindOfClass: [NSArray class]] && [uids count] > 0)
    {
      response = (WOResponse *) [co deleteUIDs: uids useTrashFolder: &withTrash inContext: context];
      if (!response)
        {
          if (!withTrash)
            {
              // When not using a trash folder, return the quota
              account = [co mailAccountFolder];
              if ((quota = [account getInboxQuota]))
                {
                  data = [NSDictionary dictionaryWithObjectsAndKeys: quota, @"quotas", nil];
                  response = [self responseWithStatus: 200
                                            andString: [data jsonRepresentation]];
                }
              else
                response = [self responseWithStatus: 200];
            }
          else
            {
              // Verify if the message beeing delete is saved as the root of a collapsed thread
              us = [[context activeUser] userSettings];
              moduleSettings = [us objectForKey: @"Mail"];
              threadsCollapsed = [moduleSettings objectForKey:@"threadsCollapsed"];
              currentMailbox = [co nameInContainer];
              currentAccount = [[co container] nameInContainer];
              keyForMsgUIDs = [NSString stringWithFormat:@"/%@/%@", currentAccount, currentMailbox];

              if (threadsCollapsed)
                {
                  if ((mailboxThreadsCollapsed = [threadsCollapsed objectForKey:keyForMsgUIDs]))
                    {
                      for (i = 0; i < [uids count]; i++)
                        [mailboxThreadsCollapsed removeObject:[uids objectAtIndex:i]];
                      [us synchronize];
                    }
                }
              response = [self responseWith204];
            }
        }
    }
  else
    {
      data = [NSDictionary dictionaryWithObject: [self labelForKey: @"Missing 'uids' parameter." inContext: context]
                                         forKey: @"message"];
      response = [self responseWithStatus: 500 andJSONRepresentation: data];
    }

  return response;
}

- (WOResponse *) saveMessagesAction
{
  SOGoMailFolder *co;
  WOResponse *response;
  NSArray *uids;
  NSDictionary *data, *jsonResponse;

  co = [self clientObject];
  data = [[[context request] contentAsString] objectFromJSONString];
  uids = [data objectForKey: @"uids"];
  response = nil;

  if ([uids count] > 0)
    {
      response = [co archiveUIDs: uids
                  inArchiveNamed: [self labelForKey: @"Saved Messages.zip" inContext: context]
                       inContext: context];
      if (!response)
        response = [self responseWith204];
    }
  else
    {
      jsonResponse = [NSDictionary dictionaryWithObject: [self labelForKey: @"Missing 'uids' parameter." inContext: context]
                                                 forKey: @"message"];
      response = [self responseWithStatus: 500 andJSONRepresentation: jsonResponse];
    }

  return response;
}

- (id) markFolderReadAction
{
  id response;

  response = [[self clientObject] addFlagsToAllMessages: @"seen"];
  if (!response)
    response = [self responseWith204];

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
  NSString *destinationFolder;
  SOGoMailAccount *account;
  WOResponse *response;
  SOGoMailFolder *co;
  NSDictionary *data;
  NSArray *uids;

  id quota;

  co = [self clientObject];
  data = [[[context request] contentAsString] objectFromJSONString];
  uids = [data objectForKey: @"uids"];
  destinationFolder = [data objectForKey: @"folder"];
  response = nil;

  if ([uids count] > 0 && destinationFolder)
    {
      response = [co copyUIDs: uids  toFolder: destinationFolder inContext: context];
      if (!response)
        {
          // We return the inbox quota
          account = [co mailAccountFolder];
          if ((quota = [account getInboxQuota]))
            {
              data = [NSDictionary dictionaryWithObject: quota  forKey: @"quotas"];
              response = [self responseWithStatus: 200 andJSONRepresentation: data];
            }
          else
            response = [self responseWithStatus: 200];
        }
      else
        {
          data = [NSDictionary dictionaryWithObject: [(NSException *)response reason]
                                             forKey: @"message"];
          response = [self responseWithStatus: 500 andJSONRepresentation: data];
        }
    }
  else
    {
      data = [NSDictionary dictionaryWithObject: [self labelForKey: @"Error copying messages." inContext: context]
                                         forKey: @"message"];
      response = [self responseWithStatus: 500 andJSONRepresentation: data];
    }

  return response;
}

- (WOResponse *) moveMessagesAction
{
  NSString *currentMailbox, *currentAccount, *keyForMsgUIDs;
  NSMutableDictionary *moduleSettings, *threadsCollapsed;
  NSMutableArray *mailboxThreadsCollapsed;
  NSString *destinationFolder;
  SOGoUserSettings *us=nil;
  WOResponse *response;
  NSDictionary *data;
  SOGoMailFolder *co;
  NSArray *uids;

  int i;

  co = [self clientObject];
  data = [[[context request] contentAsString] objectFromJSONString];
  uids = [data objectForKey: @"uids"];
  destinationFolder = [data objectForKey: @"folder"];
  response = nil;

  if ([uids count] > 0 && destinationFolder)
    {
      response = [co moveUIDs: uids  toFolder: destinationFolder inContext: context];
      if (!response)
        {
          // Verify if the message being deleted is saved as the root of a collapsed thread
          us = [[context activeUser] userSettings];
          moduleSettings = [us objectForKey: @"Mail"];
          threadsCollapsed = [moduleSettings objectForKey: @"threadsCollapsed"];
          currentMailbox = [co nameInContainer];
          currentAccount = [[co container] nameInContainer];
          keyForMsgUIDs = [NSString stringWithFormat:@"/%@/%@", currentAccount, currentMailbox];

          if (threadsCollapsed)
            {
              if ((mailboxThreadsCollapsed = [threadsCollapsed objectForKey: keyForMsgUIDs]))
                {
                  for (i = 0; i < [uids count]; i++)
                    [mailboxThreadsCollapsed removeObject:[uids objectAtIndex:i]];
                  [us synchronize];
                }
            }
          response = [self responseWith204];
        }
      else
        {
          data = [NSDictionary dictionaryWithObject: [(NSException *)response reason]
                                             forKey: @"message"];
          response = [self responseWithStatus: 500 andJSONRepresentation: data];
        }
    }
  else
    {
      data = [NSDictionary dictionaryWithObject: @"Error 'uids' and/or 'folder' parameters."
                                         forKey: @"message"];
      response = [self responseWithStatus: 500 andJSONRepresentation: data];
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
  NSDictionary *jsonResponse;
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
         {
           jsonResponse = [NSDictionary dictionaryWithObject: @"You reached an impossible end."
                                                      forKey: @"message"];
           response = [self responseWithStatus: 500 andJSONRepresentation: jsonResponse];
        }
    }
  else
    {
      jsonResponse = [NSDictionary dictionaryWithObject: @"You reached an impossible end."
                                                 forKey: @"message"];
      response = [self responseWithStatus: 500 andJSONRepresentation: jsonResponse];
    }

  return response;
}

- (WOResponse *) _setFolderPurpose: (NSString *) purpose
{
  SOGoMailFolder *co;
  WOResponse *response;
  SOGoUser *owner;
  SOGoUserDefaults *ud;
  NSDictionary *jsonResponse;
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
        {
          jsonResponse = [NSDictionary dictionaryWithObject: @"You reached an impossible end."
                                                     forKey: @"message"];
          response = [self responseWithStatus: 500 andJSONRepresentation: jsonResponse];
        }

      if ([response status] == 204)
        [ud synchronize];
    }
  else
    {
      jsonResponse = [NSDictionary dictionaryWithObject: [self labelForKey: @"Unable to change the purpose of this folder." inContext: context]
                                                 forKey: @"message"];
      response = [self responseWithStatus: 500 andJSONRepresentation: jsonResponse];
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

- (WOResponse *) setAsJunkFolderAction
{
  return [self _setFolderPurpose: @"Junk"];
}

- (WOResponse *) expungeAction 
{
  SOGoMailAccount *account;
  WOResponse *response;
  SOGoTrashFolder *co;
  NSException *error;
  NSDictionary *data;

  id quota;

  co = [self clientObject];

  error = [co expunge];
  if (error)
    {
      data = [NSDictionary dictionaryWithObject: [self labelForKey: @"Unable to expunge folder." inContext: context]
                                         forKey: @"message"];
      response = [self responseWithStatus: 500 andJSONRepresentation: data];
    }
  else
    {
      [co flushMailCaches];

      // We return the inbox quota
      account = [co mailAccountFolder];
      if ((quota = [account getInboxQuota]))
        {
          data = [NSDictionary dictionaryWithObject: quota  forKey: @"quotas"];
          response = [self responseWithStatus: 200 andJSONRepresentation: data];
        }
      else
        response = [self responseWithStatus: 200];
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

  id quota;

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
      data = [NSDictionary dictionaryWithObject: [self labelForKey: @"Unable to empty the trash folder." inContext: context]
                                         forKey: @"message"];
      response = [self responseWithStatus: 500 andJSONRepresentation: data];
    }
  else
    {
      // We return the inbox quota
      account = [co mailAccountFolder];
      if ((quota = [account getInboxQuota]))
        {
          data = [NSDictionary dictionaryWithObjectsAndKeys: quota, @"quotas", nil];
          response = [self responseWithStatus: 200
                                    andString: [data jsonRepresentation]];
        }
      else
        response = [self responseWithStatus: 200];
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

- (WOResponse *) addOrRemoveLabelAction
{
  WOResponse *response;
  WORequest *request;
  SOGoMailFolder *co;
  NSArray *msgUIDs;
  NSMutableArray *flags;
  NSString *operation;
  NSDictionary *content, *result;
  BOOL addOrRemove;
  NGImap4Client *client;
  id o, flag;

  int i;

  request = [context request];
  content = [[request contentAsString] objectFromJSONString];
  flags = nil;
  msgUIDs = nil;

  // Validate parameters
  o = [content objectForKey:@"flags"];
  if ([o isKindOfClass: [NSString class]])
    flags = [NSMutableArray arrayWithObject: o];
  o = [content objectForKey:@"msgUIDs"];
  if ([o isKindOfClass: [NSArray class]])
    msgUIDs = [NSArray arrayWithArray: o];
  operation = [content objectForKey:@"operation"];
  addOrRemove = ([operation isEqualToString:@"add"]? YES: NO);

  if (!flags || !msgUIDs)
    {
      result = [NSDictionary dictionaryWithObject: [self labelForKey: @"Missing 'flags' and 'msgUIDs' parameters."
                                                           inContext: context]
                                           forKey: @"error"];
      response = [self responseWithStatus: 500 andJSONRepresentation: result];
    }
  else
    {
      // We unescape our flags
      for (i = [flags count]-1; i >= 0; i--)
        {
          flag = [flags objectAtIndex: i];
          if ([flag isKindOfClass: [NSString class]])
            [flags replaceObjectAtIndex: i  withObject: [flag fromCSSIdentifier]];
          else
            [flags removeObjectAtIndex: i];
        }

      co = [self clientObject];
      client = [[co imap4Connection] client];
      [[co imap4Connection] selectFolder: [co imap4URL]];
      result = [client storeFlags:flags forUIDs:msgUIDs addOrRemove:addOrRemove];
      if ([[result valueForKey: @"result"] boolValue])
        response = [self responseWith204];
      else
        response = [self responseWithStatus: 500 andJSONRepresentation: result];
    }

  return response;
}

- (WOResponse *) removeAllLabelsAction
{
  WOResponse *response;
  WORequest *request;
  SOGoMailFolder *co;
  NGImap4Client *client;
  NSArray *msgUIDs;
  NSMutableArray *flags;
  NSDictionary *v, *content, *result;

  request = [context request];
  content = [[request contentAsString] objectFromJSONString];
  msgUIDs = [NSArray arrayWithArray:[content objectForKey:@"msgUIDs"]];

  // We always unconditionally remove the Mozilla tags
  flags = [NSMutableArray arrayWithObjects: @"$Label1", @"$Label2", @"$Label3",
           @"$Label4", @"$Label5", nil];

  co = [self clientObject];
  v = [[[context activeUser] userDefaults] mailLabelsColors];
  [flags addObjectsFromArray: [v allKeys]];

  client = [[co imap4Connection] client];
  [[co imap4Connection] selectFolder: [co imap4URL]];
  result = [client storeFlags:flags forUIDs:msgUIDs addOrRemove:NO];

  if ([[result valueForKey: @"result"] boolValue])
    response = [self responseWith204];
  else
    response = [self responseWithStatus:500 andJSONRepresentation:result];

  return response;
}

- (WOResponse *) _markMessagesAsJunkOrNotJunk: (BOOL) isJunk
{
  NSDictionary *content;
  WOResponse *response;
  WORequest *request;
  SOGoMailFolder *co;
  NSArray *uids;

  request = [context request];
  content = [[request contentAsString] objectFromJSONString];
  uids = [NSArray arrayWithArray: [content objectForKey:@"uids"]];

  co = [self clientObject];

  if ([co markMessagesAsJunkOrNotJunk: uids  junk: isJunk])
    response = [self responseWithStatus: 500];
  else
    response = [self responseWith204];

  return response;
}

- (WOResponse *) markMessagesAsJunkAction
{
  return [self _markMessagesAsJunkOrNotJunk: YES];
}

- (WOResponse *) markMessagesAsNotJunkAction
{
  return [self _markMessagesAsJunkOrNotJunk: NO];
}

@end
