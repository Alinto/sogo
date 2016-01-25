/* NSObject+CardDAV.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2015 Inverse inc.
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
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSSet.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <DOM/DOMProtocols.h>
#import <DOM/DOMNode.h>
#import <SaxObjC/SaxObjC.h>
#import <SaxObjC/XMLNamespaces.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/WOResponse+SOGo.h>

#import "SOGoContactFolder.h"
#import "SOGoContactGCSEntry.h"

@implementation SOGoFolder (CardDAV)

- (void) _appendObject: (NSDictionary *) object
           withBaseURL: (NSString *) baseURL
      toREPORTResponse: (WOResponse *) r
{
  id component;
  NSString *name, *etagLine, *contactString;

  name = [object objectForKey: @"c_name"];
  if ([name length])
    {
      component = [self lookupName: name inContext: context acquire: NO];
      if ([component isKindOfClass: [NSException class]])
        {
          [self logWithFormat: @"Object with name '%@' not found. You likely have a LDAP configuration issue.", name];
          return;
        }

#warning we provide both "address-data" and "addressbook-data" for compatibility reasons, we should actually check which one has been queried
      [r appendContentString: @"<D:response>"
                        @"<D:href>"];
      [r appendContentString: baseURL];
      if (![baseURL hasSuffix: @"/"])
        [r appendContentString: @"/"];
      [r appendContentString: name];
      [r appendContentString: @"</D:href>"
                        @"<D:propstat>"
                        @"<D:prop>"];
      etagLine = [NSString stringWithFormat: @"<D:getetag>%@</D:getetag>",
                           [component davEntityTag]];
      [r appendContentString: etagLine];
      [r appendContentString: @"<C:address-data>"];
      contactString = [[component contentAsString] stringByEscapingXMLString];
      [r appendContentString: contactString];
      [r appendContentString: @"</C:address-data>"
                        @"<C:addressbook-data>"];
      [r appendContentString: contactString];
      [r appendContentString: @"</C:addressbook-data>"
         @"</D:prop>"
         @"<D:status>HTTP/1.1 200 OK</D:status>"
         @"</D:propstat>"
         @"</D:response>"];
    }
}

- (void) _appendComponentsMatchingFilters: (NSArray *) filters
                               toResponse: (WOResponse *) response
                                  context: (id) localContext
{
  unsigned int count,i , max;
  NSAutoreleasePool *pool;
  NSDictionary *currentFilter;
  NSMutableSet *contacts;
  NSString *baseURL, *domain;

  contacts = [NSMutableSet set];
  baseURL = [self baseURLInContext: localContext];
  domain = [[localContext activeUser] domain];

  max = [filters count];
  for (count = 0; count < max; count++)
    {
      currentFilter = [filters objectAtIndex: count];
      [contacts addObjectsFromArray:
        [(id<SOGoContactFolder>)self lookupContactsWithFilter: [[currentFilter allValues] lastObject]
                                                    onCriteria: @"name_or_address"
                                                        sortBy: @"c_givenname"
                                                      ordering: NSOrderedDescending
                                                      inDomain: domain]];

    }

  pool = [[NSAutoreleasePool alloc] init];
  i = 0;
  for (NSDictionary *contact in contacts)
    {
      [self _appendObject: contact withBaseURL: baseURL
        toREPORTResponse: response];
      if (i % 10 == 0)
        {
          RELEASE(pool);
          pool = [[NSAutoreleasePool alloc] init];
        }
      i++;
    }
  RELEASE(pool);
}

- (BOOL) _isValidFilter: (NSString *) theString
{
  NSString *newString;

  newString = [theString lowercaseString];

  return ([newString isEqualToString: @"sn"]
          || [newString isEqualToString: @"givenname"]
          || [newString isEqualToString: @"email"]
          || [newString isEqualToString: @"mail"]
          || [newString isEqualToString: @"telephonenumber"]);
}

- (NSDictionary *) _parseContactFilter: (id <DOMElement>) filterElement
{
  NSMutableDictionary *filterData;
  id <DOMNode> parentNode;
  id <DOMNodeList> ranges;

  filterData = nil;

  parentNode = [filterElement parentNode];

  if ([[(id)parentNode tagName] isEqualToString: @"filter"]
      && [self _isValidFilter: [filterElement attribute: @"name"]])
    {
      ranges = [filterElement getElementsByTagName: @"text-match"];

      if ([(NSArray *) ranges count]
          && [(NSArray *) [[ranges objectAtIndex: 0] childNodes] count])
        {
          filterData = [NSMutableDictionary dictionary];
          [filterData setObject: [(NGDOMNode *)[ranges objectAtIndex: 0] textValue]
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

  children = [(NSArray *)[parentNode getElementsByTagName: @"prop-filter"]
               objectEnumerator];
  while ((node = [children nextObject]))
    {
      filter = [self _parseContactFilter: node];
      if (filter)
        [filters addObject: filter];
    }

  // If no filters are provided, we return everything.
  if (![filters count])
  {
      [filters addObject: [NSDictionary dictionaryWithObject: @"." forKey: @"email"]];
      [filters addObject: [NSDictionary dictionaryWithObject: @"%" forKey: @"name"]];
  }

  return filters;
}

- (id) davAddressbookQuery: (id) queryContext
{
  WOResponse *r;
  NSArray *filters;
  id <DOMDocument> document;

  r = [queryContext response];
  [r prepareDAVResponse];
  [r appendContentString: @"<D:multistatus xmlns:D=\"DAV:\""
     @" xmlns:C=\"urn:ietf:params:xml:ns:carddav\">"];

  document = [[queryContext request] contentAsDOMDocument];
  filters = [self _parseContactFilters: [document documentElement]];

  [self _appendComponentsMatchingFilters: filters
        toResponse: r
           context: queryContext];
  [r appendContentString: @"</D:multistatus>"];

  return r;
}

@end
