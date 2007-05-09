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
#import <NGObjWeb/SoObject.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/SoUser.h>
#import <EOControl/EOSortOrdering.h>

#import <SoObjects/SOGo/LDAPSource.h>
#import "SOGoContactLDIFEntry.h"
#import "SOGoContactLDAPFolder.h"

#define folderListingFields [NSArray arrayWithObjects: @"c_name", @"cn", \
                                     @"displayName",                     \
                                     @"streetAddress",                   \
                                     @"o", \
                                     @"sn", @"givenname", @"l",          \
                                     @"mail", @"telephonenumber",        \
                                     @"mailNickname",                    \
                                     @"sAMAccountName",                  \
                                     @"uid",                  \
                                     nil]

@class WOContext;

@implementation SOGoContactLDAPFolder

+ (id <SOGoContactFolder>) contactFolderWithName: (NSString *) aName
                                  andDisplayName: (NSString *) aDisplayName
                                     inContainer: (SOGoObject *) aContainer
{
  SOGoContactLDAPFolder *folder;

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
      name = nil;
      displayName = nil;
      container = nil;
      entries = nil;
      ldapSource = nil;
    }

  return self;
}

- (id <SOGoContactFolder>) initWithName: (NSString *) newName
                         andDisplayName: (NSString *) newDisplayName
                            inContainer: (SOGoObject *) newContainer
{
  self = [self init];

  ASSIGN (name, newName);
  ASSIGN (displayName, newDisplayName);
  ASSIGN (container, newContainer);

  return self;
}

- (void) dealloc
{
  [name release];
  [displayName release];
  [container release];
  [entries release];
  [ldapSource release];
  [super dealloc];
}

- (void) setLDAPSource: (LDAPSource *) newLDAPSource
{
  ASSIGN (ldapSource, newLDAPSource);
}

- (NSString *) displayName
{
  return displayName;
}

- (NSString *) nameInContainer
{
  return name;
}

- (id) lookupName: (NSString *) objectName
        inContext: (WOContext *) lookupContext
          acquire: (BOOL) acquire
{
  id obj;
  NSDictionary *ldifEntry;

//   NSLog (@"looking up name '%@'...", name);

  /* first check attributes directly bound to the application */
  obj = [super lookupName: objectName inContext: lookupContext acquire: NO];
  if (!obj)
    {
      ldifEntry = [ldapSource lookupContactEntry: objectName];
      obj = ((ldifEntry)
	     ? [SOGoContactLDIFEntry contactEntryWithName: name
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

- (NSArray *) lookupContactsWithFilter: (NSString *) filter
                                sortBy: (NSString *) sortKey
                              ordering: (NSComparisonResult) sortOrdering
{
  NSArray *records, *result;
  EOSortOrdering *ordering;

  result = nil;

  if (filter && [filter length] > 0)
    {
      records = [ldapSource fetchContactsMatching: filter];
      ordering
        = [EOSortOrdering sortOrderingWithKey: sortKey
                          selector: ((sortOrdering == NSOrderedDescending)
                                     ? EOCompareCaseInsensitiveDescending
                                     : EOCompareCaseInsensitiveAscending)];
      result
        = [records sortedArrayUsingKeyOrderArray:
                     [NSArray arrayWithObject: ordering]];
    }

  //[self debugWithFormat:@"fetched %i records.", [records count]];
  return result;
}

- (NSString *) groupDavResourceType
{
  return @"vcard-collection";
}

/* acls */
/* TODO: this might change one day when we support LDAP acls */
- (NSArray *) aclsForUser: (NSString *) uid
{
  return nil;
}

@end
