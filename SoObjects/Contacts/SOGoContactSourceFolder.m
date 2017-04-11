/* SOGoContactSourceFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2016 Inverse inc.
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

#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <EOControl/EOSortOrdering.h>
#import <SaxObjC/XMLNamespaces.h>

#import <SOGo/DOMNode+SOGo.h>
#import <SOGo/LDAPSource.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/NSObject+DAV.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/WORequest+SOGo.h>
#import <SOGo/WOResponse+SOGo.h>

#import "NSArray+Contacts.h"
#import "SOGoContactFolders.h"
#import "SOGoContactGCSFolder.h"
#import "SOGoContactLDIFEntry.h"
#import "SOGoContactSourceFolder.h"

@class WOContext;

@implementation SOGoContactSourceFolder

+ (id) folderWithName: (NSString *) aName
       andDisplayName: (NSString *) aDisplayName
	  inContainer: (id) aContainer
{
  id folder;

  folder = [[self alloc] initWithName: aName
                         andDisplayName: aDisplayName
                         inContainer: aContainer];
  [folder autorelease];

  return folder;
}

- (id) init
{
  if ((self = [super init]))
    {
      childRecords = [NSMutableDictionary new];
      source = nil;
    }

  return self;
}

- (id) initWithName: (NSString *) newName
     andDisplayName: (NSString *) newDisplayName
	inContainer: (id) newContainer
{
  if ((self = [self initWithName: newName
		    inContainer: newContainer]))
    {
      if (![newDisplayName length])
        newDisplayName = newName;
      ASSIGN (displayName, (NSMutableString *)newDisplayName);
    }

  return self;
}

- (void) dealloc
{
  [childRecords release];
  [source release];
  [super dealloc];
}

- (void) setSource: (id <SOGoSource>) newSource
{
  ASSIGN (source, newSource);
}

- (id <SOGoSource>) source
{
  return source;
}

- (void) setIsPersonalSource: (BOOL) isPersonal
{
  isPersonalSource = isPersonal;
}

- (BOOL) isPersonalSource
{
  return isPersonalSource;
}

- (BOOL) listRequiresDot
{
  return [source listRequiresDot];
}

- (NSString *) groupDavResourceType
{
  return @"vcard-collection";
}

- (NSArray *) davResourceType
{
  NSMutableArray *resourceType;
  NSArray *type;

  resourceType = [NSMutableArray arrayWithArray: [super davResourceType]];
  type = [NSArray arrayWithObjects: @"addressbook", XMLNS_CARDDAV, nil];
  [resourceType addObject: type];
  type = [NSArray arrayWithObjects: @"directory", XMLNS_CARDDAV, nil];
  [resourceType addObject: type];

  return resourceType;
}

- (id) lookupName: (NSString *) objectName
        inContext: (WOContext *) lookupContext
          acquire: (BOOL) acquire
{
  NSDictionary *ldifEntry;
  SOGoContactLDIFEntry *obj;
  NSString *url;
  BOOL isNew = NO;
  NSArray *baseClasses;

  /* first check attributes directly bound to the application */
  obj = [super lookupName: objectName inContext: lookupContext acquire: NO];

  if (!obj)
    {
      ldifEntry = [childRecords objectForKey: objectName];
      if (!ldifEntry)
        {
          ldifEntry = [source lookupContactEntry: objectName
                                        inDomain: [[context activeUser] domain]];
          if (ldifEntry)
            [childRecords setObject: ldifEntry forKey: objectName];
          else if ([self isValidContentName: objectName])
            {
              url = [[[lookupContext request] uri] urlWithoutParameters];
              if ([url hasSuffix: @"AsContact"])
                {
                  baseClasses = [NSArray arrayWithObjects: @"inetorgperson",
                                         @"mozillaabpersonalpha", nil];
                  ldifEntry = [NSMutableDictionary
                                dictionaryWithObject: baseClasses
                                forKey: @"objectclass"];
                  isNew = YES;
                }
            }
        }
      if (ldifEntry)
        {
          obj = [SOGoContactLDIFEntry contactEntryWithName: objectName
                                             withLDIFEntry: ldifEntry
                                               inContainer: self];
          if (isNew)
            [obj setIsNew: YES];
        }
      else
        obj = [NSException exceptionWithHTTPStatus: 404];
    }

  return obj;
}

