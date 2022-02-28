/* NSObject+CardDAV.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2022 Inverse inc.
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

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <DOM/DOMNode.h>
#import <EOControl/EOQualifier.h>
#import <EOControl/EOSortOrdering.h>
#import <SaxObjC/SaxObjC.h>

#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/WOResponse+SOGo.h>
#import <SOGo/DOMNode+SOGo.h>

#import "SOGoContactFolder.h"
#import "SOGoContactGCSEntry.h"

@implementation SOGoFolder (CardDAV)

- (void) _appendProperties: (NSArray *) properties
                 forObject: (NSDictionary *) object
               withBaseURL: (NSString *) baseURL
          toREPORTResponse: (WOResponse *) r
{
  id component;
  NSString *name, *etagLine, *contactString;

  name = [object objectForKey: @"c_name"];
  if ([name length])
    {
      contactString = nil;
      component = [self lookupName: name inContext: context acquire: NO];
      if ([component isKindOfClass: [NSException class]])
        {
          [self logWithFormat: @"Object with name '%@' not found.", name];
          return;
        }

      [r appendContentString: @"<D:response>"
                        @"<D:href>"];
      [r appendContentString: baseURL];
      if (![baseURL hasSuffix: @"/"])
        [r appendContentString: @"/"];
      [r appendContentString: name];
      [r appendContentString: @"</D:href>"
                        @"<D:propstat>"
                        @"<D:prop>"];


      if ([properties containsObject: @"{DAV:}getetag"])
        {
          etagLine = [NSString stringWithFormat: @"<D:getetag>%@</D:getetag>",
                               [component davEntityTag]];
          [r appendContentString: etagLine];
        }

      if ([properties containsObject: @"{urn:ietf:params:xml:ns:carddav}address-data"])
        {
          [r appendContentString: @"<C:address-data>"];
          contactString = [[component contentAsString] safeStringByEscapingXMLString];
          [r appendContentString: contactString];
          [r appendContentString: @"</C:address-data>"];
        }

      if ([properties containsObject: @"{urn:ietf:params:xml:ns:carddav}addressbook-data"])
        {
          [r appendContentString: @"<C:addressbook-data>"];
          if (!contactString)
            contactString = [[component contentAsString] safeStringByEscapingXMLString];
          [r appendContentString: contactString];
          [r appendContentString: @"</C:addressbook-data>"];
        }

      [r appendContentString:  @"</D:prop>"
                        @"<D:status>HTTP/1.1 200 OK</D:status>"
                       @"</D:propstat>"
                       @"</D:response>"];
    }
}

- (void) _appendComponentsProperties: (NSArray *) properties
                   matchingQualifier: (EOQualifier *) qualifier
                          toResponse: (WOResponse *) response
                             context: (id) localContext
{
  EOSortOrdering *sort;
  NSAutoreleasePool *pool;
  NSDictionary *contact;
  NSMutableArray *names;
  NSEnumerator *contacts;
  NSString *baseURL, *domain, *name;
  unsigned int i;

  baseURL = [self baseURLInContext: localContext];
  domain = [[localContext activeUser] domain];
  sort = [EOSortOrdering sortOrderingWithKey: @"c_cn"
                                    selector: EOCompareCaseInsensitiveAscending];
  names = [NSMutableArray array];

  contacts = [[(id<SOGoContactFolder>)self lookupContactsWithQualifier: qualifier
                                                       andSortOrdering: sort
                                                              inDomain: domain] objectEnumerator];

  i = 0;
  pool = [[NSAutoreleasePool alloc] init];
  while ((contact = [contacts nextObject]))
    {
      // Don't append suspected duplicates
      name = [contact objectForKey: @"c_name"]; // primary key of contacts
      if (![names containsObject: name])
        {
          [self _appendProperties: properties
                        forObject: contact
                      withBaseURL: baseURL
                 toREPORTResponse: response];
          [names addObject: name];
          if (i % 10 == 0)
            {
              RELEASE(pool);
              pool = [[NSAutoreleasePool alloc] init];
            }
          i++;
        }
    }
  RELEASE(pool);
}

/**
   Validate the prop-filter name of the addressbook-query. Must match the supported vCard
   properties of all SOGoContactFolder classes.
   @see [SOGoContactFolder addVCardProperty:toCriteria:]
   @see [SOGoContactGCSFolder addVCardProperty:toCriteria:]
   @see [LDAPSource addVCardProperty:toCriteria:]
   @see [SQLSource addVCardProperty:toCriteria:]
 */
- (BOOL) _isValidFilter: (NSString *) theString
{
  NSString *newString;
  BOOL isValid;

  newString = [theString lowercaseString];

  isValid = ([newString isEqualToString: @"fn"]
             || [newString isEqualToString: @"n"]
             || [newString isEqualToString: @"email"]
             || [newString isEqualToString: @"tel"]
             || [newString isEqualToString: @"org"]
             || [newString isEqualToString: @"adr"]);

  if (!isValid)
    [self warnWithFormat: @"Unsupported prop-filter name '%@'", theString];

  return isValid;
}

