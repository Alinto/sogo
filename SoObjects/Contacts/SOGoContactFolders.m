/* SOGoContactFolders.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2013 Inverse inc.
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

#import <Foundation/NSSortDescriptor.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <DOM/DOMElement.h>

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/NSURL+GCS.h>
#import <GDLAccess/EOAdaptorChannel.h>

#import <SOGo/NSObject+DAV.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/WORequest+SOGo.h>

#import "SOGoContactGCSFolder.h"
#import "SOGoContactSourceFolder.h"

#import "SOGoContactFolders.h"

Class SOGoContactSourceFolderK;

#define XMLNS_INVERSEDAV @"urn:inverse:params:xml:ns:inverse-dav"

@implementation SOGoContactFolders

+ (void) initialize
{
  SOGoContactSourceFolderK = [SOGoContactSourceFolder class];
}

+ (NSString *) gcsFolderType
{
  return @"Contact";
}

+ (Class) subFolderClass
{
  return [SOGoContactGCSFolder class];
}

- (void) _fetchLDAPAddressBooks: (id <SOGoSource>) source
{
  id <SOGoSource> abSource;
  SOGoContactSourceFolder *folder;
  NSArray *abSources;
  NSUInteger count, max;
  NSString *name;

  abSources = [source addressBookSourcesForUser: owner];
  max = [abSources count];
  for (count = 0; count < max; count++)
    {
      abSource = [abSources objectAtIndex: count];
      name = [abSource sourceID];
      folder = [SOGoContactSourceFolder folderWithName: name
                                        andDisplayName: [abSource displayName]
                                           inContainer: self];
      [folder setSource: abSource];
      [folder setIsPersonalSource: YES];
      [subFolders setObject: folder forKey: name];
    }
}

- (NSException *) appendPersonalSources
{
  SOGoUser *currentUser;
  NSException *result;
  id <SOGoSource> source;

  currentUser = [context activeUser];
  source = [currentUser authenticationSource];
  if ([source hasUserAddressBooks])
    {
      result = nil;
      /* We don't handle ACLs for user LDAP addressbooks yet, therefore only
         the owner has access to his addressbooks. */
      if (activeUserIsOwner
          || [[currentUser login] isEqualToString: owner])
        {
          [self _fetchLDAPAddressBooks: source];
          if (![subFolders objectForKey: @"personal"])
            {
              result = [source addAddressBookSource: @"personal"
                                    withDisplayName: [self defaultFolderName]
                                            forUser: owner];
              if (!result)
                [self _fetchLDAPAddressBooks: source];
            }
        }
    }
  else
    result = [super appendPersonalSources];

  return result;
}

- (NSException *) appendCollectedSources
{
  GCSChannelManager *cm;
  EOAdaptorChannel *fc;
  NSURL *folderLocation;
  NSString *sql, *gcsFolderType;
  NSException *error;
  
  cm = [GCSChannelManager defaultChannelManager];
  folderLocation = [[GCSFolderManager defaultFolderManager] folderInfoLocation];
  fc = [cm acquireOpenChannelForURL: folderLocation];
  if ([fc isOpen])
  {
    gcsFolderType = [[self class] gcsFolderType];
    
    sql = [NSString stringWithFormat: (@"SELECT c_path4 FROM %@"
                                       @" WHERE c_path2 = '%@'"
                                       @" AND c_folder_type = '%@'"),
           [folderLocation gcsTableName], owner, gcsFolderType];
    
    error = [super fetchSpecialFolders: sql withChannel: fc andFolderType: SOGoCollectedFolder];
    
    [cm releaseChannel: fc];
  }
  else
    error = [NSException exceptionWithName: @"SOGoDBException"
                                    reason: @"database connection could not be open"
                                  userInfo: nil];
  
  return error;
}

- (NSDictionary *) systemSources
{
  NSMutableDictionary *systemSources;
  SOGoUserManager *um;
  SOGoSystemDefaults *sd;
  NSEnumerator *sourceIDs, *domains;
  NSString *currentSourceID, *srcDisplayName, *domain;
  SOGoContactSourceFolder *currentFolder;
  SOGoUser *currentUser;

  systemSources = [NSMutableDictionary dictionary];

  if (! ([[context request] isIPhoneAddressBookApp] &&
           ![[context request] isAndroid]))
    {
      currentUser = [context activeUser];
      if (activeUserIsOwner
          || [[currentUser login] isEqualToString: owner])
        {
          domain = [currentUser domain];
          um = [SOGoUserManager sharedUserManager];
          sd = [SOGoSystemDefaults sharedSystemDefaults];
          domains = [[sd visibleDomainsForDomain: domain] objectEnumerator];
          while (domain)
            {
              sourceIDs = [[um addressBookSourceIDsInDomain: domain]
                            objectEnumerator];
              while ((currentSourceID = [sourceIDs nextObject]))
                {
                  srcDisplayName
                    = [um displayNameForSourceWithID: currentSourceID];
                  currentFolder = [SOGoContactSourceFolder
                                    folderWithName: currentSourceID
                                    andDisplayName: srcDisplayName
                                       inContainer: self];
                  [currentFolder setSource: [um sourceWithID: currentSourceID]];
                  [systemSources setObject: currentFolder forKey: currentSourceID];
                }
              domain = [domains nextObject];
            }
        }
    }

  return systemSources;
}

