/* MAPIStoreContactsContext.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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

#import <Foundation/NSString.h>

#import <NGObjWeb/WOContext+SoObjects.h>

#import <Contacts/SOGoContactGCSEntry.h>
#import <Contacts/SOGoContactGCSFolder.h>
#import <Contacts/SOGoContactFolders.h>

#import "MAPIApplication.h"
#import "MAPIStoreAuthenticator.h"
#import "MAPIStoreContactsMessageTable.h"
#import "MAPIStoreMapping.h"

#import "MAPIStoreContactsContext.h"

@implementation MAPIStoreContactsContext

+ (NSString *) MAPIModuleName
{
  return @"contacts";
}

+ (void) registerFixedMappings: (MAPIStoreMapping *) mapping
{
  [mapping registerURL: @"sogo://openchange:openchange@contacts/"
                withID: 0x1a0001];
}

- (void) setupModuleFolder
{
  SOGoUserFolder *userFolder;
  SOGoContactFolders *parentFolder;

  userFolder = [SOGoUserFolder objectWithName: [authenticator username]
                                  inContainer: MAPIApp];
  [parentFoldersBag addObject: userFolder];
  [woContext setClientObject: userFolder];

  parentFolder = [userFolder lookupName: @"Contacts"
			      inContext: woContext
				acquire: NO];
  [parentFoldersBag addObject: parentFolder];
  [woContext setClientObject: parentFolder];

  moduleFolder = [parentFolder lookupName: @"personal"
				inContext: woContext
				  acquire: NO];
  [moduleFolder retain];
}

- (Class) messageTableClass
{
  return [MAPIStoreContactsMessageTable class];
}

- (id) createMessageOfClass: (NSString *) messageClass
	      inFolderAtURL: (NSString *) folderURL;
{
  SOGoContactGCSFolder *parentFolder;
  SOGoContactGCSEntry *newEntry;
  NSString *name;

  parentFolder = [self lookupObject: folderURL];
  name = [NSString stringWithFormat: @"%@.vcf",
                   [SOGoObject globallyUniqueObjectId]];
  newEntry = [SOGoContactGCSEntry objectWithName: name
				     inContainer: parentFolder];
  [newEntry setIsNew: YES];

  return newEntry;
}

@end
