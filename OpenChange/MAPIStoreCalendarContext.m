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

#import <EOControl/EOQualifier.h>

#import <NGCards/iCalEvent.h>
#import <Appointments/SOGoAppointmentObject.h>

#import "MAPIApplication.h"
#import "MAPIStoreAuthenticator.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreTypes.h"
#import "NSCalendarDate+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "SOGoGCSFolder+MAPIStore.h"

#import "MAPIStoreCalendarContext.h"

#undef DEBUG
#include <mapistore/mapistore.h>

@implementation MAPIStoreCalendarContext

+ (NSString *) MAPIModuleName
{
  return @"calendar";
}

+ (void) registerFixedMappings: (MAPIStoreMapping *) mapping
{
  [mapping registerURL: @"sogo://openchange:openchange@calendar/personal/"
                withID: 0x190001];
}

- (void) setupModuleFolder
{
  id userFolder;

  userFolder = [SOGoUserFolder objectWithName: [authenticator username]
                                  inContainer: MAPIApp];
  [parentFoldersBag addObject: userFolder];
  [woContext setClientObject: userFolder];

  moduleFolder = [userFolder lookupName: @"Calendar"
                              inContext: woContext
                                acquire: NO];
  [moduleFolder retain];
}

- (NSArray *) getFolderMessageKeys: (SOGoFolder *) folder
		 matchingQualifier: (EOQualifier *) qualifier
{
  EOQualifier *componentQualifier, *calendarQualifier;

  componentQualifier
    = [[EOKeyValueQualifier alloc] initWithKey: @"c_component"
			      operatorSelector: EOQualifierOperatorEqual
					 value: @"vevent"];
  [componentQualifier autorelease];
  if (qualifier)
    {
      calendarQualifier = [[EOAndQualifier alloc]
			    initWithQualifiers:
			      componentQualifier,
			    qualifier,
			    nil];
      [calendarQualifier autorelease];
    }
  else
    calendarQualifier = componentQualifier;

  return [super getFolderMessageKeys: folder
		   matchingQualifier: calendarQualifier];
}

