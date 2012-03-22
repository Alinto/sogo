/*
  Copyright (C) 2006-2011 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

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

- (NSArray *) contactInfos
{
  id <SOGoContactFolder> folder;
  NSString *ascending, *searchText, *valueText;
  NSComparisonResult ordering;
  WORequest *rq;

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

      [contactInfos release];
      contactInfos = [folder lookupContactsWithFilter: valueText
                                           onCriteria: searchText
                                               sortBy: [self sortKey]
                                             ordering: ordering
                                             inDomain: [[context activeUser] domain]];
      [contactInfos retain];
    }

  return contactInfos;
}

/**
 * Retrieve the addressbook contacts with respect to the sort and
 * search criteria.
 * @return a JSON array of dictionaries representing the contacts.
 */
- (id <WOActionResults>) contactsListAction
{
  id <WOActionResults> result;
  NSArray *contactsList;

  contactsList = [self contactInfos];
  result = [self responseWithStatus: 200
			  andString: [contactsList jsonRepresentation]];

  return result;
}

- (id <WOActionResults>) contactSearchAction
{
  id <WOActionResults> result;
  id <SOGoContactFolder> folder;
  NSString *searchText, *mail, *domain;
  NSDictionary *contact, *data;
  NSArray *contacts, *descriptors, *sortedContacts;
  NSMutableDictionary *uniqueContacts;
  unsigned int i;
  NSSortDescriptor *commonNameDescriptor;
  WORequest *rq;

  rq = [context request];
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
          mail = [contact objectForKey: @"c_mail"];
          if ([mail isNotNull] && [uniqueContacts objectForKey: mail] == nil)
            [uniqueContacts setObject: contact forKey: mail];
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
           sortedContacts, @"contacts", nil];
      result = [self responseWithStatus: 200
			      andString: [data jsonRepresentation]];
    }
  else
    result = [NSException exceptionWithHTTPStatus: 400
                                           reason: @"missing 'search' parameter"];  

  return result;
}

@end /* UIxContactsListActions */
