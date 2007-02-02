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
#import <Foundation/NSString.h>

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/SoUser.h>

#import <NGLdap/NGLdapAttribute.h>
#import <NGLdap/NGLdapConnection.h>
#import <NGLdap/NGLdapEntry.h>

#import "common.h"

#import "NGLdapEntry+Contact.h"

#import "SOGoContactLDAPEntry.h"
#import "SOGoContactLDAPFolder.h"

#define folderListingFields [NSArray arrayWithObjects: @"c_name", @"cn", \
                                     @"displayName",                     \
                                     @"streetAddress",                   \
                                     @"sn", @"givenname", @"l",          \
                                     @"mail", @"telephonenumber",        \
                                     @"mailNickname",                    \
                                     @"sAMAccountName",                  \
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
      connection = nil;
      contactIdentifier = nil;
      userIdentifier = nil;
      rootDN = nil;
      entries = nil;
    }

  return self;
}

- (id <SOGoContactFolder>) initWithName: (NSString *) aName
                         andDisplayName: (NSString *) aDisplayName
                            inContainer: (SOGoObject *) aContainer
{
  if ((self = [self initWithName: aName
                    inContainer: aContainer]))
    [self setDisplayName: aDisplayName];

  return self;
}

- (void) dealloc
{
  if (connection)
    {
      if ([connection isBound])
        [connection unbind];
      [connection release];
    }
  if (contactIdentifier)
    [contactIdentifier release];
  if (userIdentifier)
    [userIdentifier release];
  if (rootDN)
    [rootDN release];
  if (entries)
    [entries release];
  [super dealloc];
}

- (void) setDisplayName: (NSString *) aDisplayName
{
  if (displayName)
    [displayName release];
  displayName = aDisplayName;
  if (displayName)
    [displayName retain];
}

- (NSString *) displayName
{
  return displayName;
}

- (void) LDAPSetHostname: (NSString *) aHostname
                 setPort: (int) aPort
               setBindDN: (NSString *) aBindDN
               setBindPW: (NSString *) aBindPW
    setContactIdentifier: (NSString *) aCI
       setUserIdentifier: (NSString *) aUI
               setRootDN: (NSString *) aRootDN;
{
  connection = [[NGLdapConnection alloc] initWithHostName: aHostname
                                         port: aPort];
  [connection bindWithMethod: nil
              binddn: aBindDN
              credentials: aBindPW];

  if (rootDN)
    [rootDN release];
  rootDN = [aRootDN copy];
  if (contactIdentifier)
    [contactIdentifier release];
  contactIdentifier = [aCI copy];
  if (userIdentifier)
    [userIdentifier release];
  userIdentifier = [aUI copy];
}

- (NGLdapConnection *) LDAPconnection
{
  return connection;
}

- (NGLdapAttribute *) _attrWithName: (NSString *) aName
{
  return [[[NGLdapAttribute alloc] initWithAttributeName: aName] autorelease];
}

- (NSArray *) _searchAttributes
{
  return [NSArray arrayWithObjects:
                    contactIdentifier,
                  userIdentifier,
                  @"title",
                  @"company",
                  @"o",
                  @"displayName",
                  @"modifytimestamp",
                  @"mozillaHomeState",
                  @"mozillaHomeUrl",
                  @"homeurl",
                  @"st",
                  @"region",
                  @"mozillaCustom2",
                  @"custom2",
                  @"mozillaHomeCountryName",
                  @"description",
                  @"notes",
                  @"department",
                  @"departmentnumber",
                  @"ou",
                  @"orgunit",
                  @"mobile",
                  @"cellphone",
                  @"carphone",
                  @"mozillaCustom1",
                  @"custom1",
                  @"mozillaNickname",
                  @"xmozillanickname",
                  @"mozillaWorkUrl",
                  @"workurl",
                  @"fax",
                  @"facsimileTelephoneNumber",
                  @"telephoneNumber",
                  @"mozillaHomeStreet",
                  @"mozillaSecondEmail",
                  @"xmozillasecondemail",
                  @"mozillaCustom4",
                  @"custom4",
                  @"nsAIMid",
                  @"nscpaimscreenname",
                  @"street",
                  @"streetAddress",
                  @"postOfficeBox",
                  @"homePhone",
                  @"cn",
                  @"commonname",
                  @"givenName",
                  @"mozillaHomePostalCode",
                  @"mozillaHomeLocalityName",
                  @"mozillaWorkStreet2",
                  @"mozillaUseHtmlMail",
                  @"xmozillausehtmlmail",
                  @"mozillaHomeStreet2",
                  @"postalCode",
                  @"zip",
                  @"c",
                  @"countryname",
                  @"pager",
                  @"pagerphone",
                  @"mail",
                  @"sn",
                  @"surname",
                  @"mozillaCustom3",
                  @"custom3",
                  @"l",
                  @"locality",
                  @"birthyear",
                  @"serialNumber",
                  @"calFBURL",
                  nil];
}

