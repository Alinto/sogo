/* SOGo+DAV.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGExtensions/NSObject+Logs.h>

#import <DOM/DOMDocument.h>
#import <DOM/DOMNode.h>
#import <DOM/DOMProtocols.h>
#import <SaxObjC/XMLNamespaces.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSObject+DAV.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/NSString+DAV.h>
#import <SOGo/WORequest+SOGo.h>
#import <SOGo/WOResponse+SOGo.h>
#import <SOGo/SOGoSource.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserFolder.h>

#import "SOGo+DAV.h"

@implementation SOGo (SOGoWebDAVExtensions)

- (NSArray *) davPrincipalURL
{
  NSArray *principalURL;
  NSString *classes;
  WOContext *context;

  context = [self context];
  if ([[context request] isICal4])
    {
      classes = [[self davComplianceClassesInContext: context]
                  componentsJoinedByString: @", "];
      [[context response] setHeader: classes forKey: @"DAV"];
    }

  principalURL = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
                          [self davURLAsString], nil];

  return [NSArray arrayWithObject: principalURL];
}

- (WOResponse *) davPrincipalSearchPropertySet: (WOContext *) localContext
{
  static NSDictionary *davResponse = nil;
  NSMutableArray *propertySet;
  NSDictionary *property, *prop, *description;
  NSArray *currentValue, *properties, *descriptions, *namespaces;
  int count, max;
  WOResponse *r;

  if (!davResponse)
    {
      properties = [NSArray arrayWithObjects:
                              @"calendar-user-type",
                            @"calendar-user-address-set",
                            @"calendar-user-type",
                            @"displayname",
                            @"first-name",
                            @"last-name",
                            @"email-address-set",
                            nil];
      descriptions
        = [properties resultsOfSelector: @selector (asDAVPropertyDescription)];
      namespaces = [NSArray arrayWithObjects:
                              XMLNS_CALDAV,
                            XMLNS_CALDAV,
                            XMLNS_CALDAV,
                            XMLNS_WEBDAV,
                            XMLNS_CalendarServerOrg,
                            XMLNS_CalendarServerOrg,
                            XMLNS_CalendarServerOrg,
                            nil];

      max = [properties count];
      propertySet = [NSMutableArray arrayWithCapacity: max];
      for (count = 0; count < max; count++)
        {
          property = davElement([properties objectAtIndex: count],
                                [namespaces objectAtIndex: count]);
          prop = davElementWithContent(@"prop", @"DAV:",
                                       property);
          description
            = davElementWithContent(@"description", @"DAV:",
                                    [descriptions objectAtIndex: count]);
          currentValue = [NSArray arrayWithObjects: prop, description, nil];
          [propertySet
            addObject: davElementWithContent(@"principal-search-property",
                                             @"DAV:",
                                             currentValue)];
        }
      davResponse = davElementWithContent (@"principal-search-property-set",
                                           @"DAV:",
                                           propertySet);
      [davResponse retain];
    }

  r = [localContext response];
  [r prepareDAVResponse];
  [r appendContentString: [davResponse asWebDavStringWithNamespaces: nil]];

  return r;
}

#warning all REPORT method should be standardized...
- (NSDictionary *) _formalizePrincipalMatchResponse: (NSArray *) hrefs
{
  NSDictionary *multiStatus;
  NSEnumerator *hrefList;
  NSString *currentHref;
  NSMutableArray *responses;
  NSArray *responseElements;

  responses = [NSMutableArray array];

  hrefList = [hrefs objectEnumerator];
  while ((currentHref = [hrefList nextObject]))
    {
      responseElements
	= [NSArray arrayWithObjects: davElementWithContent (@"href",
                                                            XMLNS_WEBDAV,
							    currentHref),
		   davElementWithContent (@"status", XMLNS_WEBDAV,
					  @"HTTP/1.1 200 OK"),
		   nil];
      [responses addObject: davElementWithContent (@"response", XMLNS_WEBDAV,
						   responseElements)];
    }

  multiStatus = davElementWithContent (@"multistatus", XMLNS_WEBDAV,
                                       responses);

  return multiStatus;
}

- (NSDictionary *) _handlePrincipalMatchSelfInContext: (WOContext *) localContext
{
  NSString *davURL, *userLogin;
  NSArray *principalURL;

  davURL = [self davURLAsString];
  userLogin = [[localContext activeUser] login];
  principalURL
    = [NSArray arrayWithObject: [NSString stringWithFormat: @"%@%@/", davURL,
					  userLogin]];
  return [self _formalizePrincipalMatchResponse: principalURL];
}

- (void) _fillArrayWithPrincipalsOwnedBySelf: (NSMutableArray *) hrefs
                                   inContext: (WOContext *) localContext
{
  NSArray *roles;

  roles = [[localContext activeUser] rolesForObject: self
                                          inContext: localContext];
  if ([roles containsObject: SoRole_Owner])
    [hrefs addObject: [self davURLAsString]];
}

- (NSDictionary *)
   _handlePrincipalMatchPrincipalProperty: (id <DOMElement>) child
                                inContext: (WOContext *) localContext
{
  NSMutableArray *hrefs;
  NSDictionary *response;

  hrefs = [NSMutableArray array];
  [self _fillArrayWithPrincipalsOwnedBySelf: hrefs
                                  inContext: localContext];

  response = [self _formalizePrincipalMatchResponse: hrefs];

  return response;
}

- (NSDictionary *) _handlePrincipalMatchReport: (id <DOMDocument>) document
                                     inContext: (WOContext *) localContext
{
  NSDictionary *response;
  id <DOMElement> documentElement, queryChild;
  NSArray *children;
  NSString *queryTag, *error;

  documentElement = [document documentElement];
  children = [self          domNode: documentElement
                getChildNodesByType: DOM_ELEMENT_NODE];
  if ([children count] == 1)
    {
      queryChild = [children objectAtIndex: 0];
      queryTag = [queryChild tagName];
      if ([queryTag isEqualToString: @"self"])
	response = [self _handlePrincipalMatchSelfInContext: localContext];
      else if ([queryTag isEqualToString: @"principal-property"])
	response = [self _handlePrincipalMatchPrincipalProperty: queryChild
                                                      inContext: localContext];
      else
        {
          error = (@"Query element must be either '{DAV:}principal-property'"
                   @"  or '{DAV:}self'");
          response = [NSException exceptionWithHTTPStatus: 400
                                                   reason: error];
        }
    }
  else
    {
      error = (@"Query must have one element: '{DAV:}principal-property'"
               @" or '{DAV:}self'");
      response = [NSException exceptionWithHTTPStatus: 400
                                               reason: error];
    }

  return response;
}

- (WOResponse *) davPrincipalMatch: (WOContext *) localContext
{
  WOResponse *r;
  id <DOMDocument> document;
  NSDictionary *xmlResponse;

  r = [localContext response];

  document = [[localContext request] contentAsDOMDocument];
  xmlResponse = [self _handlePrincipalMatchReport: document
                                        inContext: localContext];
  if ([xmlResponse isKindOfClass: [NSException class]])
    r = (WOResponse *) xmlResponse;
  else
    {
      [r prepareDAVResponse];
      [r appendContentString: [xmlResponse asWebDavStringWithNamespaces: nil]];
    }

  return r;
}

- (void) _fillMatches: (NSMutableDictionary *) matches
	  fromElement: (NSObject <DOMElement> *) searchElement
{
  NSObject <DOMNodeList> *list;
  NSObject <DOMNode> *valueNode;
  NSArray *elements;
  NSString *property, *match;

  list = [searchElement getElementsByTagName: @"prop"];
  if ([list length])
    {
      elements = [self domNode: [list objectAtIndex: 0]
		       getChildNodesByType: DOM_ELEMENT_NODE];
      if ([elements count])
	{
	  valueNode = [elements objectAtIndex: 0];
	  property = [NSString stringWithFormat: @"{%@}%@",
			       [valueNode namespaceURI],
			       [valueNode nodeName]];
	}
    }
  list = [searchElement getElementsByTagName: @"match"];
  if ([list length])
    {
      valueNode = [[list objectAtIndex: 0] firstChild];
      match = [valueNode nodeValue];
    }

  [matches setObject: match forKey: property];
}

- (void) _fillProperties: (NSMutableArray *) properties
	     fromElement: (NSObject <DOMElement> *) propElement
{
  NSEnumerator *elements;
  NSObject <DOMElement> *propNode;
  NSString *property;

  elements = [[self domNode: propElement
		    getChildNodesByType: DOM_ELEMENT_NODE]
	       objectEnumerator];
  while ((propNode = [elements nextObject]))
    {
      property = [NSString stringWithFormat: @"{%@}%@",
			   [propNode namespaceURI],
			   [propNode nodeName]];
      [properties addObject: property];
    }
}

- (void) _fillPrincipalMatches: (NSMutableDictionary *) matches
		 andProperties: (NSMutableArray *) properties
		   fromElement: (NSObject <DOMElement> *) documentElement
{
  NSEnumerator *children;
  NSObject <DOMElement> *currentElement;
  NSString *tag;

  children = [[self domNode: documentElement
		    getChildNodesByType: DOM_ELEMENT_NODE]
	       objectEnumerator];
  while ((currentElement = [children nextObject]))
    {
      tag = [currentElement tagName];
      if ([tag isEqualToString: @"property-search"])
	[self _fillMatches: matches fromElement: currentElement];
      else if  ([tag isEqualToString: @"prop"])
	[self _fillProperties: properties fromElement: currentElement];
      else
	[self errorWithFormat: @"principal-property-search: unknown tag '%@'",
	      tag];
    }
}

#warning this is a bit ugly, as usual
- (void)       _fillCollections: (NSMutableArray *) collections
    withCalendarHomeSetMatching: (NSString *) value
                      inContext: (WOContext *) localContext
{
  SOGoUserFolder *collection;
  NSRange substringRange;

  substringRange = [value rangeOfString: @"/SOGo/dav/"];

  if (substringRange.location == NSNotFound)
    return;

  value = [value substringFromIndex: NSMaxRange (substringRange)];
  substringRange = [value rangeOfString: @"/Calendar"];

  if (substringRange.location == NSNotFound)
    return;

  value = [value substringToIndex: substringRange.location];
  collection = [[SOGoUser userWithLogin: value]
		 homeFolderInContext: localContext];
  if (collection)
    [collections addObject: collection];
}

- (void)       _fillCollections: (NSMutableArray *) collections
    withEmailAddressSetMatching: (NSString *) value
                      inContext: (WOContext *) localContext
{
  id <SOGoSource> authenticationSource;
  SOGoUser *activeUser;
  NSArray *records;
  NSUInteger count, max;
  NSString *uid;
  SOGoUserFolder *collection;

  activeUser = [localContext activeUser];
  if ([activeUser respondsToSelector: @selector (authenticationSource)])
    {
      authenticationSource = [[localContext activeUser] authenticationSource];
      records = [authenticationSource
                  fetchContactsMatching: value
                               inDomain: [activeUser domain]];
      max = [records count];
      for (count = 0; count < max; count++)
        {
          uid = [[records objectAtIndex: count] objectForKey: @"c_uid"];
          if ([uid length] > 0)
            {
              collection = [[SOGoUser userWithLogin: uid]
                             homeFolderInContext: localContext];
              [collections addObject: collection];
            }
        }
    }
}

- (void) _fillCollections: (NSMutableArray *) collections
                    where: (NSString *) key
                  matches: (NSString *) value
                inContext: (WOContext *) localContext
{
  if ([key
	isEqualToString: @"{urn:ietf:params:xml:ns:caldav}calendar-home-set"])
    [self _fillCollections: collections withCalendarHomeSetMatching: value
                 inContext: localContext];
  else if ([key isEqualToString: @"{http://calendarserver.org/ns/}email-address-set"])
    [self _fillCollections: collections withEmailAddressSetMatching: value
                 inContext: localContext];
  else
    [self warnWithFormat: @"principal-property-search: unhandled key '%@'",
	  key];
}

- (NSArray *) _principalCollectionsMatching: (NSDictionary *) matches
                                  inContext: (WOContext *) localContext
{
  NSMutableArray *collections;
  NSEnumerator *allKeys;
  NSString *currentKey;

  collections = [NSMutableArray array];

  allKeys = [[matches allKeys] objectEnumerator];
  while ((currentKey = [allKeys nextObject]))
    [self _fillCollections: collections
                     where: currentKey
                   matches: [matches objectForKey: currentKey]
                 inContext: localContext];

  return collections;
}

/*   <D:principal-property-search xmlns:D="DAV:">
     <D:property-search>
       <D:prop>
         <D:displayname/>
       </D:prop>
       <D:match>doE</D:match>
     </D:property-search>
     <D:property-search>
       <D:prop xmlns:B="http://www.example.com/ns/">
         <B:title/>
       </D:prop>
       <D:match>Sales</D:match>
     </D:property-search>
     <D:prop xmlns:B="http://www.example.com/ns/">
       <D:displayname/>
       <B:department/>
       <B:phone/>
       <B:office/>
       <B:salary/>
     </D:prop>
     </D:principal-property-search> */

