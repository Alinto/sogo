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
#import <NGCards/NGVCardPhoto.h>
#import <NGCards/NSArray+NGCards.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import <Contacts/SOGoContactFolder.h>
#import <Contacts/SOGoContactFolders.h>
#import <Contacts/SOGoContactObject.h>
#import <Contacts/SOGoContactGCSEntry.h>
#import <Contacts/SOGoContactGCSFolder.h>

#import "UIxContactEditor.h"

@implementation UIxContactEditor

- (id) init
{
  if ((self = [super init]))
    {
      snapshot = [[NSMutableDictionary alloc] initWithCapacity: 16];
      preferredEmail = nil;
      photosURL = nil;
      addressBookItem = nil;
      item = nil;
      card = nil;
      componentAddressBook = nil;
      contactCategories = nil;
    }

  return self;
}

- (void) dealloc
{
  [snapshot release];
  [preferredEmail release];
  [photosURL release];
  [addressBookItem release];
  [item release];
  [componentAddressBook release];
  [contactCategories release];
  [super dealloc];
}

/* accessors */

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

// - (void) _fixupSnapshot
// {
//   NSString *currentKey, *currentString;
//   NSMutableString *newString;
//   NSArray *keys;
//   unsigned int count, max;

//   keys = [snapshot allKeys];
//   max = [keys count];
//   for (count = 0; count < max; count++)
//     {
//       currentKey = [keys objectAtIndex: count];
//       currentString = [snapshot objectForKey: currentKey];
//       newString = [currentString mutableCopy];
//       [newString autorelease];
//       [newString replaceString: @";" withString: @"\\;"];
//       if (![newString isEqualToString: currentString])
// 	[snapshot setObject: newString forKey: currentKey];
//     }
// }

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
  id co;

  co = [self clientObject];

  return ([co isKindOfClass: [SOGoContentObject class]]
	  && [co isNew]);
}

- (NSArray *) addressBooksList
{
  NSEnumerator *folders;
  NSMutableArray *addressBooksList;
  SoSecurityManager *sm;
  SOGoContactFolders *folderContainer;
  SOGoContactFolder *folder, *currentFolder;

  addressBooksList = [NSMutableArray array];
  sm = [SoSecurityManager sharedSecurityManager];
  folderContainer = [[[self clientObject] container] container];
  folders = [[folderContainer subFolders] objectEnumerator];
  folder = [self componentAddressBook];
  currentFolder = [folders nextObject];

  while (currentFolder)
    {
      if ([currentFolder isEqual: folder] ||
	  ([currentFolder isKindOfClass: [SOGoContactGCSFolder class]] &&
	   ![sm validatePermission: SoPerm_AddDocumentsImagesAndFiles
			  onObject: currentFolder
			 inContext: context]))
	[addressBooksList addObject: currentFolder];
      currentFolder = [folders nextObject];
    }
  
  return addressBooksList;
}

- (SOGoContactFolder *) componentAddressBook
{
  SOGoContactFolder *folder;
  
  folder = [[self clientObject] container];
  
  return folder;
}

- (void) setComponentAddressBook: (SOGoContactFolder *) _componentAddressBook
{
  ASSIGN (componentAddressBook, _componentAddressBook);
}

- (NSString *) addressBookDisplayName
{
  NSString *fDisplayName;
  SOGoContactFolder *folder;
  SOGoContactFolders *parentFolder;

  fDisplayName = [addressBookItem displayName];
  folder = [[self clientObject] container];
  parentFolder = [folder container];
  if ([fDisplayName isEqualToString: [parentFolder defaultFolderName]])
    fDisplayName = [self labelForKey: fDisplayName];

  return fDisplayName;
}

- (void) setContactCategories: (NSString *) jsonCategories
{
  NSArray *newCategories;

  newCategories = [jsonCategories objectFromJSONString];
  if ([newCategories isKindOfClass: [NSArray class]])
    ASSIGN (contactCategories, newCategories);
}

