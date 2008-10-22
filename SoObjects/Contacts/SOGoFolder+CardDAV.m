/* NSObject+CardDAV.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse inc.
 *
 * Author: Ludovic Marcotte <ludovic@inverse.ca>
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

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSString+misc.h>
#import <DOM/DOMProtocols.h>
#import <SaxObjC/SaxObjC.h>
#import <SaxObjC/XMLNamespaces.h>

#import "SOGoContactFolder.h"
#import "SOGoContactGCSEntry.h"

@implementation SOGoFolder (CardDAV)

- (void) _appendComponentsMatchingFilters: (NSArray *) filters
                               toResponse: (WOResponse *) response
				  context: (id) localContext
{
  unsigned int count, max;
  NSDictionary *currentFilter, *contact;
  NSEnumerator *contacts;
  NSString *baseURL;

  baseURL = [self baseURLInContext: localContext];

  max = [filters count];
  for (count = 0; count < max; count++)
    {
      currentFilter = [filters objectAtIndex: count];
      contacts = [[self lookupContactsWithFilter: [[currentFilter allValues] lastObject]
			sortBy: @"c_givenname"
			ordering: NSOrderedDescending]
		   objectEnumerator];
      
      while ((contact = [contacts nextObject]))
	[self appendObject: contact
	      withBaseURL: baseURL
	      toREPORTResponse: response];
    }
}

- (BOOL) _isValidFilter: (NSString *) theString
{
  NSString *newString;

  newString = [theString lowercaseString];

  return ([theString isEqualToString: @"sn"]
	  || [theString isEqualToString: @"givenname"]
	  || [theString isEqualToString: @"mail"]
	  || [theString isEqualToString: @"telephonenumber"]);
}

- (NSDictionary *) _parseContactFilter: (id <DOMElement>) filterElement
{
  NSMutableDictionary *filterData;
  id <DOMNode> parentNode;
  id <DOMNodeList> ranges;

  filterData = nil;

  parentNode = [filterElement parentNode];

  if ([[parentNode tagName] isEqualToString: @"filter"]
      && [self _isValidFilter: [filterElement attribute: @"name"]])
    {
      ranges = [filterElement getElementsByTagName: @"text-match"];

      if ([(NSArray *) ranges count]
	  && [(NSArray *) [[ranges objectAtIndex: 0] childNodes] count])
	{
	  filterData = [NSMutableDictionary new];
	  [filterData autorelease];
	  [filterData setObject: [[(NSArray *)[[ranges objectAtIndex: 0] childNodes] lastObject] data]
		      forKey: [filterElement attribute: @"name"]];
	}
    }

  return filterData;
}

- (NSArray *) _parseContactFilters: (id <DOMElement>) parentNode
{
  NSEnumerator *children;
  id <DOMElement> node;
  NSMutableArray *filters;
  NSDictionary *filter;

  filters = [NSMutableArray array];

  children = [[parentNode getElementsByTagName: @"prop-filter"]
	       objectEnumerator];
  while ((node = [children nextObject]))
    {
      filter = [self _parseContactFilter: node];
      if (filter)
        [filters addObject: filter];
    }

  return filters;
}

- (id) davAddressbookQuery: (id) queryContext
{
  WOResponse *r;
  NSArray *filters;
  id <DOMDocument> document;

  r = [queryContext response];
  [r setStatus: 207];
  [r setContentEncoding: NSUTF8StringEncoding];
  [r setHeader: @"text/xml; charset=\"utf-8\"" forKey: @"content-type"];
  [r setHeader: @"no-cache" forKey: @"pragma"];
  [r setHeader: @"no-cache" forKey: @"cache-control"];
  [r appendContentString:@"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [r appendContentString: @"<D:multistatus xmlns:D=\"DAV:\""
     @" xmlns:C=\"urn:ietf:params:xml:ns:carddav\">"];

  document = [[queryContext request] contentAsDOMDocument];
  filters = [self _parseContactFilters: [document documentElement]];

  [self _appendComponentsMatchingFilters: filters
        toResponse: r
	context: queryContext];
  [r appendContentString:@"</D:multistatus>"];

  return r;
}

@end
