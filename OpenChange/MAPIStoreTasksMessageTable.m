/* MAPIStoreTasksMessageTable.m - this file is part of SOGo
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

#import <EOControl/EOQualifier.h>

#import <NGCards/iCalToDo.h>

#import <Appointments/SOGoTaskObject.h>

#import "MAPIStoreTasksMessage.h"
#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSDate+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreTasksMessageTable.h"

#include <mapistore/mapistore_nameid.h>

static Class MAPIStoreTasksMessageK = Nil;

@implementation MAPIStoreTasksMessageTable

+ (void) initialize
{
  MAPIStoreTasksMessageK = [MAPIStoreTasksMessage class];
}

+ (Class) childObjectClass
{
  return MAPIStoreTasksMessageK;
}

- (NSString *) backendIdentifierForProperty: (enum MAPITAGS) property
{
  static NSMutableDictionary *knownProperties = nil;

  if (!knownProperties)
    {
      knownProperties = [NSMutableDictionary new];
      [knownProperties setObject: @"c_enddate"
			  forKey: MAPIPropertyKey (PidLidTaskDueDate)];
    }

  return [knownProperties objectForKey: MAPIPropertyKey (property)];
}

/* restrictions */

- (MAPIRestrictionState) evaluatePropertyRestriction: (struct mapi_SPropertyRestriction *) res
				       intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState rc;
  id value;

  value = NSObjectFromMAPISPropValue (&res->lpProp);
  switch ((uint32_t) res->ulPropTag)
    {
    case PR_MESSAGE_CLASS_UNICODE:
      if ([value isKindOfClass: [NSString class]]
	  && [value isEqualToString: @"IPM.Task"])
	rc = MAPIRestrictionStateAlwaysTrue;
      else
	rc = MAPIRestrictionStateAlwaysFalse;
      break;
    case PR_SENSITIVITY:
      rc = MAPIRestrictionStateAlwaysTrue;
      break;
    case PR_RULE_PROVIDER_UNICODE: // TODO: what's this?
      rc = MAPIRestrictionStateAlwaysTrue;
      break;
    case PidLidTaskOwnership:
      rc = MAPIRestrictionStateAlwaysTrue;
      break;
    case PidLidTaskStatus:
      rc = MAPIRestrictionStateAlwaysTrue;
      break;

    case PidLidTaskComplete:
      *qualifier = [[EOKeyValueQualifier alloc]
		     initWithKey: @"c_status"
		     operatorSelector: EOQualifierOperatorEqual
			   value: [NSNumber numberWithInt: 1]];
      [*qualifier autorelease];
      rc = MAPIRestrictionStateNeedsEval;
      break;

    case PidLidTaskDateCompleted:
      rc = MAPIRestrictionStateAlwaysTrue;
      break;

    default:
      rc = [super evaluatePropertyRestriction: res intoQualifier: qualifier];
    }

  return rc;
}

- (MAPIRestrictionState) evaluateExistRestriction: (struct mapi_SExistRestriction *) res
				    intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState rc;

  switch ((uint32_t) res->ulPropTag)
    {
    case PidLidTaskDateCompleted:
      /* since we don't store the completion date in the quick table, we only
	 checks whether the task has been completed */
      *qualifier = [[EOKeyValueQualifier alloc]
		     initWithKey: @"c_status"
		     operatorSelector: EOQualifierOperatorEqual
			   value: [NSNumber numberWithInt: 1]];
      [*qualifier autorelease];
      rc = MAPIRestrictionStateNeedsEval;
      break;

    default:
      rc = [super evaluateExistRestriction: res intoQualifier: qualifier];
    }

  return rc;
}

/* sorting */

- (NSString *) sortIdentifierForProperty: (enum MAPITAGS) property
{
  static NSMutableDictionary *knownProperties = nil;

  if (!knownProperties)
    {
      knownProperties = [NSMutableDictionary new];
      [knownProperties setObject: @"c_title"
                          forKey: MAPIPropertyKey (PR_NORMALIZED_SUBJECT_UNICODE)];
      [knownProperties setObject: @"c_enddate"
                          forKey: MAPIPropertyKey (PidLidTaskDueDate)];
      [knownProperties setObject: @"c_creationdate"
                          forKey: MAPIPropertyKey (PidLidTaskOrdinal)];
    }

  return [knownProperties objectForKey: MAPIPropertyKey (property)];
}

@end
