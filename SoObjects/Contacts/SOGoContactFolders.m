/* SOGoContactFolders.m - this file is part of SOGo
 *
 * Copyright (C) 2006, 2007 Inverse inc.
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
#import <DOM/DOMElement.h>
#import <DOM/DOMProtocols.h>

#import <SOGo/NSObject+DAV.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserManager.h>
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

- (NSException *) appendSystemSources
{
  SOGoUserManager *um;
  NSEnumerator *sourceIDs;
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
        }
    }

  return nil;
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

- (NSException *) setDavContactsCategories: (NSString *) newCategories
{
  SOGoUser *ownerUser;
  NSMutableArray *categories;
  DOMElement *documentElement, *catNode, *textNode;
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
            {
              textNode = [[catNode childNodes] objectAtIndex: 0];
              [categories addObject: [textNode nodeValue]];
            }
        }
    }

  NSLog (@"setting categories to : %@", categories);
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
