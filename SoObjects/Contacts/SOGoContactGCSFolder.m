/*
  Copyright (C) 2006-2019 Inverse inc.

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


#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/WOContext.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <SaxObjC/XMLNamespaces.h>
#import <EOControl/EOFetchSpecification.h>
#import <EOControl/EOQualifier.h>
#import <EOControl/EOSortOrdering.h>

#import <NGCards/CardGroup.h>
#import <GDLContentStore/GCSFolder.h>

#import <SOGo/DOMNode+SOGo.h>
#import <SOGo/SOGoCache.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/NSObject+DAV.h>
#import <SOGo/WORequest+SOGo.h>

#import "SOGoContactGCSEntry.h"
#import "SOGoContactGCSList.h"

#import "SOGoContactGCSFolder.h"

static NSArray *folderListingFields = nil;

@implementation SOGoContactGCSFolder

+ (void) initialize
{
  if (!folderListingFields)
    folderListingFields = [[NSArray alloc] initWithObjects: @"c_name",
                                           @"c_cn", @"c_givenname", @"c_sn",
                                           @"c_screenname", @"c_o",
                                           @"c_mail", @"c_telephonenumber",
                                           @"c_categories",
                                           @"c_component",
                                           @"c_hascertificate", nil];
}

- (id) init
{
  if ((self = [super init]))
    {
      baseCardDAVURL = nil;
      basePublicCardDAVURL = nil;
    }

  return self;
}

- (void) dealloc
{
  [baseCardDAVURL release];
  [basePublicCardDAVURL release];
  [super dealloc];
}

- (NSArray *) searchFields
{
  static NSArray *searchFields = nil;

  if (!searchFields)
    {
      // "name" expands to c_sn, c_givenname and c_cn
      searchFields = [NSArray arrayWithObjects: @"name", @"c_mail", @"c_categories", @"c_o", nil];
      [searchFields retain];
    }

  return searchFields;
}

- (Class) objectClassForContent: (NSString *) content
{
  CardGroup *cardEntry;
  NSString *firstTag;
  Class objectClass;

  objectClass = Nil;

  cardEntry = [CardGroup parseSingleFromSource: content];
  if (cardEntry)
    {
      firstTag = [[cardEntry tag] uppercaseString];
      if ([firstTag isEqualToString: @"VCARD"])
	objectClass = [SOGoContactGCSEntry class];
      else if ([firstTag isEqualToString: @"VLIST"])
	objectClass = [SOGoContactGCSList class];
    }

  return objectClass;
}

- (Class) objectClassForComponentName: (NSString *) componentName
{
  Class objectClass;
  
  if ([componentName isEqualToString: @"vcard"])
    objectClass = [SOGoContactGCSEntry class];
  else if ([componentName isEqualToString: @"vlist"])
    objectClass = [SOGoContactGCSList class];
  else
    objectClass = Nil;

  return objectClass;
}

- (Class) objectClassForResourceNamed: (NSString *) name
{
  EOQualifier *qualifier;
  NSArray *records;
  NSString *component;
  Class objectClass;

  qualifier = [EOQualifier qualifierWithQualifierFormat: @"c_name = %@", [name asSafeSQLString]];
  records = [[self ocsFolder] fetchFields: [NSArray arrayWithObject: @"c_component"]
                              matchingQualifier: qualifier];

  if ([records count])
    {
      component = [[records objectAtIndex: 0] valueForKey: @"c_component"];
      objectClass = [self objectClassForComponentName: component];
    }
  else
    objectClass = Nil;
  
  return objectClass;
}

- (BOOL) requestNamedIsHandledLater: (NSString *) name
{
  return [name isEqualToString: @"OPTIONS"];
}

- (id) lookupName: (NSString *)_key
        inContext: (id)_ctx
          acquire: (BOOL)_flag
{
  id obj;
  NSString *url;
  BOOL handledLater;

  /* first check attributes directly bound to the application */
  handledLater = [self requestNamedIsHandledLater: _key];
  if (handledLater)
    obj = nil;
  else
    {
      obj = [super lookupName:_key inContext:_ctx acquire:NO];
      if (!obj)
        {
	  if ([self isValidContentName: _key])
            {
              url = [[[_ctx request] uri] urlWithoutParameters];
              if ([url hasSuffix: @"AsContact"])
                obj = [SOGoContactGCSEntry objectWithName: _key
					   inContainer: self];
              else if ([url hasSuffix: @"AsList"])
                obj = [SOGoContactGCSList objectWithName: _key
					  inContainer: self];
	      [obj setIsNew: YES];
            }
        }
      if (!obj || ([obj isKindOfClass: [SOGoContactGCSList class]] && [[_ctx request] isMacOSXAddressBookApp]))
        obj = [NSException exceptionWithHTTPStatus:404 /* Not Found */];
    }

  if (obj)
    [[SOGoCache sharedCache] registerObject: obj
			     withName: _key
			     inContainer: container];

  return obj;
}