- (void) _appendProperties: (NSArray *) properties
	      ofCollection: (SOGoUserFolder *) collection
	       toResponses: (NSMutableArray *) responses
{
  unsigned int count, max;
  SEL methodSel;
  NSString *currentProperty;
  id currentValue;
  NSMutableArray *response, *props, *propstat;
  NSDictionary *keyTuple;

  response = [NSMutableArray array];
  [response addObject: davElementWithContent (@"href", XMLNS_WEBDAV,
					      [collection davURLAsString])];
  props = [NSMutableArray array];

  max = [properties count];
  for (count = 0; count < max; count++)
    {
      currentProperty = [properties objectAtIndex: count];
      methodSel = SOGoSelectorForPropertyGetter (currentProperty);
      if (methodSel && [collection respondsToSelector: methodSel])
	{
	  currentValue = [collection performSelector: methodSel];
	  #warning evil eVIL EVIl!
	  if ([currentValue isKindOfClass: [NSArray class]])
	    {
	      currentValue = [currentValue objectAtIndex: 0];
	      currentValue
		= davElementWithContent ([currentValue objectAtIndex: 0],
					 [currentValue objectAtIndex: 1],
					 [currentValue objectAtIndex: 3]);
	    }
	  keyTuple = [currentProperty asWebDAVTuple];
	  [props addObject: davElementWithContent ([keyTuple objectForKey: @"method"],
						   [keyTuple objectForKey: @"ns"],
						   currentValue)];
	}
    }

  propstat = [NSMutableArray array];
  [propstat addObject: davElementWithContent (@"status", XMLNS_WEBDAV,
                                              @"HTTP/1.1 200 OK")];
  [propstat addObject: davElementWithContent (@"prop", XMLNS_WEBDAV,
                                              props)];
  [response addObject: davElementWithContent (@"propstat", XMLNS_WEBDAV, propstat)];
  [responses addObject: davElementWithContent (@"response", XMLNS_WEBDAV,
					       response)];
}

