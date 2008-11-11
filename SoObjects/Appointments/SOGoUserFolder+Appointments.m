/* SOGoUserFolder+Appointments.m - this file is part of SOGo
 *
 * Copyright (C) 2008 Inverse inc.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <SaxObjC/XMLNamespaces.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/NSObject+DAV.h>
#import <SOGo/NSString+DAV.h>

#import "SOGoUserFolder+Appointments.h"

@interface SOGoUserFolder (private)

- (SOGoAppointmentFolders *) privateCalendars: (NSString *) key
				    inContext: (WOContext *) localContext;

@end

@implementation SOGoUserFolder (SOGoCalDAVSupport)

- (NSArray *) davCalendarUserAddressSet
{
  NSArray *tag;
  NSMutableArray *addresses;
  NSEnumerator *emails;
  NSString *currentEmail;
  SOGoUser *ownerUser;

  addresses = [NSMutableArray array];

  ownerUser = [SOGoUser userWithLogin: owner roles: nil];
  emails = [[ownerUser allEmails] objectEnumerator];
  while ((currentEmail = [emails nextObject]))
    {
      tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
		     [NSString stringWithFormat: @"MAILTO:%@", currentEmail],
		     nil];
      [addresses addObject: tag];
    }

  return addresses;
}

/* CalDAV support */
- (NSArray *) davCalendarHomeSet
{
  /*
    <C:calendar-home-set xmlns:D="DAV:"
        xmlns:C="urn:ietf:params:xml:ns:caldav">
      <D:href>http://cal.example.com/home/bernard/calendars/</D:href>
    </C:calendar-home-set>

    Note: this is the *container* for calendar collections, not the
          collections itself. So for use its the home folder, the
	  public folder and the groups folder.
  */
  NSArray *tag;
  SOGoAppointmentFolders *parent;

  parent = [self privateCalendars: @"Calendar" inContext: context];
  tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
                 [[parent davURL] path], nil];

  return [NSArray arrayWithObject: tag];
}

- (NSArray *) davCalendarScheduleInboxURL
{
  NSArray *tag;
  SOGoAppointmentFolders *parent;

  parent = [self privateCalendars: @"Calendar" inContext: context];
  tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
                 [NSString stringWithFormat: @"%@personal/", [[parent davURL] path]],
		 nil];

  return [NSArray arrayWithObject: tag];
}

- (NSString *) davCalendarScheduleOutboxURL
{
  NSArray *tag;
  SOGoAppointmentFolders *parent;

  parent = [self privateCalendars: @"Calendar" inContext: context];
  tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
                 [NSString stringWithFormat: @"%@personal/", [[parent davURL] path]],
		 nil];

  return [NSArray arrayWithObject: tag];
}

- (NSString *) davDropboxHomeURL
{
  NSArray *tag;
  SOGoAppointmentFolders *parent;

  parent = [self privateCalendars: @"Calendar" inContext: context];
  tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
                 [NSString stringWithFormat: @"%@personal/", [[parent davURL] path]],
		 nil];

  return [NSArray arrayWithObject: tag];
}

- (NSString *) davNotificationsURL
{
  NSArray *tag;
  SOGoAppointmentFolders *parent;

  parent = [self privateCalendars: @"Calendar" inContext: context];
  tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
                 [NSString stringWithFormat: @"%@personal/", [[parent davURL] path]],
		 nil];

  return [NSArray arrayWithObject: tag];
}