- (enum MAPISTATUS) getMessageTableChildproperty: (void **) data
					   atURL: (NSString *) childURL
					 withTag: (enum MAPITAGS) proptag
					inFolder: (SOGoFolder *) folder
					 withFID: (uint64_t) fid
{
  // id child;
  id event;
  int rc;

  rc = MAPI_E_SUCCESS;
  switch (proptag)
    {
    case PR_ICON_INDEX: // TODO
      /* see http://msdn.microsoft.com/en-us/library/cc815472.aspx */
      // *longValue = 0x00000401 for recurring event
      // *longValue = 0x00000402 for meeting
      // *longValue = 0x00000403 for recurring meeting
      // *longValue = 0x00000404 for invitation
      *data = MAPILongValue (memCtx, 0x00000400);
      break;
    case PR_MESSAGE_CLASS_UNICODE:
      *data = talloc_strdup(memCtx, "IPM.Appointment");
      break;
    case 0x818f0040: // DTSTART
      event = [[self lookupObject: childURL] component: NO secure: NO];
      *data = [[event startDate] asFileTimeInMemCtx: memCtx];
      break;
    case 0x818a0040: // DTEND
      event = [[self lookupObject: childURL] component: NO secure: NO];
      *data = [[event endDate] asFileTimeInMemCtx: memCtx];
      break;
    case 0x82410003: // LABEL idx, should be saved in an X- property
      *data = MAPILongValue (memCtx, 0);
      break;
    case PR_SUBJECT_UNICODE: // SUMMARY
    case PR_NORMALIZED_SUBJECT_UNICODE:
    case PR_CONVERSATION_TOPIC_UNICODE:
      event = [[self lookupObject: childURL] component: NO secure: NO];
      *data = [[event summary] asUnicodeInMemCtx: memCtx];
      break;
    case 0x810c001f: // LOCATION
      event = [[self lookupObject: childURL] component: NO secure: NO];
      *data = [[event location] asUnicodeInMemCtx: memCtx];
      break;
    case 0x8224000b: // private (bool), should depend on CLASS
      *data = MAPIBoolValue (memCtx, NO);
      break;
    case PR_SENSITIVITY: // not implemented, depends on CLASS
      // normal = 0, personal?? = 1, private = 2, confidential = 3
      *data = MAPILongValue (memCtx, 0);
      break;
    case PR_CREATION_TIME:
      event = [[self lookupObject: childURL] component: NO secure: NO];
      *data = [[event created] asFileTimeInMemCtx: memCtx];
      break;

      // case PR_VD_NAME_UNICODE:
      //         *data = talloc_strdup(memCtx, "PR_VD_NAME_UNICODE");
      //         break;
      // case PR_EMS_AB_DXA_REMOTE_CLIENT_UNICODE: "Home:" ???
      //         *data = talloc_strdup(memCtx, "PR_EMS...");
      //         break;
    default:
      rc = [super getMessageTableChildproperty: data
                                         atURL: childURL
                                       withTag: proptag
                                      inFolder: folder
                                       withFID: fid];
    }

  // #define PR_REPLY_TIME                                       PROP_TAG(PT_SYSTIME   , 0x0030) /* 0x00300040 */
  // #define PR_INTERNET_MESSAGE_ID_UNICODE                      PROP_TAG(PT_UNICODE   , 0x1035) /* 0x1035001f */
  // #define PR_FLAG_STATUS                                      PROP_TAG(PT_LONG      , 0x1090) /* 0x10900003 */
  // #define PR_SEARCH_KEY                                       PROP_TAG(PT_BINARY    , 0x300b) /* 0x300b0102 */


  // #define PR_EMS_AB_INCOMING_MSG_SIZE_LIMIT                   PROP_TAG(PT_LONG      , 0x8190) /* 0x81900003 */
  // Not found: 81930003 // ?
  // Not found: 80fa000b // ?
  // Not found: 81c4000b // ?
  // Not found: 81e7000b // ?
  // Not found: 81ee000b // ?

  // Not found: 81f80003 //
  // Not found: 82020102 //
  // Not found: 818b0102 // 
  // Not found: 81d1001f //

  return rc;
}

- (id) createMessageInFolder: (id) parentFolder
{
  SOGoAppointmentObject *newEntry;
  NSString *name;

  name = [NSString stringWithFormat: @"%@.ics",
                   [SOGoObject globallyUniqueObjectId]];
  newEntry = [SOGoAppointmentObject objectWithName: name
                                       inContainer: parentFolder];
  [newEntry setIsNew: YES];

  return newEntry;
}

// - (int) getFolderTableChildproperty: (void **) data
//                               atURL: (NSString *) childURL
//                             withTag: (enum MAPITAGS) proptag
//                            inFolder: (SOGoFolder *) folder
//                             withFID: (uint64_t) fid
// {
//         int rc;

//         [self logWithFormat: @"XXXXX unexpected!!!!!!!!!"];
//         rc = MAPI_E_SUCCESS;
//         switch (proptag) {
//         default:
//                 rc = [super getFolderTableChildproperty: data
//                                           atURL: childURL
//                                                 withTag: proptag
//                                                inFolder: folder
//                                                 withFID: fid];
//         }
        
//         return rc;
// }

- (MAPIRestrictionState) evaluatePropertyRestriction: (struct mapi_SPropertyRestriction *) res
				       intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState rc;
  id value;

  value = NSObjectFromMAPISPropValue (&res->lpProp);
  switch (res->ulPropTag)
    {
    case PR_MESSAGE_CLASS_UNICODE:
      if ([value isEqualToString: @"IPM.Appointment"])
	rc = MAPIRestrictionStateAlwaysTrue;
      else
	rc = MAPIRestrictionStateAlwaysFalse;
      break;
    default:
      rc = [super evaluatePropertyRestriction: res intoQualifier: qualifier];
    }

  return rc;
}

- (NSString *) backendIdentifierForProperty: (enum MAPITAGS) property
{
  static NSMutableDictionary *knownProperties = nil;

  if (!knownProperties)
    {
      knownProperties = [NSMutableDictionary new];
    }

  return [knownProperties objectForKey: MAPIPropertyKey (property)];
}

@end
