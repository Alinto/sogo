/* UIxFolderActions.m - this file is part of SOGo
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

#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/NSException+HTTP.h>

#import <SOGo/SOGoUserManager.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoContentObject.h>
#import <SOGo/SOGoParentFolder.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>

#import <Contacts/SOGoContactGCSFolder.h>
#import <Contacts/SOGoContactSourceFolder.h>

#import <Appointments/SOGoAppointmentFolder.h>

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
  NSArray *allACLs;
  NSDictionary *jsonResponse;
  NSMutableDictionary *acls;
  NSURL *mailInvitationURL;
  BOOL objectCreator, objectEditor, objectEraser;

  response = nil;
  [self _setupContext];
  if ([owner isEqualToString: login])
    {
      jsonResponse = [NSDictionary dictionaryWithObject: [self labelForKey: @"You cannot (un)subscribe to a folder that you own!"]
                                                 forKey: @"message"];
      response = [self responseWithStatus: 403
                    andJSONRepresentation: jsonResponse];
    }
  else
    {
      [clientObject subscribeUserOrGroup: login
                                reallyDo: reallyDo
                                response: response];

      if (isMailInvitation)
        {
          mailInvitationURL = [clientObject soURLToBaseContainerForCurrentUser];
          response = [self responseWithStatus: 302];
          [response setHeader: [mailInvitationURL absoluteString]
                       forKey: @"location"];
        }
      else
        {
          // We extract ACLs for this address book
          allACLs = ([owner isEqualToString: login] ? nil : [clientObject aclsForUser: login]);
          objectCreator = ([owner isEqualToString: login] || [allACLs containsObject: SOGoRole_ObjectCreator]);
          objectEditor = ([owner isEqualToString: login] || [allACLs containsObject: SOGoRole_ObjectEditor]);
          objectEraser = ([owner isEqualToString: login] || [allACLs containsObject: SOGoRole_ObjectEraser]);
          acls = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool: objectCreator], @"objectCreator",
                                   [NSNumber numberWithBool: objectEditor], @"objectEditor",
                                   [NSNumber numberWithBool: objectEraser], @"objectEraser", nil];

          // @see [SOGoGCSFolder folderWithSubscriptionReference:inContainer:]
          jsonResponse
            = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSString stringWithFormat: @"%@_%@", [owner asCSSIdentifier], [clientObject nameInContainer]], @"id",
                            owner, @"owner",
                            [clientObject displayName], @"name",
                            [NSNumber numberWithBool: [clientObject isKindOfClass: [SOGoGCSFolder class]]], @"isEditable",
                            [NSNumber numberWithBool:
                                        [clientObject isKindOfClass: [SOGoContactSourceFolder class]]
                                      && ![(SOGoContactSourceFolder *) clientObject isPersonalSource]], @"isRemote",
                            acls, @"acls",
                            nil];
          response = [self responseWithStatus: 200
                        andJSONRepresentation: jsonResponse];
        }
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

/**
 * @api {get} /so/:username/:folderPath/canAccessContent Test access rights
 * @apiVersion 1.0.0
 * @apiName GetCanAccessContent
 * @apiGroup Common
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/personal/canAccessContent
 */
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
  folderSubscription = [moduleSettings objectForKey: @"InactiveFolders"];
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

/**
 * @api {get} /so/:username/:folderPath/newguid Generate new ID
 * @apiVersion 1.0.0
 * @apiName GetNewGUID
 * @apiGroup Common
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/personal/newguid
 *
 * @apiSuccess (Success 200) {String} pid Folder ID (element's parent)
 * @apiSuccess (Success 200) {String} id  New element ID
 * @apiError   (Error 500) {Object} error The error message
 */
- (WOResponse *) newguidAction
{
  NSString *objectId, *folderId;
  NSDictionary *data;
  WOResponse *response;
  SOGoFolder *co;
  SoSecurityManager *sm;

  co = [self clientObject];
  objectId = [co globallyUniqueObjectId];
  if ([objectId length] > 0)
    {
      sm = [SoSecurityManager sharedSecurityManager];
      if (![sm validatePermission: SoPerm_AddDocumentsImagesAndFiles
	      onObject: co
	      inContext: context])
	{
          folderId = [co nameInContainer];
	}
      else
	{
          folderId = @"personal";
	}
      // Append meaningful extension to objects of calendars and addressbooks
      if ([co isKindOfClass: [SOGoContactGCSFolder class]])
        {
          objectId = [NSString stringWithFormat: @"%@.vcf", objectId];
        }
      else if ([co isKindOfClass: [SOGoAppointmentFolder class]])
        {
          objectId = [NSString stringWithFormat: @"%@.ics", objectId];
        }
      data = [NSDictionary dictionaryWithObjectsAndKeys: objectId, @"id", folderId, @"pid", nil];
      response = [self responseWithStatus: 200
                                andString: [data jsonRepresentation]];
    }
  else
    response = [NSException exceptionWithHTTPStatus: 500 /* Internal Error */
                                             reason: @"could not create a unique ID"];

  return response;
}

