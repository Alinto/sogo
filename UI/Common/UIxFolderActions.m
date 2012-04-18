/* UIxFolderActions.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2010 Inverse inc.
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/SoClassSecurityInfo.h>
#import <NGObjWeb/NSException+HTTP.h>

#import <SoObjects/SOGo/SOGoUserManager.h>
#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/SOGoContentObject.h>
#import <SoObjects/SOGo/SOGoGCSFolder.h>
#import <SoObjects/SOGo/SOGoParentFolder.h>
#import <SoObjects/SOGo/SOGoPermissions.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoUserSettings.h>

#import "WODirectAction+SOGo.h"

#import "UIxFolderActions.h"

@implementation UIxFolderActions

- (void) _setupContext
{
  NSString *mailInvitationParam;
  SOGoUser *activeUser;

  activeUser = [context activeUser];
  login = [activeUser login];
  clientObject = [self clientObject];
  owner = [clientObject ownerInContext: nil];

  baseFolder = [[clientObject container] nameInContainer];

  um = [SOGoUserManager sharedUserManager];
  us = [activeUser userSettings];
  moduleSettings = [us objectForKey: baseFolder];
  if (!moduleSettings)
    moduleSettings = [NSMutableDictionary dictionary];
  [us setObject: moduleSettings forKey: baseFolder];

  mailInvitationParam
    = [[context request] formValueForKey: @"mail-invitation"];
  isMailInvitation = [mailInvitationParam boolValue];
}

- (WOResponse *) _subscribeAction: (BOOL) reallyDo
{
  WOResponse *response;
  NSURL *mailInvitationURL;

  response = [context response];
  [response setHeader: @"text/plain; charset=utf-8"
               forKey: @"Content-Type"];

  [self _setupContext];
  if ([owner isEqualToString: login])
    {
      [response setStatus: 403];
      [response appendContentString:
                  @"You cannot (un)subscribe to a folder that you own!"];
    }
  else
    {
      [clientObject subscribeUserOrGroup: login reallyDo: reallyDo];
      if (isMailInvitation)
        {
          mailInvitationURL
            = [clientObject soURLToBaseContainerForCurrentUser];
          [response setStatus: 302];
          [response setHeader: [mailInvitationURL absoluteString]
                       forKey: @"location"];
        }
      else
        [response setStatus: 204];
    }

  return response;
}

- (WOResponse *) subscribeAction
{
  return [self _subscribeAction: YES];
}

- (WOResponse *) unsubscribeAction
{
  return [self _subscribeAction: NO];
}

- (WOResponse *) canAccessContentAction
{
  /* We want this action to be authorized managed by the SOPE's internal acl
     handling. */
  return [self responseWith204];
// #warning IMPROVEMENTS REQUIRED!
//   NSArray *acls;
// //  NSEnumerator *userAcls;
// //  NSString *currentAcl;

//   [self _setupContext];
  
// //  NSLog(@"canAccessContentAction %@, owner %@", subscriptionPointer, owner);

//   if ([login isEqualToString: owner] || [owner isEqualToString: @"nobody"]) {
//     return [self responseWith204];
//   }
//   else {
//     acls = [clientObject aclsForUser: login];
// //    userAcls = [acls objectEnumerator];
// //    currentAcl = [userAcls nextObject];
// //    while (currentAcl) {
// //      NSLog(@"ACL login %@, owner %@, folder %@: %@",
// //	    login, owner, baseFolder, currentAcl);
// //      currentAcl = [userAcls nextObject];
// //    }
//     if (([[clientObject folderType] isEqualToString: @"Contact"]
// 	 && [acls containsObject: SOGoRole_ObjectViewer]) ||
// 	([[clientObject folderType] isEqualToString: @"Appointment"]
// 	 && [acls containsObject: SOGoRole_AuthorizedSubscriber])) {
//       return [self responseWith204];
//     }
//   }
  
//   return [self responseWithStatus: 403];
}

- (WOResponse *) _realFolderActivation: (BOOL) makeActive
{
  NSMutableArray *folderSubscription;
  NSString *folderName;

  [self _setupContext];
  folderSubscription
    = [moduleSettings objectForKey: @"InactiveFolders"];
  if (!folderSubscription)
    {
      folderSubscription = [NSMutableArray array];
      [moduleSettings setObject: folderSubscription forKey: @"InactiveFolders"];
    }

  folderName = [clientObject nameInContainer];
  if (makeActive)
    [folderSubscription removeObject: folderName];
  else
    [folderSubscription addObjectUniquely: folderName];

  [us synchronize];

  return [self responseWith204];
}

- (WOResponse *) activateFolderAction
{
  return [self _realFolderActivation: YES];
}

- (WOResponse *) deactivateFolderAction
{
  return [self _realFolderActivation: NO];
}

- (WOResponse *) renameFolderAction
{
  WOResponse *response;
  NSString *folderName;

  folderName = [[context request] formValueForKey: @"name"];
  if ([folderName length] > 0)
    {
      clientObject = [self clientObject];
      [clientObject renameTo: folderName];
      response = [self responseWith204];
    }
  else
    {
      response = [self responseWithStatus: 500];
      [response appendContentString: @"Missing 'name' parameter."];
    }

  return response;
}

