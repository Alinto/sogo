/* MAPIStoreCalendarContext.m - this file is part of SOGo
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

#import <Foundation/NSDictionary.h>

#import <NGObjWeb/WOContext+SoObjects.h>

#import <NGExtensions/NSObject+Logs.h>

#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoAppointmentFolders.h>
#import <Appointments/SOGoAppointmentObject.h>

#import <NGCards/iCalPerson.h>

#import "MAPIApplication.h"
#import "MAPIStoreAuthenticator.h"
#import "MAPIStoreCalendarMessageTable.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreTypes.h"
#import "SOGoGCSFolder+MAPIStore.h"

#import "MAPIStoreCalendarContext.h"
#import "NSString+MAPIStore.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_nameid.h>

@implementation MAPIStoreCalendarContext

+ (NSString *) MAPIModuleName
{
  return @"calendar";
}

+ (void) registerFixedMappings: (MAPIStoreMapping *) mapping
{
  [mapping registerURL: @"sogo://openchange:openchange@calendar/"
                withID: 0x190001];
}

- (void) setupModuleFolder
{
  SOGoUserFolder *userFolder;
  SOGoAppointmentFolders *parentFolder;

  userFolder = [SOGoUserFolder objectWithName: [authenticator username]
                                  inContainer: MAPIApp];
  [parentFoldersBag addObject: userFolder];
  [woContext setClientObject: userFolder];

  parentFolder = [userFolder lookupName: @"Calendar"
			      inContext: woContext
				acquire: NO];
  [parentFoldersBag addObject: parentFolder];
  [woContext setClientObject: parentFolder];

  moduleFolder = [parentFolder lookupName: @"personal"
				inContext: woContext
				  acquire: NO];
  [moduleFolder retain];
}

- (id) createMessageOfClass: (NSString *) messageClass
	      inFolderAtURL: (NSString *) folderURL;
{
  SOGoAppointmentFolder *parentFolder;
  SOGoAppointmentObject *newEntry;
  NSString *name;

  parentFolder = [self lookupObject: folderURL];
  name = [NSString stringWithFormat: @"%@.ics",
                   [SOGoObject globallyUniqueObjectId]];
  newEntry = [SOGoAppointmentObject objectWithName: name
				    inContainer: parentFolder];
  [newEntry setIsNew: YES];

  return newEntry;
}

- (Class) messageTableClass
{
  return [MAPIStoreCalendarMessageTable class];
}

- (int) openMessage: (struct mapistore_message *) msg
	     forKey: (NSString *) childKey
	    inTable: (MAPIStoreTable *) table
{
  NSString *name, *email;
  NSArray *attendees;
  iCalPerson *person;
  id event;
  struct SRowSet *recipients;
  int count, max, rc;

  rc = [super openMessage: msg forKey: childKey inTable: table];

  if (rc == MAPI_E_SUCCESS && table == messageTable)
    {
      event = [[table lookupChild: childKey] component: NO secure: NO];
      attendees = [event attendees];
      max = [attendees count];

      recipients = msg->recipients;
      recipients->cRows = max;
      recipients->aRow = talloc_array (recipients, struct SRow, max);
   
      for (count = 0; count < max; count++)
	{
	  recipients->aRow[count].ulAdrEntryPad = 0;
	  recipients->aRow[count].cValues = 3;
	  recipients->aRow[count].lpProps = talloc_array (recipients->aRow,
							  struct SPropValue,
							  3);
	  
	  // TODO (0x01 = primary recipient)
	  set_SPropValue_proptag (&(recipients->aRow[count].lpProps[0]),
				  PR_RECIPIENT_TYPE,
				  MAPILongValue (memCtx, 0x01));
	  
	  person = [attendees objectAtIndex: count];
	  
          name = [person cn];
	  if (!name)
	    name = @"";
	  
	  email = [person email];
	  if (!email)
	    email = @"";
	  
	  set_SPropValue_proptag (&(recipients->aRow[count].lpProps[1]),
				  PR_DISPLAY_NAME,
				  [name asUnicodeInMemCtx: recipients->aRow[count].lpProps]);
	  set_SPropValue_proptag (&(recipients->aRow[count].lpProps[2]),
				  PR_EMAIL_ADDRESS,
				  [email asUnicodeInMemCtx: recipients->aRow[count].lpProps]);
	  
	}
    }

  return rc;
}

@end
