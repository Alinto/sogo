/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
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
#import <Foundation/NSEnumerator.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoPermissions.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/SoObject.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSNull+misc.h>

#import <NGCards/NGVCard.h>
#import <NGCards/NSArray+NGCards.h>

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
    }

  return self;
}

- (void) dealloc
{
  [snapshot release];
  [preferredEmail release];
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

- (NSString *)_completeURIForMethod:(NSString *)_method {
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
	  ![sm validatePermission: SoPerm_AddDocumentsImagesAndFiles
	       onObject: currentFolder
	       inContext: context])
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
{
  NSArray *elements;
  NSString *value;

  elements = [anArray cardElementsWithAttribute: @"type"
                      havingValue: aType];
  if ([elements count] > 0)
    value = [[elements objectAtIndex: 0] value: 0];
  else
    value = nil;

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
                   inArray: elements];
  homeMail = [self _simpleValueForType: @"home"
                   inArray: elements];
  prefMail = [self _simpleValueForType: @"pref"
                   inArray: elements];

  if (max > 0)
    {
      potential = [[elements objectAtIndex: 0] value: 0];
      if (!workMail)
        {
          if (homeMail && homeMail == potential && max > 1)
            workMail = [[elements objectAtIndex: 1] value: 0];
          else
            workMail = potential;
        }
      if (!homeMail && max > 1)
        {
          if (workMail && workMail == potential)
            homeMail = [[elements objectAtIndex: 1] value: 0];
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
        to: [[card uniqueChildWithTag: @"x-mozilla-html"] value: 0]];
}

- (void) _setupOrgFields
{
  NSArray *org, *orgServices;
  NSRange aRange;
  unsigned int max;

  org = [card org];
  max = [org count];
  if (max > 0)
    {
      [self _setSnapshotValue: @"workCompany" to: [org objectAtIndex: 0]];
      if (max > 1)
        {
          aRange = NSMakeRange (1, max - 1);
          orgServices = [org subarrayWithRange: aRange];
          [self _setSnapshotValue: @"workService"
                to: [orgServices componentsJoinedByString: @", "]];
        }
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
  NSArray *n, *elements;
  CardElement *element;
  unsigned int max;

  n = [card n];
  if (n)
    {
      max = [n count];
      if (max > 0)
        {
          [self _setSnapshotValue: @"sn" to: [n objectAtIndex: 0]];
          if (max > 1)
            [self _setSnapshotValue: @"givenName" to: [n objectAtIndex: 1]];
        }
    }
  [self _setSnapshotValue: @"fn" to: [card fn]];
  [self _setSnapshotValue: @"nickname" to: [card nickname]];

  elements = [card childrenWithTag: @"tel"];
  [self _setSnapshotValue: @"telephoneNumber"
        to: [self _simpleValueForType: @"work" inArray: elements]];
  [self _setSnapshotValue: @"homeTelephoneNumber"
        to: [self _simpleValueForType: @"home" inArray: elements]];
  [self _setSnapshotValue: @"mobile"
        to: [self _simpleValueForType: @"cell" inArray: elements]];
  [self _setSnapshotValue: @"facsimileTelephoneNumber"
        to: [self _simpleValueForType: @"fax" inArray: elements]];
  [self _setSnapshotValue: @"pager"
        to: [self _simpleValueForType: @"pager" inArray: elements]];

  [self _setupEmailFields];

  [self _setSnapshotValue: @"screenName"
        to: [[card uniqueChildWithTag: @"x-aim"] value: 0]];

  elements = [card childrenWithTag: @"adr"
                   andAttribute: @"type" havingValue: @"work"];
  if (elements && [elements count] > 0)
    {
      element = [elements objectAtIndex: 0];
      [self _setSnapshotValue: @"workStreetAddress"
            to: [element value: 2]];
      [self _setSnapshotValue: @"workCity"
            to: [element value: 3]];
      [self _setSnapshotValue: @"workState"
            to: [element value: 4]];
      [self _setSnapshotValue: @"workPostalCode"
            to: [element value: 5]];
      [self _setSnapshotValue: @"workCountry"
            to: [element value: 6]];
    }

  elements = [card childrenWithTag: @"adr"
                   andAttribute: @"type" havingValue: @"home"];
  if (elements && [elements count] > 0)
    {
      element = [elements objectAtIndex: 0];
      [self _setSnapshotValue: @"homeStreetAddress"
            to: [element value: 2]];
      [self _setSnapshotValue: @"homeCity"
            to: [element value: 3]];
      [self _setSnapshotValue: @"homeState"
            to: [element value: 4]];
      [self _setSnapshotValue: @"homePostalCode"
            to: [element value: 5]];
      [self _setSnapshotValue: @"homeCountry"
            to: [element value: 6]];
    }

  elements = [card childrenWithTag: @"url"];
  [self _setSnapshotValue: @"workURL"
        to: [self _simpleValueForType: @"work" inArray: elements]];
  [self _setSnapshotValue: @"homeURL"
        to: [self _simpleValueForType: @"home" inArray: elements]];
  [self _setSnapshotValue: @"calFBURL"
        to: [[card uniqueChildWithTag: @"FBURL"] value: 0]];

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
  [phone setValue: 0 to: [snapshot objectForKey: @"telephoneNumber"]];
  phone = [self _elementWithTag: @"tel" ofType: @"home"];
  [phone setValue: 0 to: [snapshot objectForKey: @"homeTelephoneNumber"]];
  phone = [self _elementWithTag: @"tel" ofType: @"cell"];
  [phone setValue: 0 to: [snapshot objectForKey: @"mobile"]];
  phone = [self _elementWithTag: @"tel" ofType: @"fax"];
  [phone setValue: 0
         to: [snapshot objectForKey: @"facsimileTelephoneNumber"]];
  phone = [self _elementWithTag: @"tel" ofType: @"pager"];
  [phone setValue: 0
         to: [snapshot objectForKey: @"pager"]];
}

- (void) _saveEmails
{
  CardElement *workMail, *homeMail;

  workMail = [self _elementWithTag: @"email" ofType: @"work"];
  [workMail setValue: 0 to: [snapshot objectForKey: @"workMail"]];
  homeMail = [self _elementWithTag: @"email" ofType: @"home"];
  [homeMail setValue: 0 to: [snapshot objectForKey: @"homeMail"]];
  if (preferredEmail)
    {
      if ([preferredEmail isEqualToString: @"work"])
        [card setPreferred: workMail];
      else
        [card setPreferred: homeMail];
    }

  [[card uniqueChildWithTag: @"x-mozilla-html"]
    setValue: 0
    to: [snapshot objectForKey: @"mozillaUseHtmlMail"]];
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
  [element setValue: 2 to: [snapshot objectForKey: @"homeStreetAddress"]];
  [element setValue: 3 to: [snapshot objectForKey: @"homeCity"]];
  [element setValue: 4 to: [snapshot objectForKey: @"homeState"]];
  [element setValue: 5 to: [snapshot objectForKey: @"homePostalCode"]];
  [element setValue: 6 to: [snapshot objectForKey: @"homeCountry"]];

  element = [self _elementWithTag: @"adr" ofType: @"work"];
  [element setValue: 2 to: [snapshot objectForKey: @"workStreetAddress"]];
  [element setValue: 3 to: [snapshot objectForKey: @"workCity"]];
  [element setValue: 4 to: [snapshot objectForKey: @"workState"]];
  [element setValue: 5 to: [snapshot objectForKey: @"workPostalCode"]];
  [element setValue: 6 to: [snapshot objectForKey: @"workCountry"]];

  element = [CardElement simpleElementWithTag: @"fburl"
                         value: [snapshot objectForKey: @"calFBURL"]];
  [card setUniqueChild: element];

  units = [NSArray arrayWithObject: [snapshot objectForKey: @"workService"]];
  [card setOrg: [snapshot objectForKey: @"workCompany"]
	units: units];

  [self _savePhoneValues];
  [self _saveEmails];
  [[self _elementWithTag: @"url" ofType: @"home"]
    setValue: 0 to: [snapshot objectForKey: @"homeURL"]];
  [[self _elementWithTag: @"url" ofType: @"work"]
    setValue: 0 to: [snapshot objectForKey: @"workURL"]];

  [[card uniqueChildWithTag: @"x-aim"]
    setValue: 0
    to: [snapshot objectForKey: @"screenName"]];
}

- (id <WOActionResults>) saveAction
{
  SOGoContactGCSEntry *contact;
  id result;
  NSString *jsRefreshMethod;
  SoSecurityManager *sm;
  NSException *ex;

  contact = [self clientObject];
  card = [contact vCard];
  if (card)
    {
//       [self _fixupSnapshot];
      [self _saveSnapshot];
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
		ex = [contact moveToFolder: componentAddressBook]; // TODO: handle exception
	    }
	}
      
      if ([[[[self context] request] formValueForKey: @"nojs"] intValue])
        result = [self redirectToLocation: [self applicationPath]];
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