- (EOQualifier *) _parseContactFilter: (id <DOMElement>) filterElement // a prop-filter element
{
  NSMutableArray *qualifiers;
  NSMutableArray *criteria;
  NSString *name, *test;
  NGDOMElement *match;
  EOQualifier *qualifier;
  id <DOMNode> parentNode;
  id <DOMNodeList> ranges;
  unsigned int i;

  qualifier = nil;

  parentNode = [filterElement parentNode];
  name = [[filterElement attribute: @"name"] lowercaseString];

  if ([[(id)parentNode tagName] isEqualToString: @"filter"]
      && [self _isValidFilter: name])
    {
      qualifiers = [NSMutableArray array];
      criteria = [NSMutableArray array];
      test = [[filterElement attribute: @"test"] lowercaseString];
      ranges = [filterElement getElementsByTagName: @"text-match"];

      [(id<SOGoContactFolder>)self addVCardProperty: name
                                         toCriteria: criteria];

      for (i = 0; i < [ranges length]; i++)
        {
          match = (NGDOMElement *)[ranges objectAtIndex: i];
          if ([(NSArray *)[match childNodes] count])
            {
              SEL currentOperator;
              EOQualifier *currentQualifier;
              NSString *currentMatchType, *currentMatch;

              currentMatch = [match textValue];
              currentMatchType = [[match attribute: @"match-type"] lowercaseString];
              if ([currentMatchType isEqualToString: @"equals"])
                currentOperator = EOQualifierOperatorEqual;
              else // contains, starts-with, ends-with
                {
                  currentOperator = EOQualifierOperatorCaseInsensitiveLike;
                  currentMatch = [NSString stringWithFormat: @"*%@*", currentMatch];
                }

              currentQualifier = [[EOKeyValueQualifier alloc] initWithKey: [criteria objectAtIndex: 0]
                                                         operatorSelector: currentOperator
                                                                    value: currentMatch];
              [currentQualifier autorelease];
              [qualifiers addObject: currentQualifier];
            }
        }

      if ([qualifiers count] > 1)
        {
          if ([test isEqualToString: @"allof"])
            qualifier = [[EOAndQualifier alloc] initWithQualifierArray: qualifiers];
          else // anyof
            qualifier = [[EOOrQualifier alloc] initWithQualifierArray: qualifiers];
          [qualifier autorelease];
        }
      else if ([qualifiers count])
        qualifier = [qualifiers objectAtIndex: 0];
    }

  return qualifier;
}

- (EOQualifier *) _parseContactFilters: (id <DOMElement>) parentNode
{
  EOQualifier *qualifier, *currentQualifier;
  NSEnumerator *children;
  id <DOMElement> filterElement, node;
  NSMutableArray *qualifiers;
  NSString *test;

  qualifier = nil;
  filterElement = [(NGDOMNodeWithChildren *) parentNode firstElementWithTag: @"filter"
                                                                inNamespace: @"urn:ietf:params:xml:ns:carddav"];

  if (filterElement)
    {
      qualifiers = [NSMutableArray array];
      test = [[filterElement attribute: @"test"] lowercaseString];
      children = [(NSArray *)[parentNode getElementsByTagName: @"prop-filter"] objectEnumerator];
      while ((node = [children nextObject]))
        {
          currentQualifier = [self _parseContactFilter: node];
          if (currentQualifier)
            [qualifiers addObject: currentQualifier];
        }

      if ([qualifiers count] > 1)
        {
          if ([test isEqualToString: @"allof"])
            qualifier = [[EOAndQualifier alloc] initWithQualifierArray: qualifiers];
          else
            qualifier = [[EOOrQualifier alloc] initWithQualifierArray: qualifiers];
          [qualifier autorelease];
        }
      else if ([qualifiers count])
        qualifier = [qualifiers objectAtIndex: 0];
    }

  return qualifier;
}

/**
   CARDDAV:addressbook-query Report
   https://datatracker.ietf.org/doc/html/rfc6352#section-8.6

   <?xml version="1.0" encoding="UTF-8"?>
     <C:addressbook-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav">
       <D:prop>
         <D:getetag/>
         <C:address-data/>
       </D:prop>
       <C:filter test="anyof">
         <C:prop-filter name="EMAIL" test="allof">
           <C:text-match collation="i;unicode-casemap" match-type="starts-with">foo</C:text-match>
         </C:prop-filter>
       </C:filter>
     </C:addressbook-query>
 */
- (id) davAddressbookQuery: (id) queryContext
{
  EOQualifier *qualifier;
  WOResponse *r;
  NSArray *properties;
  id <DOMDocument> document;
  id <DOMElement> documentElement, propElement;

  r = [queryContext response];
  [r prepareDAVResponse];
  [r appendContentString: @"<D:multistatus xmlns:D=\"DAV:\""
     @" xmlns:C=\"urn:ietf:params:xml:ns:carddav\">"];

  document = [[queryContext request] contentAsDOMDocument];
  documentElement = [document documentElement];
  propElement = [(NGDOMNodeWithChildren *) documentElement firstElementWithTag: @"prop"
                                                                   inNamespace: @"DAV:"];
  properties = [(NGDOMNodeWithChildren *) propElement flatPropertyNameOfSubElements];
  qualifier = [self _parseContactFilters: documentElement];

  [self _appendComponentsProperties: properties
                  matchingQualifier: qualifier
                         toResponse: r
                            context: queryContext];
  [r appendContentString: @"</D:multistatus>"];

  return r;
}

@end
