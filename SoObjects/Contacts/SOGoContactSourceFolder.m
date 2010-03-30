/* SOGoContactSourceFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2009 Inverse inc.
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

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/SoObject.h>
#import <NGObjWeb/SoSelectorInvocation.h>
#import <NGObjWeb/SoUser.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <EOControl/EOSortOrdering.h>
#import <SaxObjC/XMLNamespaces.h>

#import <SOGo/SOGoPermissions.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>

#import "SOGoContactLDIFEntry.h"
#import "SOGoContactSourceFolder.h"

@class WOContext;

@implementation SOGoContactSourceFolder

#warning this should be unified within SOGoFolder
- (void) appendObject: (NSDictionary *) object
          withBaseURL: (NSString *) baseURL
     toREPORTResponse: (WOResponse *) r
{
  SOGoContactLDIFEntry *component;
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

      [r appendContentString: @"  <D:response>\r\n"];
      [r appendContentString: @"    <D:href>"];
      [r appendContentString: baseURL];
      if (![baseURL hasSuffix: @"/"])
	[r appendContentString: @"/"];
      [r appendContentString: name];
      [r appendContentString: @"</D:href>\r\n"];

      [r appendContentString: @"    <D:propstat>\r\n"];
      [r appendContentString: @"      <D:prop>\r\n"];
      etagLine = [NSString stringWithFormat: @"        <D:getetag>%@</D:getetag>\r\n",
                           [component davEntityTag]];
      [r appendContentString: etagLine];
      [r appendContentString: @"      </D:prop>\r\n"];
      [r appendContentString: @"      <D:status>HTTP/1.1 200 OK</D:status>\r\n"];
      [r appendContentString: @"    </D:propstat>\r\n"];
      [r appendContentString: @"    <C:addressbook-data>"];
      contactString = [[component contentAsString] stringByEscapingXMLString];
      [r appendContentString: contactString];
      [r appendContentString: @"</C:addressbook-data>\r\n"];
      [r appendContentString: @"  </D:response>\r\n"];
    }
}

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
      ASSIGN (displayName, newDisplayName);
    }

  return self;
}

- (void) dealloc
{
  [childRecords release];
  [source release];
  [super dealloc];
}

- (void) setSource: (id) newSource
{
  ASSIGN (source, newSource);
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

- (id) lookupName: (NSString *) objectName
        inContext: (WOContext *) lookupContext
          acquire: (BOOL) acquire
{
  NSDictionary *ldifEntry;
  id obj;

  /* first check attributes directly bound to the application */
  obj = [super lookupName: objectName inContext: lookupContext acquire: NO];

  if (!obj)
    {
      ldifEntry = [childRecords objectForKey: objectName];
      if (!ldifEntry)
        {
          ldifEntry = [source lookupContactEntry: objectName];
          [childRecords setObject: ldifEntry forKey: objectName];
        }
      if (ldifEntry)
        obj = [SOGoContactLDIFEntry contactEntryWithName: objectName
                                           withLDIFEntry: ldifEntry
                                             inContainer: self];
      else
        obj = [NSException exceptionWithHTTPStatus: 404];
    }

  return obj;
}

- (NSArray *) toOneRelationshipKeys
{
  return [source allEntryIDs];
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
  while ((oldRecord = [oldRecords nextObject]))
    {
      newRecord = [NSMutableDictionary new];
      [newRecord setObject: [oldRecord objectForKey: @"c_uid"]
		 forKey: @"c_uid"];
      [newRecord setObject: [oldRecord objectForKey: @"c_name"]
		 forKey: @"c_name"];

      data = [oldRecord objectForKey: @"displayname"];
      if (!data)
	data = [oldRecord objectForKey: @"c_cn"];
      if (!data)
	data = @"";
      [newRecord setObject: data forKey: @"c_cn"];

      data = [oldRecord objectForKey: @"mail"];
      if (!data)
	data = @"";
      [newRecord setObject: data forKey: @"c_mail"];

      data = [oldRecord objectForKey: @"nsaimid"];
      if (![data length])
	data = [oldRecord objectForKey: @"nscpaimscreenname"];
      if (![data length])
	data = @"";
      [newRecord setObject: data forKey: @"c_screenname"];

      data = [oldRecord objectForKey: @"o"];
      if (!data)
	data = @"";
      [newRecord setObject: data forKey: @"c_o"];

      data = [oldRecord objectForKey: @"telephonenumber"];
      if (![data length])
	data = [oldRecord objectForKey: @"cellphone"];
      if (![data length])
	data = [oldRecord objectForKey: @"homephone"];
      if (![data length])
	data = @"";
      [newRecord setObject: data forKey: @"c_telephonenumber"];

      // Custom attribute for group-lookups. See LDAPSource.m where
      // it's set.
      data = [oldRecord objectForKey: @"isGroup"];
      if (data)
	[newRecord setObject: data forKey: @"isGroup"];

      data = [oldRecord objectForKey: @"c_info"];
      if ([data length] > 0)
        [newRecord setObject: data forKey: @"contactInfo"];

      [newRecords addObject: newRecord];
      [newRecord release];
    }

  return newRecords;
}

- (NSArray *) lookupContactsWithFilter: (NSString *) filter
                                sortBy: (NSString *) sortKey
                              ordering: (NSComparisonResult) sortOrdering
{
  NSArray *records, *result;
  EOSortOrdering *ordering;

  result = nil;

  if (filter && [filter length] > 0)
    {
      records = [source fetchContactsMatching: filter];
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

- (NSString *) outlookFolderClass
{
  return @"IPF.Contact";
}

/* sorting */
- (NSComparisonResult) compare: (id) otherFolder
{
  NSComparisonResult comparison;

  if ([NSStringFromClass([otherFolder class])
			isEqualToString: @"SOGoContactGCSFolder"])
    comparison = NSOrderedDescending;
  else
    comparison
      = [[self displayName]
	  localizedCaseInsensitiveCompare: [otherFolder displayName]];

  return comparison;
}

/* acls */
- (NSString *) ownerInContext: (WOContext *) noContext
{
  return @"nobody";
}

- (NSArray *) subscriptionRoles
{
  return [NSArray arrayWithObject: SoRole_Authenticated];
}

/* TODO: this might change one day when we support LDAP acls */
- (NSArray *) aclsForUser: (NSString *) uid
{
  return nil;
}

@end
