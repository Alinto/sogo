/* UIxContactFoldersView.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2010 Inverse inc.
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

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoObject.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <NGExtensions/NSNull+misc.h>

#import <GDLContentStore/GCSFolder.h>
#import <GDLContentStore/GCSFolderManager.h>

#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <Contacts/SOGoContactFolders.h>
#import <Contacts/SOGoContactFolder.h>
#import <Contacts/SOGoContactGCSFolder.h>
#import <Contacts/SOGoContactSourceFolder.h>

#import "UIxContactFoldersView.h"

Class SOGoContactSourceFolderK, SOGoGCSFolderK;

@implementation UIxContactFoldersView

+ (void) initialize
{
  SOGoContactSourceFolderK = [SOGoContactSourceFolder class];
  SOGoGCSFolderK = [SOGoGCSFolder class];
}

- (id) init
{
  if ((self = [super init]))
    contextIsSetup = NO;
  
  return self;
}

- (void) _setupContext
{
  SOGoUser *activeUser;
  NSString *module;
  SOGoContactFolders *clientObject;

  if (!contextIsSetup)
    {
      activeUser = [context activeUser];
      clientObject = [self clientObject];
      
      module = [clientObject nameInContainer];
      
      us = [activeUser userSettings];
      moduleSettings = [us objectForKey: module];
      if (!moduleSettings)
        {
          moduleSettings = [NSMutableDictionary new];
          [us setObject: moduleSettings forKey: module];
          [moduleSettings release];
        }
      contextIsSetup = YES;
    }
}

- (void) setCurrentContact: (NSDictionary *) _contact
{
  currentContact = _contact;
}

- (NSDictionary *) currentContact
{
  return currentContact;
}

- (NSString *) currentContactClasses
{
  return [[currentContact objectForKey: @"c_component"] lowercaseString];
}

- (NSArray *) personalContactInfos
{
  SOGoContactFolders *folders;
  id <SOGoContactFolder> folder;
  NSArray *contactInfos;

  folders = [self clientObject];
  folder = [folders lookupPersonalFolder: @"personal" ignoringRights: YES];
  if (folder && [folder conformsToProtocol: @protocol (SOGoContactFolder)])
    contactInfos = [folder lookupContactsWithFilter: nil
                                         onCriteria: nil
                                             sortBy: @"c_cn"
                                           ordering: NSOrderedAscending
                                           inDomain: nil];
  else
    contactInfos = nil;
  
  return contactInfos;
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

- (id <WOActionResults>) allContactSearchAction
{
  id <WOActionResults> result;
  SOGoFolder <SOGoContactFolder> *folder;
  NSString *searchText, *mail, *domain;
  NSDictionary *data;
  NSArray *folders, *contacts, *descriptors, *sortedContacts;
  NSMutableArray *sortedFolders;
  NSMutableDictionary *contact, *uniqueContacts;
  unsigned int i, j, max;
  NSSortDescriptor *commonNameDescriptor;
  BOOL excludeGroups, excludeLists;

  searchText = [self queryParameterForKey: @"search"];
  if ([searchText length] > 0)
    {
      // NSLog(@"Search all contacts: %@", searchText);
      excludeGroups = [[self queryParameterForKey: @"excludeGroups"] boolValue];
      excludeLists = [[self queryParameterForKey: @"excludeLists"] boolValue];
      domain = [[context activeUser] domain];
      folders = nil;
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
      NS_ENDHANDLER;
      max = [folders count];
      sortedFolders = [NSMutableArray arrayWithCapacity: max];
      uniqueContacts = [NSMutableDictionary dictionary];
      for (i = 0; i < max; i++)
        {
          folder = [folders objectAtIndex: i];
	  /* We first search in LDAP folders (in case of duplicated entries in GCS folders) */
          if ([folder isKindOfClass: SOGoContactSourceFolderK])
            [sortedFolders insertObject: folder atIndex: 0];
          else
            [sortedFolders addObject: folder];
        }
      for (i = 0; i < max; i++)
        {
          folder = [sortedFolders objectAtIndex: i];
          //NSLog(@"  Address book: %@ (%@)", [folder displayName], [folder class]);
          contacts = [folder lookupContactsWithFilter: searchText
                                           onCriteria: @"name_or_address"
                                               sortBy: @"c_cn"
                                             ordering: NSOrderedAscending
                                             inDomain: domain];
          for (j = 0; j < [contacts count]; j++)
            {
              contact = [contacts objectAtIndex: j];
              mail = [contact objectForKey: @"c_mail"];
              //NSLog(@"   found %@ (%@) ? %@", [contact objectForKey: @"c_name"], mail,
              //      [contact description]);
              if (!excludeLists && [[contact objectForKey: @"c_component"]
                                          isEqualToString: @"vlist"])
                {
                  [contact setObject: [folder nameInContainer] 
                              forKey: @"container"];
                  [uniqueContacts setObject: contact 
                                     forKey: [contact objectForKey: @"c_name"]]; 
                }
              else if ([mail length]
                       && [uniqueContacts objectForKey: mail] == nil
                       && !(excludeGroups && [contact objectForKey: @"isGroup"]))
                [uniqueContacts setObject: contact forKey: mail];
            }
        }
      if ([uniqueContacts count] > 0)
        {
          // Sort the contacts by display name
          commonNameDescriptor = [[NSSortDescriptor alloc] initWithKey: @"c_cn"
                                                             ascending:YES];
          descriptors = [NSArray arrayWithObjects: commonNameDescriptor, nil];
          [commonNameDescriptor release];
          sortedContacts = [[uniqueContacts allValues]
                             sortedArrayUsingDescriptors: descriptors];
        }
      else
        sortedContacts = [NSArray array];
      data = [NSDictionary dictionaryWithObjectsAndKeys: searchText, @"searchText",
                           sortedContacts, @"contacts",
                           nil];
      result = [self responseWithStatus: 200];
      [(WOResponse*) result appendContentString: [data jsonRepresentation]];
    }
  else
    result = [NSException exceptionWithHTTPStatus: 400
                                           reason: @"missing 'search' parameter"];  

  return result;
}

