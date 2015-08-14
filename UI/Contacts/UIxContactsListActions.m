/*
  Copyright (C) 2006-2015 Inverse inc.

  This file is part of SOGo.

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

#import <Foundation/Foundation.h>
#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/NSDictionary+Utilities.h>
#import <SoObjects/SOGo/NSString+Utilities.h>
#import <SoObjects/SOGo/SOGoSystemDefaults.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WORequest.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSNull+misc.h>

#import <Common/WODirectAction+SOGo.h>

#import <Contacts/SOGoContactObject.h>
#import <Contacts/SOGoContactFolder.h>
#import <Contacts/SOGoContactFolders.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>

#import <NGCards/NGVCard.h>
#import <NGCards/NGVList.h>
#import <SoObjects/Contacts/SOGoContactGCSEntry.h>
#import <SoObjects/Contacts/SOGoContactLDIFEntry.h>
#import <SoObjects/Contacts/SOGoContactGCSList.h>
#import <SoObjects/Contacts/SOGoContactGCSFolder.h>
#import <GDLContentStore/GCSFolder.h>

#import "UIxContactsListActions.h"

@implementation UIxContactsListActions

- (id) init
{
  if ((self = [super init]))
    contactInfos = nil;
  
  return self;
}

- (void) dealloc
{
  [contactInfos release];
  [super dealloc];
}

/* accessors */

- (NSString *) defaultSortKey
{
  return @"c_cn";
}

- (NSString *) sortKey
{
  NSString *s;
  WORequest *rq;
  
  rq = [context request];
  s = [rq formValueForKey: @"sort"];
  if (![s length])
    s = [self defaultSortKey];

  return s;
}

- (void) saveSortValue
{
  NSMutableDictionary *contactSettings;
  NSString *ascending, *sort;
  SOGoUserSettings *us;

  sort = [[context request] formValueForKey: @"sort"];
  ascending = [[context request] formValueForKey: @"asc"];

  if ([sort length])
    { 
      us = [[context activeUser] userSettings];
      contactSettings = [us objectForKey: @"Contact"];
      // Must create if it doesn't exist
      if (!contactSettings)
        {
          contactSettings = [NSMutableDictionary dictionary];
          [us setObject: contactSettings forKey: @"Contact"];
        }
      [contactSettings setObject: [NSArray arrayWithObjects: [sort lowercaseString], [NSString stringWithFormat: @"%d", [ascending intValue]], nil]
                                                     forKey: @"SortingState"];
      [us synchronize];
    }
}

- (NSArray *) contactInfos
{
  id <SOGoContactFolder> folder;
  NSString *ascending, *searchText, *valueText;
  NSArray *results;
  NSMutableArray *filteredContacts;
  NSDictionary *contact;
  BOOL excludeLists;
  NSComparisonResult ordering;
  WORequest *rq;
  unsigned int i;

  [self saveSortValue];

  if (!contactInfos)
    {
      folder = [self clientObject];
      rq = [context request];

      ascending = [rq formValueForKey: @"asc"];
      ordering = ((![ascending length] || [ascending boolValue])
		  ? NSOrderedAscending : NSOrderedDescending);

      searchText = [rq formValueForKey: @"search"];
      if ([searchText length] > 0)
	valueText = [rq formValueForKey: @"value"];
      else
	valueText = nil;

      excludeLists = [[rq formValueForKey: @"excludeLists"] boolValue];

      [contactInfos release];
      results = [folder lookupContactsWithFilter: valueText
                                      onCriteria: searchText
                                          sortBy: [self sortKey]
                                        ordering: ordering
                                        inDomain: [[context activeUser] domain]];
      if (excludeLists)
        {
          filteredContacts = [NSMutableArray array];
          for (i = 0; i < [results count]; i++)
            {
              contact = [results objectAtIndex: i];
              if (![[contact objectForKey: @"c_component"] isEqualToString: @"vlist"])
                {
                  [filteredContacts addObject: contact];
                }
            }
          contactInfos = [NSArray arrayWithArray: filteredContacts];
        }
      else
        {
          contactInfos = results;
        }
      [contactInfos retain];
    }

  return contactInfos;
}