- (EOQualifier *) qualifierForFilter: (NSString *) filter
                          onCriteria: (NSArray *) criteria
{
  NSEnumerator *criteriaList;
  NSMutableArray *filters;
  NSString *filterFormat, *currentCriteria, *qs;
  EOQualifier *qualifier;

  qualifier = nil;
  if ([filter length] > 0)
    {
      filter = [filter asSafeSQLString];
      filters = [NSMutableArray array];
      filterFormat = [NSString stringWithFormat: @"(%%@ isCaseInsensitiveLike: '%%%%%@%%%%')", filter];
      if (criteria)
        criteriaList = [criteria objectEnumerator];
      else
        criteriaList = [[self searchFields] objectEnumerator];

      while (( currentCriteria = [criteriaList nextObject] ))
        {
          if ([currentCriteria isEqualToString: @"name"])
            {
              [filters addObject: @"c_sn"];
              [filters addObject: @"c_givenname"];
              [filters addObject: @"c_cn"];
            }
          else if ([[self searchFields] containsObject: currentCriteria])
            [filters addObject: currentCriteria];
        }

      if ([filters count])
        {
          qs = [[[filters uniqueObjects] stringsWithFormat: filterFormat] componentsJoinedByString: @" OR "];
          qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
        }
    }

  return qualifier;
}

/**
 * Normalize keys of dictionary representing a contact.
 * @param contactRecord a dictionary with pairs from the quick table
 * @see [UIxContactView dataAction]
 */
- (void) fixupContactRecord: (NSMutableDictionary *) contactRecord
{
  NSString *data;

  // c_categories => categories
  data = [contactRecord objectForKey: @"c_categories"];
  if ([data length])
    [contactRecord setObject: data forKey: @"categories"];

  // c_name => id
  data = [contactRecord objectForKey: @"c_name"];
  if ([data length])
    [contactRecord setObject: data forKey: @"id"];

  // c_cn
  data = [contactRecord objectForKey: @"c_cn"];
  if (![data length])
    {
      data = [contactRecord keysWithFormat: @"%{c_givenname} %{c_sn}"];
      if ([data length] > 1)
        {
          [contactRecord setObject: data forKey: @"c_cn"];
        }
      else
        {
          data = [contactRecord objectForKey: @"c_o"];
          [contactRecord setObject: data forKey: @"c_cn"];
        }
    }

  // c_screenname
  if (![contactRecord objectForKey: @"c_screenname"])
    [contactRecord setObject: @"" forKey: @"c_screenname"];

  // c_mail => emails[]
  data = [contactRecord objectForKey: @"c_mail"];
  if ([data length])
    {
      NSArray *values;
      NSDictionary *email;
      NSMutableArray *emails;
      NSString *type, *value;
      int i, max;

      values = [data componentsSeparatedByString: @","];
      max = [values count];
      emails = [NSMutableArray arrayWithCapacity: max];
      for (i = 0; i < max; i++)
        {
          type = (i == 0)? @"pref" : @"home";
          value = [values objectAtIndex: i];
          email = [NSDictionary dictionaryWithObjectsAndKeys: type, @"type", value, @"value", nil];
          [emails addObject: email];
        }
      [contactRecord setObject: emails forKey: @"emails"];
    }
  else
    {
      [contactRecord setObject: @"" forKey: @"c_mail"];
      [contactRecord setObject: [NSArray array] forKey: @"emails"];
    }

  // c_telephonenumber => phones[]
  data = [contactRecord objectForKey: @"c_telephonenumber"];
  if ([data length])
    {
      NSDictionary *phonenumber;
      phonenumber = [NSDictionary dictionaryWithObjectsAndKeys: @"pref", @"type", data, @"value", nil];
      [contactRecord setObject: [NSArray arrayWithObject: phonenumber] forKey: @"phones"];
    }
  else
    {
      [contactRecord setObject: @"" forKey: @"c_telephonenumber"];
      [contactRecord setObject: [NSArray array] forKey: @"phones"];
    }
}