- (void) checkDefaultModulePreference
{
  SOGoUserDefaults *ud;

  if (![self isPopup])
    {
      ud = [[context activeUser] userDefaults];
      if ([ud rememberLastModule])
        {
          [ud setLoginModule: @"Contacts"];
          [ud synchronize];
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

  folderContainer = [self clientObject];

  return [folderContainer subFolders];
}

- (NSString *) currentContactFolderId
{
  return [NSString stringWithFormat: @"/%@", [currentFolder nameInContainer]];
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
  return (([currentFolder isKindOfClass: SOGoContactSourceFolderK]
           && ![currentFolder isPersonalSource])
          ? @"remote" : @"local");
}

- (NSString *) currentContactFolderAclEditing
{
  return ([currentFolder isKindOfClass: SOGoGCSFolderK]
          ? @"available": @"unavailable");
}

- (NSString *) currentContactFolderListEditing
{
  return ([currentFolder isKindOfClass: SOGoGCSFolderK]
          ? @"available": @"unavailable");
}

- (NSString *) verticalDragHandleStyle
{
  NSString *vertical;
  
  [self _setupContext];
  vertical = [moduleSettings objectForKey: @"DragHandleVertical"];

  return ((vertical && [vertical intValue] > 0)
          ? (id)[vertical stringByAppendingFormat: @"px"] : nil);
}

- (NSString *) horizontalDragHandleStyle
{
  NSString *horizontal;

  [self _setupContext];
  horizontal = [moduleSettings objectForKey: @"DragHandleHorizontal"];

  return ((horizontal && [horizontal intValue] > 0)
          ? (id)[horizontal stringByAppendingFormat: @"px"] : nil);
}

- (NSString *) contactsListContentStyle
{
  NSString *height;

  [self _setupContext];
  height = [moduleSettings objectForKey: @"DragHandleVertical"];

  return ((height && [height intValue] > 0)
          ? [NSString stringWithFormat: @"%ipx", ([height intValue] - 27)] : nil);
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

  [us synchronize];

  return [self responseWithStatus: 204];
}

- (id) defaultAction
{
  // NSString *check;
  // WOResponse *response;
  // static NSString *etag = @"\"contacts-ui\"";

  [self checkDefaultModulePreference];

  // check = [[context request] headerForKey: @"if-none-match"];
  // if ([check length] > 0 && [check rangeOfString: etag].location != NSNotFound) /* not perfectly correct */
  //   response = [self responseWithStatus: 304];
  // else
  //   {
  //     response = [context response];
  //     [response setHeader: etag forKey: @"etag"];
  //     response = (WOResponse *) [super defaultAction];
  //   }
  
  // return response;
  return [super defaultAction];
}

@end