- (void) _appendProperties: (NSArray *) properties
	     ofCollections: (NSArray *) collections
		toResponse: (WOResponse *) response
{
  NSDictionary *mStatus;
  NSMutableArray *responses;
  unsigned int count, max;

  max = [collections count];
  responses = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    [self _appendProperties: properties
               ofCollection: [collections objectAtIndex: count]
                toResponses: responses];
  mStatus = davElementWithContent (@"multistatus", XMLNS_WEBDAV, responses);
  [response appendContentString: [mStatus asWebDavStringWithNamespaces: nil]];
}

/* rfc3744, should be moved into SOGoUserFolder */
- (WOResponse *) davPrincipalPropertySearch: (WOContext *) localContext
{
  NSObject <DOMDocument> *document;
  NSObject <DOMElement> *documentElement;
  NSArray *collections;
  NSMutableDictionary *matches;
  NSMutableArray *properties;
  WOResponse *r;

  document = [[localContext request] contentAsDOMDocument];
  documentElement = [document documentElement];

  matches = [NSMutableDictionary dictionary];
  properties = [NSMutableArray array];
  [self _fillPrincipalMatches: matches andProperties: properties
                  fromElement: documentElement];
  collections = [self _principalCollectionsMatching: matches
                                          inContext: localContext];
  r = [localContext response];
  [r prepareDAVResponse];
  [self _appendProperties: properties ofCollections: collections
               toResponse: r];

  return r;
}

