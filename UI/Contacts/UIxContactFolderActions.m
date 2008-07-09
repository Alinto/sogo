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

- (id) init
{
  if ((self = [super init]))
    {
    }

  return self;
}

- (void) dealloc
{
  [super dealloc];
}

- (WOResponse *) copyAction
{
  WORequest *request;
  NSArray *contactsId;
  NSEnumerator *uids;
  NSString *folderId, *uid, *newUid;
  SOGoContactFolders *folders;
  SOGoParentFolder *folder, *destinationFolder;
  id <SOGoContactObject> contact;
  SOGoContentObject *newContact;
  NGVCard *card;
  NSException *ex;
  unsigned int errorCount;

  request = [context request];
  errorCount = 0;

  if ((folderId = [request formValueForKey: @"folder"]) &&
      (contactsId = [request formValuesForKey: @"uid"]))
    {
      // Search the specified destination folder
      folder = [self clientObject];
      folders = [(SOGoUserFolder*)[[folder container] container] privateContacts: @"Contacts"
						inContext: nil];
      destinationFolder = [folders lookupName: folderId
				   inContext: nil
				   acquire: NO];
      if (destinationFolder)
	{
       	  uids = [contactsId objectEnumerator];
	  uid = [uids nextObject];
	  
	  while (uid)
	    {
	      contact = [folder lookupName: uid
				inContext: [self context]
				acquire: NO];
	      if (![(NSObject*)contact isKindOfClass: [NSException class]])
		{
		  newUid = [SOGoObject globallyUniqueObjectId];
		  card = [contact vCard];
		  [card setUid: newUid];
		  
		  //[contact setContent: [card versitString]];
		  //[contact copyTo: destinationFolder]; // verify if exception

		  newContact = [SOGoContentObject objectWithName: newUid
						  inContainer: destinationFolder];
		  ex = [newContact saveContentString: [card versitString]];
		  if (ex != nil)
		    errorCount++;
		}
	      uid = [uids nextObject];
	    }
	}
    }
  
  return [self responseWithStatus: 204];
}

- (WOResponse *) moveAction
{
   return [self responseWithStatus: 204];
}

@end
