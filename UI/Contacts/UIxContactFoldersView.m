/* UIxContactFoldersView.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2008 Inverse inc.
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
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoObject.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <NGExtensions/NSNull+misc.h>

#import <GDLContentStore/GCSFolder.h>
#import <GDLContentStore/GCSFolderManager.h>

#import <SoObjects/SOGo/LDAPUserManager.h>
#import <SoObjects/SOGo/SOGoPermissions.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/NSDictionary+Utilities.h>
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

- (id <WOActionResults>) mailerContactsAction
{
  selectorComponentClass = @"UIxContactsMailerSelection";

  return self;
}

- (NSString *) selectorComponentClass
{
  return selectorComponentClass;
}

- (WOElement *) selectorComponent
{
  WOElement *newComponent;

  newComponent = [self pageWithName: selectorComponentClass];

  return newComponent;
}

- (BOOL) hasContactSelectionButtons
{
  return (selectorComponentClass != nil);
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

- (NSArray *) _responseForResults: (NSArray *) results
{
  NSEnumerator *contacts;
  NSString *email, *infoKey, *info;
  NSDictionary *contact;
  NSMutableArray *formattedContacts;
  NSMutableDictionary *formattedContact; 
  NSUserDefaults *sud;

  formattedContacts = [NSMutableArray arrayWithCapacity: [results count]];

  if ([results count] > 0)
    {
      sud = [NSUserDefaults standardUserDefaults];
      infoKey = [sud stringForKey: @"SOGoLDAPContactInfoAttribute"];
      contacts = [results objectEnumerator];
      contact = [contacts nextObject];
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
	      if ([infoKey length] > 0)
		{
		  info = [contact objectForKey: infoKey];
		  if (info != nil)
		    [formattedContact setObject: info
				      forKey: @"contactInfo"];
		}
	      [formattedContacts addObject: formattedContact];
	    }
	  contact = [contacts nextObject];
	}
    }

  return formattedContacts;
}

- (id <WOActionResults>) allContactSearchAction
{
  id <WOActionResults> result;
  id <SOGoContactFolder> folder;
  NSString *searchText, *mail;
  NSDictionary *contact, *data;
  NSArray *folders, *contacts, *descriptors, *sortedContacts;
  NSMutableArray *sortedFolders;
  NSMutableDictionary *uniqueContacts;
  unsigned int i, j;
  NSSortDescriptor *commonNameDescriptor;
  BOOL excludeGroups;

  searchText = [self queryParameterForKey: @"search"];
  if ([searchText length] > 0)
    {
      NSLog(@"Search all contacts: %@", searchText);
      excludeGroups = [[self queryParameterForKey: @"excludeGroups"] boolValue];
      NS_DURING
        folders = [[self clientObject] subFolders];
      NS_HANDLER
        /* We need to specifically test for @"SOGoDBException", which is
           raised explicitly in SOGoParentFolder. Any other exception should
           be re-raised. */
        if ([[localException name] isEqualToString: @"SOGoDBException"])
          folders = nil;
        else
          [localException raise];
      NS_ENDHANDLER
        sortedFolders = [NSMutableArray arrayWithCapacity: [folders count]];
      uniqueContacts = [NSMutableDictionary dictionary];
      /* We first search in LDAP folders (in case of duplicated entries in GCS folders) */
      for (i = 0; i < [folders count]; i++)
        {
          folder = [folders objectAtIndex: i];
          if ([folder isKindOfClass: [SOGoContactLDAPFolder class]])
	    [sortedFolders insertObject: folder atIndex: 0];
          else
            [sortedFolders addObject: folder];
        }
      for (i = 0; i < [sortedFolders count]; i++)
        {
          folder = [sortedFolders objectAtIndex: i];
          //NSLog(@"  Address book: %@ (%@)", [folder displayName], [folder class]);
          contacts = [folder lookupContactsWithFilter: searchText
                                               sortBy: @"c_cn"
                                             ordering: NSOrderedAscending];
          for (j = 0; j < [contacts count]; j++)
            {
              contact = [contacts objectAtIndex: j];
              mail = [contact objectForKey: @"c_mail"];
              //NSLog(@"   found %@ (%@)", [contact objectForKey: @"displayName"], mail);
              if ([mail isNotNull]
		  && [uniqueContacts objectForKey: mail] == nil
		  && !(excludeGroups && [contact objectForKey: @"isGroup"]))
		[uniqueContacts setObject: contact forKey: mail];
            }
        }      
      if ([uniqueContacts count] > 0)
        {
          // Sort the contacts by display name
          commonNameDescriptor = [[[NSSortDescriptor alloc] initWithKey: @"c_cn"
                                                              ascending:YES] autorelease];
          descriptors = [NSArray arrayWithObjects: commonNameDescriptor, nil];
          sortedContacts = [[uniqueContacts allValues] sortedArrayUsingDescriptors: descriptors];
        }
      else
        sortedContacts = [NSArray array];
      data = [NSDictionary dictionaryWithObjectsAndKeys: searchText, @"searchText",
           sortedContacts, @"contacts",
           nil];
      result = [self responseWithStatus: 200];
      [(WOResponse*)result appendContentString: [data jsonRepresentation]];
    }
  else
    result = [NSException exceptionWithHTTPStatus: 400
                                           reason: @"missing 'search' parameter"];  

  return result;
}