- (NSArray *) toOneRelationshipKeys
{
  NSString *userDomain;

  userDomain = [[context activeUser] domain];
  return [source allEntryIDsVisibleFromDomain: userDomain];
}

- (NSException *) saveLDIFEntry: (SOGoContactLDIFEntry *) ldifEntry
{
  return (([ldifEntry isNew])
          ? [source addContactEntry: [ldifEntry ldifRecord]
                    withID: [ldifEntry nameInContainer]]
          : [source updateContactEntry: [ldifEntry ldifRecord]]);
}

- (NSException *) deleteLDIFEntry: (SOGoContactLDIFEntry *) ldifEntry
{
  return [source removeContactEntryWithID: [ldifEntry nameInContainer]];
}

/**
 * Normalize keys of dictionary representing a contact.
 * @param oldRecord a dictionary with pairs from the source folder (LDAP or SQL)
 * @see [SOGoContactGCSFolder _fixupContactRecord]
 */
- (NSDictionary *) _flattenedRecord: (NSDictionary *) oldRecord
{
  NSMutableDictionary *newRecord;
  id data;
  NSObject <SOGoSource> *recordSource;

  newRecord = [NSMutableDictionary dictionaryWithCapacity: 8];
  [newRecord setObject: [oldRecord objectForKey: @"c_uid"]
                forKey: @"c_uid"];

  // c_name => id
  [newRecord setObject: [oldRecord objectForKey: @"c_name"]
                forKey: @"c_name"];
  [newRecord setObject: [oldRecord objectForKey: @"c_name"]
                forKey: @"id"];

  // displayname || c_cn => fn
  data = [oldRecord objectForKey: @"displayname"];
  if (!data)
    data = [oldRecord objectForKey: @"c_cn"];
  if (data)
    [newRecord setObject: data forKey: @"fn"];
  else
    data = @"";
  [newRecord setObject: data forKey: @"c_cn"];

  if ([[SOGoSystemDefaults sharedSystemDefaults] enableDomainBasedUID])
    {
      data = [oldRecord objectForKey: @"c_domain"];
      if (data)
        [newRecord setObject: data forKey: @"c_domain"];
    }

  // mail => emails[]
  data = [oldRecord objectForKey: @"c_emails"];
  if (!data)
    data = [oldRecord objectForKey: @"mail"];
  if (data)
    {
      if ([data isKindOfClass: [NSArray class]])
        {
          if ([data count] > 0)
            {
              NSEnumerator *emails;
              NSMutableArray *recordEmails;
              NSString *email;
              emails = [(NSArray *)data objectEnumerator];
              recordEmails = [NSMutableArray arrayWithCapacity: [data count]];
              while ((email = [emails nextObject]))
                {
                  [recordEmails addObject: [NSDictionary dictionaryWithObject: email forKey: @"value"]];
                }
              [newRecord setObject: recordEmails forKey: @"emails"];
            }
        }
      else if (data)
        {
          NSDictionary *email;
          email = [NSDictionary dictionaryWithObjectsAndKeys: @"pref", @"type", data, @"value", nil];
          [newRecord setObject: [NSArray arrayWithObject: email] forKey: @"emails"];
        }
      else
        data = @"";
    }
  else
    data = @"";
  [newRecord setObject: data forKey: @"c_mail"];

  data = [oldRecord objectForKey: @"mozillanickname"];
  if (![data length])
    data = [oldRecord objectForKey: @"nsaimid"];
  if (![data length])
    data = [oldRecord objectForKey: @"nscpaimscreenname"];
  if (![data length])
    data = @"";
  [newRecord setObject: data forKey: @"c_screenname"];

  // o => org
  data = [oldRecord objectForKey: @"o"];
  if (data)
    [newRecord setObject: data forKey: @"org"];
  else
    data = @"";
  [newRecord setObject: data forKey: @"c_o"];

  // telephonenumber || cellphone || homephone => phones[]
  data = [oldRecord objectForKey: @"telephonenumber"];
  if (![data length])
    data = [oldRecord objectForKey: @"cellphone"];
  if (![data length])
    data = [oldRecord objectForKey: @"homephone"];
  if (data)
    {
      NSDictionary *phonenumber;
      phonenumber = [NSDictionary dictionaryWithObjectsAndKeys: @"pref", @"type", data, @"value", nil];
      [newRecord setObject: [NSArray arrayWithObject: phonenumber] forKey: @"phones"];
    }
  else
    data = @"";
  [newRecord setObject: data forKey: @"c_telephonenumber"];

  // Custom attribute for group-lookups. See LDAPSource.m where
  // it's set.
  data = [oldRecord objectForKey: @"isGroup"];
  if (data)
    {
      [newRecord setObject: data forKey: @"isGroup"];
      [newRecord setObject: @"vlist" forKey: @"c_component"];
    }
  else
    {
      [newRecord setObject: @"vcard" forKey: @"c_component"];
    }
  
  // c_info => note
  data = [oldRecord objectForKey: @"c_info"];
  if ([data length] > 0)
    {
      [newRecord setObject: data forKey: @"note"];
      [newRecord setObject: data forKey: @"contactInfo"];
    }

  // photo => hasPhoto
  data = [oldRecord objectForKey: @"photo"];
  [newRecord setObject: [NSNumber numberWithInt: [data length] ? 1 : 0] forKey: @"hasPhoto"];

  recordSource = [oldRecord objectForKey: @"source"];
  if ([recordSource conformsToProtocol: @protocol (SOGoDNSource)] &&
      [[(NSObject <SOGoDNSource>*) recordSource MSExchangeHostname] length])
    [newRecord setObject: [NSNumber numberWithInt: 1] forKey: @"isMSExchange"];
  
  return newRecord;
}

