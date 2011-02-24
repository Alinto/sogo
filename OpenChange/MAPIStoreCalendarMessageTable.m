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

#import <NGCards/iCalEvent.h>

#import "MAPIStoreTypes.h"
#import "NSCalendarDate+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreCalendarMessageTable.h"

#include <mapistore/mapistore_nameid.h>

@implementation MAPIStoreCalendarMessageTable

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
      [knownProperties setObject: @"c_enddate"
                          forKey: MAPIPropertyKey (PidLidAppointmentEndWhole)];
      [knownProperties setObject: @"c_iscycle"
                          forKey: MAPIPropertyKey (PidLidRecurring)];
    }

  return [knownProperties objectForKey: MAPIPropertyKey (property)];
}

@end
