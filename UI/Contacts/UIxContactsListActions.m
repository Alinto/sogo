/*
  Copyright (C) 2006-2016 Inverse inc.

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
#import <Foundation/NSEnumerator.h>

#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/NSDictionary+Utilities.h>
#import <SoObjects/SOGo/NSString+Utilities.h>
#import <SoObjects/SOGo/SOGoSystemDefaults.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WORequest.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSNull+misc.h>

#import <EOControl/EOQualifier.h>
#import <EOControl/EOSortOrdering.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>

#import <SoObjects/Contacts/SOGoContactGCSEntry.h>
#import <SoObjects/Contacts/SOGoContactGCSFolder.h>

#import "UIxContactsListActions.h"

// The maximum number of headers to prefetch when querying the IDs list
#define headersPrefetchMaxSize 100

@implementation UIxContactsListActions

- (id) init
{
  if ((self = [super init]))
    {
      requestData = nil;
      contactInfos = nil;
      sortedIDs = nil;
    }
  
  return self;
}

- (void) dealloc
{
  [requestData release];
  [contactInfos release];
  [sortedIDs release];
  [super dealloc];
}

/* accessors */

- (NSDictionary *) requestData
{
  WORequest *rq;

  if (!requestData)
    {
      rq = [context request];
      requestData = [[rq contentAsString] objectFromJSONString];
      [requestData retain];
    }

  return requestData;
}

- (NSString *) defaultSortKey
{
  return @"c_cn";
}

- (NSString *) sortKey
{
  NSString *s;
  static NSArray *sortKeys = nil;

  if (!sortKeys)
    {
      sortKeys = [NSArray arrayWithObjects: @"c_cn", @"c_sn", @"c_givenname", @"c_mail",
                          @"c_screenname", @"c_o", @"c_telephonenumber", nil];
      [sortKeys retain];
    }

  s = [[self requestData] objectForKey: @"sort"];
  if (![s length] || ![sortKeys containsObject: s])
    s = [self defaultSortKey];

  return s;
}

