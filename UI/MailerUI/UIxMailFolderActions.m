/* UIxMailFolderActions.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2021 Inverse inc.
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
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>

#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4Client.h>
#import <NGImap4/NSString+Imap4.h>


#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailFolder.h>
#import <Mailer/SOGoTrashFolder.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoSystemDefaults.h>
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
                                                     forKey: @"message"];
          response = [self responseWithStatus: 500 andJSONRepresentation: jsonResponse];
        }
    }
  else
    {
      jsonResponse = [NSDictionary dictionaryWithObject: [self labelForKey: @"Missing 'name' parameter."  inContext: context]
                                                 forKey: @"message"];
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
 * @apiSuccess (Success 200) {String} sievePath  New mailbox path relative to account for Sieve script usage
 * @apiError   (Error 500) {Object} error   The error message
 */
- (WOResponse *) renameFolderAction
{
  SOGoMailFolder *co;
  SOGoUserSettings *us;
  WORequest *request;
  WOResponse *response;
  NSException *error;
  NSString *newFolderName, *newFolderPath, *sievePath, *currentMailbox, *currentAccount,
    *keyForMsgUIDs, *newKeyForMsgUIDs;
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

          NSString *sieveFolderEncoding = [[SOGoSystemDefaults sharedSystemDefaults] sieveFolderEncoding];
          if ([sieveFolderEncoding isEqualToString: @"UTF-8"])
            sievePath = [newFolderPath stringByDecodingImap4FolderName];
          else
            sievePath = newFolderPath;

          message = [NSDictionary dictionaryWithObjectsAndKeys:
                                    newFolderPath, @"path", sievePath, @"sievePath", nil];
          response = [self responseWithStatus: 200 andJSONRepresentation: message];
        }
    }

  return response;
}

/**
 * @api {post} /so/:username/Mail/:accountId/:mailboxPath/renameFolder Rename mailbox
 * @apiVersion 1.0.0
 * @apiName PostRenameFolder
 * @apiGroup Mail
 *
 * @apiParam {String} parent Name of the new parent mailbox
 *
 * @apiSuccess (Success 200) {String} path  New mailbox path relative to account
 * @apiSuccess (Success 200) {String} sievePath  New mailbox path relative to account for Sieve script usage
 * @apiError   (Error 500) {Object} error   The error message
 */
- (WOResponse *) moveFolderAction
{
  SOGoMailFolder *co;
  SOGoUserSettings *us;
  WORequest *request;
  WOResponse *response;
  NSException *error;
  NSString *newParentPath, *newFolderPath, *sievePath, *currentMailbox, *currentAccount,
    *keyForMsgUIDs, *newKeyForMsgUIDs;
  NSMutableDictionary *params, *moduleSettings, *threadsCollapsed, *message;
  NSArray *currentComponents, *newComponents, *values;
  int count;

  co = [self clientObject];

  // Prepare the variables need to verify if the current folder have any collapsed threads saved in userSettings
  us = [[context activeUser] userSettings];
  moduleSettings = [us objectForKey: @"Mail"];
  threadsCollapsed = [moduleSettings objectForKey:@"threadsCollapsed"];

  // Retrieve new folder name from JSON payload
  request = [context request];
  params = [[request contentAsString] objectFromJSONString];
  newParentPath = [params objectForKey: @"parent"]; // encoded parent path (ex: "Travail/Employ&AOk-s")

  if (!newParentPath || [newParentPath length] == 0)
    {
      message = [NSDictionary dictionaryWithObject: [self labelForKey: @"Missing parent parameter" inContext: context]
                                            forKey: @"message"];
      response = [self responseWithStatus: 500 andJSONRepresentation: message];
    }
  else
    {
      newFolderPath = [NSString stringWithFormat:@"/%@/%@",
                                newParentPath,
                                [[co imap4URL] lastPathComponent]];
      error = [co renameTo: newFolderPath];
      if (error)
        {
          message = [NSDictionary dictionaryWithObject: [self labelForKey: @"Unable to move folder." inContext: context]
                                                forKey: @"message"];
          response = [self responseWithStatus: 500 andJSONRepresentation: message];
        }
      else
        {
          // Build lookup key for current mailbox path
          currentComponents = [[co imap4URL] pathComponents];
          count = [currentComponents count];
          currentComponents = [[currentComponents subarrayWithRange: NSMakeRange(1,count-1)]
                                resultsOfSelector: @selector (asCSSIdentifier)];
          currentComponents = [currentComponents stringsWithFormat: @"folder%@"];
          currentAccount = [[co mailAccountFolder] nameInContainer]; // integer (ex: 0)
          keyForMsgUIDs = [NSString stringWithFormat:@"/%@/%@", currentAccount,
                                    [currentComponents componentsJoinedByString: @"/"]];

          // Build lookup key for new mailbox path
          newComponents = [newParentPath pathComponents];
          newComponents = [newComponents resultsOfSelector: @selector (asCSSIdentifier)];
          newComponents = [newComponents stringsWithFormat: @"folder%@"];
          currentMailbox = [NSString stringWithFormat: @"folder%@", [[[co imap4URL] lastPathComponent] asCSSIdentifier]];
          newKeyForMsgUIDs = [NSString stringWithFormat:@"/%@/%@/%@", currentAccount,
                                       [newComponents componentsJoinedByString: @"/"], currentMailbox];

          // Verify if the current folder have any collapsed threads save under it old name and adjust the folderName
          if (threadsCollapsed)
            {
              if ([threadsCollapsed objectForKey: keyForMsgUIDs])
                {
                  values = [NSArray arrayWithArray:[threadsCollapsed objectForKey:keyForMsgUIDs]];
                  [threadsCollapsed setObject:values forKey:newKeyForMsgUIDs];
                  [threadsCollapsed removeObjectForKey:keyForMsgUIDs];
                  [us synchronize];
                }
            }
          newFolderPath = [newFolderPath substringFromIndex: 1]; // remove slash at beginning of path

          NSString *sieveFolderEncoding = [[SOGoSystemDefaults sharedSystemDefaults] sieveFolderEncoding];
          if ([sieveFolderEncoding isEqualToString: @"UTF-8"])
            sievePath = [newFolderPath stringByDecodingImap4FolderName];
          else
            sievePath = newFolderPath;

          message = [NSDictionary dictionaryWithObjectsAndKeys:
                                    newFolderPath, @"path", sievePath, @"sievePath", nil];
          response = [self responseWithStatus: 200 andJSONRepresentation: message];
        }
    }

  return response;
}