- (id) batchDeleteAction
{
  WOResponse *response;
  NSString *idsParam;
  NSArray *ids;

  idsParam = [[context request] formValueForKey: @"ids"];
  ids = [idsParam componentsSeparatedByString: @"/"];
  if ([ids count])
    {
      clientObject = [self clientObject];
      [clientObject deleteEntriesWithIds: ids];
      response = [self responseWith204];
    }
  else
    {
      response = [self responseWithStatus: 500];
      [response appendContentString: @"At least 1 id required."];
    }
  
  return response;
}

- (NSException*) _moveContacts: (NSArray*) contactsId 
		      toFolder: (NSString*) destinationFolderId
		   andKeepCopy: (BOOL) keepCopy
{
  NSEnumerator *uids;
  NSException *ex;
  NSString *uid;
  SOGoContentObject *currentChild;
  SOGoGCSFolder *sourceFolder, *destinationFolder;
  SOGoParentFolder *folders;
  SoSecurityManager *sm;
  WORequest *request;
  unsigned int errorCount;

  sm = [SoSecurityManager sharedSecurityManager];
  request = [context request];
  ex = nil;
  errorCount = 0;

  // Search the specified destination folder
  sourceFolder = [self clientObject];
  folders = [sourceFolder container];
  destinationFolder = [folders lookupName: destinationFolderId
			       inContext: nil
			       acquire: NO];
  if (destinationFolder)
    {
      // Verify write access to the folder
      ex = [sm validatePermission: SoPerm_AddDocumentsImagesAndFiles
	       onObject: destinationFolder
	       inContext: context];
      if (!ex)
	{
	  uids = [contactsId objectEnumerator];
	  while ((uid = [uids nextObject]))
	    {
	      // Search the currentChild ID
	      currentChild = [sourceFolder lookupName: uid
					   inContext: [self context]
					   acquire: NO];
	      if ([currentChild isKindOfClass: [NSException class]])
		errorCount++;
	      else
		{
		  if (keepCopy)
		    ex = [currentChild copyToFolder: destinationFolder];
		  else
		    ex = [currentChild moveToFolder: destinationFolder];
		  if (ex)
		    errorCount++;
		}
	    }
	}
    }
  else
    ex = [NSException exceptionWithName: @"UnknownDestinationFolder"
		      reason: @"Unknown Destination Folder"
		      userInfo: nil];

  if (errorCount > 0)
    // At least one currentChild was not copied
    ex = [NSException exceptionWithHTTPStatus: 400
		      reason: @"Invalid Contact"];
  else if (ex != nil)
    // Destination address book doesn't exist or is not writable
    ex = [NSException exceptionWithHTTPStatus: 403
		      reason: [ex name]];

  return ex;
}

- (id <WOActionResults>) copyAction
{
  WORequest *request;
  id <WOActionResults> response;
  NSString *destinationFolderId;
  NSArray *contactsId;
  NSException *ex;
  
  request = [context request];

  if ((destinationFolderId = [request formValueForKey: @"folder"]) &&
      (contactsId = [request formValuesForKey: @"uid"]))
    ex = [self _moveContacts: contactsId
                    toFolder: destinationFolderId
		 andKeepCopy: YES];
  else
    ex = [NSException exceptionWithHTTPStatus: 400
                                       reason: (@"missing 'folder' and/or"
                                                @" 'uid' parameter")];
  
  if (ex)
    response = (id) ex;
  else
    response = [self responseWith204];

  return response;
}

- (id <WOActionResults>) moveAction
{
  WORequest *request;
  id <WOActionResults> response;
  NSString *destinationFolderId;
  NSArray *contactsId;
  NSException *ex;
  
  request = [context request];

  if ((destinationFolderId = [request formValueForKey: @"folder"])
      && (contactsId = [request formValuesForKey: @"uid"]))
    ex = [self _moveContacts: contactsId
                    toFolder: destinationFolderId
		 andKeepCopy: NO];
  else
    ex = [NSException exceptionWithHTTPStatus: 400
                                       reason: (@"missing 'folder' and/or"
                                                @"'uid' parameter")];
  
  if (ex)
    response = (id <WOActionResults>) ex;
  else
    response = [self responseWith204];
  
  return response;
}

- (id <WOActionResults>) subscribeUsersAction
{
  id <WOActionResults> response;
  NSString *uids;
  NSArray *userIDs;
  SOGoGCSFolder *folder;
  NSException *ex;
  int count, max;
  
  uids = [[context request] formValueForKey: @"uids"];
  if ([uids length])
    {
      userIDs = [uids componentsSeparatedByString: @","];
      folder = [self clientObject];
      max = [userIDs count];
      for (count = 0; count < max; count++)
        [folder subscribeUserOrGroup: [userIDs objectAtIndex: count]
			    reallyDo: YES];
      ex = nil;
    }
  else
    ex = [NSException exceptionWithHTTPStatus: 400
                                       reason: @"missing 'uids' parameter"];
  
  if (ex)
    response = (id <WOActionResults>) ex;
  else
    response = [self responseWith204];
  
  return response;
}

@end