- (SOGoWebDAVValue *) davCurrentUserPrincipal
{
  NSDictionary *userHREF;
  NSString *usersUrl, *login;
  SOGoUser *activeUser;
  SOGoWebDAVValue *davCurrentUserPrincipal;

  activeUser = [[self context] activeUser];
  login = [activeUser login];
  if ([login isEqualToString: @"anonymous"])
    davCurrentUserPrincipal = nil;
  else
    {
      usersUrl = [NSString stringWithFormat: @"%@%@/",
                           [self davURLAsString], login];
      userHREF = davElementWithContent (@"href", XMLNS_WEBDAV, usersUrl);
      davCurrentUserPrincipal
        = [davElementWithContent (@"current-user-principal",
                                  XMLNS_WEBDAV,
                                  userHREF)
                                 asWebDAVValue];
    }

  return davCurrentUserPrincipal;
}

- (NSArray *) davComplianceClassesInContext: (WOContext *) localContext
{
  static NSMutableArray *newClasses = nil;
  NSArray *selfClasses;

  if (!newClasses)
    {
      newClasses
        = [[super davComplianceClassesInContext: localContext] mutableCopy];
      selfClasses = [NSArray arrayWithObjects: @"access-control",
                             @"addressbook", @"calendar-access",
                             @"calendar-schedule", @"calendar-auto-schedule",
                             @"calendar-proxy",

                             @"calendar-query-extended",
                             @"extended-mkcol",
                             @"calendarserver-principal-property-search",
                             nil];
      [newClasses addObjectsFromArray: selfClasses];
    }

  return newClasses;
}

- (SOGoWebDAVValue *) davPrincipalCollectionSet
{
  NSString *davURL;
  NSDictionary *collectionHREF;
  NSString *classes;
  WOContext *context;

  context = [self context];
  if ([[context request] isICal4])
    {
      classes = [[self davComplianceClassesInContext: context]
                  componentsJoinedByString: @", "];
      [[context response] setHeader: classes forKey: @"dav"];
    }

  /* WOApplication has no support for the DAV methods we define here so we
     use the user's principal object as a reference */
  davURL = [self davURLAsString];
  collectionHREF = davElementWithContent (@"href", XMLNS_WEBDAV, davURL);

  return [davElementWithContent (@"principal-collection-set",
				 XMLNS_WEBDAV,
				 [NSArray arrayWithObject: collectionHREF])
				asWebDAVValue];
}

@end
