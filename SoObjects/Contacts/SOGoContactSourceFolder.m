/* SOGoContactSourceFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2011 Inverse inc.
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
#import <Foundation/NSValue.h>

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

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoSource.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/WORequest+SOGo.h>

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
          ldifEntry = [source lookupContactEntry: objectName];
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
  return [source allEntryIDs];
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

- (NSDictionary *) _flattenedRecord: (NSDictionary *) oldRecord
{
  NSMutableDictionary *newRecord;
  id data;
  NSObject <SOGoSource> *recordSource;

  newRecord = [NSMutableDictionary dictionaryWithCapacity: 8];
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
  else if ([data isKindOfClass: [NSArray class]])
    {
      if ([data count] > 0)
        data = [data objectAtIndex: 0];
      else
        data = @"";
    }
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
    {
      [newRecord setObject: data forKey: @"isGroup"];
      [newRecord setObject: @"vlist" forKey: @"c_component"];
    }
#warning TODO: create a custom icon for resources
  else
    {
      [newRecord setObject: @"vcard" forKey: @"c_component"];
    }
  
  data = [oldRecord objectForKey: @"c_info"];
  if ([data length] > 0)
    [newRecord setObject: data forKey: @"contactInfo"];

  recordSource = [oldRecord objectForKey: @"source"];
  if ([recordSource conformsToProtocol: @protocol (SOGoDNSource)] &&
      [[(NSObject <SOGoDNSource>*) recordSource MSExchangeHostname] length])
    [newRecord setObject: [NSNumber numberWithInt: 1] forKey: @"isMSExchange"];
  
  return newRecord;
}

- (NSArray *) _flattenedRecords: (NSArray *) records
{
  NSMutableArray *newRecords;
  NSEnumerator *oldRecords;
  NSDictionary *oldRecord;

  newRecords = [NSMutableArray arrayWithCapacity: [records count]];

  oldRecords = [records objectEnumerator];
  while ((oldRecord = [oldRecords nextObject]))
    [newRecords addObject: [self _flattenedRecord: oldRecord]];

  return newRecords;
}

/* This method returns the entry corresponding to the name passed as
   parameter. */
- (NSDictionary *) lookupContactWithName: (NSString *) aName
{
  NSDictionary *record;

  if (aName && [aName length] > 0)
    record = [self _flattenedRecord: [source lookupContactEntry: aName]];
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
                     || ([otherFolder isKindOfClass: isa] && [otherFolder isPersonalSource]));

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