- (id <WOActionResults>) contactSearchAction
{
  NSDictionary *data;
  NSArray *contacts;
  NSString *searchText;
  id <WOActionResults> result;
  LDAPUserManager *um;

  searchText = [self queryParameterForKey: @"search"];
  if ([searchText length] > 0)
    {
      um = [LDAPUserManager sharedUserManager];
      contacts 
        = [self _responseForResults: [um fetchContactsMatching: searchText]];
      data = [NSDictionary dictionaryWithObjectsAndKeys: searchText, @"searchText",
           contacts, @"contacts",
           nil];
      result = [self responseWithStatus: 200];
      [(WOResponse*)result appendContentString: [data jsonRepresentation]];
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
  SOGoGCSFolder *subfolder;
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
  while ((subfolder = [subfolders nextObject]))
    {
      if (![securityManager validatePermission: SOGoPerm_AccessObject
                                      onObject: subfolder inContext: context])
        {
          folderName = [NSString stringWithFormat: @"/%@/%@",
                     [parentFolder nameInContainer],
                     [subfolder nameInContainer]];
          currentDictionary
            = [NSMutableDictionary dictionaryWithCapacity: 3];
          [currentDictionary setObject: [subfolder displayName]
                                forKey: @"displayName"];
          [currentDictionary setObject: folderName forKey: @"name"];
          [currentDictionary setObject: [subfolder folderType]
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

- (void) checkDefaultModulePreference
{
  NSUserDefaults *clientUD;
  NSString *pref;

  if (![self isPopup])
    {
      clientUD = [[context activeUser] userDefaults];
      pref = [clientUD stringForKey: @"SOGoUIxDefaultModule"];

      if (pref && [pref isEqualToString: @"Last"])
        {
          [clientUD setObject: @"Contacts" forKey: @"SOGoUIxLastModule"];
          [clientUD synchronize];
        }
    }
}

- (BOOL) isPopup
{
  return [[self queryParameterForKey: @"popup"] boolValue];
}

- (NSArray *) contactFolders
{
  SOGoContactFolders *folderContainer;

  [self checkDefaultModulePreference];
  folderContainer = [self clientObject];

  return [folderContainer subFolders];
}

- (NSString *) currentContactFolderId
{
  return [NSString stringWithFormat: @"/%@",
         [currentFolder nameInContainer]];
}

- (NSString *) currentContactFolderName
{
  return [currentFolder displayName];
}

- (NSString *) currentContactFolderOwner
{
  return [currentFolder ownerInContext: context];
}

- (NSString *) currentContactFolderClass
{
  return ([currentFolder isKindOfClass: [SOGoContactLDAPFolder class]]? @"remote" : @"local");
}

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
