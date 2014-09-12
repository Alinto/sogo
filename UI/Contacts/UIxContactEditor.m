/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2005-2010 Inverse inc.

  This file is part of SOGo

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSEnumerator.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoPermissions.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/SoObject.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSNull+misc.h>

#import <NGCards/NGVCard.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoContentObject.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import <Contacts/SOGoContactFolder.h>
#import <Contacts/SOGoContactFolders.h>
#import <Contacts/SOGoContactObject.h>
#import <Contacts/SOGoContactGCSEntry.h>
#import <Contacts/SOGoContactGCSFolder.h>

#import "UIxContactEditor.h"

static Class SOGoContactGCSEntryK = Nil;

@implementation UIxContactEditor

+ (void) initialize
{
  SOGoContactGCSEntryK = [SOGoContactGCSEntry class];
}

- (id) init
{
  if ((self = [super init]))
    {
      ldifRecord = nil;
      addressBookItem = nil;
      item = nil;
      componentAddressBook = nil;
    }

  return self;
}

- (void) dealloc
{
  [ldifRecord release];
  [addressBookItem release];
  [item release];
  [componentAddressBook release];
  [super dealloc];
}

/* accessors */

- (NSMutableDictionary *) ldifRecord
{
  NSDictionary *clientLDIFRecord;
  NSString *queryValue;

  if (!ldifRecord)
    {
      clientLDIFRecord = [[self clientObject] simplifiedLDIFRecord];
      ldifRecord = [clientLDIFRecord mutableCopy];
      queryValue = [self queryParameterForKey: @"contactEmail"];
      if ([queryValue length] > 0)
        [ldifRecord setObject: queryValue forKey: @"mail"];
      queryValue = [self queryParameterForKey: @"contactFN"];
      if ([queryValue length] > 0)
        [ldifRecord setObject: queryValue forKey: @"displayname"];
   }

  return ldifRecord;
}

- (void) setAddressBookItem: (id) _item
{
  ASSIGN (addressBookItem, _item);
}

- (id) addressBookItem
{
  return addressBookItem;
}

- (NSString *) saveURL
{
  return [NSString stringWithFormat: @"%@/saveAsContact",
		   [[self clientObject] baseURL]];
}

- (NSArray *) htmlMailFormatList
{
  static NSArray *htmlMailFormatItems = nil;

  if (!htmlMailFormatItems)
    {
      htmlMailFormatItems = [NSArray arrayWithObjects: @"FALSE", @"TRUE", nil];
      [htmlMailFormatItems retain];
    }

  return htmlMailFormatItems;
}

- (NSString *) itemHtmlMailFormatText
{
  return [self labelForKey:
		 [NSString stringWithFormat: @"htmlMailFormat_%@", item]];
}

- (void) setItem: (NSString *) newItem
{
  item = newItem;
}

- (NSString *) item
{
  return item;
}

/* load/store content format */

/* helper */

- (NSString *) _completeURIForMethod: (NSString *) _method
{
  // TODO: this is a DUP of UIxAppointmentEditor
  NSString *uri;
  NSRange r;

  uri = [[[self context] request] uri];

  /* first: identify query parameters */
  r = [uri rangeOfString: @"?" options:NSBackwardsSearch];
  if (r.length > 0)
    uri = [uri substringToIndex:r.location];

  /* next: append trailing slash */
  if (![uri hasSuffix: @"/"])
    uri = [uri stringByAppendingString: @"/"];

  /* next: append method */
  uri = [uri stringByAppendingString:_method];

  /* next: append query parameters */
  return [self completeHrefForMethod:uri];
}

- (BOOL) isNew
{
  return ([[self clientObject] isNew]);
}

- (NSArray *) addressBooksList
{
  NSEnumerator *folders;
  NSMutableArray *addressBooksList;
  SoSecurityManager *sm;
  SOGoContactFolders *folderContainer;
  id <SOGoContactFolder> folder, currentFolder;

  addressBooksList = [NSMutableArray array];
  sm = [SoSecurityManager sharedSecurityManager];
  folderContainer = [[[self clientObject] container] container];
  folders = [[folderContainer subFolders] objectEnumerator];
  folder = [self componentAddressBook];
  currentFolder = [folders nextObject];

  while (currentFolder)
    {
      if ([currentFolder isEqual: folder] ||
          ![sm validatePermission: SoPerm_AddDocumentsImagesAndFiles
                         onObject: currentFolder
                        inContext: context])
	[addressBooksList addObject: currentFolder];
      currentFolder = [folders nextObject];
    }

  return addressBooksList;
}

- (id <SOGoContactFolder>) componentAddressBook
{
  return [[self clientObject] container];
}

- (void) setComponentAddressBook: (id <SOGoContactFolder>) _componentAddressBook
{
  ASSIGN (componentAddressBook, _componentAddressBook);
}

