/* MAPIStoreOutboxContext.m - this file is part of SOGo
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

#import <Mailer/SOGoDraftsFolder.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailFolder.h>

#import "MAPIApplication.h"
#import "MAPIStoreAuthenticator.h"
#import "MAPIStoreMapping.h"

#import "MAPIStoreOutboxContext.h"

@implementation MAPIStoreOutboxContext

+ (NSString *) MAPIModuleName
{
  return @"outbox";
}

+ (void) registerFixedMappings: (MAPIStoreMapping *) mapping
{
  [mapping registerURL: @"sogo://openchange:openchange@outbox/"
                withID: 0x150001];
}

- (void) setupModuleFolder
{
  SOGoUserFolder *userFolder;
  SOGoMailAccounts *accountsFolder;
  SOGoMailAccount *accountFolder;
  id currentContainer;

  userFolder = [SOGoUserFolder objectWithName: [authenticator username]
                                  inContainer: MAPIApp];
  [parentFoldersBag addObject: userFolder];
  [woContext setClientObject: userFolder];

  accountsFolder = [userFolder lookupName: @"Mail"
                                inContext: woContext
                                  acquire: NO];
  [parentFoldersBag addObject: accountsFolder];
  [woContext setClientObject: accountsFolder];

  accountFolder = [accountsFolder lookupName: @"0"
                                  inContext: woContext
                                    acquire: NO];
  [parentFoldersBag addObject: accountFolder];
  [woContext setClientObject: accountFolder];

  moduleFolder = [accountFolder draftsFolderInContext: nil];
  [moduleFolder retain];
  currentContainer = [moduleFolder container];
  while (currentContainer != accountFolder)
    {
      [parentFoldersBag addObject: currentContainer];
      currentContainer = [currentContainer container];
    }
}

- (id) createMessageOfClass: (NSString *) messageClass
	      inFolderAtURL: (NSString *) folderURL;
{
  return [moduleFolder newDraft];
}

@end