/**
 * @api {get} /so/:username/Contacts/:addressbookId/view List cards
 * @apiVersion 1.0.0
 * @apiName GetContactsList
 * @apiGroup Contacts
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Contacts/personal/view?search=name_or_address\&value=Bob
 *
 * @apiParam {Boolean} [asc] Descending sort when false. Defaults to true (ascending).
 * @apiParam {String} [sort] Sort field. Either c_cn, c_mail, c_screenname, c_o, or c_telephonenumber.
 * @apiParam {String} [search] Field criteria. Either name_or_address, category, or organization.
 * @apiParam {String} [value] String to match
 *
 * @apiSuccess (Success 200) {String} id Address book         ID
 * @apiSuccess (Success 200) {String} [publicCardDavURL]      Public CardDAV URL of the address book
 * @apiSuccess (Success 200) {String} cardDavURL              CardDAV URL of the address book
 * @apiSuccess (Success 200) {Object[]} [cards]               Matching cards
 * @apiSuccess (Success 200) {String} cards.id                Card ID
 * @apiSuccess (Success 200) {String} cards.c_name            Card ID
 * @apiSuccess (Success 200) {String} cards.c_component       Either vcard or vlist
 * @apiSuccess (Success 200) {String} cards.c_cn              Fullname
 * @apiSuccess (Success 200) {String} cards.c_givenname       Firstname
 * @apiSuccess (Success 200) {String} cards.c_sn              Lastname
 * @apiSuccess (Success 200) {String} cards.c_screenname      Screenname
 * @apiSuccess (Success 200) {String} cards.c_o               Organization name
 * @apiSuccess (Success 200) {Object} cards.emails            Preferred email address
 * @apiSuccess (Success 200) {String} cards.emails.type       Type (e.g., home or work)
 * @apiSuccess (Success 200) {String} cards.emails.value      Email address
 * @apiSuccess (Success 200) {String} cards.c_mail            Preferred email address
 * @apiSuccess (Success 200) {String} cards.c_telephonenumber Preferred telephone number
 * @apiSuccess (Success 200) {String} cards.c_categories      Comma-separated list of categories
 *
 * See [SOGoContactGCSFolder fixupContactRecord:]
 */
- (id <WOActionResults>) contactsListAction
{
  id <WOActionResults> result;
  NSDictionary *data;
  NSArray *contactsList;

  contactsList = [self contactInfos];

  data = [NSDictionary dictionaryWithObjectsAndKeys:
                         [[self clientObject] nameInContainer], @"id",
                       [self cardDavURL], @"cardDavURL",
                       [self publicCardDavURL], @"publicCardDavURL",
                       contactsList, @"cards",
                       nil];

  result = [self responseWithStatus: 200
                          andString: [data jsonRepresentation]];

  return result;
}

- (id <WOActionResults>) contactSearchAction
{
  id <WOActionResults> result;
  id <SOGoContactFolder> folder;
  BOOL excludeLists;
  NSString *searchText, *mail, *domain;
  NSDictionary *contact, *data;
  NSArray *contacts, *descriptors, *sortedContacts;
  NSMutableDictionary *uniqueContacts;
  unsigned int i;
  NSSortDescriptor *commonNameDescriptor;
  WORequest *rq;

  rq = [context request];
  excludeLists = [[rq formValueForKey: @"excludeLists"] boolValue];
  searchText = [rq formValueForKey: @"search"];
  if ([searchText length] > 0)
    {
      NS_DURING
        folder = [self clientObject];
      NS_HANDLER
        if ([[localException name] isEqualToString: @"SOGoDBException"])
          folder = nil;
        else
          [localException raise];
      NS_ENDHANDLER
        
      domain = [[context activeUser] domain];
      uniqueContacts = [NSMutableDictionary dictionary];
      contacts = [folder lookupContactsWithFilter: searchText
                                       onCriteria: @"name_or_address"
                                           sortBy: @"c_cn"
                                         ordering: NSOrderedAscending
                                         inDomain: domain];
      for (i = 0; i < [contacts count]; i++)
        {
          contact = [contacts objectAtIndex: i];
          if (!excludeLists || ![[contact objectForKey: @"c_component"] isEqualToString: @"vlist"])
            {
              mail = [contact objectForKey: @"c_mail"];
              if ([mail isNotNull] && [uniqueContacts objectForKey: mail] == nil)
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
           sortedContacts, @"cards", nil];
      result = [self responseWithStatus: 200
			      andString: [data jsonRepresentation]];
    }
  else
    result = [NSException exceptionWithHTTPStatus: 400
                                           reason: @"missing 'search' parameter"];  

  return result;
}

- (NSString *) cardDavURL
{
  NSString *davURL, *baseCardDAVURL;
 
  davURL = @"";

  if ([[self clientObject] respondsToSelector: @selector(realDavURL)]) 
    davURL = [[[self clientObject] realDavURL] absoluteString];

  if ([davURL hasSuffix: @"/"])
    baseCardDAVURL = [davURL substringToIndex: [davURL length] - 1];
  else
    baseCardDAVURL = davURL;
  
  return [NSString stringWithFormat: @"%@/", baseCardDAVURL];
}

- (NSString *) publicCardDavURL
{
  if ([[self clientObject] respondsToSelector: @selector(publicDavURL)] &&
      [[SOGoSystemDefaults sharedSystemDefaults] enablePublicAccess])
    {
      NSString *davURL, *basePublicCardDAVURL;

      davURL = [[[self clientObject] publicDavURL] absoluteString];
      if ([davURL hasSuffix: @"/"])
        basePublicCardDAVURL = [davURL substringToIndex: [davURL length] - 1];
      else
        basePublicCardDAVURL = davURL;
      
      return [NSString stringWithFormat: @"%@/", basePublicCardDAVURL];
    }

  return @"";
}

@end /* UIxContactsListActions */