- (NSString *) addressBookDisplayName
{
  return [addressBookItem displayName];
}

- (BOOL) supportCategories
{
  return [[self clientObject] isKindOfClass: SOGoContactGCSEntryK];
}

- (void) setJsonContactCategories: (NSString *) jsonCategories
{
  NSArray *newCategories;

  newCategories = [jsonCategories objectFromJSONString];
  if ([newCategories isKindOfClass: [NSArray class]])
    [[self ldifRecord] setObject: newCategories
                          forKey: @"vcardcategories"];
  else
    [[self ldifRecord] removeObjectForKey: @"vcardcategories"];
}

- (NSString *) jsonContactCategories
{
  NSArray *categories;

  categories = [[self ldifRecord] objectForKey: @"vcardcategories"];

  return [categories jsonRepresentation];
}

- (NSArray *) _languageContactsCategories
{
  NSArray *categoryLabels;

  categoryLabels = [[self labelForKey: @"contacts_category_labels"]
                       componentsSeparatedByString: @","];
  if (!categoryLabels)
    categoryLabels = [NSArray array];
  
  return [categoryLabels trimmedComponents];
}

- (NSArray *) _fetchAndCombineCategoriesList
{
  NSString *ownerLogin;
  SOGoUserDefaults *ud;
  NSArray *cats, *newCats, *contactCategories;

  ownerLogin = [[self clientObject] ownerInContext: context];
  ud = [[SOGoUser userWithLogin: ownerLogin] userDefaults];
  cats = [ud contactsCategories];
  if (!cats)
    cats = [self _languageContactsCategories];

  contactCategories = [[self ldifRecord] objectForKey: @"vcardcategories"];
  if (contactCategories)
    {
      newCats = [cats mergedArrayWithArray: contactCategories];
      if ([newCats count] != [cats count])
        {
          cats = [newCats sortedArrayUsingSelector:
                            @selector (localizedCaseInsensitiveCompare:)];
          [ud setContactsCategories: cats];
          [ud synchronize];
        }
    }

  return cats;
}

- (NSString *) contactCategoriesList
{
  NSArray *cats;
  NSString *list;

  cats = [self _fetchAndCombineCategoriesList];
  list = [cats jsonRepresentation];
  if (!list)
    list = @"[]";

  return list;
}

/* actions */

// - (BOOL) shouldTakeValuesFromRequest: (WORequest *) request
//                            inContext: (WOContext*) context
// {
//   NSString *actionName;
// 
//   actionName = [[request requestHandlerPath] lastPathComponent];
// 
//   return ([actionName hasPrefix: @"save"]);
// }

- (NSString *) viewActionName
{
  /* this is overridden in the mail based contacts UI to redirect to tb.edit */
  return @"";
}

- (NSString *) editActionName
{
  /* this is overridden in the mail based contacts UI to redirect to tb.edit */
  return @"editAsContact";
}

- (BOOL) supportPhotos
{
  return [[self clientObject] isKindOfClass: SOGoContactGCSEntryK];
}

- (BOOL) hasPhoto
{
  return [[self clientObject] hasPhoto];
}

- (NSString *) photoURL
{
  NSURL *soURL;

  soURL = [[self clientObject] soURL];

  return [NSString stringWithFormat: @"%@/photo", [soURL absoluteString]];
}

- (id <WOActionResults>) saveAction
{
  SOGoContentObject <SOGoContactObject> *contact;
  WORequest *request;
  WOResponse *response;
  NSDictionary *params, *data;

  contact = [self clientObject];
  request = [context request];
  params = [[request contentAsString] objectFromJSONString];
  [contact setAttributes: params];

  [contact save];

  // Return card UID and addressbook ID in a JSON payload
  data = [NSDictionary dictionaryWithObjectsAndKeys:
                         [[contact container] nameInContainer], @"pid",
                         [contact nameInContainer], @"id",
                         nil];
  response = [self responseWithStatus: 200
                            andString: [data jsonRepresentation]];

  return response;
}

- (id) writeAction
{
  NSString *email, *cn, *url;
  NSMutableString *address;

  [self ldifRecord];
  email = [ldifRecord objectForKey: @"mail"];
  if ([email length] == 0)
    email = [ldifRecord objectForKey: @"mozillasecondemail"];

  if (email)
    {
      address = [NSMutableString string];
      cn = [ldifRecord objectForKey: @"cn"];
      if ([cn length] > 0)
	[address appendFormat: @"%@ <%@>", cn, email];
      else
	[address appendString: email];
      
      url = [NSString stringWithFormat: @"%@/Mail/compose?mailto=%@",
		      [self userFolderPath], address];
    }
  else
    url = [NSString stringWithFormat: @"%@/Mail/compose", [self userFolderPath]];
  
  return [self redirectToLocation: url];
}

@end /* UIxContactEditor */