- (NSException *) appendSystemSources
{
  [subFolders addEntriesFromDictionary: [self systemSources]];

  return nil;
}

- (NSException *) newFolderWithName: (NSString *) name
		 andNameInContainer: (NSString *) newNameInContainer
{
  SOGoUser *currentUser;
  NSException *result;
  id <SOGoSource> source;

  currentUser = [context activeUser];
  source = [currentUser authenticationSource];
  if ([source hasUserAddressBooks])
    {
      result = nil;
      /* We don't handle ACLs for user LDAP addressbooks yet, therefore only
         the owner has access to his addressbooks. */
      if (activeUserIsOwner
          || [[currentUser login] isEqualToString: owner])
        {
          result = [source addAddressBookSource: newNameInContainer
                                withDisplayName: name
                                        forUser: owner];
          if (!result)
            [self _fetchLDAPAddressBooks: source];
        }
    }
  else
    result = [super newFolderWithName: name
                   andNameInContainer: newNameInContainer];

  return result;
}

- (NSException *) renameLDAPAddressBook: (NSString *) sourceID
                        withDisplayName: (NSString *) newDisplayName
{
  NSException *result;
  SOGoUser *currentUser;
  id <SOGoSource> source;

  currentUser = [context activeUser];
  source = [currentUser authenticationSource];
  /* We don't handle ACLs for user LDAP addressbooks yet, therefore only
     the owner has access to his addressbooks. */
  if (activeUserIsOwner
      || [[currentUser login] isEqualToString: owner])
    result = [source renameAddressBookSource: sourceID
                             withDisplayName: newDisplayName
                                       forUser: owner];
  else
    result = [NSException exceptionWithHTTPStatus: 403
                                           reason: @"operation denied"];

  return result;
}

- (NSException *) removeLDAPAddressBook: (NSString *) sourceID
{
  NSException *result;
  SOGoUser *currentUser;
  id <SOGoSource> source;

  if ([sourceID isEqualToString: @"personal"]){
    result = [NSException exceptionWithHTTPStatus: 403 reason: [NSString stringWithFormat: (@"folder '%@' cannot be deleted"), sourceID]];
  }
  else
    {
      result = nil;
      currentUser = [context activeUser];
      source = [currentUser authenticationSource];
      /* We don't handle ACLs for user LDAP addressbooks yet, therefore only
         the owner has access to his addressbooks. */
      if (activeUserIsOwner
          || [[currentUser login] isEqualToString: owner])
        result = [source removeAddressBookSource: sourceID
                                         forUser: owner];
      else
        result = [NSException exceptionWithHTTPStatus: 403
                                               reason: @"operation denied"];
    }

  return result;
}
  
- (NSString *) defaultFolderName
{
  return [self labelForKey: @"Personal Address Book"];
}

- (NSString *) collectedFolderName
{
  return [self labelForKey: @"Collected Address Book"];
}

- (NSArray *) toManyRelationshipKeys
{
  NSMutableArray *keys;

  if ([[context request] isMacOSXAddressBookApp])
    keys = [NSMutableArray arrayWithObject: @"personal"];
  else
    keys = (NSMutableArray *) [super toManyRelationshipKeys];

  return keys;
}

- (id) lookupName: (NSString *) name
        inContext: (WOContext *) lookupContext
          acquire: (BOOL) acquire
{
  id folder = nil;
  SOGoUser *currentUser;
  SOGoUserManager *um;
  SOGoSystemDefaults *sd;
  NSEnumerator *domains;
  NSArray *sourceIDs;
  NSString *domain, *srcDisplayName;

  if ([[context request] isIPhoneAddressBookApp] &&
      ![[context request] isAndroid])
    {
      currentUser = [context activeUser];
      if (activeUserIsOwner
          || [[currentUser login] isEqualToString: owner])
        {
          domain = [currentUser domain];
          um = [SOGoUserManager sharedUserManager];
          sd = [SOGoSystemDefaults sharedSystemDefaults];
          domains = [[sd visibleDomainsForDomain: domain] objectEnumerator];
          while (domain)
            {
              sourceIDs = [um addressBookSourceIDsInDomain: domain];
              if ([sourceIDs containsObject: name])
                {
                  srcDisplayName = [um displayNameForSourceWithID: name];
                  folder = [SOGoContactSourceFolder
                             folderWithName: name
                             andDisplayName: srcDisplayName
                                inContainer: self];
                  [folder setSource: [um sourceWithID: name]];
                }
              domain = [domains nextObject];
            }
        }
    }

  if (!folder)
    folder = [super lookupName: name inContext: lookupContext
                    acquire: acquire];

  return folder;
}