- (void) saveSortValue
{
  NSMutableDictionary *contactSettings;
  NSString *ascending, *sort;
  SOGoUserSettings *us;

  sort = [[self requestData] objectForKey: @"sort"];
  ascending = [[self requestData] objectForKey: @"asc"];

  if ([sort length])
    {
      sort = [self sortKey];
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
  NSString *ascending, *valueText;
  NSArray *results, *searchFields, *fields;
  NSMutableArray *filteredContacts, *headers;
  NSDictionary *data, *contact;
  BOOL excludeLists;
  NSComparisonResult ordering;
  NSUInteger max, count;
  unsigned int i;

  [self saveSortValue];

  if (!contactInfos)
    {
      folder = [self clientObject];
      data = [self requestData];

      ascending = [data objectForKey: @"asc"];
      ordering = ((!ascending || [ascending boolValue])
		  ? NSOrderedAscending : NSOrderedDescending);

      searchFields = [data objectForKey: @"search"];
      if ([searchFields isKindOfClass: [NSArray class]] && [searchFields count] > 0)
	valueText = [data objectForKey: @"value"];
      else
        {
          searchFields = nil;
          valueText = nil;
        }

      excludeLists = [[data objectForKey: @"excludeLists"] boolValue];

      [contactInfos release];
      results = [folder lookupContactsWithFilter: valueText
                                      onCriteria: searchFields
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

      // Convert array of dictionaries to array of arrays (lighter on the wire)
      max = [contactInfos count];
      headers = [NSMutableArray arrayWithCapacity: max];
      if (max > 0)
        {
          count = 0;
          fields = [[contactInfos objectAtIndex: 0] allKeys];
          [headers addObject: fields];
          while (count < max)
            {
              [headers addObject: [[contactInfos objectAtIndex: count] objectsForKeys: fields
                                                                       notFoundMarker: [NSNull null]]];
              count++;
            }
        }

      contactInfos = headers;
      [contactInfos retain];
    }

  return contactInfos;
}

- (NSArray *) sortedIDs
{
  id <SOGoContactFolder> folder;
  NSString *ascending, *valueText;
  NSArray *searchFields, *fields, *records;
  NSDictionary *data, *record;
  NSEnumerator *recordsList;
  NSMutableArray *ids;
  BOOL excludeLists;
  EOKeyValueQualifier *kvQualifier;
  EOSortOrdering *ordering;
  EOQualifier *qualifier;
  SEL compare;

  folder = [self clientObject];

  if (!sortedIDs && [folder isKindOfClass: [SOGoContactGCSFolder class]])
    {
      fields = [NSArray arrayWithObjects: @"c_name", nil];
      data =  [self requestData];
      qualifier = nil;

      // ORDER BY clause
      ascending = [data valueForKey: @"asc"];
      if (!ascending || [ascending boolValue])
        compare = EOCompareAscending;
      else
        compare = EOCompareDescending;
      ordering = [EOSortOrdering sortOrderingWithKey: [self sortKey]
                                            selector: compare];

      // WHERE clause
      searchFields = (NSArray *)[data objectForKey: @"search"];
      if ([searchFields count] > 0)
        {
          valueText = [data objectForKey: @"value"];
          qualifier = [(SOGoContactGCSFolder *) folder qualifierForFilter: valueText
                                                               onCriteria: searchFields];
        }
      excludeLists = [[data objectForKey: @"excludeLists"] boolValue];
      if (excludeLists)
        {
          kvQualifier = [[EOKeyValueQualifier alloc]
                               initWithKey: @"c_component"
                          operatorSelector: EOQualifierOperatorNotEqual
                                     value: @"vlist"];
          [kvQualifier autorelease];
          if (qualifier)
            qualifier = [[EOAndQualifier alloc] initWithQualifiers: kvQualifier, qualifier, nil];
          else
            qualifier = kvQualifier;
        }

      // Perform lookup
      records = [(SOGoContactGCSFolder *) folder lookupContactsFields: fields
                                                        withQualifier: qualifier
                                                         andOrderings: [NSArray arrayWithObject: ordering]];

      // Convert records to an array of strings (c_name)
      ids = [NSMutableArray arrayWithCapacity: [records count]];
      recordsList = [records objectEnumerator];
      while ((record = [recordsList nextObject]))
        [ids addObject: [record objectForKey: @"c_name"]];

      [sortedIDs release];
      sortedIDs = ids;
      [sortedIDs retain];
    }

  return sortedIDs;
}

- (NSArray *) getHeadersForIDs: (NSArray *) ids
{
  id <SOGoContactFolder> folder;
  NSArray *results, *fields;
  NSEnumerator *idsList;
  NSMutableArray *qualifiers, *headers;
  NSString *contactID;
  EOKeyValueQualifier *kvQualifier;
  EOQualifier *orQualifier;
  NSUInteger max, count;

  folder = [self clientObject];

  if (!contactInfos && [ids count] && [folder isKindOfClass: [SOGoContactGCSFolder class]])
    {
      qualifiers = [NSMutableArray arrayWithCapacity: [ids count]];
      idsList = [ids objectEnumerator];

      while ((contactID = [idsList nextObject]))
        {
          kvQualifier = [[EOKeyValueQualifier alloc]
                               initWithKey: @"c_name"
                          operatorSelector: EOQualifierOperatorEqual
                                     value: contactID];
          [kvQualifier autorelease];
          [qualifiers addObject: kvQualifier];
        }

      orQualifier = [[EOOrQualifier alloc] initWithQualifierArray: qualifiers];
      [orQualifier autorelease];

      results = [(SOGoContactGCSFolder *) folder lookupContactsWithQualifier: orQualifier];
      max = [results count];
      headers = [NSMutableArray arrayWithCapacity: max];
      if (max > 0)
        {
          count = 0;
          fields = [[results objectAtIndex: 0] allKeys];
          [headers addObject: fields];
          while (count < max)
            {
              [headers addObject: [[results objectAtIndex: count] objectsForKeys: fields
                                                                  notFoundMarker: [NSNull null]]];
              count++;
            }
        }

      [contactInfos release];
      contactInfos = headers;
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
 * @apiParam {Boolean} [partial] Send all contacts IDs and headers of the first 50 contacts. Defaults to false.
 * @apiParam {Boolean} [asc] Descending sort when false. Defaults to true (ascending).
 * @apiParam {String} [sort] Sort field. Either c_cn, c_mail, c_screenname, c_o, or c_telephonenumber.
 * @apiParam {String} [search] Field criteria. Either name_or_address, category, or organization.
 * @apiParam {String} [value] String to match
 *
 * @apiSuccess (Success 200) {String} id Address book         ID
 * @apiSuccess (Success 200) {String} [publicCardDavURL]      Public CardDAV URL of the address book
 * @apiSuccess (Success 200) {String} cardDavURL              CardDAV URL of the address book
 * @apiSuccess (Success 200) {String[]} [ids]                 Sorted IDs when requesting partial results
 * @apiSuccess (Success 200) {Object[]} headers               Matching cards
 * @apiSuccess (Success 200) {String} headers.id                Card ID
 * @apiSuccess (Success 200) {String} headers.c_name            Card ID
 * @apiSuccess (Success 200) {String} headers.c_component       Either vcard or vlist
 * @apiSuccess (Success 200) {String} headers.c_cn              Fullname
 * @apiSuccess (Success 200) {String} headers.c_givenname       Firstname
 * @apiSuccess (Success 200) {String} headers.c_sn              Lastname
 * @apiSuccess (Success 200) {String} headers.c_screenname      Screenname
 * @apiSuccess (Success 200) {String} headers.c_o               Organization name
 * @apiSuccess (Success 200) {Object} headers.emails            Preferred email address
 * @apiSuccess (Success 200) {String} headers.emails.type       Type (e.g., home or work)
 * @apiSuccess (Success 200) {String} headers.emails.value      Email address
 * @apiSuccess (Success 200) {String} headers.c_mail            Preferred email address
 * @apiSuccess (Success 200) {String} headers.phones            Preferred telephone number
 * @apiSuccess (Success 200) {String} headers.phones.type       Type (e.g., home or work)
 * @apiSuccess (Success 200) {String} headers.phones.value      Phone number
 * @apiSuccess (Success 200) {String} headers.c_telephonenumber Preferred telephone number
 * @apiSuccess (Success 200) {String} headers.c_categories      Comma-separated list of categories
 *
 * See [SOGoContactGCSFolder fixupContactRecord:]
 */
- (id <WOActionResults>) contactsListAction
{
  id <WOActionResults> result;
  id folder;
  NSMutableDictionary *data;
  NSArray *ids, *partialIds, *headers;
  NSRange range;
  NSString *partial;

  folder = [self clientObject];
  data = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                [folder nameInContainer], @"id",
                              [self cardDavURL], @"cardDavURL",
                              [self publicCardDavURL], @"publicCardDavURL",
                              nil];
  partial = [[self requestData] objectForKey: @"partial"];

  if ([partial intValue] && [folder isKindOfClass: [SOGoContactGCSFolder class]])
    {
      // Only save sort state when performing a partial listing
      [self saveSortValue];

      // Fetch all sorted IDs
      ids = [self sortedIDs];

      // Fetch the first X entries
      if ([ids count] > headersPrefetchMaxSize)
        {
          range = NSMakeRange(0, headersPrefetchMaxSize);
          partialIds = [ids subarrayWithRange: range];
        }
      else
        {
          partialIds = ids;
        }
      headers = [self getHeadersForIDs: partialIds];

      if (ids)
        [data setObject: ids forKey: @"ids"];
      if (headers)
        [data setObject: headers forKey: @"headers"];
    }
  else
    {
      headers = [self contactInfos];
      if (headers)
        [data setObject: headers forKey: @"headers"];
    }

  result = [self responseWithStatus: 200
              andJSONRepresentation: data];

  return result;
}

- (id <WOActionResults>) getHeadersAction
{
  NSArray *ids, *headers;
  NSDictionary *data;
  WOResponse *response;

  data = [self requestData];
  if (![[data objectForKey: @"ids"] isKindOfClass: [NSArray class]] ||
      [[data objectForKey: @"ids"] count] == 0)
    {
      data = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"No ID specified", @"message", nil];
      response = [self responseWithStatus: 404 /* Not Found */
                    andJSONRepresentation: data];

      return response;
    }

  ids = [data objectForKey: @"ids"];
  headers = [self getHeadersForIDs: ids];

  response = [self responseWithStatus: 200
                andJSONRepresentation: headers];

  return response;
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

  excludeLists = [[[self requestData] objectForKey: @"excludeLists"] boolValue];
  searchText = [[self requestData] objectForKey: @"search"];
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
                                       onCriteria: nil
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