- (NSArray *) _flattenedRecords: (NSArray *) records
{
  NSMutableDictionary *oldRecord;
  NSMutableArray *newRecords;
  NSEnumerator *oldRecords;
  NSDictionary *o;

  newRecords = [NSMutableArray arrayWithCapacity: [records count]];

  oldRecords = [records objectEnumerator];
  while ((o = [oldRecords nextObject]))
    {
      oldRecord = [NSMutableDictionary dictionary];
      [oldRecord addEntriesFromDictionary: o];
      if ([source isKindOfClass: [LDAPSource class]])
        [(LDAPSource *)source applyContactMappingToResult: oldRecord];
      [newRecords addObject: [self _flattenedRecord: oldRecord]];
    }

  return newRecords;
}

/* This method returns the entry corresponding to the name passed as
   parameter. */
- (NSDictionary *) lookupContactWithName: (NSString *) aName
{
  NSDictionary *record;

  if (aName && [aName length] > 0)
    {
      record = [source lookupContactEntry: aName
                                 inDomain: [[context activeUser] domain]];
      record = [self _flattenedRecord: record];
    }
  else
    record = nil;

  return record;
}

- (NSArray *) lookupContactsWithFilter: (NSString *) filter
                            onCriteria: (NSString *) criteria
                                sortBy: (NSString *) sortKey
                              ordering: (NSComparisonResult) sortOrdering
                              inDomain: (NSString *) domain
{
  NSArray *records, *result;
  EOSortOrdering *ordering;

  result = nil;

  if (([filter length] > 0 && [criteria isEqualToString: @"name_or_address"])
      || ![source listRequiresDot])
    {
      records = [source fetchContactsMatching: filter
                                     inDomain: domain];
      [childRecords setObjects: records
                       forKeys: [records objectsForKey: @"c_name"
                                        notFoundMarker: nil]];
      records = [self _flattenedRecords: records];
      ordering
        = [EOSortOrdering sortOrderingWithKey: sortKey
                          selector: ((sortOrdering == NSOrderedDescending)
                                     ? EOCompareCaseInsensitiveDescending
                                     : EOCompareCaseInsensitiveAscending)];
      result
        = [records sortedArrayUsingKeyOrderArray:
                     [NSArray arrayWithObject: ordering]];
    }

  return result;
}

