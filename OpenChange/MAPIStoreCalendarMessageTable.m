/* MAPIStoreCalendarMessageTable.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2012 Inverse inc
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
#import <Foundation/NSNull.h>
#import <Foundation/NSString.h>

#import <EOControl/EOQualifier.h>

#import <NGCards/iCalEvent.h>

#import "MAPIStoreCalendarMessage.h"
#import "MAPIStoreTypes.h"
#import "NSDate+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreCalendarMessageTable.h"

#include <mapistore/mapistore_nameid.h>

static Class MAPIStoreCalendarMessageK = Nil;

@implementation MAPIStoreCalendarMessageTable

+ (void) initialize
{
  MAPIStoreCalendarMessageK = [MAPIStoreCalendarMessage class];
}

+ (Class) childObjectClass
{
  return MAPIStoreCalendarMessageK;
}

- (EOQualifier *) _orgMailNotNullQualifier
{
  static EOQualifier *orgMailQualifier = nil;
  EOQualifier *notNullQualifier, *nullQualifier, *notEmptyQualifier, *emptyQualifier;

  if (!orgMailQualifier)
    {
      nullQualifier = [[EOKeyValueQualifier alloc]
                                initWithKey: @"c_orgmail"
                           operatorSelector: EOQualifierOperatorEqual
                                      value: [NSNull null]];
      notNullQualifier = [[EONotQualifier alloc]
                           initWithQualifier: nullQualifier];
      emptyQualifier = [[EOKeyValueQualifier alloc]
                                initWithKey: @"c_orgmail"
                           operatorSelector: EOQualifierOperatorEqual
                                      value: @""];
      notEmptyQualifier = [[EONotQualifier alloc]
                           initWithQualifier: emptyQualifier];
      orgMailQualifier = [[EOAndQualifier alloc]
                           initWithQualifiers: notNullQualifier,
                           notEmptyQualifier, nil];
      [nullQualifier release];
      [notNullQualifier release];
      [emptyQualifier release];
      [notEmptyQualifier release];
    }

  return orgMailQualifier;
}

- (MAPIRestrictionState) evaluatePropertyRestriction: (struct mapi_SPropertyRestriction *) res
				       intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState rc;
  id value;
  NSMutableString *likeString;
  NSString *likePartString;
  EOAndQualifier *andQualifier, *stringQualifier;
  union {
    uint32_t longValue;
    char charValue[4];
  } apptIdValue;

  value = NSObjectFromMAPISPropValue (&res->lpProp);
  switch ((uint32_t) res->ulPropTag)
    {
    case PR_MESSAGE_CLASS_UNICODE:
      if ([value isEqualToString: @"IPM.Appointment"])
	rc = MAPIRestrictionStateAlwaysTrue;
      else
	rc = MAPIRestrictionStateAlwaysFalse;
      break;
    case PR_OWNER_APPT_ID:
      // c_orgmail != NULL && c_orgmail != '' && c_uid like 'ab%89';
      apptIdValue.longValue = [value unsignedLongValue];
      likeString = [NSMutableString string];
      likePartString = [[NSString alloc]
                         initWithBytes: apptIdValue.charValue
                                length: 2
                              encoding: NSISOLatin1StringEncoding];
      [likeString appendString: likePartString];
      [likePartString release];
      [likeString appendString: @"%%"];
      likePartString = [[NSString alloc]
                         initWithBytes: apptIdValue.charValue + 2
                                length: 2
                              encoding: NSISOLatin1StringEncoding];
      [likeString appendString: likePartString];
      [likePartString release];
      stringQualifier = [[EOKeyValueQualifier alloc]
                                initWithKey: @"c_uid"
                           operatorSelector: EOQualifierOperatorLike
                                      value: likeString];
      andQualifier = [[EOAndQualifier alloc]
                       initWithQualifiers: [self _orgMailNotNullQualifier],
                       stringQualifier, nil];
      [andQualifier autorelease];
      [stringQualifier release];
      *qualifier = andQualifier;
      rc = MAPIRestrictionStateNeedsEval;
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
      [knownProperties setObject: @"c_isallday"
                          forKey: MAPIPropertyKey (PidLidAppointmentSubType)];
      [knownProperties setObject: @"c_creationdate"
                          forKey: MAPIPropertyKey (PR_CREATION_TIME)];
      [knownProperties setObject: @"c_uid"
                          forKey: MAPIPropertyKey (PR_OWNER_APPT_ID)];
    }

  return [knownProperties objectForKey: MAPIPropertyKey (property)];
}

@end
