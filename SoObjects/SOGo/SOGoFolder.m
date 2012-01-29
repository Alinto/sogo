/* SOGoFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2011 Inverse inc.
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
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/SoWebDAVValue.h>

#import <NGExtensions/NSObject+Logs.h>

#import <DOM/DOMElement.h>

#import <SaxObjC/XMLNamespaces.h>

#import <SOGoUI/SOGoFolderAdvisory.h>

#import "DOMNode+SOGo.h"
#import "NSArray+Utilities.h"
#import "NSObject+DAV.h"
#import "NSString+DAV.h"
#import "NSString+Utilities.h"
#import "SOGoPermissions.h"
#import "SOGoUser.h"
#import "SOGoDomainDefaults.h"
#import "SOGoWebDAVAclManager.h"
#import "WORequest+SOGo.h"
#import "WOResponse+SOGo.h"

#import "SOGoFolder.h"

@interface SOGoObject (SOGoDAVHelpers)

- (void) _fillArrayWithPrincipalsOwnedBySelf: (NSMutableArray *) hrefs;

@end

@interface SOGoFolder (private)

- (NSArray *) _interpretWebDAVArrayValue: (id) value;
- (NSDictionary *) _expandPropertyResponse: (NGDOMElement *) property
                                   forHREF: (NSString *) href;

@end

@implementation SOGoFolder

+ (SOGoWebDAVAclManager *) webdavAclManager
{
  static SOGoWebDAVAclManager *aclManager = nil;

  if (!aclManager)
    {
      aclManager = [SOGoWebDAVAclManager new];
      [aclManager registerDAVPermission: davElement (@"read", XMLNS_WEBDAV)
			abstract: YES
			withEquivalent: SoPerm_WebDAVAccess
			asChildOf: davElement (@"all", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"read-current-user-privilege-set", XMLNS_WEBDAV)
			abstract: YES
			withEquivalent: nil
			asChildOf: davElement (@"read", XMLNS_WEBDAV)];
    }

  return aclManager;
}

- (id) init
{
  if ((self = [super init]))
    {
      displayName = nil;
      isSubscription = NO;
    }

  return self;
}

- (void) dealloc
{
  [displayName release];
  [super dealloc];
}

- (void) setDisplayName: (NSString *) newDisplayName
{
  ASSIGN (displayName, newDisplayName);
}

- (NSString *) displayName
{
  return ((id)displayName ? (id)displayName : (id)nameInContainer);
}

- (void) setIsSubscription: (BOOL) newIsSubscription
{
  isSubscription = newIsSubscription;
}

- (BOOL) isSubscription
{
  return isSubscription;
}

- (NSString *) realNameInContainer
{
  NSString *realNameInContainer, *ownerName;

  if (isSubscription)
    {
      ownerName = [[self ownerInContext: context] asCSSIdentifier];
      realNameInContainer
	= [nameInContainer substringFromIndex: [ownerName length] + 1];
    }
  else
    realNameInContainer = nameInContainer;

  return realNameInContainer;
}

- (NSString *) folderType
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSArray *) toOneRelationshipKeys
{
  return nil;
}

- (NSArray *) toManyRelationshipKeys
{
  return nil;
}

- (BOOL) isValidContentName: (NSString *) name
{
  return ([name length] > 0);
}

- (BOOL) isFolderish
{
  return YES;
}

- (NSString *) davURLAsString
{
  return [[container davURLAsString]
           stringByAppendingFormat: @"%@/", nameInContainer];
}

- (NSString *) httpURLForAdvisoryToUser: (NSString *) uid
{
  return [[self soURL] absoluteString];
}

- (NSString *) resourceURLForAdvisoryToUser: (NSString *) uid
{
  return [[self davURL] absoluteString];
}

/* sorting */
- (NSComparisonResult) _compareByOrigin: (SOGoFolder *) otherFolder
{
  NSComparisonResult comparison;

  if (isSubscription == [otherFolder isSubscription])
    comparison = NSOrderedSame;
  else
    {
      if (isSubscription)
	comparison = NSOrderedDescending;
      else
	comparison = NSOrderedAscending;
    }

  return comparison;
}

- (NSComparisonResult) _compareByNameInContainer: (SOGoFolder *) otherFolder
{
  NSString *selfName, *otherName;
  NSComparisonResult comparison;

  selfName = [self realNameInContainer];
  otherName = [otherFolder realNameInContainer];
  if ([selfName isEqualToString: @"personal"])
    {
      if ([otherName isEqualToString: @"personal"])
	comparison = NSOrderedSame;
      else
	comparison = NSOrderedAscending;
    }
  else
    {
      if ([otherName isEqualToString: @"personal"])
	comparison = NSOrderedDescending;
      else
	comparison = NSOrderedSame;
    }

  return comparison;
}