- (NSArray *) _flattenedRecords: (NSArray *) records
{
  NSMutableArray *newRecords;
  NSEnumerator *oldRecords;
  NSDictionary *oldRecord;
  NSMutableDictionary *newRecord;
  
  newRecords = [NSMutableArray arrayWithCapacity: [records count]];

  oldRecords = [records objectEnumerator];
  oldRecord = [oldRecords nextObject];
  while (oldRecord)
    {
      newRecord = [NSMutableDictionary dictionaryWithDictionary: oldRecord];
      [self fixupContactRecord: newRecord];
      [newRecords addObject: newRecord];
      oldRecord = [oldRecords nextObject];
    }

  return newRecords;
}

/* This method returns the quick entry corresponding to the name passed as
   parameter. */
- (NSDictionary *) lookupContactWithName: (NSString *) aName
{
  NSArray *dbRecords;
  NSMutableDictionary *record;
  EOQualifier *qualifier;
  NSString *qs;

  record = nil;
 
  if (aName && [aName length] > 0)
    {
      aName = [aName asSafeSQLString];
      qs = [NSString stringWithFormat: @"(c_name='%@')", aName];
      qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
      dbRecords = [[self ocsFolder] fetchFields: folderListingFields
			      matchingQualifier: qualifier];
      if ([dbRecords count] > 0)
        {
          record = [dbRecords objectAtIndex: 0];
          [self fixupContactRecord: record];
        }
    }
  
  return record;
}

/* 
 * GCS folder are personal folders and are not associated to a domain.
 * The domain is therefore ignored.
 */
- (NSArray *) lookupContactsWithFilter: (NSString *) filter
                            onCriteria: (NSArray *) criteria
                                sortBy: (NSString *) sortKey
                              ordering: (NSComparisonResult) sortOrdering
                              inDomain: (NSString *) domain
{
  NSArray *dbRecords, *records;
  EOQualifier *qualifier;
  EOSortOrdering *ordering;

  qualifier = [self qualifierForFilter: filter onCriteria: criteria];
  dbRecords = [[self ocsFolder] fetchFields: folderListingFields
                          matchingQualifier: qualifier];

  if ([dbRecords count] > 0)
    {
      records = [self _flattenedRecords: dbRecords];
      ordering
        = [EOSortOrdering sortOrderingWithKey: sortKey
                          selector: ((sortOrdering == NSOrderedDescending)
                                     ? EOCompareCaseInsensitiveDescending
                                     : EOCompareCaseInsensitiveAscending)];
      records
        = [records sortedArrayUsingKeyOrderArray:
                     [NSArray arrayWithObject: ordering]];
    }
  else
    records = nil;

  [self debugWithFormat:@"fetched %i records.", [records count]];
  return records;
}

