/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2005-2015 Inverse inc.

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
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSURL.h>
#import <Foundation/NSCalendarDate.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoPermissions.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSNull+misc.h>


#import <SOGo/CardElement+SOGo.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import <Contacts/NGVCard+SOGo.h>
#import <Contacts/SOGoContactFolders.h>
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

- (void) setAttributes: (NSDictionary *) attributes
{
  CardElement *element;
  NSArray *elements, *values;
  NSMutableArray *units, *categories;
  NSCalendarDate *date;
  id o;
  unsigned int i, year, month, day;

  [card setNWithFamily: [attributes objectForKey: @"c_sn"]
                 given: [attributes objectForKey: @"c_givenname"]
            additional: nil prefixes: nil suffixes: nil];
  [card setNickname: [attributes objectForKey: @"nickname"]];
  [card setFn: [attributes objectForKey: @"c_cn"]];
  [card setTitle: [attributes objectForKey: @"title"]];
  [card setRole: [attributes objectForKey: @"role"]];

  if ([attributes objectForKey: @"c_screenname"])
    [[card uniqueChildWithTag: @"x-aim"]
      setSingleValue: [attributes objectForKey: @"c_screenname"]
              forKey: @""];

  o = [attributes objectForKey: @"birthday"];
  if ([o isKindOfClass: [NSString class]] && [o length])
    {
      date = [card dateFromString: o inContext: context];
      year = [date yearOfCommonEra];
      month = [date monthOfYear];
      day = [date dayOfMonth];
      [card setBday: [NSString stringWithFormat: @"%.4d%.2d%.2d", year, month, day]];
    }
  else
    [card setBday: nil];

  if ([[attributes objectForKey: @"addresses"] isKindOfClass: [NSArray class]])
    {
      elements = [card childrenWithTag: @"adr"];
      [card removeChildren: elements];
      values = [attributes objectForKey: @"addresses"];
      for (i = 0; i < [values count]; i++)
        {
          o = [values objectAtIndex: i];
          if ([o isKindOfClass: [NSDictionary class]])
            {
              element = [card elementWithTag: @"adr" ofType: [o objectForKey: @"type"]];
              [element setSingleValue: [o objectForKey: @"postoffice"]
                              atIndex: 0 forKey: @""];
              [element setSingleValue: [o objectForKey: @"street2"]
                              atIndex: 1 forKey: @""];
              [element setSingleValue: [o objectForKey: @"street"]
                              atIndex: 2 forKey: @""];
              [element setSingleValue: [o objectForKey: @"locality"]
                              atIndex: 3 forKey: @""];
              [element setSingleValue: [o objectForKey: @"region"]
                              atIndex: 4 forKey: @""];
              [element setSingleValue: [o objectForKey: @"postalcode"]
                              atIndex: 5 forKey: @""];
              [element setSingleValue: [o objectForKey: @"country"]
                              atIndex: 6 forKey: @""];
            }
        }
    }

  if ([[attributes objectForKey: @"orgUnits"] isKindOfClass: [NSArray class]])
    {
      elements = [card childrenWithTag: @"org"];
      [card removeChildren: elements];
      values = [attributes objectForKey: @"orgUnits"];
      units = [NSMutableArray arrayWithCapacity: [values count]];
      for (i = 0; i < [values count]; i++)
        {
          o = [values objectAtIndex: i];
          if ([o isKindOfClass: [NSDictionary class]])
            {
              [units addObject: [o objectForKey: @"value"]];
            }
        }
    }
  else
    {
      units = nil;
    }
  [card setOrg: [attributes objectForKey: @"c_org"]
         units: units];

  elements = [card childrenWithTag: @"tel"];
  [card removeChildren: elements];
  values = [attributes objectForKey: @"phones"];
  if ([values isKindOfClass: [NSArray class]])
    {
      NSEnumerator *list = [values objectEnumerator];
      id attrs;
      while ((attrs = [list nextObject]))
        {
          if ([attrs isKindOfClass: [NSDictionary class]])
            {
              [card addElementWithTag: @"tel"
                               ofType: [attrs objectForKey: @"type"]
                            withValue: [attrs objectForKey: @"value"]];
            }
        }
  }

  if ([[attributes objectForKey: @"emails"] isKindOfClass: [NSArray class]])
    {
      elements = [card childrenWithTag: @"email"];
      [card removeChildren: elements];
      values = [attributes objectForKey: @"emails"];
      if (values)
        {
          NSEnumerator *list = [values objectEnumerator];
          while ((o = [list nextObject]))
            {
              if ([o isKindOfClass: [NSDictionary class]])
                {
                  [card addElementWithTag: @"email"
                                   ofType: [o objectForKey: @"type"]
                                withValue: [o objectForKey: @"value"]];
                }
            }
        }
    }

  elements = [card childrenWithTag: @"url"];
  [card removeChildren: elements];
  values = [attributes objectForKey: @"urls"];
  if ([values isKindOfClass: [NSArray class]])
    {
      NSEnumerator *list = [values objectEnumerator];
      id attrs;
      while ((attrs = [list nextObject]))
        {
          if ([attrs isKindOfClass: [NSDictionary class]])
            {
              [card addElementWithTag: @"url"
                               ofType: [attrs objectForKey: @"type"]
                            withValue: [attrs objectForKey: @"value"]];
            }
        }
  }

  [card setNotes: [attributes objectForKey: @"notes"]];

  if ([[attributes objectForKey: @"categories"] isKindOfClass: [NSArray class]])
    {
      elements = [card childrenWithTag: @"categories"];
      [card removeChildren: elements];
      values = [attributes objectForKey: @"categories"];
      categories = [NSMutableArray arrayWithCapacity: [values count]];
      for (i = 0; i < [values count]; i++)
        {
          o = [values objectAtIndex: i];
          if ([o isKindOfClass: [NSDictionary class]])
            {
              o = [o objectForKey: @"value"];
              if (o && [o isKindOfClass: [NSString class]] && [(NSString *) o length] > 0)
                {
                  [categories addObject: o];
                }
            }
        }
      [card setCategories: categories];
    }

  [card cleanupEmptyChildren];
}


