/* UIxContactFoldersView.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse groupe conseil
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
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoObject.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <GDLContentStore/GCSFolder.h>
#import <GDLContentStore/GCSFolderManager.h>

#import <SoObjects/SOGo/LDAPUserManager.h>
#import <SoObjects/SOGo/SOGoPermissions.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/NSString+Utilities.h>
#import <SoObjects/Contacts/SOGoContactFolders.h>
#import <SoObjects/Contacts/SOGoContactFolder.h>
#import <SoObjects/Contacts/SOGoContactGCSFolder.h>
#import <SoObjects/Contacts/SOGoContactLDAPFolder.h>

#import "UIxContactFoldersView.h"

@implementation UIxContactFoldersView

- (void) _setupContext
{
  SOGoUser *activeUser;
  NSString *module;
  SOGoContactFolders *clientObject;

  activeUser = [context activeUser];
  clientObject = [self clientObject];

  module = [clientObject nameInContainer];

  ud = [activeUser userSettings];
  moduleSettings = [ud objectForKey: module];
  if (!moduleSettings)
    {
      moduleSettings = [NSMutableDictionary new];
      [moduleSettings autorelease];
    }
  [ud setObject: moduleSettings forKey: module];
}

- (id) _selectActionForApplication: (NSString *) actionName
{
  SOGoContactFolders *folders;
  NSString *url, *action;
  WORequest *request;

  folders = [self clientObject];
  action = [NSString stringWithFormat: @"../personal/%@", actionName];

  request = [[self context] request];

  url = [[request uri] composeURLWithAction: action
                       parameters: [self queryParameters]
                       andHash: NO];

  return [self redirectToLocation: url];
}

- (id) defaultAction
{
  return [self _selectActionForApplication: @"view"];
}

- (id) selectForMailerAction
{
  return [self _selectActionForApplication: @"mailer-contacts"];
}

- (void) _fillResults: (NSMutableDictionary *) results
	     inFolder: (id <SOGoContactFolder>) folder
	 withSearchOn: (NSString *) contact
{
  NSEnumerator *folderResults;
  NSDictionary *currentContact;
  NSString *uid;

  folderResults = [[folder lookupContactsWithFilter: contact
			   sortBy: @"cn"
			   ordering: NSOrderedAscending] objectEnumerator];
  currentContact = [folderResults nextObject];
  while (currentContact)
    {
      uid = [currentContact objectForKey: @"c_uid"];
      if (uid && ![results objectForKey: uid])
	[results setObject: currentContact forKey: uid];
      currentContact = [folderResults nextObject];
    }
}

- (NSString *) _emailForResult: (NSDictionary *) result
{
  NSMutableString *email;
  NSString *name, *mail;

  email = [NSMutableString string];
  name = [result objectForKey: @"displayName"];
  if (![name length])
    name = [result objectForKey: @"cn"];
  mail = [result objectForKey: @"mail"];
  if ([name length])
    [email appendFormat: @"%@ <%@>", name, mail];
  else
    [email appendString: mail];

  return email;
}

- (WOResponse *) _responseForResults: (NSArray *) results
{
  WOResponse *response;
  NSEnumerator *contacts;
  NSString *email;
  NSDictionary *contact;
  NSMutableArray *formattedContacts;
  NSMutableDictionary *formattedContact; 

  response = [context response];

  if ([results count] > 0)
    {
      [response setStatus: 200];
      contacts = [results objectEnumerator];
      contact = [contacts nextObject];
      formattedContacts = [[NSMutableArray alloc] initWithCapacity: [results count]];
      while (contact)
	{
	  email = [contact objectForKey: @"c_email"];
	  if ([email length])
	    {
	      formattedContact = [NSMutableDictionary dictionary];
	      [formattedContact setObject: [contact objectForKey: @"c_uid"]
				forKey: @"uid"];
	      [formattedContact setObject: [contact objectForKey: @"cn"]
				forKey: @"name"];
	      [formattedContact setObject: email
				forKey: @"email"];
	      [formattedContacts addObject: formattedContact];
	    }
	  contact = [contacts nextObject];
	}
      [response appendContentString: [formattedContacts jsonRepresentation]];
      [formattedContacts release];
    }
  else
    [response setStatus: 404];

  return response;
}

- (id <WOActionResults>) contactSearchAction
{
  NSString *contact;
  id <WOActionResults> result;
  LDAPUserManager *um;
  
  contact = [self queryParameterForKey: @"search"];
  if ([contact length] > 0)
    {
      um = [LDAPUserManager sharedUserManager];
      result
	= [self _responseForResults: [um fetchContactsMatching: contact]];
    }
  else
    result = [NSException exceptionWithHTTPStatus: 400
                          reason: @"missing 'search' parameter"];
  
  return result;
}

- (NSArray *) _subFoldersFromFolder: (SOGoParentFolder *) parentFolder
{
  NSMutableArray *folders;
  NSEnumerator *subfolders;
  SOGoGCSFolder *currentFolder;
  NSString *folderName;
  NSMutableDictionary *currentDictionary;
  SoSecurityManager *securityManager;

  securityManager = [SoSecurityManager sharedSecurityManager];

//   return (([securityManager validatePermission: SoPerm_AccessContentsInformation
//                             onObject: contactFolder
//                             inContext: context] == nil)

  folders = [NSMutableArray new];
  [folders autorelease];

  subfolders = [[parentFolder subFolders] objectEnumerator];
  while ((currentFolder = [subfolders nextObject]))
    {
      if (![securityManager validatePermission: SOGoPerm_AccessObject
			    onObject: currentFolder inContext: context])
	{
	  folderName = [NSString stringWithFormat: @"/%@/%@",
				 [parentFolder nameInContainer],
				 [currentFolder nameInContainer]];
	  currentDictionary
	    = [NSMutableDictionary dictionaryWithCapacity: 3];
	  [currentDictionary setObject: [currentFolder displayName]
			     forKey: @"displayName"];
	  [currentDictionary setObject: folderName forKey: @"name"];
	  [currentDictionary setObject: [currentFolder folderType]
			     forKey: @"type"];
	  [folders addObject: currentDictionary];
	}
    }

  return folders;
}

// - (SOGoContactGCSFolder *) contactFolderForUID: (NSString *) uid
// {
//   SOGoFolder *upperContainer;
//   SOGoUserFolder *userFolder;
//   SOGoContactFolders *contactFolders;
//   SOGoContactGCSFolder *contactFolder;
//   SoSecurityManager *securityManager;

//   upperContainer = [[[self clientObject] container] container];
//   userFolder = [SOGoUserFolder objectWithName: uid
//                                inContainer: upperContainer];
//   contactFolders = [SOGoUserFolder lookupName: @"Contacts"
// 				   inContext: context
// 				   acquire: NO];
//   contactFolder = [contactFolders lookupName: @"personal"
// 				  inContext: context
// 				  acquire: NO];

//   securityManager = [SoSecurityManager sharedSecurityManager];

//   return (([securityManager validatePermission: SoPerm_AccessContentsInformation
//                             onObject: contactFolder
//                             inContext: context] == nil)
//           ? contactFolder : nil);
// }

- (WOResponse *) saveDragHandleStateAction
{
  WORequest *request;
  NSString *dragHandle;
  
  [self _setupContext];
  request = [context request];
 
  if ((dragHandle = [request formValueForKey: @"vertical"]) != nil)
    [moduleSettings setObject: dragHandle
		    forKey: @"DragHandleVertical"];
  else if ((dragHandle = [request formValueForKey: @"horizontal"]) != nil)
    [moduleSettings setObject: dragHandle
		    forKey: @"DragHandleHorizontal"];
  else
    return [self responseWithStatus: 400];
  
  [ud synchronize];

  return [self responseWithStatus: 204];
}

@end
