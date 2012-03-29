/* SOGoContactFolders.m - this file is part of SOGo
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

/* MailItems                IPF.Note
   ContactItems             IPF.Contact
   AppointmentItems         IPF.Appointment
   NoteItems                IPF.StickyNote
   TaskItems                IPF.Task
   JournalItems             IPF.Journal     */

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSEnumerator.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <DOM/DOMElement.h>
#import <DOM/DOMProtocols.h>

#import <SOGo/NSObject+DAV.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/WORequest+SOGo.h>

#import "SOGoContactGCSFolder.h"
#import "SOGoContactSourceFolder.h"

#import "SOGoContactFolders.h"

#define XMLNS_INVERSEDAV @"urn:inverse:params:xml:ns:inverse-dav"
@implementation SOGoContactFolders

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

- (NSException *) appendSystemSources
{
  SOGoUserManager *um;
  SOGoSystemDefaults *sd;
  NSEnumerator *sourceIDs, *domains;
  NSString *currentSourceID, *srcDisplayName, *domain;
  SOGoContactSourceFolder *currentFolder;
  SOGoUser *currentUser;

  if (![[context request] isIPhoneAddressBookApp])
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
                  [subFolders setObject: currentFolder forKey: currentSourceID];
                }
              domain = [domains nextObject];
            }
        }
    }

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

  if ([sourceID isEqualToString: @"personal"])
    result = [NSException exceptionWithHTTPStatus: 403
                                          reason: @"folder 'personal' cannot be deleted"];
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

  if ([[context request] isIPhoneAddressBookApp])
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
  DOMElement *documentElement, *catNode;
  id <DOMDocument> document;
  id <DOMNodeList> catNodes;
  NSUInteger count, max;
  SOGoUserDefaults *ud;

  categories = [NSMutableArray array];

  if ([newCategories length] > 0)
    {
      document = [[context request] contentAsDOMDocument];
      documentElement = (DOMElement *) [document documentElement];
      catNodes = [documentElement getElementsByTagName: @"category"];
      max = [catNodes length];
      for (count = 0; count < max; count++)
        {
          catNode = [catNodes objectAtIndex: count];
          if ([catNode hasChildNodes])
            [categories addObject: [catNode textValue]];
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

@end