- (void) _loadEntries: (NSString *) entryId
{
  NSEnumerator *contacts;
  NGLdapEntry *entry;
  NSString *key;

  if (!entries)
    entries = [NSMutableDictionary new];

  if (entryId)
    {
      if (![entries objectForKey: entryId])
        {
          entry
            = [connection entryAtDN:
                            [NSString stringWithFormat: @"%@=%@,%@",
                                      contactIdentifier, entryId, rootDN]
                          attributes: [self _searchAttributes]];
          if (entry)
            [entries setObject: entry forKey: entryId];
        }
    }
  else
    {
      contacts = [connection deepSearchAtBaseDN: rootDN
                             qualifier: nil
                             attributes: [self _searchAttributes]];
      if (contacts)
        {
          entry = [contacts nextObject];
          while (entry)
            {
              key = [[entry attributeWithName: contactIdentifier]
                      stringValueAtIndex: 0];
              if (key && ![entries objectForKey: key])
                [entries setObject: entry forKey: key];
              entry = [contacts nextObject];
            }
        }
    }
}

- (id) lookupName: (NSString *) name
        inContext: (WOContext *) context
          acquire: (BOOL) acquire
{
  id obj;
  NGLdapEntry *entry;

//   NSLog (@"looking up name '%@'...", name);

  /* first check attributes directly bound to the application */
  obj = [super lookupName: name inContext: context acquire: NO];
  if (!obj)
    {
      [self _loadEntries: name];
      entry = [entries objectForKey: name];
      obj = ((entry)
             ? [SOGoContactLDAPEntry contactEntryWithName: name
                                     withLDAPEntry: entry
                                     inContainer: self]
             : [NSException exceptionWithHTTPStatus: 404]);
    }

  return obj;
}

- (NSArray *) toOneRelationshipKeys
{
  [self _loadEntries: nil];

  return [entries allKeys];
}

- (id <SOGoContactObject>) lookupContactWithId: (NSString *) recordId
{
  NGLdapEntry *entry;

  [self _loadEntries: recordId];

  entry = [entries objectForKey: recordId];
  return ((entry)
          ? [SOGoContactLDAPEntry contactEntryWithName: recordId
                                  withLDAPEntry: entry
                                  inContainer: self]
          : nil);
}

- (EOQualifier *) _qualifierForFilter: (NSString *) filter
{
  NSString *qs;
  EOQualifier *qualifier;

  if (filter && [filter length] > 0)
    {
      qs = [NSString stringWithFormat:
                       @"(cn='%@*')"
                     @"OR (sn='%@*')"
                     @"OR (displayName='%@*')"
                     @"OR (mail='%@*')"
                     @"OR (telephoneNumber='*%@*')",
                     filter, filter, filter, filter, filter];
      qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
    }
  else
    qualifier = nil;

  return qualifier;
}

- (NSArray *) lookupContactsWithFilter: (NSString *) filter
                                sortBy: (NSString *) sortKey
                              ordering: (NSComparisonResult) sortOrdering
{
  NSMutableArray *records;
  NSArray *result;
  NGLdapEntry *entry;
  NSEnumerator *contacts;
  EOSortOrdering *ordering;

  result = nil;

  if (filter && [filter length] > 0)
    {
//       NSLog (@"%@: fetching records matching '*%@*', sorted by '%@'"
//              @" in order %d",
//              self, filter, sortKey, sortOrdering);

      records = [NSMutableArray new];
      [records autorelease];

      contacts = [connection deepSearchAtBaseDN: rootDN
                             qualifier: [self _qualifierForFilter: filter]
                             attributes: folderListingFields];
      entry = [contacts nextObject];
      while (entry)
        {
          [records addObject: [entry asDictionaryWithAttributeNames: nil
                                     withUID: userIdentifier
                                     andCName: contactIdentifier]];
          entry = [contacts nextObject];
        }

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

@end