- (NSString *) _deduceObjectNameFromURL: (NSString *) url
                            fromBaseURL: (NSString *) baseURL
{
  NSRange urlRange;
  NSString *name;

  urlRange = [url rangeOfString: baseURL];
  if (urlRange.location != NSNotFound)
    {
      name = [url substringFromIndex: NSMaxRange (urlRange)];
      if ([name hasPrefix: @"/"])
        name = [name substringFromIndex: 1];
    }
  else
    name = nil;

  return name;
}

/* TODO: multiget reorg */
- (NSString *) _nodeTagForProperty: (NSString *) property
{
  NSString *namespace, *nodeName, *nsRep;
  NSRange nsEnd;

  nsEnd = [property rangeOfString: @"}"];
  namespace
    = [property substringFromRange: NSMakeRange (1, nsEnd.location - 1)];
  nodeName = [property substringFromIndex: nsEnd.location + 1];
  if ([namespace isEqualToString: XMLNS_CARDDAV])
    nsRep = @"C";
  else
    nsRep = @"D";

  return [NSString stringWithFormat: @"%@:%@", nsRep, nodeName];
}

- (NSString *) _nodeTag: (NSString *) property
{
  static NSMutableDictionary *tags = nil;
  NSString *nodeTag;

  if (!tags)
    tags = [NSMutableDictionary new];
  nodeTag = [tags objectForKey: property];
  if (!nodeTag)
    {
      nodeTag = [self _nodeTagForProperty: property];
      [tags setObject: nodeTag forKey: property];
    }

  return nodeTag;
}

- (NSString **) _properties: (NSString **) properties
                      count: (unsigned int) propertiesCount
                   ofObject: (NSDictionary *) object
{
  SOGoContactLDIFEntry *ldifEntry;
  NSString **currentProperty;
  NSString **values, **currentValue;
  SEL methodSel;

//   NSLog (@"_properties:ofObject:: %@", [NSDate date]);

  values = NSZoneMalloc (NULL,
                         (propertiesCount + 1) * sizeof (NSString *));
  *(values + propertiesCount) = nil;

  ldifEntry = [SOGoContactLDIFEntry
                contactEntryWithName: [object objectForKey: @"c_name"]
                       withLDIFEntry: object
                         inContainer: self];
  currentProperty = properties;
  currentValue = values;
  while (*currentProperty)
    {
      methodSel = SOGoSelectorForPropertyGetter (*currentProperty);
      if (methodSel && [ldifEntry respondsToSelector: methodSel])
        *currentValue = [[ldifEntry performSelector: methodSel]
                          safeStringByEscapingXMLString];
      currentProperty++;
      currentValue++;
    }

//    NSLog (@"/_properties:ofObject:: %@", [NSDate date]);

  return values;
}

- (NSArray *) _propstats: (NSString **) properties
                   count: (unsigned int) propertiesCount
		ofObject: (NSDictionary *) object
{
  NSMutableArray *propstats, *properties200, *properties404, *propDict;
  NSString **property, **values, **currentValue;
  NSString *propertyValue, *nodeTag;

//   NSLog (@"_propstats:ofObject:: %@", [NSDate date]);

  propstats = [NSMutableArray array];

  properties200 = [NSMutableArray array];
  properties404 = [NSMutableArray array];

  values = [self _properties: properties count: propertiesCount
                    ofObject: object];
  currentValue = values;

  property = properties;
  while (*property)
    {
      nodeTag = [self _nodeTag: *property];
      if (*currentValue)
	{
	  propertyValue = [NSString stringWithFormat: @"<%@>%@</%@>",
				    nodeTag, *currentValue, nodeTag];
	  propDict = properties200;
	}
      else
	{
	  propertyValue = [NSString stringWithFormat: @"<%@/>", nodeTag];
	  propDict = properties404;
	}
      [propDict addObject: propertyValue];
      property++;
      currentValue++;
    }
  free (values);

  if ([properties200 count])
    [propstats addObject: [NSDictionary dictionaryWithObjectsAndKeys:
					  properties200, @"properties",
					@"HTTP/1.1 200 OK", @"status",
					nil]];
  if ([properties404 count])
    [propstats addObject: [NSDictionary dictionaryWithObjectsAndKeys:
					  properties404, @"properties",
					@"HTTP/1.1 404 Not Found", @"status",
					nil]];
//    NSLog (@"/_propstats:ofObject:: %@", [NSDate date]);

  return propstats;
}