- (WOResponse *) _prepareResponseFromContext: (WOContext *) queryContext
{
  WOResponse *r;

  r = [queryContext response];
  [r setStatus: 207];
  [r setContentEncoding: NSUTF8StringEncoding];
  [r setHeader: @"text/xml; charset=\"utf-8\"" forKey: @"content-type"];
  [r setHeader: @"no-cache" forKey: @"pragma"];
  [r setHeader: @"no-cache" forKey: @"cache-control"];
  [r appendContentString:@"<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n"];

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
{
  SOGoUserFolder *collection;
  NSRange substringRange;

  substringRange = [value rangeOfString: @"/SOGo/dav/"];
  value = [value substringFromIndex: NSMaxRange (substringRange)];
  substringRange = [value rangeOfString: @"/Calendar"];
  value = [value substringToIndex: substringRange.location];
  collection = [[SOGoUser userWithLogin: value roles: nil]
		 homeFolderInContext: context];
  if (collection)
    [collections addObject: collection];
}

- (NSMutableArray *) _firstPrincipalCollectionsWhere: (NSString *) key
					     matches: (NSString *) value
{
  NSMutableArray *collections;

  collections = [NSMutableArray array];
  if ([key
	isEqualToString: @"{urn:ietf:params:xml:ns:caldav}calendar-home-set"])
    [self _fillCollections: collections withCalendarHomeSetMatching: value];
  else
    [self errorWithFormat: @"principal-property-search: unhandled key '%@'",
	  key];

  return collections;
}

#warning unused stub
- (BOOL) collectionDavKey: (NSString *) key
		  matches: (NSString *) value
{
  return YES;
}

- (void) _principalCollections: (NSMutableArray **) baseCollections
			 where: (NSString *) key
		       matches: (NSString *) value
{
  SOGoUserFolder *currentCollection;
  unsigned int count, max;

  if (!*baseCollections)
    *baseCollections = [self _firstPrincipalCollectionsWhere: key
			     matches: value];
  else
    {
      max = [*baseCollections count];
      for (count = max; count > 0; count--)
	{
	  currentCollection = [*baseCollections objectAtIndex: count - 1];
	  if (![currentCollection collectionDavKey: key matches: value])
	    [*baseCollections removeObjectAtIndex: count - 1];
	}
    }
}

- (NSArray *) _principalCollectionsMatching: (NSDictionary *) matches
{
  NSMutableArray *collections;
  NSEnumerator *allKeys;
  NSString *currentKey;

  collections = nil;

  allKeys = [[matches allKeys] objectEnumerator];
  while ((currentKey = [allKeys nextObject]))
    [self _principalCollections: &collections
	  where: currentKey
	  matches: [matches objectForKey: currentKey]];

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
  NSMutableArray *response, *props;
  NSDictionary *keyTuple;

  response = [NSMutableArray new];
  [response addObject: davElementWithContent (@"href", XMLNS_WEBDAV,
					      [collection davURL])];
  props = [NSMutableArray new];
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
  [response addObject: davElementWithContent (@"propstat", XMLNS_WEBDAV,
					      davElementWithContent
					      (@"prop", XMLNS_WEBDAV,
					       props))];
  [responses addObject: davElementWithContent (@"response", XMLNS_WEBDAV,
					       response)];
  [props release];
  [response release];
}

- (void) _appendProperties: (NSArray *) properties
	     ofCollections: (NSArray *) collections
		toResponse: (WOResponse *) response
{
  NSDictionary *mStatus;
  NSMutableArray *responses;
  unsigned int count, max;

  responses = [NSMutableArray new];

  max = [collections count];
  for (count = 0; count < max; count++)
    [self _appendProperties: properties
	  ofCollection: [collections objectAtIndex: count]
	  toResponses: responses];
  mStatus = davElementWithContent (@"multistatus", XMLNS_WEBDAV, responses);
  [response appendContentString: [mStatus asWebDavStringWithNamespaces: nil]];
  [responses release];
}

- (WOResponse *) davPrincipalPropertySearch: (WOContext *) queryContext
{
  NSObject <DOMDocument> *document;
  NSObject <DOMElement> *documentElement;
  NSArray *collections;
  NSMutableDictionary *matches;
  NSMutableArray *properties;
  WOResponse *r;

  document = [[context request] contentAsDOMDocument];
  documentElement = [document documentElement];

  matches = [NSMutableDictionary new];
  properties = [NSMutableArray new];
  [self _fillPrincipalMatches: matches andProperties: properties
	fromElement: documentElement];
  collections = [self _principalCollectionsMatching: matches];
  r = [self _prepareResponseFromContext: queryContext];
  [self _appendProperties: properties ofCollections: collections
	toResponse: r];
  [properties release];
  [matches release];

  return r;
//        @"<D:response><D:href>/SOGo/dav/wsourdeau/</D:href>"
//      @"<D:propstat>"
//      @"<D:status>HTTP/1.1 200 OK</D:status>"
//      @"<D:prop>"
//      @"<C:calendar-home-set><D:href>/SOGo/dav/wsourdeau/Calendar/</D:href></C:calendar-home-set>"
//      @"<C:calendar-user-address-set><D:href>MAILTO:wsourdeau@inverse.ca</D:href></C:calendar-user-address-set>"
//      @"<C:schedule-inbox-URL><D:href>/SOGo/dav/wsourdeau/Calendar/personal/</D:href></C:schedule-inbox-URL>"
//      @"<C:schedule-outbox-URL><D:href>/SOGo/dav/wsourdeau/Calendar/personal/</D:href></C:schedule-outbox-URL>"
//      @"</D:prop>"
//      @"</D:propstat></D:response>"];

//   <D:property-search>
//     <D:prop>
//       <C:calendar-home-set/>
//     </D:prop>
//     <D:match>/SOGo/dav/wsourdeau/Calendar</D:match>
//   </D:property-search>
//   <D:prop>
//     <C:calendar-home-set/>
//     <C:calendar-user-address-set/>
//     <C:schedule-inbox-URL/>
//     <C:schedule-outbox-URL/>
//   </D:prop>
}

@end