- (NSArray *) lookupContactsWithQualifier: (EOQualifier *) qualifier
{
  return [self lookupContactsFields: folderListingFields
                      withQualifier: qualifier
                       andOrderings: nil];
}

- (NSArray *) lookupContactsFields: (NSArray *) fields
                     withQualifier: (EOQualifier *) qualifier
                      andOrderings: (NSArray *) orderings
{
  NSArray *dbRecords, *records;
  EOFetchSpecification *spec;

  spec = [EOFetchSpecification fetchSpecificationWithEntityName: [[self ocsFolder] folderName]
                                                      qualifier: qualifier
                                                  sortOrderings: orderings];

  dbRecords = [[self ocsFolder] fetchFields: fields
                         fetchSpecification: spec
                              ignoreDeleted: YES];

  if ([dbRecords count] > 0 && fields == folderListingFields)
    records = [self _flattenedRecords: dbRecords];
  else
    records = dbRecords;

  [self debugWithFormat:@"fetched %i records.", [records count]];
  return records;
}

- (NSDictionary *) davSQLFieldsTable
{
  static NSMutableDictionary *davSQLFieldsTable = nil;

  if (!davSQLFieldsTable)
    {
      davSQLFieldsTable = [[super davSQLFieldsTable] mutableCopy];
      [davSQLFieldsTable setObject: @"c_content" forKey: @"{urn:ietf:params:xml:ns:carddav}address-data"];
    }

  return davSQLFieldsTable;
}

- (NSString *) groupDavResourceType
{
  return @"vcard-collection";
}

- (NSArray *) davResourceType
{
  NSMutableArray *resourceType;
  NSArray *cardDavCollection;

  cardDavCollection
    = [NSArray arrayWithObjects: @"addressbook",
	       @"urn:ietf:params:xml:ns:carddav", nil];
  resourceType = [NSMutableArray arrayWithArray: [super davResourceType]];
  [resourceType addObject: cardDavCollection];

  return resourceType;
}

- (id) davAddressbookMultiget: (id) queryContext
{
  return [self performMultigetInContext: queryContext
                            inNamespace: @"urn:ietf:params:xml:ns:carddav"];
}

/* sorting */
- (NSComparisonResult) compare: (id) otherFolder
{
  NSComparisonResult comparison;

  if ([NSStringFromClass([otherFolder class])
			isEqualToString: @"SOGoContactSourceFolder"])
    comparison = NSOrderedAscending;
  else
    comparison = [super compare: otherFolder];

  return comparison;
}

/* folder type */

- (NSString *) folderType
{
  return @"Contact";
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

- (NSString *) _baseCardDAVURL
{
  NSString *davURL;

  if (!baseCardDAVURL)
    {
      davURL = [[self realDavURL] absoluteString];
      if ([davURL hasSuffix: @"/"])
        baseCardDAVURL = [davURL substringToIndex: [davURL length] - 1];
      else
        baseCardDAVURL = davURL;
      [baseCardDAVURL retain];
    }

  return baseCardDAVURL;
}

- (NSString *) cardDavURL
{
  return [NSString stringWithFormat: @"%@/", [self _baseCardDAVURL]];
}

- (NSString *) _basePublicCardDAVURL
{
  NSString *davURL;

  if (!basePublicCardDAVURL)
    {
      davURL = [[self publicDavURL] absoluteString];
      if ([davURL hasSuffix: @"/"])
        basePublicCardDAVURL = [davURL substringToIndex: [davURL length] - 1];
      else
        basePublicCardDAVURL = davURL;
      [basePublicCardDAVURL retain];
    }

  return basePublicCardDAVURL;
}

- (NSString *) publicCardDavURL
{
  return [NSString stringWithFormat: @"%@/", [self _basePublicCardDAVURL]];
}

@end /* SOGoContactGCSFolder */