- (void) _appendPropstat: (NSDictionary *) propstat
                toBuffer: (NSMutableString *) r
{
  NSArray *properties;
  unsigned int count, max;

  [r appendString: @"<D:propstat><D:prop>"];
  properties = [propstat objectForKey: @"properties"];
  max = [properties count];
  for (count = 0; count < max; count++)
    [r appendString: [properties objectAtIndex: count]];
  [r appendString: @"</D:prop><D:status>"];
  [r appendString: [propstat objectForKey: @"status"]];
  [r appendString: @"</D:status></D:propstat>"];
}

- (void) appendObject: (NSDictionary *) object
	   properties: (NSString **) properties
                count: (unsigned int) propertiesCount
          withBaseURL: (NSString *) baseURL
	     toBuffer: (NSMutableString *) r
{
  NSArray *propstats;
  unsigned int count, max;

  [r appendFormat: @"<D:response><D:href>"];
  [r appendString: baseURL];
  [r appendString: [[object objectForKey: @"c_name"] stringByEscapingURL]];
  [r appendString: @"</D:href>"];

  propstats = [self _propstats: properties count: propertiesCount
                      ofObject: object];
  max = [propstats count];
  for (count = 0; count < max; count++)
    [self _appendPropstat: [propstats objectAtIndex: count]
                 toBuffer: r];

  [r appendString: @"</D:response>"];
}

- (void) appendMissingObjectRef: (NSString *) href
		       toBuffer: (NSMutableString *) r
{
  [r appendString: @"<D:response><D:href>"];
  [r appendString: href];
  [r appendString: @"</D:href><D:status>HTTP/1.1 404 Not Found</D:status></D:response>"];
}

- (void) _appendComponentProperties: (NSArray *) properties
                       matchingURLs: (id <DOMNodeList>) refs
                         toResponse: (WOResponse *) response
{
  NSObject <DOMElement> *element;
  NSString *url, *baseURL, *cname, *domain;
  NSString **propertiesArray;
  NSMutableString *buffer;
  NSDictionary *object;

  unsigned int count, max, propertiesCount;
  
  baseURL = [self davURLAsString];
#warning review this when fixing http://www.scalableogo.org/bugs/view.php?id=276
  if (![baseURL hasSuffix: @"/"])
    baseURL = [NSString stringWithFormat: @"%@/", baseURL];

  propertiesArray = [properties asPointersOfObjects];
  propertiesCount = [properties count];

  max = [refs length];
  buffer = [NSMutableString stringWithCapacity: max*512];
  domain = [[context activeUser] domain];
  for (count = 0; count < max; count++)
    {
      element = [refs objectAtIndex: count];
      url = [[[element firstChild] nodeValue] stringByUnescapingURL];
      cname = [self _deduceObjectNameFromURL: url fromBaseURL: baseURL];
      object = [source lookupContactEntry: cname inDomain: domain];
      if (object)
        [self appendObject: object
                properties: propertiesArray
                     count: propertiesCount
               withBaseURL: baseURL
                  toBuffer: buffer];
      else
        [self appendMissingObjectRef: url
                            toBuffer: buffer];
    }
  [response appendContentString: buffer];
//   NSLog (@"/adding properties with url");

  NSZoneFree (NULL, propertiesArray);
}