- (NSException *) setDavContactsCategories: (NSString *) newCategories
{
  SOGoUser *ownerUser;
  NSMutableArray *categories;
  id <DOMElement> documentElement, catNode;
  id <DOMDocument> document;
  id <DOMNodeList> catNodes;
  NSUInteger count, max;
  SOGoUserDefaults *ud;

  categories = [NSMutableArray array];

  if ([newCategories length] > 0)
    {
      document = [[context request] contentAsDOMDocument];
      documentElement = [document documentElement];
      catNodes = [documentElement getElementsByTagName: @"category"];
      max = [catNodes length];
      for (count = 0; count < max; count++)
        {
          catNode = [catNodes objectAtIndex: count];
          if ([catNode hasChildNodes])
            [categories addObject: [(NGDOMNode *) catNode textValue]];
        }
    }

  // NSLog (@"setting categories to : %@", categories);
  ownerUser = [SOGoUser userWithLogin: owner];
  ud = [ownerUser userDefaults];
  [ud setContactsCategories: categories];
  [ud synchronize];

  return nil;
}

- (SOGoWebDAVValue *) davContactsCategories
{
  NSMutableArray *davCategories;
  NSArray *categories;
  NSUInteger count, max;
  SOGoUser *ownerUser;
  NSDictionary *catElement;

  ownerUser = [SOGoUser userWithLogin: owner];
  categories = [[ownerUser userDefaults] contactsCategories];

  max = [categories count];
  davCategories = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      catElement = davElementWithContent (@"category",
                                          XMLNS_INVERSEDAV,
                                          [categories objectAtIndex: count]);
      [davCategories addObject: catElement];
    }

  return [davElementWithContent (@"contacts-categories",
                                 XMLNS_INVERSEDAV,
                                 davCategories)
                                asWebDAVValue];
}

- (NSArray *) allContactsFromFilter: (NSString *) theFilter
                      excludeGroups: (BOOL) excludeGroups
                       excludeLists: (BOOL) excludeLists
{
  SOGoFolder <SOGoContactFolder> *folder;
  NSString *mail, *domain;
  NSArray *folders, *contacts, *descriptors, *sortedContacts;
  NSMutableArray *sortedFolders;
  NSMutableDictionary *contact, *uniqueContacts;
  unsigned int i, j, max;
  NSSortDescriptor *commonNameDescriptor;

  // NSLog(@"Search all contacts: %@", searchText);

  domain = [[context activeUser] domain];
  folders = nil;
  NS_DURING
  folders = [self subFolders];
  NS_HANDLER
  /* We need to specifically test for @"SOGoDBException", which is
   raised explicitly in SOGoParentFolder. Any other exception should
   be re-raised. */
  if ([[localException name] isEqualToString: @"SOGoDBException"])
  folders = nil;
  else
  [localException raise];
  NS_ENDHANDLER;
  max = [folders count];
  sortedFolders = [NSMutableArray arrayWithCapacity: max];
  uniqueContacts = [NSMutableDictionary dictionary];
  for (i = 0; i < max; i++)
  {
    folder = [folders objectAtIndex: i];
	  /* We first search in LDAP folders (in case of duplicated entries in GCS folders) */
    if ([folder isKindOfClass: SOGoContactSourceFolderK])
    [sortedFolders insertObject: folder atIndex: 0];
    else
    [sortedFolders addObject: folder];
  }
  for (i = 0; i < max; i++)
  {
    folder = [sortedFolders objectAtIndex: i];
    //NSLog(@"  Address book: %@ (%@)", [folder displayName], [folder class]);
    contacts = [folder lookupContactsWithFilter: theFilter
                                     onCriteria: nil
                                         sortBy: @"c_cn"
                                       ordering: NSOrderedAscending
                                       inDomain: domain];
    for (j = 0; j < [contacts count]; j++)
    {
      contact = [contacts objectAtIndex: j];
      mail = [contact objectForKey: @"c_mail"];
      //NSLog(@"   found %@ (%@) ? %@", [contact objectForKey: @"c_name"], mail,
      //      [contact description]);
      if (!excludeLists && [[contact objectForKey: @"c_component"]
                            isEqualToString: @"vlist"])
      {
        [contact setObject: [folder nameInContainer]
                    forKey: @"container"];
        [uniqueContacts setObject: contact
                           forKey: [contact objectForKey: @"c_name"]];
      }
      else if ([mail length]
               && [uniqueContacts objectForKey: mail] == nil
               && !(excludeGroups && [contact objectForKey: @"isGroup"]))
      [uniqueContacts setObject: contact forKey: mail];
    }
  }
  if ([uniqueContacts count] > 0)
  {
    // Sort the contacts by display name
    commonNameDescriptor = [[NSSortDescriptor alloc] initWithKey: @"c_cn"
                                                       ascending:YES];
    descriptors = [NSArray arrayWithObjects: commonNameDescriptor, nil];
    [commonNameDescriptor release];
    sortedContacts = [[uniqueContacts allValues]
                      sortedArrayUsingDescriptors: descriptors];
  }
  else
    sortedContacts = [NSArray array];

  return sortedContacts;
}


@end
