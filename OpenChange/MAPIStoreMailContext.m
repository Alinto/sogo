/* MAPIStoreMailContext.m - this file is part of SOGo
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

#import <NGObjWeb/WOContext+SoObjects.h>

#import <NGExtensions/NSObject+Logs.h>

#import <NGImap4/NGImap4EnvelopeAddress.h>

#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailFolder.h>
#import <Mailer/SOGoMailObject.h>

#import <SOGo/NSArray+Utilities.h>

#import "MAPIApplication.h"
#import "MAPIStoreAuthenticator.h"
#import "MAPIStoreMailFolderTable.h"
#import "MAPIStoreMailMessageTable.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreTypes.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreMailContext.h"

#undef DEBUG
#include <mapistore/mapistore.h>

@implementation MAPIStoreMailContext

+ (NSString *) MAPIModuleName
{
  return @"inbox";
}

+ (void) registerFixedMappings: (MAPIStoreMapping *) mapping
{
  [mapping registerURL: @"sogo://openchange:openchange@inbox/"
		withID: 0x160001];
}

- (void) setupModuleFolder
{
  SOGoUserFolder *userFolder;
  SOGoMailAccounts *accountsFolder;
  SOGoMailAccount *accountFolder;
  SOGoFolder *currentContainer;

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

  moduleFolder = [accountFolder inboxFolderInContext: nil];
  [moduleFolder retain];
  currentContainer = [moduleFolder container];
  while (currentContainer != (SOGoFolder *) accountFolder)
    {
      [parentFoldersBag addObject: currentContainer];
      currentContainer = [currentContainer container];
    }

  [self logWithFormat: @"moduleFolder: %@", moduleFolder];
}

- (Class) messageTableClass
{
  return [MAPIStoreMailMessageTable class];
}

- (Class) folderTableClass
{
  return [MAPIStoreMailFolderTable class];
}

- (int) openMessage: (struct mapistore_message *) msg
	     forKey: (NSString *) childKey
	    inTable: (MAPIStoreTable *) table
{
  SOGoMailObject *child;
  int rc;
  struct SRowSet *recipients;
  NSArray *to;
  NSInteger count, max;
  NGImap4EnvelopeAddress *currentAddress;
  NSString *name;

  rc = [super openMessage: msg forKey: childKey inTable: table];

  if (rc == MAPI_E_SUCCESS && table == messageTable)
    {
      child = [[table folder] lookupName: childKey inContext: nil acquire: NO];
      /* Retrieve recipients from the message */
      to = [child toEnvelopeAddresses];
      max = [to count];
      recipients = talloc_zero (memCtx, struct SRowSet);
      recipients->cRows = max;
      recipients->aRow = talloc_array (recipients, struct SRow, max);
      for (count = 0; count < max; count++)
        {
          recipients->aRow[count].ulAdrEntryPad = 0;
          recipients->aRow[count].cValues = 2;
          recipients->aRow[count].lpProps = talloc_array (recipients->aRow,
                                                          struct SPropValue,
                                                          2);

          // TODO (0x01 = primary recipient)
          set_SPropValue_proptag (&(recipients->aRow[count].lpProps[0]),
                                  PR_RECIPIENT_TYPE,
                                  MAPILongValue (memCtx, 0x01));

          currentAddress = [to objectAtIndex: count];
          // name = [currentAddress personalName];
          // if (![name length])
          name = [currentAddress baseEMail];
	  if (!name)
	    name = @"";
          set_SPropValue_proptag (&(recipients->aRow[count].lpProps[1]),
                                  PR_DISPLAY_NAME,
                                  [name asUnicodeInMemCtx: recipients->aRow[count].lpProps]);
        }
      msg->recipients = recipients;
    }

  return rc;
}

@end
