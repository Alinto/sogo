/* SOGoContactLDAPFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse groupe conseil
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
#import <EOControl/EOSortOrdering.h>
#import <SaxObjC/XMLNamespaces.h>

#import <SoObjects/SOGo/SOGoPermissions.h>
#import <SoObjects/SOGo/LDAPSource.h>
#import <SoObjects/SOGo/NSString+Utilities.h>
#import "SOGoContactLDIFEntry.h"
#import "SOGoContactLDAPFolder.h"

@class WOContext;

@implementation SOGoContactLDAPFolder

#warning this should be unified within SOGoFolder
- (void) appendObject: (NSDictionary *) object
          withBaseURL: (NSString *) baseURL
     toREPORTResponse: (WOResponse *) r
{
  SOGoContactLDIFEntry *component;
  NSString *name, *etagLine, *contactString;

  name = [object objectForKey: @"c_name"];
  component = [self lookupName: name inContext: context acquire: NO];

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
      entries = nil;
      ldapSource = nil;
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
      ASSIGN (displayName, newDisplayName);
    }

  return self;
}

- (void) dealloc
{
  [entries release];
  [ldapSource release];
  [super dealloc];
}

- (void) setLDAPSource: (LDAPSource *) newLDAPSource
{
  ASSIGN (ldapSource, newLDAPSource);
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
  id obj;
  NSDictionary *ldifEntry;

  //NSLog (@"looking up name '%@'...", objectName);

  /* first check attributes directly bound to the application */
  obj = [super lookupName: objectName inContext: lookupContext acquire: NO];

  if (!obj)
    {
      ldifEntry = [ldapSource lookupContactEntry: objectName];
      obj = ((ldifEntry)
	     ? [SOGoContactLDIFEntry contactEntryWithName: objectName
				     withLDIFEntry: ldifEntry
				     inContainer: self]
	     : [NSException exceptionWithHTTPStatus: 404]);
    }

  return obj;
}

- (NSArray *) toOneRelationshipKeys
{
  return [ldapSource allEntryIDs];
}

- (NSArray *) _flattenedRecords: (NSArray *) records
{
  NSMutableArray *newRecords;
  NSEnumerator *oldRecords;
  NSDictionary *oldRecord;
  NSMutableDictionary *newRecord;
  NSString *data;
  
  newRecords = [[NSMutableArray alloc] initWithCapacity: [records count]];
  [newRecords autorelease];

  oldRecords = [records objectEnumerator];
  oldRecord = [oldRecords nextObject];
  while (oldRecord)
    {
      newRecord = [NSMutableDictionary new];
      [newRecord autorelease];

      [newRecord setObject: [oldRecord objectForKey: @"c_uid"]
		 forKey: @"c_uid"];
      [newRecord setObject: [oldRecord objectForKey: @"c_name"]
		 forKey: @"c_name"];

      data = [oldRecord objectForKey: @"displayName"];
      if (!data)
	data = [oldRecord objectForKey: @"c_cn"];
      if (!data)
	data = @"";
      [newRecord setObject: data forKey: @"displayName"];

      data = [oldRecord objectForKey: @"mail"];
      if (!data)
	data = @"";
      [newRecord setObject: data forKey: @"mail"];

      data = [oldRecord objectForKey: @"nsAIMid"];
      if (![data length])
	data = [oldRecord objectForKey: @"nscpaimscreenname"];
      if (![data length])
	data = @"";
      [newRecord setObject: data forKey: @"screenName"];

      data = [oldRecord objectForKey: @"o"];
      if (!data)
	data = @"";
      [newRecord setObject: data forKey: @"org"];

      data = [oldRecord objectForKey: @"telephoneNumber"];
      if (![data length])
	data = [oldRecord objectForKey: @"cellphone"];
      if (![data length])
	data = [oldRecord objectForKey: @"homePhone"];
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
  NSArray *records, *result;
  EOSortOrdering *ordering;

  result = nil;

  if (filter && [filter length] > 0)
    {
      records = [self _flattenedRecords:
			[ldapSource fetchContactsMatching: filter]];
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