- (NSString *) contactCategories
{
  NSString *jsonCats;

  if (!contactCategories)
    ASSIGN (contactCategories, [card categories]);
  jsonCats = [contactCategories jsonRepresentation];
  if (!jsonCats)
    jsonCats = @"[]";

  return jsonCats;
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

- (NSArray *) _fetchAndCombineCategoriesList: (NSArray *) contactCats
{
  NSString *ownerLogin;
  SOGoUserDefaults *ud;
  NSArray *cats, *newCats;

  ownerLogin = [[self clientObject] ownerInContext: context];
  ud = [[SOGoUser userWithLogin: ownerLogin] userDefaults];
  cats = [ud contactsCategories];
  if (!cats)
    cats = [self _languageContactsCategories];

  if (contactCats)
    {
      newCats = [cats mergedArrayWithArray: contactCats];
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

  cats = [self _fetchAndCombineCategoriesList: [card categories]];
  list = [cats jsonRepresentation];
  if (!list)
    list = @"[]";

  return list;
}

/* actions */

- (BOOL) shouldTakeValuesFromRequest: (WORequest *) request
                           inContext: (WOContext*) context
{
  NSString *actionName;

  actionName = [[request requestHandlerPath] lastPathComponent];

  return ([[self clientObject] isKindOfClass: [SOGoContactGCSEntry class]]
	  && [actionName hasPrefix: @"save"]);
}

- (void) _setSnapshotValue: (NSString *) key
                        to: (NSString *) aValue
{
  if (!aValue)
    aValue = @"";

  [snapshot setObject: aValue forKey: key];
}

- (NSMutableDictionary *) snapshot
{
  return snapshot;
}

- (NSString *) _simpleValueForType: (NSString *) aType
                           inArray: (NSArray *) anArray
			   excluding: (NSString *) aTypeToExclude		  
{
  NSArray *elements;
  NSString *value;

  elements = [anArray cardElementsWithAttribute: @"type"
                      havingValue: aType];

  value = nil;

  if ([elements count] > 0)
    {
      CardElement *ce;
      int i;

      for (i = 0; i < [elements count]; i++)
	{
	  ce = [elements objectAtIndex: i];
	  value = [ce flattenedValuesForKey: @""];

	  if (!aTypeToExclude)
	    break;
	  
	  if (![ce hasAttribute: @"type" havingValue: aTypeToExclude])
	    break;

	  value = nil;
	}
    }

  return value;
}

- (void) _setupEmailFields
{
  NSArray *elements;
  NSString *workMail, *homeMail, *prefMail, *potential;
  unsigned int max;

  elements = [card childrenWithTag: @"email"];
  max = [elements count];
  workMail = [self _simpleValueForType: @"work"
                   inArray: elements  excluding: nil];
  homeMail = [self _simpleValueForType: @"home"
                   inArray: elements  excluding: nil];
  prefMail = [self _simpleValueForType: @"pref"
                   inArray: elements  excluding: nil];

  if (max > 0)
    {
      potential = [[elements objectAtIndex: 0] flattenedValuesForKey: @""];
      if (!workMail)
        {
          if (homeMail && homeMail == potential)
	    {
	      if (max > 1)
		workMail = [[elements objectAtIndex: 1] flattenedValuesForKey: @""];
	    }
          else
            workMail = potential;
        }
      if (!homeMail && max > 1)
        {
          if (workMail && workMail == potential)
            homeMail = [[elements objectAtIndex: 1] flattenedValuesForKey: @""];
          else
            homeMail = potential;
        }

      if (prefMail)
        {
          if (prefMail == workMail)
            preferredEmail = @"work";
          else if (prefMail == homeMail)
            preferredEmail = @"home";
        }
    }

  [self _setSnapshotValue: @"workMail" to: workMail];
  [self _setSnapshotValue: @"homeMail" to: homeMail];

  [self _setSnapshotValue: @"mozillaUseHtmlMail"
        to: [[card uniqueChildWithTag: @"x-mozilla-html"] flattenedValuesForKey: @""]];
}

- (void) _setupOrgFields
{
  NSMutableArray *orgServices;
  CardElement *org;
  NSString *service;
  NSUInteger count, max;

  org = [card org];
  [self _setSnapshotValue: @"workCompany"
                       to: [org flattenedValueAtIndex: 0 forKey: @""]];
  max = [[org valuesForKey: @""] count];
  if (max > 1)
    {
      orgServices = [NSMutableArray arrayWithCapacity: max];
      for (count = 1; count < max; count++)
        {
          service = [org flattenedValueAtIndex: count forKey: @""];
          if ([service length] > 0)
            [orgServices addObject: service];
        }

      [self _setSnapshotValue: @"workService"
                           to: [orgServices componentsJoinedByString: @", "]];
    }
}

- (NSString *) preferredEmail
{
  return preferredEmail;
}

- (void) setPreferredEmail: (NSString *) aString
{
  preferredEmail = aString;
}

- (void) _retrieveQueryParameter: (NSString *) queryKey
               intoSnapshotValue: (NSString *) snapshotKey
{
  NSString *queryValue;

  queryValue = [self queryParameterForKey: queryKey];
  if (queryValue && [queryValue length] > 0)
    [self _setSnapshotValue: snapshotKey to: queryValue];
}

- (void) initSnapshot
{
  NSArray *elements;
  CardElement *element;

  element = [card n];
  [self _setSnapshotValue: @"sn"
                       to: [element flattenedValueAtIndex: 0 forKey: @""]];
  [self _setSnapshotValue: @"givenName"
                       to: [element flattenedValueAtIndex: 1 forKey: @""]];
  [self _setSnapshotValue: @"fn" to: [card fn]];
  [self _setSnapshotValue: @"nickname" to: [card nickname]];

  elements = [card childrenWithTag: @"tel"];
  // We do this (exclude FAX) in order to avoid setting the WORK number as the FAX
  // one if we do see the FAX field BEFORE the WORK number.
  [self _setSnapshotValue: @"telephoneNumber"
        to: [self _simpleValueForType: @"work" inArray: elements  excluding: @"fax"]];
  [self _setSnapshotValue: @"homeTelephoneNumber"
        to: [self _simpleValueForType: @"home" inArray: elements  excluding: @"fax"]];
  [self _setSnapshotValue: @"mobile"
        to: [self _simpleValueForType: @"cell" inArray: elements  excluding: nil]];
  [self _setSnapshotValue: @"facsimileTelephoneNumber"
        to: [self _simpleValueForType: @"fax" inArray: elements  excluding: nil]];
  [self _setSnapshotValue: @"pager"
        to: [self _simpleValueForType: @"pager" inArray: elements  excluding: nil]];

  // If we don't have a "home" and "work" phone number but
  // we have a "voice" one defined, we set it to the "work" value
  // This can happen when we have :
  // VERSION:2.1
  // N:name;surname;;;;
  // TEL;VOICE;HOME:
  // TEL;VOICE;WORK:
  // TEL;PAGER:
  // TEL;FAX;WORK:
  // TEL;CELL:514 123 1234
  // TEL;VOICE:450 456 6789
  // ADR;HOME:;;;;;;
  // ADR;WORK:;;;;;;
  // ADR:;;;;;;
  if ([[snapshot objectForKey: @"telephoneNumber"] length] == 0 &&
      [[snapshot objectForKey: @"homeTelephoneNumber"] length] == 0 &&
      [elements count] > 0)
    {
      [self _setSnapshotValue: @"telephoneNumber"
	    to: [self _simpleValueForType: @"voice" inArray: elements  excluding: nil]];
    }

  [self _setupEmailFields];

  [self _setSnapshotValue: @"screenName"
        to: [[card uniqueChildWithTag: @"x-aim"] flattenedValuesForKey: @""]];

  elements = [card childrenWithTag: @"adr"
                   andAttribute: @"type" havingValue: @"work"];
  if (elements && [elements count] > 0)
    {
      element = [elements objectAtIndex: 0];
      [self _setSnapshotValue: @"workExtendedAddress"
                           to: [element flattenedValueAtIndex: 1 forKey: @""]];
      [self _setSnapshotValue: @"workStreetAddress"
                           to: [element flattenedValueAtIndex: 2 forKey: @""]];
      [self _setSnapshotValue: @"workCity"
                           to: [element flattenedValueAtIndex: 3 forKey: @""]];
      [self _setSnapshotValue: @"workState"
                           to: [element flattenedValueAtIndex: 4 forKey: @""]];
      [self _setSnapshotValue: @"workPostalCode"
                           to: [element flattenedValueAtIndex: 5 forKey: @""]];
      [self _setSnapshotValue: @"workCountry"
                           to: [element flattenedValueAtIndex: 6 forKey: @""]];
    }

  elements = [card childrenWithTag: @"adr"
                   andAttribute: @"type" havingValue: @"home"];
  if (elements && [elements count] > 0)
    {
      element = [elements objectAtIndex: 0];
      [self _setSnapshotValue: @"homeExtendedAddress"
                           to: [element flattenedValueAtIndex: 1 forKey: @""]];
      [self _setSnapshotValue: @"homeStreetAddress"
                           to: [element flattenedValueAtIndex: 2 forKey: @""]];
      [self _setSnapshotValue: @"homeCity"
                           to: [element flattenedValueAtIndex: 3 forKey: @""]];
      [self _setSnapshotValue: @"homeState"
                           to: [element flattenedValueAtIndex: 4 forKey: @""]];
      [self _setSnapshotValue: @"homePostalCode"
                           to: [element flattenedValueAtIndex: 5 forKey: @""]];
      [self _setSnapshotValue: @"homeCountry"
                           to: [element flattenedValueAtIndex: 6 forKey: @""]];
    }

  elements = [card childrenWithTag: @"url"];
  [self _setSnapshotValue: @"workURL"
        to: [self _simpleValueForType: @"work"  inArray: elements  excluding: nil]];
  [self _setSnapshotValue: @"homeURL"
        to: [self _simpleValueForType: @"home"  inArray: elements  excluding: nil]];
  
  // If we don't have a "work" or "home" URL but we still have 
  // an URL field present, let's add it to the "home" value
  if ([[snapshot objectForKey: @"workURL"] length] == 0 &&
      [[snapshot objectForKey: @"homeURL"] length] == 0 &&
      [elements count] > 0)
    {
      [self _setSnapshotValue: @"homeURL"
	    to: [[elements objectAtIndex: 0] flattenedValuesForKey: @""]];
    }
  // If we do have a "work" URL but no "home" URL but two
  // values URLs present, let's add the second one as the home URL
  else if ([[snapshot objectForKey: @"workURL"] length] > 0 &&
	   [[snapshot objectForKey: @"homeURL"] length] == 0 &&
	   [elements count] > 1)
    {
      int i;

      for (i = 0; i < [elements count]; i++)
	{
	  if ([[[elements objectAtIndex: i] flattenedValuesForKey: @""]
		caseInsensitiveCompare: [snapshot objectForKey: @"workURL"]] != NSOrderedSame)
	    {
	      [self _setSnapshotValue: @"homeURL"
		    to: [[elements objectAtIndex: i] flattenedValuesForKey: @""]];
	      break;
	    }
	}
    }
    

  [self _setSnapshotValue: @"calFBURL"
        to: [[card uniqueChildWithTag: @"FBURL"] flattenedValuesForKey: @""]];

  [self _setSnapshotValue: @"title" to: [card title]];
  [self _setupOrgFields];

  [self _setSnapshotValue: @"bday" to: [card bday]];
  [self _setSnapshotValue: @"tz" to: [card tz]];
  [self _setSnapshotValue: @"note" to: [card note]];

  [self _retrieveQueryParameter: @"contactEmail"
        intoSnapshotValue: @"workMail"];
  [self _retrieveQueryParameter: @"contactFN"
        intoSnapshotValue: @"fn"];
}

- (id <WOActionResults>) defaultAction
{
  card = [[self clientObject] vCard];
  if (card)
    [self initSnapshot];
  else
    return [NSException exceptionWithHTTPStatus:404 /* Not Found */
                        reason: @"could not open contact"];

  return self;
}

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

- (BOOL) canCreateOrModify
{
  SOGoObject *co;

  co = [self clientObject];

  return ([co isKindOfClass: [SOGoContentObject class]]
          && [super canCreateOrModify]);
}

- (NSArray *) photosURL
{
  NSArray *photoElements;
  NSURL *soURL;
  NSString *baseInlineURL, *photoURL;
  NGVCardPhoto *photo;
  int count, max;

  if (!photosURL)
    {
      soURL = [[self clientObject] soURL];
      baseInlineURL = [soURL absoluteString];
      photoElements = [card childrenWithTag: @"photo"];
      max = [photoElements count];
      photosURL = [[NSMutableArray alloc] initWithCapacity: max];
      for (count = 0; count < max; count++)
        {
          photo = [photoElements objectAtIndex: count];
          if ([photo isInline])
            photoURL = [NSString stringWithFormat: @"%@/photo%d",
                                 baseInlineURL, count];
          else
            photoURL = [photo flattenedValuesForKey: @""];
          [photosURL addObject: photoURL];
        }
    }

  return photosURL;
}

- (CardElement *) _elementWithTag: (NSString *) tag
                           ofType: (NSString *) type
{
  NSArray *elements;
  CardElement *element;

  elements = [card childrenWithTag: tag
                   andAttribute: @"type" havingValue: type];
  if ([elements count] > 0)
    element = [elements objectAtIndex: 0];
  else
    {
      element = [CardElement new];
      [element autorelease];
      [element setTag: tag];
      [element addType: type];
      [card addChild: element];
    }

  return element;
}

- (void) _savePhoneValues
{
  CardElement *phone;

  phone = [self _elementWithTag: @"tel" ofType: @"work"];
  [phone setSingleValue: [snapshot objectForKey: @"telephoneNumber"] forKey: @""];
  phone = [self _elementWithTag: @"tel" ofType: @"home"];
  [phone setSingleValue: [snapshot objectForKey: @"homeTelephoneNumber"] forKey: @""];
  phone = [self _elementWithTag: @"tel" ofType: @"cell"];
  [phone setSingleValue: [snapshot objectForKey: @"mobile"] forKey: @""];
  phone = [self _elementWithTag: @"tel" ofType: @"fax"];
  [phone setSingleValue: [snapshot objectForKey: @"facsimileTelephoneNumber"]
                 forKey: @""];
  phone = [self _elementWithTag: @"tel" ofType: @"pager"];
  [phone setSingleValue: [snapshot objectForKey: @"pager"] forKey: @""];
}

- (void) _saveEmails
{
  CardElement *workMail, *homeMail;

  workMail = [self _elementWithTag: @"email" ofType: @"work"];
  [workMail setSingleValue: [snapshot objectForKey: @"workMail"] forKey: @""];
  homeMail = [self _elementWithTag: @"email" ofType: @"home"];
  [homeMail setSingleValue: [snapshot objectForKey: @"homeMail"] forKey: @""];
  if (preferredEmail)
    {
      if ([preferredEmail isEqualToString: @"work"])
        [card setPreferred: workMail];
      else
        [card setPreferred: homeMail];
    }

  [[card uniqueChildWithTag: @"x-mozilla-html"]
    setSingleValue: [snapshot objectForKey: @"mozillaUseHtmlMail"]
            forKey: @""];
}

- (void) _saveSnapshot
{
  CardElement *element;
  NSArray *units;

  [card setNWithFamily: [snapshot objectForKey: @"sn"]
        given: [snapshot objectForKey: @"givenName"]
        additional: nil
        prefixes: nil
        suffixes: nil];
  [card setNickname: [snapshot objectForKey: @"nickname"]];
  [card setFn: [snapshot objectForKey: @"fn"]];
  [card setTitle: [snapshot objectForKey: @"title"]];
  [card setBday: [snapshot objectForKey: @"bday"]];
  [card setNote: [snapshot objectForKey: @"note"]];
  [card setTz: [snapshot objectForKey: @"tz"]];

  element = [self _elementWithTag: @"adr" ofType: @"home"];
  [element setSingleValue: [snapshot objectForKey: @"homeExtendedAddress"]
                  atIndex: 1 forKey: @""];
  [element setSingleValue: [snapshot objectForKey: @"homeStreetAddress"]
                  atIndex: 2 forKey: @""];
  [element setSingleValue: [snapshot objectForKey: @"homeCity"]
                  atIndex: 3 forKey: @""];
  [element setSingleValue: [snapshot objectForKey: @"homeState"]
                  atIndex: 4 forKey: @""];
  [element setSingleValue: [snapshot objectForKey: @"homePostalCode"]
                  atIndex: 5 forKey: @""];
  [element setSingleValue: [snapshot objectForKey: @"homeCountry"]
                  atIndex: 6 forKey: @""];

  element = [self _elementWithTag: @"adr" ofType: @"work"];
  [element setSingleValue: [snapshot objectForKey: @"workExtendedAddress"]
                  atIndex: 1 forKey: @""];
  [element setSingleValue: [snapshot objectForKey: @"workStreetAddress"]
                  atIndex: 2 forKey: @""];
  [element setSingleValue: [snapshot objectForKey: @"workCity"]
                  atIndex: 3 forKey: @""];
  [element setSingleValue: [snapshot objectForKey: @"workState"]
                  atIndex: 4 forKey: @""];
  [element setSingleValue: [snapshot objectForKey: @"workPostalCode"]
                  atIndex: 5 forKey: @""];
  [element setSingleValue: [snapshot objectForKey: @"workCountry"]
                  atIndex: 6 forKey: @""];

  element = [CardElement simpleElementWithTag: @"fburl"
                         value: [snapshot objectForKey: @"calFBURL"]];
  [card setUniqueChild: element];

  units = [NSArray arrayWithObject: [snapshot objectForKey: @"workService"]];
  [card setOrg: [snapshot objectForKey: @"workCompany"]
	units: units];

  [self _savePhoneValues];
  [self _saveEmails];
  [[self _elementWithTag: @"url" ofType: @"home"]
    setSingleValue: [snapshot objectForKey: @"homeURL"] forKey: @""];
  [[self _elementWithTag: @"url" ofType: @"work"]
    setSingleValue: [snapshot objectForKey: @"workURL"] forKey: @""];

  [[card uniqueChildWithTag: @"x-aim"]
    setSingleValue: [snapshot objectForKey: @"screenName"]
            forKey: @""];
}

- (id <WOActionResults>) saveAction
{
  SOGoContactGCSEntry *contact;
  id result;
  NSString *jsRefreshMethod;
  SoSecurityManager *sm;

  contact = [self clientObject];
  card = [contact vCard];
  if (card)
    {
//       [self _fixupSnapshot];
      [self _saveSnapshot];
      [card setCategories: contactCategories];
      [self _fetchAndCombineCategoriesList: contactCategories];
      [contact save];

      if (componentAddressBook && componentAddressBook != [self componentAddressBook])
	{
	  sm = [SoSecurityManager sharedSecurityManager];
	  if (![sm validatePermission: SoPerm_DeleteObjects
		   onObject: componentAddressBook
		   inContext: context])
	    {
	      if (![sm validatePermission: SoPerm_AddDocumentsImagesAndFiles
		       onObject: componentAddressBook
		       inContext: context])
		[contact moveToFolder: (SOGoGCSFolder *)componentAddressBook]; // TODO: handle exception
	    }
	}
      
      if ([[[[self context] request] formValueForKey: @"nojs"] intValue])
        result = [self redirectToLocation: [self modulePath]];
      else
        {
          jsRefreshMethod
            = [NSString stringWithFormat: @"refreshContacts(\"%@\")",
                        [contact nameInContainer]];
          result = [self jsCloseWithRefreshMethod: jsRefreshMethod];
        }
    }
  else
    result = [NSException exceptionWithHTTPStatus: 400 /* Bad Request */
                          reason: @"method cannot be invoked on "
                          @"the specified object"];

  return result;
}

- (id) writeAction
{
  NSString *email, *cn, *url;
  NSMutableString *address;

  card = [[self clientObject] vCard];
  [self initSnapshot];
  if ([preferredEmail isEqualToString: @"home"])
    email = [snapshot objectForKey: @"homeMail"];
  else
    email = [snapshot objectForKey: @"workMail"];

  if (email)
    {
      address = [NSMutableString string];
      cn = [card fn];
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

#warning Could this be part of a common parent with UIxAppointment/UIxTaskEditor/UIxListEditor ?
- (id) newAction
{
  NSString *objectId, *method, *uri;
  id <WOActionResults> result;
  SOGoContactGCSFolder *co;
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
	  method = [NSString stringWithFormat: @"%@/%@.vcf/editAsContact",
			     [co soURL], objectId];
	}
      else
	{
	  method = [NSString stringWithFormat: @"%@/Contacts/personal/%@.vcf/editAsContact",
			     [self userFolderPath], objectId];
	}
      uri = [self completeHrefForMethod: method];
      result = [self redirectToLocation: uri];
    }
  else
    result = [NSException exceptionWithHTTPStatus: 500 /* Internal Error */
                          reason: @"could not create a unique ID"];

  return result;
}

@end /* UIxContactEditor */

