/* UIxContactFolderActions.m - this file is part of SOGo
 *
 * Copyright (C) 2008 Inverse groupe conseil
 *
 * Author: Francis Lachapelle <flachapelle@inverse.ca>
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

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoPermissions.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <NGCards/NGVCard.h>

#import <Contacts/SOGoContactFolders.h>
#import <Contacts/SOGoContactObject.h>

#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/NSObject+Utilities.h>
#import <SoObjects/SOGo/NSString+Utilities.h>
#import <SoObjects/SOGo/SOGoContentObject.h>
#import <SoObjects/SOGo/SOGoFolder.h>
#import <SoObjects/SOGo/SOGoUser.h>

#import "../Common/WODirectAction+SOGo.h"

#import "UIxContactFolderActions.h"

@implementation UIxContactFolderActions

- (NSException*) _moveContacts: (NSArray*) contactsId 
                     toFolder: (NSString*) destinationFolderId
                  andKeepCopy: (BOOL) keepCopy
{
  NGVCard *card;
  NSEnumerator *uids;
  NSException *ex;
  NSString *uid, *newUid;
  id <SOGoContactObject> contact;
  SOGoContactFolders *folders;
  SOGoParentFolder *sourceFolder, *destinationFolder;
  SOGoContentObject *newContact;
  SoSecurityManager *sm;
  WORequest *request;
  unsigned int errorCount;

  sm = [SoSecurityManager sharedSecurityManager];
  request = [context request];
  ex = nil;
  errorCount = 0;

  // Search the specified destination folder
  sourceFolder = [self clientObject];
  folders = [(SOGoUserFolder*)[[sourceFolder container] container] privateContacts: @"Contacts"
			      inContext: nil];
  destinationFolder = [folders lookupName: destinationFolderId
			       inContext: nil
			       acquire: NO];
  if (destinationFolder)
    {
      // Verify write access to the folder
      ex = [sm validatePermission: SoPerm_AddDocumentsImagesAndFiles
	       onObject: destinationFolder
	       inContext: context];
      if (ex == nil)
	{
	  uids = [contactsId objectEnumerator];
	  uid = [uids nextObject];
	      
	  while (uid)
	    {
	      // Search the contact ID
	      contact = [sourceFolder lookupName: uid
				      inContext: [self context]
				      acquire: NO];
	      if ([(NSObject*)contact isKindOfClass: [NSException class]])
		errorCount++;
	      else
		{
		  card = [contact vCard];

		  if (keepCopy)
		    {
		      // Change the contact UID
		      newUid = [SOGoObject globallyUniqueObjectId];
		      [card setUid: newUid];
		      newContact = [SOGoContentObject objectWithName: newUid
						      inContainer: destinationFolder];
		    }
		  else
		    // Don't change the contact UID
		    newContact = [SOGoContentObject objectWithName: [contact nameInContainer]
						    inContainer: (SOGoGCSFolder*)destinationFolder];
		  		  
		  ex = [newContact saveContentString: [card versitString]];
		  
		  if (ex == nil && !keepCopy)
		    // Delete the original contact if necessary
		    ex = [contact delete];
		  if (ex != nil)
		    errorCount++;
		}	      
	      uid = [uids nextObject];
	    }
	}
    }
  else
    ex = [NSException exceptionWithName: @"UnkownDestinationFolder"
		      reason: @"Unknown Destination Folder"
		      userInfo: nil];
  
  if (errorCount > 0)
    // At least one contact was not copied
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
  ex = nil;

  if ((destinationFolderId = [request formValueForKey: @"folder"]) &&
      (contactsId = [request formValuesForKey: @"uid"]))
    {
      ex = [self _moveContacts: contactsId
		 toFolder: destinationFolderId
		 andKeepCopy: YES];
      if (ex != nil)
	response = (id)ex;
    }
  else
    response = [NSException exceptionWithHTTPStatus: 400
			    reason: @"missing 'folder' and/or 'uid' parameter"];
  
    if (ex == nil)
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
  ex = nil;

  if ((destinationFolderId = [request formValueForKey: @"folder"]) &&
      (contactsId = [request formValuesForKey: @"uid"]))
    {
      ex = [self _moveContacts: contactsId
		 toFolder: destinationFolderId
		 andKeepCopy: NO];
      if (ex != nil)
	response = (id)ex;
    }
  else
    response = [NSException exceptionWithHTTPStatus: 400
			    reason: @"missing 'folder' and/or 'uid' parameter"];
  
    if (ex == nil)
      response = [self responseWith204];

    return response;
}

@end
