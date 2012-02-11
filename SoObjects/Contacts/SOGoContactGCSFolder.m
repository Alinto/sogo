/*
  Copyright (C) 2006-2011 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

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
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSArray.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <SaxObjC/XMLNamespaces.h>
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
                                           @"c_component", nil];
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

  qualifier = [EOQualifier qualifierWithQualifierFormat:@"c_name = %@", name];
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

- (EOQualifier *) _qualifierForFilter: (NSString *) filter
                           onCriteria: (NSString *) criteria
{
  NSString *qs;
  EOQualifier *qualifier;

  if ([filter length] > 0)
    {
      filter = [[filter stringByReplacingString: @"\\"  withString: @"\\\\"]
                     stringByReplacingString: @"'"  withString: @"\\'\\'"];
      if ([criteria isEqualToString: @"name_or_address"])
        qs = [NSString stringWithFormat:
                         @"(c_sn isCaseInsensitiveLike: '%%%@%%') OR "
                       @"(c_givenname isCaseInsensitiveLike: '%%%@%%') OR "
                       @"(c_cn isCaseInsensitiveLike: '%%%@%%') OR "
                       @"(c_mail isCaseInsensitiveLike: '%%%@%%')",
                       filter, filter, filter, filter];
      else if ([criteria isEqualToString: @"category"])
        qs = [NSString stringWithFormat:
                         @"(c_categories isCaseInsensitiveLike: '%%%@%%')",
                       filter];
      else
        qs = @"(1 == 0)";

      if (qs)
        qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
      else
        qualifier = nil;
    }
  else
    qualifier = nil;

  return qualifier;
}

- (void) fixupContactRecord: (NSMutableDictionary *) contactRecord
{
  NSString *data;

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

  if (![contactRecord objectForKey: @"c_mail"])
    [contactRecord setObject: @"" forKey: @"c_mail"];
  if (![contactRecord objectForKey: @"c_screenname"])
    [contactRecord setObject: @"" forKey: @"c_screenname"];
  if (![contactRecord objectForKey: @"c_o"])
    [contactRecord setObject: @"" forKey: @"c_o"];
  if (![contactRecord objectForKey: @"c_telephonenumber"])
    [contactRecord setObject: @"" forKey: @"c_telephonenumber"];
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
      aName = [[aName stringByReplacingString: @"\\"  withString: @"\\\\"]
                 stringByReplacingString: @"'"  withString: @"\\'\\'"];
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
                            onCriteria: (NSString *) criteria
                                sortBy: (NSString *) sortKey
                              ordering: (NSComparisonResult) sortOrdering
                              inDomain: (NSString *) domain
{
  NSArray *dbRecords, *records;
  EOQualifier *qualifier;
  EOSortOrdering *ordering;

  qualifier = [self _qualifierForFilter: filter onCriteria: criteria];
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

@end /* SOGoContactGCSFolder */