/**
 * @api {post} /so/:username/Contacts/:addressbookId/:cardId/save Save card
 * @apiVersion 1.0.0
 * @apiName PostData
 * @apiGroup Contacts
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Contacts/personal/1BC8-52F53F80-1-38C52040.vcf/save
 *
 * @apiParam {String} id                   Card ID
 * @apiParam {String} pid                  Address book ID (card's container)
 * @apiParam {String} c_component          Either vcard or vlist
 * @apiParam {String} c_givenname          Firstname
 * @apiParam {String} nickname             Nickname
 * @apiParam {String} c_sn                 Lastname
 * @apiParam {String} c_cn                 Fullname
 * @apiParam {String} c_screenname         Screen Name (X-AIM for now)
 * @apiParam {String} tz                   Timezone
 * @apiParam {String} note                 Note
 * @apiParam {String[]} allCategories      All available categories
 * @apiParam {Object[]} categories         Categories assigned to the card
 * @apiParam {String} categories.value     Category name
 * @apiParam {Object[]} addresses          Postal addresses
 * @apiParam {String} addresses.type       Type (e.g., home or work)
 * @apiParam {String} addresses.postoffice Post office box
 * @apiParam {String} addresses.street     Street address
 * @apiParam {String} addresses.street2    Extended address (e.g., apartment or suite number)
 * @apiParam {String} addresses.locality   Locality (e.g., city)
 * @apiParam {String} addresses.region     Region (e.g., state or province)
 * @apiParam {String} addresses.postalcode Postal code
 * @apiParam {String} addresses.country    Country name
 * @apiParam {Object[]} emails             Email addresses
 * @apiParam {String} emails.type          Type (e.g., home or work)
 * @apiParam {String} emails.value         Email address
 * @apiParam {Object[]} phones             Phone numbers
 * @apiParam {String} phones.type          Type (e.g., mobile or work)
 * @apiParam {String} phones.value         Phone number
 * @apiParam {Object[]} urls               URLs
 * @apiParam {String} urls.type            Type (e.g., personal or work)
 * @apiParam {String} urls.value           URL
 */
- (id <WOActionResults>) saveAction
{
  SOGoContentObject <SOGoContactObject> *co;
  WORequest *request;
  NSDictionary *params, *data;

  co = [self clientObject];
  card = [co vCard];
  request = [context request];
  params = [[request contentAsString] objectFromJSONString];

  [self setAttributes: params];
  [co save];

  // Return card UID and addressbook ID in a JSON payload
  data = [NSDictionary dictionaryWithObjectsAndKeys:
                         [[co container] nameInContainer], @"pid",
                         [co nameInContainer], @"id",
                         nil];

  return [self responseWithStatus: 200 andJSONRepresentation: data];
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

