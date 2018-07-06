/* UIxContactFoldersView.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2016 Inverse inc.
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

#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <NGExtensions/NSNull+misc.h>


#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <Contacts/SOGoContactFolders.h>
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

- (NSString *) modulePath
{
  return @"Contacts";
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
                                           onCriteria: nil
                                               sortBy: @"c_cn"
                                             ordering: NSOrderedAscending
                                             inDomain: domain];
          for (j = 0; j < [contacts count]; j++)
            {
              contact = [contacts objectAtIndex: j];
              if ([[contact objectForKey: @"emails"] count] == 0)
                // Contact must have an email address
                continue;
              mail = [[[contact objectForKey: @"emails"] objectAtIndex: 0] objectForKey: @"value"];
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

- (BOOL) isPublicAccessEnabled
{
  // NOTE: This method is the same found in Common/UIxAclEditor.m
  return [[SOGoSystemDefaults sharedSystemDefaults] enablePublicAccess];
}

- (NSArray *) contactFolders
{
  SOGoContactFolders *folderContainer;
  NSMutableDictionary *urls, *acls;
  NSMutableArray *foldersAttrs;
  NSString *userLogin, *owner;
  NSArray *folders, *allACLs;
  NSDictionary *folderAttrs;
  id currentFolder;

  BOOL objectCreator, objectEditor, objectEraser, synchronize;
  int max, i;

  userLogin = [[context activeUser] login];
  folderContainer = [self clientObject];
  folders = [folderContainer subFolders];

  max = [folders count];
  foldersAttrs = [NSMutableArray arrayWithCapacity: max];
  urls = nil;

  for (i = 0; i < max; i++)
    {
      currentFolder = [folders objectAtIndex: i];
      owner = [currentFolder ownerInContext: context];

      // We extract URLs for this address book
      if ([currentFolder respondsToSelector: @selector(cardDavURL)])
        {
          urls = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                        [currentFolder cardDavURL], @"cardDavURL",
                                      nil];
          if ([self isPublicAccessEnabled])
            {
              [urls setObject: [currentFolder publicCardDavURL] forKey: @"publicCardDavURL"];
            }
        }

      // We extract ACLs for this address book
      allACLs = ([owner isEqualToString: userLogin] ? nil : [currentFolder aclsForUser: userLogin]);
      objectCreator = ([owner isEqualToString: userLogin] || [allACLs containsObject: SOGoRole_ObjectCreator]);
      objectEditor = ([owner isEqualToString: userLogin] || [allACLs containsObject: SOGoRole_ObjectEditor]);
      objectEraser = ([owner isEqualToString: userLogin] || [allACLs containsObject: SOGoRole_ObjectEraser]);
      acls = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool: objectCreator], @"objectCreator",
                               [NSNumber numberWithBool: objectEditor], @"objectEditor",
                               [NSNumber numberWithBool: objectEraser], @"objectEraser", nil];

      if ([currentFolder isKindOfClass: SOGoGCSFolderK])
        synchronize = [currentFolder synchronize];
      else
        synchronize = NO;

      if ([[currentFolder nameInContainer] isEqualToString: @"personal"])
        synchronize = YES;

      // NOTE: keep urls as the last key/value here, to avoid chopping the dictionary
      //       if it is not a GCS folder
      folderAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSString stringWithFormat: @"%@", [currentFolder nameInContainer]], @"id",
                                  [currentFolder displayName], @"name",
                                  [NSNumber numberWithBool: synchronize], @"synchronize",
                                  owner, @"owner",
                                  [NSNumber numberWithBool: [currentFolder isKindOfClass: SOGoGCSFolderK]], @"isEditable",
                                  [NSNumber numberWithBool: [currentFolder isKindOfClass: SOGoContactSourceFolderK]
                                            && ![currentFolder isPersonalSource]], @"isRemote",
                                  [NSNumber numberWithBool: [currentFolder isKindOfClass: SOGoContactSourceFolderK]
                                            && [currentFolder listRequiresDot]], @"listRequiresDot",
                                  acls, @"acls",
                                  urls, @"urls",
                                  [currentFolder searchFields], @"searchFields",
                                  nil];
      [foldersAttrs addObject: folderAttrs];
    }
  
  return foldersAttrs;
}

/**
 * @api {get} /so/:username/Contacts/addressbooksList Get address books
 * @apiVersion 1.0.0
 * @apiName GetAddressbooksList
 * @apiGroup Contacts
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Contacts/addressbooksList
 *
 * @apiSuccess (Success 200) {Object[]} addressbooks                List of address books
 * @apiSuccess (Success 200) {String} addressbooks.id               AddressBook ID
 * @apiSuccess (Success 200) {String} addressbooks.name             Human readable name
 * @apiSuccess (Success 200) {String} addressbooks.owner            User ID of owner
 * @apiSuccess (Success 200) {Number} addressbooks.synchronize      1 if address book must be synchronized in EAS
 * @apiSuccess (Success 200) {Number} addressbooks.listRequiresDot  1 if listing requires a search
 * @apiSuccess (Success 200) {Number} addressbooks.isRemote         1 if address book is a global source
 * @apiSuccess (Success 200) {Object[]} urls                        URLs to this address book
 * @apiSuccess (Success 200) {String} [urls.cardDavURL]             CardDAV URL
 * @apiSuccess (Success 200) {String} [urls.publicCardDavURL]       Public CardDAV URL
 */
- (WOResponse *) addressbooksListAction
{
  NSDictionary *data;
  WOResponse *response;

  data = [NSDictionary dictionaryWithObject: [self contactFolders]
                                     forKey: @"addressbooks"];
  response = [self responseWithStatus: 200 andJSONRepresentation: data];

  return response;
}

// - (NSString *) currentContactFolderId
// {
//   return [NSString stringWithFormat: @"/%@", [currentFolder nameInContainer]];
// }

// - (NSString *) currentContactFolderName
// {
//   return [currentFolder displayName];
// }

// - (NSString *) currentContactFolderOwner
// {
//   return [currentFolder ownerInContext: context];
//}

// - (NSString *) currentContactFolderClass
// {
//   return (([currentFolder isKindOfClass: SOGoContactSourceFolderK]
//            && ![currentFolder isPersonalSource])
//           ? @"remote" : @"local");
// }

// - (NSString *) currentContactFolderAclEditing
// {
//   return ([currentFolder isKindOfClass: SOGoGCSFolderK]
//           ? @"available": @"unavailable");
// }

// - (NSString *) currentContactFolderListEditing
// {
//   return ([currentFolder isKindOfClass: SOGoGCSFolderK]
//           ? @"available": @"unavailable");
//}

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

@interface UIxContactViewTemplate : UIxComponent
@end

@implementation UIxContactViewTemplate
@end

@interface UIxContactEditorTemplate : UIxComponent
@end

@implementation UIxContactEditorTemplate
@end