- (NSString *) _trashedNameOfFolder: (NSURL *) srcURL
                         withObject: (SOGoMailFolder *) co
{
  NSString *trashFolderName, *folderName, *path, *testPath;
  NGImap4Connection *connection;
  id test;
  int i;

  connection = [co imap4Connection];
  folderName = [[srcURL path] lastPathComponent];
  trashFolderName = [[co mailAccountFolder] trashFolderNameInContext: context];
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

  return path;
}

- (void) _removeFolder: (NSString *) srcName
{
  NGImap4Connection *connection;
  NSMutableDictionary *moduleSettings, *threadsCollapsed;;
  NSString *keyForMsgUIDs, *currentMailbox, *currentAccount;
  SOGoMailFolder *co;
  SOGoUserSettings *us;

  co = [self clientObject];
  connection = [co imap4Connection];

  // Unsubscribe from mailbox
  [[connection client] unsubscribe: srcName];

  // Verify if the current folder have any collapsed threads save under it name and erase it
  us = [[context activeUser] userSettings];
  moduleSettings = [us objectForKey: @"Mail"];
  threadsCollapsed = [moduleSettings objectForKey: @"threadsCollapsed"];
  if (threadsCollapsed)
    {
      currentMailbox = [co nameInContainer];
      currentAccount = [[co container] nameInContainer];
      keyForMsgUIDs = [NSString stringWithFormat:@"/%@/%@", currentAccount, currentMailbox];
      if ([threadsCollapsed objectForKey: keyForMsgUIDs])
        {
          [threadsCollapsed removeObjectForKey: keyForMsgUIDs];
          [us synchronize];
        }
    }
}