- (WOResponse *) performMultigetInContext: (WOContext *) queryContext
                              inNamespace: (NSString *) namespace
{
  WOResponse *r;
  id <DOMDocument> document;
  id <DOMElement> documentElement, propElement;

  r = [context response];
  [r prepareDAVResponse];
  [r appendContentString:
       [NSString stringWithFormat: @"<D:multistatus xmlns:D=\"DAV:\""
                         @" xmlns:C=\"%@\">", namespace]];
  document = [[queryContext request] contentAsDOMDocument];
  documentElement = [document documentElement];
  propElement = [(NGDOMNodeWithChildren *) documentElement
                    firstElementWithTag: @"prop"
                            inNamespace: @"DAV:"];
  [self _appendComponentProperties: [(NGDOMNodeWithChildren *) propElement flatPropertyNameOfSubElements]
                      matchingURLs: [documentElement getElementsByTagName: @"href"]
                        toResponse: r];
  [r appendContentString:@"</D:multistatus>"];

  return r;
}

- (id) davAddressbookMultiget: (id) queryContext
{
  return [self performMultigetInContext: queryContext
                            inNamespace: XMLNS_CARDDAV];
}

- (NSString *) davDisplayName
{
  return displayName;
}

- (BOOL) isFolderish
{
  return YES;
}

/* folder type */

- (NSString *) folderType
{
  return @"Contact";
}

/* sorting */
- (NSComparisonResult) compare: (id) otherFolder
{
  NSComparisonResult comparison;
  BOOL otherIsPersonal;

  otherIsPersonal = ([otherFolder isKindOfClass: [SOGoContactGCSFolder class]]
                     || ([otherFolder isKindOfClass: object_getClass(self)] && [otherFolder isPersonalSource]));

  if (isPersonalSource)
    {
      if (otherIsPersonal && ![nameInContainer isEqualToString: @"personal"])
        {
          if ([[otherFolder nameInContainer] isEqualToString: @"personal"])
            comparison = NSOrderedDescending;
          else
            comparison
              = [[self displayName]
                  localizedCaseInsensitiveCompare: [otherFolder displayName]];
        }
      else
        comparison = NSOrderedAscending;
    }
  else
    {
      if (otherIsPersonal)
        comparison = NSOrderedDescending;
      else
        comparison
          = [[self displayName]
              localizedCaseInsensitiveCompare: [otherFolder displayName]];
    }

  return comparison;
}

/* common methods */

- (NSException *) delete
{
  NSException *error;

  if (isPersonalSource)
    {
      error = [(SOGoContactFolders *) container
                  removeLDAPAddressBook: nameInContainer];
      if (!error && [[context request] handledByDefaultHandler])
        [self sendFolderAdvisoryTemplate: @"Removal"];
    }
  else
    error = [NSException exceptionWithHTTPStatus: 501 /* not implemented */
                                          reason: @"delete not available on system sources"];

  return error;
}

- (void) renameTo: (NSString *) newName
{
  NSException *error;

  if (isPersonalSource)
    {
      if (![[source displayName] isEqualToString: newName])
        {
          error = [(SOGoContactFolders *) container
                      renameLDAPAddressBook: nameInContainer
                            withDisplayName: newName];
          if (!error)
            [self setDisplayName: newName];
        }
    }
  /* If public source then method is ignored, maybe we should return an
     NSException instead... */
}

/* acls */
- (NSString *) ownerInContext: (WOContext *) noContext
{
  NSString *sourceOwner;

  if (isPersonalSource)
    sourceOwner = [[source modifiers] objectAtIndex: 0];
  else
    sourceOwner = @"nobody";

  return sourceOwner;
}

- (NSArray *) subscriptionRoles
{
  return [NSArray arrayWithObject: SoRole_Authenticated];
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  NSArray *acls, *modifiers;
  static NSArray *modifierRoles = nil;

  if (!modifierRoles)
    modifierRoles = [[NSArray alloc] initWithObjects: @"Owner",
                                     @"ObjectViewer",
                                     @"ObjectEditor", @"ObjectCreator",
                                     @"ObjectEraser", nil];

  modifiers = [source modifiers];
  if ([modifiers containsObject: uid])
    acls = [modifierRoles copy];
  else
    acls = [NSArray new];

  [acls autorelease];

  return acls;
}

@end
