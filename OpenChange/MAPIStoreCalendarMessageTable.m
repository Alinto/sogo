/* MAPIStoreCalendarMessageTable.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc
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
#import <Foundation/NSString.h>

#import <EOControl/EOQualifier.h>

#import <Appointments/SOGoAppointmentObject.h>

#import <NGCards/iCalEvent.h>

#import "MAPIStoreTypes.h"
#import "NSCalendarDate+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreCalendarMessageTable.h"

#include <mapistore/mapistore_nameid.h>

@implementation MAPIStoreCalendarMessageTable

- (EOQualifier *) componentQualifier
{
  static EOQualifier *componentQualifier = nil;

  if (!componentQualifier)
    componentQualifier
      = [[EOKeyValueQualifier alloc] initWithKey: @"c_component"
				operatorSelector: EOQualifierOperatorEqual
					   value: @"vevent"];

  return componentQualifier;
}

- (enum MAPISTATUS) getChildProperty: (void **) data
			      forKey: (NSString *) childKey
			     withTag: (enum MAPITAGS) propTag
{
  NSTimeInterval timeValue;
  id event;
  int rc;

  rc = MAPI_E_SUCCESS;
  switch (propTag)
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
    case PidLidAppointmentStartWhole: // DTSTART
      event = [[self lookupChild: childKey] component: NO secure: NO];
      *data = [[event startDate] asFileTimeInMemCtx: memCtx];
      break;
    case PidLidAppointmentEndWhole: // DTEND
      event = [[self lookupChild: childKey] component: NO secure: NO];
      *data = [[event endDate] asFileTimeInMemCtx: memCtx];
      break;
    case PidLidAppointmentDuration:
      event = [[self lookupChild: childKey] component: NO secure: NO];
      timeValue = [[event endDate] timeIntervalSinceDate: [event startDate]];
      *data = MAPILongValue (memCtx, (uint32_t) (timeValue / 60));
      break;
    case PidLidAppointmentSubType:
      event = [[self lookupChild: childKey] component: NO secure: NO];
      *data = MAPIBoolValue (memCtx, [event isAllDay]);
      break;
    case PidLidBusyStatus: // TODO
      *data = MAPILongValue (memCtx, 0x02);
      break;
    case PidLidRecurring: // TODO
      *data = MAPIBoolValue (memCtx, NO);
      break;

    // case 0x82410003: // TODO
    //   *data = MAPILongValue (memCtx, 0);
    //   break;
    case PR_SUBJECT_UNICODE: // SUMMARY
      event = [[self lookupChild: childKey] component: NO secure: NO];
      *data = [[event summary] asUnicodeInMemCtx: memCtx];
      break;
    case PidLidLocation: // LOCATION
      event = [[self lookupChild: childKey] component: NO secure: NO];
      *data = [[event location] asUnicodeInMemCtx: memCtx];
      break;
    case PidLidPrivate: // private (bool), should depend on CLASS and permissions
      *data = MAPIBoolValue (memCtx, NO);
      break;
    case PR_SENSITIVITY: // not implemented, depends on CLASS
      // normal = 0, personal?? = 1, private = 2, confidential = 3
      *data = MAPILongValue (memCtx, 0);
      break;
    case PR_CREATION_TIME:
      event = [[self lookupChild: childKey] component: NO secure: NO];
      *data = [[event created] asFileTimeInMemCtx: memCtx];
      break;

    case PR_IMPORTANCE:
      {
	unsigned int v;

	event = [[self lookupChild: childKey] component: NO secure: NO];

	if ([[event priority] isEqualToString: @"9"])
	  v = 0x0;
	else if ([[event priority] isEqualToString: @"1"])
	  v = 0x2;
	else
	  v = 0x1;

	*data = MAPILongValue (memCtx, v);
      }
      break;

      // case PidLidTimeZoneStruct:
      // case PR_VD_NAME_UNICODE:
      //         *data = talloc_strdup(memCtx, "PR_VD_NAME_UNICODE");
      //         break;
      // case PR_EMS_AB_DXA_REMOTE_CLIENT_UNICODE: "Home:" ???
      //         *data = talloc_strdup(memCtx, "PR_EMS...");
      //         break;
    default:
      rc = [super getChildProperty: data
		  forKey: childKey
		  withTag: propTag];
    }

  // #define PR_REPLY_TIME                                       PROP_TAG(PT_SYSTIME   , 0x0030) /* 0x00300040 */
  // #define PR_INTERNET_MESSAGE_ID_UNICODE                      PROP_TAG(PT_UNICODE   , 0x1035) /* 0x1035001f */
  // #define PR_FLAG_STATUS                                      PROP_TAG(PT_LONG      , 0x1090) /* 0x10900003 */

  return rc;
}

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
    case PidLidBusyStatus:
      rc = MAPIRestrictionStateAlwaysTrue; // should be based on c_isopaque
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
      [knownProperties setObject: @"c_startdate"
			  forKey: MAPIPropertyKey (PidLidAppointmentStartWhole)];
      [knownProperties setObject: @"c_enddate"
			  forKey: MAPIPropertyKey (PidLidAppointmentEndWhole)];
      [knownProperties setObject: @"c_iscycle"
			  forKey: MAPIPropertyKey (PidLidRecurring)];
    }

  return [knownProperties objectForKey: MAPIPropertyKey (property)];
}

/* sorting */

- (NSString *) sortIdentifierForProperty: (enum MAPITAGS) property
{
  static NSMutableDictionary *knownProperties = nil;

  if (!knownProperties)
    {
      knownProperties = [NSMutableDictionary new];
      [knownProperties setObject: @"c_startdate"
                          forKey: MAPIPropertyKey (PidLidAppointmentStartWhole)];
    }

  return [knownProperties objectForKey: MAPIPropertyKey (property)];
}

@end