- (WOResponse *) deleteAction
{
  NSDictionary *jsonRequest, *jsonResponse;
  NSEnumerator *subNames;
  NGImap4Connection *connection;
  SOGoMailFolder *co, *inbox;
  NSURL *srcURL;
  WORequest *request;
  WOResponse *response;
  NSException *error;
  NSInteger count;
  NSString *destName, *currentName;
  BOOL moved, withTrash;

  request = [context request];
  co = [self clientObject];
  connection = [co imap4Connection];
  srcURL = [co imap4URL];
  subNames = [[co allFolderPaths] objectEnumerator];
  jsonRequest = [[request contentAsString] objectFromJSONString];
  withTrash = ![[jsonRequest objectForKey: @"withoutTrash"] boolValue];
  error = nil;
  moved = YES;

  if (withTrash)
    {
      if ([co ensureTrashFolder])
        {
          destName = [self _trashedNameOfFolder: srcURL withObject: co];
          inbox = [[co mailAccountFolder] inboxFolderInContext: context];
          [[connection client] select: [inbox absoluteImap4Name]];

          // If srcURL is a prefix of destURL, that means we are deleting
          // the folder within the 'Trash' folder, as it's getting renamed
          // over and over with an integer suffix (in trashedURLOfFolder:...)
          // If that is the case, we simple delete the folder, instead of renaming it
          if ([destName hasPrefix: [srcURL path]])
            {
              error = [connection deleteMailboxAtURL: srcURL];
              moved = NO;
            }
          else
            {
              error = [connection moveMailbox: [srcURL path] to: destName];
            }
          if (error)
            {
              jsonResponse = [NSDictionary dictionaryWithObject: [self labelForKey: @"Unable to move/delete folder." inContext: context]
                                                         forKey: @"message"];
              response = [self responseWithStatus: 500 andJSONRepresentation: jsonResponse];
            }
          else
            {
              // We unsubscribe to the old one, and subscribe back to the new one
              [self _removeFolder: [srcURL path]];
              if (moved)
                [[connection client] subscribe: destName];

              // We do the same for all subfolders
              count = [[srcURL pathComponents] count];
              while (!error && (currentName = [subNames nextObject]))
                {
                  [self _removeFolder: currentName];
                  if (moved)
                    {
                      NSArray *currentComponents;
                      NSMutableArray *destComponents;
                      NSInteger currentCount;

                      destComponents = [NSMutableArray arrayWithArray: [destName  componentsSeparatedByString: @"/"]];
                      [destComponents removeObjectAtIndex: 0]; // remove leading forward slash
                      currentCount = [[currentName componentsSeparatedByString: @"/"] count];
                      currentComponents = [[currentName componentsSeparatedByString: @"/"] subarrayWithRange: NSMakeRange(count, currentCount - count)];
                      [destComponents addObjectsFromArray: currentComponents];

                      [[connection client] subscribe: [NSString stringWithFormat: @"/%@", [destComponents componentsJoinedByString: @"/"]]];
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
    }
  else
    {
      // Immediately delete mailbox
      connection = [co imap4Connection];
      error = [connection deleteMailboxAtURL: srcURL];
      if (error)
        {
          jsonResponse = [NSDictionary dictionaryWithObject: [self labelForKey: @"Unable to move/delete folder." inContext: context]
                                                     forKey: @"message"];
          response = [self responseWithStatus: 500 andJSONRepresentation: jsonResponse];
        }
      else
        {
          // Cleanup all references to mailbox and submailboxes
          [self _removeFolder: [srcURL path]];
          while (!error && (currentName = [subNames nextObject]))
            {
              [self _removeFolder: currentName];
            }
          response = [self responseWith204];
        }
    }

  return response;
}

- (WOResponse *) batchDeleteAction
{
  NSMutableDictionary *moduleSettings, *threadsCollapsed, *data;
  NSString *currentMailbox, *currentAccount, *keyForMsgUIDs;
  NSMutableArray *mailboxThreadsCollapsed;
  SOGoMailAccount *account;
  SOGoUserSettings *us;
  WOResponse *response;
  SOGoMailFolder *co;
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
          data = [NSMutableDictionary dictionary];
          if (!withTrash)
            {
              // When not using a trash folder, return the quota
              account = [co mailAccountFolder];
              if ((quota = [account getInboxQuota]))
                {
                  [data setObject: quota
                           forKey: @"quotas"];
                }
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
                  if ((mailboxThreadsCollapsed = [threadsCollapsed objectForKey: keyForMsgUIDs]))
                    {
                      for (i = 0; i < [uids count]; i++)
                        [mailboxThreadsCollapsed removeObject: [uids objectAtIndex:i]];
                      [us synchronize];
                    }
                }
            }
          [data setObject: [NSNumber numberWithUnsignedInt: [co unseenCount]]
                   forKey: @"unseenCount"];
          response = [self responseWithStatus: 200
                                    andString: [data jsonRepresentation]];
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
          data = [NSDictionary dictionaryWithObject: [NSNumber numberWithUnsignedInt: [co unseenCount]]
                                             forKey: @"unseenCount"];
          response = [self responseWithStatus: 200 andJSONRepresentation: data];
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

- (WOResponse *) setAsTemplatesFolderAction
{
  return [self _setFolderPurpose: @"Templates"];
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
      if ([co isSpecialFolder])
        {
          // Special folder probably doesn't exist; ignore error.
          response = [self responseWithStatus: 204];
        }
      else
        {
          data = [NSDictionary dictionaryWithObject: [self labelForKey: @"Unable to expunge folder." inContext: context]
                                             forKey: @"message"];
          response = [self responseWithStatus: 500 andJSONRepresentation: data];
        }
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
        response = [self responseWithStatus: 204];
    }

  return response;
}

- (WOResponse *) emptyJunkAction
{
  return [self emptySpecialFolderAction: @"junk"];
}

- (WOResponse *) emptyTrashAction
{
  return [self emptySpecialFolderAction: @"trash"];
}

- (WOResponse *) emptySpecialFolderAction: (NSString *) folderType
{
  NSException *error;
  SOGoSpecialMailFolder *co;
  SOGoMailAccount *account;
  NSEnumerator *subfolders;
  WOResponse *response;
  NGImap4Connection *connection;
  NSString *currentName, *errorMsg;
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
      subfolders = [[co allFolderPaths] objectEnumerator];
      while ((currentName = [subfolders nextObject]))
        {
          [[connection client] unsubscribe: currentName];
          [connection deleteMailbox: currentName];
        }
    }
  if (error)
    {
      errorMsg = [NSString stringWithFormat: @"Unable to empty the %@ folder.", folderType];
      data = [NSDictionary dictionaryWithObject: [self labelForKey: errorMsg inContext: context]
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

// - (WOResponse *) _subscriptionStubAction
// {
//   NSString *mailInvitationParam, *mailInvitationURL;
//   WOResponse *response;
//   SOGoMailFolder *clientObject;

//   mailInvitationParam
//     = [[context request] formValueForKey: @"mail-invitation"];
//   if ([mailInvitationParam boolValue])
//     {
//       clientObject = [self clientObject];
//       mailInvitationURL
// 	= [[clientObject soURLToBaseContainerForCurrentUser]
// 	    absoluteString];
//       response = [self responseWithStatus: 302];
//       [response setHeader: mailInvitationURL
// 		forKey: @"location"];
//     }
//   else
//     {
//       response = [self responseWithStatus: 500];
//       [response appendContentString: @"How did you end up here?"];
//     }

//   return response;
// }

- (WOResponse *) _subscribeOrUnsubscribeAction: (BOOL) subscribing
{
  NGImap4Client *client;
  SOGoMailFolder *co;
  NSDictionary *d;

  co = [self clientObject];
  client = [[co imap4Connection] client];

  if (subscribing)
    d = [client subscribe: [[co imap4URL] path]];
  else
    d = [client unsubscribe: [[co imap4URL] path]];

  if ([[[[d objectForKey: @"RawResponse"] objectForKey: @"ResponseResult"] objectForKey: @"result"] isEqualToString: @"ok"])
    return [self responseWith204];

  return [self responseWithStatus: 200];
}

- (WOResponse *) subscribeAction
{
  return [self _subscribeOrUnsubscribeAction: YES];
}

- (WOResponse *) unsubscribeAction
{
  return [self _subscribeOrUnsubscribeAction: NO];
}

- (id <WOActionResults>) getLabelsAction
{
  NGImap4Client *client;
  NSArray *labels, *userLabel;
  NSDictionary *result, *userLabels, *labelRecord;
  NSEnumerator *labelsList;
  NSMutableArray *allLabels;
  NSString *label;
  SOGoMailFolder *co;
  WOResponse *response;
  unsigned int i;
  static NSArray *imapKeywords = nil;

  if (!imapKeywords)
    {
      imapKeywords = [[NSArray alloc] initWithObjects: @"ANSWERED", @"DELETED",
                                      @"DRAFT", @"FLAGGED", @"NEW", @"OLD", @"RECENT",
                                      @"SEEN", @"UNANSWERED", @"UNDELETED", @"UNDRAFT",
                                      @"UNFLAGGED", @"UNSEEN", nil];
      [imapKeywords retain];
    }

  i = 0;
  allLabels = [NSMutableArray array];
  co = [self clientObject];
  client = [[co imap4Connection] client];
  result = [client select: [[co imap4URL] path]];
  labels = [result objectForKey: @"flags"];
  userLabels = [[[context activeUser] userDefaults] mailLabelsColors];
  labelsList = [[labels sortedArrayUsingSelector: @selector(compareAscending:)] objectEnumerator];
  while ((label = [labelsList nextObject]))
    {
      if (![imapKeywords containsObject: [label uppercaseString]])
        {
          if ((userLabel = [userLabels objectForKey: label]))
            {
              labelRecord = [NSDictionary dictionaryWithObjectsAndKeys:
                                            label, @"imapName",
                                              [userLabel objectAtIndex: 0], @"name",
                                              [userLabel objectAtIndex: 1], @"color", nil];
              [allLabels insertObject: labelRecord atIndex: i];
              i++;
            }
          else
            {
              labelRecord = [NSDictionary dictionaryWithObjectsAndKeys:
                                            label, @"imapName", nil];
              [allLabels addObject: labelRecord];
            }
        }
    }

  response = [self responseWithStatus: 200 andJSONRepresentation: allLabels];

  return response;
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
                                           forKey: @"message"];
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
