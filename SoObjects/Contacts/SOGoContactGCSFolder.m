/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>
#import <NGExtensions/NSObject+Logs.h>
#import <EOControl/EOQualifier.h>
#import <EOControl/EOSortOrdering.h>
#import <GDLContentStore/GCSFolder.h>

#import <SoObjects/SOGo/NSDictionary+Utilities.h>
#import "SOGoContactGCSEntry.h"
#import "SOGoContactGCSFolder.h"

#define folderListingFields [NSArray arrayWithObjects: @"c_name", @"c_cn", \
                                     @"c_givenname", @"c_sn", @"c_screenname", \
				     @"c_o", @"c_mail", @"c_telephonenumber", \
                                     nil]

@implementation SOGoContactGCSFolder

- (BOOL) folderIsMandatory
{
  return [nameInContainer isEqualToString: @"personal"];
}

/* name lookup */

- (id <SOGoContactObject>) lookupContactWithId: (NSString *) recordId
{
  SOGoContactGCSEntry *contact;

  if ([recordId length] > 0)
    contact = [SOGoContactGCSEntry objectWithName: recordId
                                   inContainer: self];
  else
    contact = nil;

  return contact;
}

- (id) lookupName: (NSString *) _key
        inContext: (WOContext *) _ctx
          acquire: (BOOL) _flag
{
  id obj;
  BOOL isPut;

  isPut = NO;
  obj = [super lookupName:_key inContext:_ctx acquire:NO];
  if (!obj)
    {
      if ([[[_ctx request] method] isEqualToString: @"PUT"])
	{
	  if ([_key isEqualToString: @"PUT"])
	    isPut = YES;
	  else
	    obj = [SOGoContactGCSEntry objectWithName: _key
				       inContainer: self];
	}
      else
        obj = [self lookupContactWithId: _key];
    }
//   if (!(obj || isPut))
//     obj = [NSException exceptionWithHTTPStatus:404 /* Not Found */];

// #if 0
//     if ([[self ocsFolder] versionOfContentWithName:_key])
// #endif
//       return [self contactWithName:_key inContext:_ctx];
//   }

  /* return 404 to stop acquisition */
  return obj;
}

/* fetching */
- (EOQualifier *) _qualifierForFilter: (NSString *) filter
{
  NSString *qs;
  EOQualifier *qualifier;

  if (filter && [filter length] > 0)
    {
      qs = [NSString stringWithFormat:
                       @"(c_sn isCaseInsensitiveLike: '%@%%') OR "
                     @"(c_givenname isCaseInsensitiveLike: '%@%%') OR "
                     @"(c_mail isCaseInsensitiveLike: '%@%%') OR "
                     @"(c_telephonenumber isCaseInsensitiveLike: '%%%@%%')",
                     filter, filter, filter, filter];
      qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
    }
  else
    qualifier = nil;

  return qualifier;
}

- (NSArray *) _flattenedRecords: (NSArray *) records
{
  NSMutableArray *newRecords;
  NSEnumerator *oldRecords;
  NSDictionary *oldRecord;
  NSMutableDictionary *newRecord;
  NSString *data;
  
  newRecords = [NSMutableArray arrayWithCapacity: [records count]];

  oldRecords = [records objectEnumerator];
  oldRecord = [oldRecords nextObject];
  while (oldRecord)
    {
      newRecord = [NSMutableDictionary new];
      [newRecord autorelease];

      [newRecord setObject: [oldRecord objectForKey: @"c_name"]
		 forKey: @"c_uid"];
      [newRecord setObject: [oldRecord objectForKey: @"c_name"]
		 forKey: @"c_name"];

      data = [oldRecord objectForKey: @"c_cn"];
      if (![data length])
	data = [oldRecord keysWithFormat: @"%{c_givenname} %{c_sn}"];
      [newRecord setObject: data
		 forKey: @"displayName"];

      data = [oldRecord objectForKey: @"c_mail"];
      if (!data)
	data = @"";
      [newRecord setObject: data forKey: @"mail"];

      data = [oldRecord objectForKey: @"c_screenname"];
      if (!data)
	data = @"";
      [newRecord setObject: data forKey: @"screenName"];

      data = [oldRecord objectForKey: @"c_o"];
      if (!data)
	data = @"";
      [newRecord setObject: data forKey: @"org"];

      data = [oldRecord objectForKey: @"c_telephonenumber"];
      if (![data length])
	data = @"";
      [newRecord setObject: data forKey: @"phone"];

      [newRecords addObject: newRecord];
      oldRecord = [oldRecords nextObject];
    }

  return newRecords;
}

- (NSArray *) lookupContactsWithFilter: (NSString *) filter
                                sortBy: (NSString *) sortKey
                              ordering: (NSComparisonResult) sortOrdering
{
  NSArray *fields, *dbRecords, *records;
  EOQualifier *qualifier;
  EOSortOrdering *ordering;

//   NSLog (@"fetching records matching '%@', sorted by '%@' in order %d",
//          filter, sortKey, sortOrdering);

  fields = folderListingFields;
  qualifier = [self _qualifierForFilter: filter];
  dbRecords = [[self ocsFolder] fetchFields: fields
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
//   else
//     [self errorWithFormat:@"(%s): fetch failed!", __PRETTY_FUNCTION__];

  //[self debugWithFormat:@"fetched %i records.", [records count]];
  return records;
}

- (NSArray *) davNamespaces
{
  return [NSArray arrayWithObject: @"urn:ietf:params:xml:ns:carddav"];
}

- (NSArray *) davComplianceClassesInContext: (id)_ctx
{
  NSMutableArray *classes;
  NSArray *primaryClasses;

  classes = [NSMutableArray new];
  [classes autorelease];

  primaryClasses = [super davComplianceClassesInContext: _ctx];
  if (primaryClasses)
    [classes addObjectsFromArray: primaryClasses];
  [classes addObject: @"access-control"];
  [classes addObject: @"addressbook-access"];

  return classes;
}

- (NSString *) groupDavResourceType
{
  return @"vcard-collection";
}

// /* GET */

// - (id) GETAction: (id)_ctx
// {
//   // TODO: I guess this should really be done by SOPE (redirect to
//   //       default method)
//   WOResponse *r;
//   NSString *uri;

//   uri = [[_ctx request] uri];
//   if (![uri hasSuffix:@"/"]) uri = [uri stringByAppendingString:@"/"];
//   uri = [uri stringByAppendingString:@"view"];
  
//   r = [_ctx response];
//   [r setStatus:302 /* moved */];
//   [r setHeader:uri forKey:@"location"];
//   return r;
// }

/* folder type */

- (NSString *) folderType
{
  return @"Contact";
}

- (NSString *) outlookFolderClass
{
  return @"IPF.Contact";
}

@end /* SOGoContactGCSFolder */