- (NSComparisonResult) compare: (id) otherFolder
{
  NSComparisonResult comparison;

  comparison = [self _compareByOrigin: otherFolder];
  if (comparison == NSOrderedSame)
    {
      comparison = [self _compareByNameInContainer: otherFolder];
      if (comparison == NSOrderedSame)
        {
          if ([self displayName] == nil)
            comparison = NSOrderedAscending;
          else if ([otherFolder displayName] == nil)
            comparison = NSOrderedDescending;
          else
            comparison
              = [[self displayName]
                  localizedCaseInsensitiveCompare: [otherFolder displayName]];
        }
    }

  return comparison;
}

/* email advisories */

- (void) sendFolderAdvisoryTemplate: (NSString *) template
{
  NSString *pageName;
  SOGoUser *user;
  SOGoFolderAdvisory *page;
  NSString *language;

  user = [SOGoUser userWithLogin: [self ownerInContext: context]];
  if ([[user domainDefaults] foldersSendEMailNotifications])
    {
      language = [[user userDefaults] language];
      pageName = [NSString stringWithFormat: @"SOGoFolder%@%@Advisory",
			   language, template];

      page = [[WOApplication application] pageWithName: pageName
					  inContext: context];
      [page setFolderObject: self];
      [page setRecipientUID: [user login]];
      [page send];
    }
}

/* WebDAV */

- (NSString *) davEntityTag
{
  return @"\"None\"";
}

- (NSString *) davContentType
{
  return @"httpd/unix-directory";
}

- (NSArray *) davResourceType
{
  NSArray *rType, *groupDavCollection;

  if ([self respondsToSelector: @selector (groupDavResourceType)])
    {
      groupDavCollection
	= [NSArray arrayWithObjects: [self groupDavResourceType],
		   XMLNS_GROUPDAV, nil];
      rType = [NSArray arrayWithObjects: @"collection", groupDavCollection,
		       nil];
    }
  else
    rType = [NSArray arrayWithObject: @"collection"];

  return rType;
}

- (BOOL) davIsCollection
{
  return YES;
}

- (NSArray *) _extractHREFSFromPropertyValues: (NSArray *) values
{
  NSMutableArray *hrefs;
  NSDictionary *value;
  int count, max;

  max = [values count];
  hrefs = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      value = [values objectAtIndex: count];
      if ([value isKindOfClass: [NSDictionary class]])
        {
          if ([[value objectForKey: @"method"] isEqualToString: @"href"])
            [hrefs addObject: [value objectForKey: @"content"]];
          else
            [self errorWithFormat: @"value is not an href"];
        }
      else if ([value isKindOfClass: [NSString class]])
        {
          /* we extract the text between <href>XXX</href>, but in a bad way */
          [hrefs addObject: [(NSString *) value removeOutsideTags]];
        }
      else
        [self errorWithFormat: @"value class is '%@' instead of NSDictionary",
              NSStringFromClass ([value class])];
    }

  return hrefs;
}

- (NSArray *) _interpretSoWebDAVValue: (SoWebDAVValue *) value
{
  NSString *valueString;

  valueString = [value stringForTag: @"" rawName: @""
                          inContext: context prefixes: nil];

  return [NSArray arrayWithObject: [valueString removeOutsideTags]];
}

- (NSArray *) _interpretWebDAVValue: (id) value
{
  NSArray *result;

  if ([value isKindOfClass: [NSString class]])
    result = [NSArray arrayWithObject: value];
  else if ([value isKindOfClass: [SoWebDAVValue class]])
    result = [self _interpretSoWebDAVValue: value];
  else if ([value isKindOfClass: [NSArray class]])
    result = [self _interpretWebDAVArrayValue: value];
  else
    result = nil;

  return result;
}

- (NSArray *) _interpretWebDAVArrayValue: (id) value
{
  int count, max;
  NSMutableArray *results;
  id subValue, subResults;

  max = [value count];
  results = [NSMutableArray arrayWithCapacity: max];
  if (max > 0)
    {
      subValue = [value objectAtIndex: 0];
      if ([subValue isKindOfClass: [NSString class]])
        [results addObject:
                   davElementWithContent (subValue,  
                                          [value objectAtIndex: 1],
                                          [value objectAtIndex: 3])];
      else
        {
          for (count = 0; count < max; count++)
            {
              subResults
                = [self _interpretWebDAVValue: [value objectAtIndex: count]];
              [results addObjectsFromArray: subResults];
            }
        }
    }

  return results;
}

- (NSArray *) _expandedPropertyValue: (NGDOMElement *) property
                           forObject: (SOGoObject *) currentObject
{
  NSString *propertyTag;
  SEL propertySel;
  id value;

  propertyTag = [property asPropertyPropertyName];
  propertySel = [self davPropertySelectorForKey: propertyTag];
  if (propertySel)
    value = [currentObject performSelector: propertySel];
  else
    value = nil;

  return [self _interpretWebDAVValue: value];
}