- (WOResponse *) renameFolderAction
{
  WOResponse *response;
  WORequest *request;
  NSDictionary *params, *message;
  NSString *folderName;

  request = [context request];
  params = [[request contentAsString] objectFromJSONString];
  folderName = [params objectForKey: @"name"];
  if ([folderName length] > 0)
    {
      clientObject = [self clientObject];
      NS_DURING
        {
          [clientObject renameTo: folderName];
          response = [self responseWith204];
        }
      NS_HANDLER
        {
          message = [NSDictionary dictionaryWithObject: [localException reason] forKey: @"message"];
          response = [self responseWithStatus: 409 /* Conflict */
                                    andString: [message jsonRepresentation]];
        }
      NS_ENDHANDLER;
    }
  else
    {
      message = [NSDictionary dictionaryWithObject: @"Missing name parameter" forKey: @"message"];
      response = [self responseWithStatus: 500
                                andString: [message jsonRepresentation]];
    }

  return response;
}

/**
 * @api {post} /so/:username/:folderPath/batchDelete?uids=:uids Delete multiple resources
 * @apiVersion 1.0.0
 * @apiName GetBatchDelete
 * @apiGroup Common
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Contacts/personal/batchDelete \
 *          -H 'Content-Type: application/json' \
 *          -d '{ "uids": ["1BC8-52F53F80-1-38C52041.vcf", "4095-52B0C180-31-9225E71.vlf"] }'
 *
 * @apiParam {String[]} uids List of resources IDs
 *
 * @apiError (Error 400) {Object} error The error message
 */
- (id) batchDeleteAction
{
  WOResponse *response;
  NSDictionary *data;
  NSArray *ids;

  data = [[[context request] contentAsString] objectFromJSONString];
  ids = [data objectForKey: @"uids"];
  
  if ([ids isKindOfClass: [NSArray class]] && [ids count])
    {
      clientObject = [self clientObject];
      [clientObject deleteEntriesWithIds: ids];
      response = [self responseWith204];
    }
  else
    {
      response = [self responseWithStatus: 400
                    andJSONRepresentation: [NSDictionary dictionaryWithObject: @"At least 1 id required."
                                                                     forKey: @"message"]];
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
  unsigned int errorCount;

  sm = [SoSecurityManager sharedSecurityManager];
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
  id <WOActionResults> response;
  NSString *destinationFolderId;
  NSArray *contactsId;
  NSDictionary *data;
  NSException *ex;
  
  data = [[[context request] contentAsString] objectFromJSONString];
  contactsId = [data objectForKey: @"uids"];
  destinationFolderId = [data objectForKey: @"folder"];

  if (destinationFolderId && [contactsId count])
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
  id <WOActionResults> response;
  NSString *destinationFolderId;
  NSDictionary *data;
  NSArray *contactsId;
  NSException *ex;
  
  data = [[[context request] contentAsString] objectFromJSONString];
  contactsId = [data objectForKey: @"uids"];
  destinationFolderId = [data objectForKey: @"folder"];

  if (destinationFolderId && [contactsId count])
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

/**
 * @api {get} /so/:username/:folderPath/subscribeUsers?uids=:uids Subscribe user(s)
 * @apiVersion 1.0.0
 * @apiName GetSubscribeUsers
 * @apiGroup Common
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/personal/subscribeUsers?uids=sogo2,sogo3
 *
 * @apiParam {String} uids Comma-separated list of user IDs
 *
 * @apiError (Error 400) {Object} error The error message
 */
- (id <WOActionResults>) subscribeUsersAction
{
  id <WOActionResults> response;
  NSString *uids;
  NSArray *userIDs;
  SOGoGCSFolder *folder;
  int count, max;
  
  uids = [[context request] formValueForKey: @"uids"];
  if ([uids length])
    {
      userIDs = [uids componentsSeparatedByString: @","];
      folder = [self clientObject];
      max = [userIDs count];
      for (count = 0; count < max; count++)
        [folder subscribeUserOrGroup: [userIDs objectAtIndex: count]
			    reallyDo: YES
                            response: nil];
      response = [self responseWith204];
    }
  else
    response = [self responseWithStatus: 400
                  andJSONRepresentation: [NSDictionary dictionaryWithObject: @"missing 'uids' parameter"
                                                                     forKey: @"message"]];
  
  return response;
}

@end