- (NSArray *) _expandPropertyValue: (NGDOMElement *) property
                         forObject: (SOGoObject *) currentObject
{
  NSArray *values, *hrefs;
  NSString *href;
  NSMutableArray *expandedValues;
  int count, max;
  BOOL needsExpansion;

  needsExpansion = ([[property childElementsWithTag: @"property"] length] > 0);
  values = [self _expandedPropertyValue: property
                              forObject: currentObject];
  max = [values count];
  expandedValues = [NSMutableArray arrayWithCapacity: max];
  if (max)
    {
      if (needsExpansion)
        {
          hrefs = [self _extractHREFSFromPropertyValues: values];
          max = [hrefs count];
          for (count = 0; count < max; count++)
            {
              href = [hrefs objectAtIndex: count];
              [expandedValues addObject: [self _expandPropertyResponse: property
                                                               forHREF: href]];
            }
        }
      else
        [expandedValues setArray: values];
    }

  return expandedValues;
}

- (NSDictionary *) _expandPropertyResponse: (NGDOMElement *) property
                                 forObject: (SOGoObject *) currentObject
{
  id <DOMNodeList> properties;
  NSArray *childValue;
  NGDOMElement *childProperty;
  NSDictionary *response;
  NSMutableArray *properties200, *properties404;
  int count, max;
  NSString *tagName, *tagNS;

  properties = [property childElementsWithTag: @"property"];
  max = [properties length];
  properties200 = [NSMutableArray arrayWithCapacity: max];
  properties404 = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      childProperty = [properties objectAtIndex: count];
      childValue = [self _expandPropertyValue: childProperty
                                    forObject: currentObject];
      tagNS = [childProperty attribute: @"namespace"];
      if (!tagNS)
        tagNS = XMLNS_WEBDAV;
      tagName = [childProperty attribute: @"name"];
      if (childValue)
        [properties200 addObject: davElementWithContent (tagName,
                                                         tagNS,
                                                         childValue)];
      else
        [properties404 addObject: davElement (tagName, tagNS)];
    }
  response = [self responseForURL: [currentObject davURLAsString]
                withProperties200: properties200
                 andProperties404: properties404];

  return response;
}

- (NSDictionary *) _expandPropertyResponse: (NGDOMElement *) property
                                   forHREF: (NSString *) href
{
  SOGoObject *lookupObject;
  NSDictionary *response;

  lookupObject = [self lookupObjectAtDAVUrl: href];
  if (lookupObject)
    response = [self _expandPropertyResponse: property
                                   forObject: lookupObject];
  else
    response = nil;

  return response;
}

- (WOResponse *) davExpandProperty: (WOContext *) localContext
{
  WOResponse *r;
  id <DOMDocument> document;
  NSDictionary *response, *multistatus;
  NGDOMElement *documentElement;

  r = [localContext response];
  [r prepareDAVResponse];

  document = [[context request] contentAsDOMDocument];
  documentElement = (NGDOMElement *) [document documentElement];
  response = [self _expandPropertyResponse: documentElement forObject: self];
  multistatus = davElementWithContent (@"multistatus", XMLNS_WEBDAV,
                                       response);
  [r appendContentString: [multistatus asWebDavStringWithNamespaces: nil]];

  return r;
}

/* web dav acl helper */
- (void) _fillArrayWithPrincipalsOwnedBySelf: (NSMutableArray *) hrefs
{
  NSEnumerator *children;
  NSString *currentKey;

  [super _fillArrayWithPrincipalsOwnedBySelf: hrefs];
  children = [[self toOneRelationshipKeys] objectEnumerator];
  while ((currentKey = [children nextObject]))
    [[self lookupName: currentKey inContext: context
	   acquire: NO] _fillArrayWithPrincipalsOwnedBySelf: hrefs];

  children = [[self toManyRelationshipKeys] objectEnumerator];
  while ((currentKey = [children nextObject]))
    [[self lookupName: currentKey inContext: context
	   acquire: NO] _fillArrayWithPrincipalsOwnedBySelf: hrefs];
}


- (NSArray *) davGroupMemberSet
{
  return [NSArray array];
}

- (NSArray *) davGroupMembership
{
  return [NSArray array];
}

/* folder type */

- (BOOL) isEqual: (id) otherFolder
{
  return ([otherFolder class] == [self class]
	  && [container isEqual: [otherFolder container]]
	  && [nameInContainer
	       isEqualToString: [otherFolder nameInContainer]]);
}

/* acls */

- (NSString *) defaultUserID
{
  return nil;
}

- (NSArray *) subscriptionRoles
{
  return [NSArray arrayWithObjects: SoRole_Owner, SOGoRole_ObjectViewer,
		  SOGoRole_ObjectEditor, SOGoRole_ObjectCreator,
		  SOGoRole_ObjectEraser, nil];
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  return nil;
}

- (NSArray *) aclUsers
{
  return nil;
}

- (NSArray *) davPrincipalURL
{
  NSArray *principalURL;
  NSString *classes;

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

@end
