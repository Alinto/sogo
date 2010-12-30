/* MAPIStoreTasksMessageTable.m - this file is part of SOGo
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

#import <EOControl/EOQualifier.h>

#import <NGCards/iCalToDo.h>

#import <Appointments/SOGoTaskObject.h>

#import "MAPIStoreTypes.h"
#import "NSCalendarDate+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreTasksMessageTable.h"

#include <mapistore/mapistore_nameid.h>

@implementation MAPIStoreTasksMessageTable

- (enum MAPISTATUS) getChildProperty: (void **) data
			      forKey: (NSString *) childKey
			     withTag: (enum MAPITAGS) propTag
{
  NSString *status;
  // id child;
  iCalToDo *task;
  int32_t statusValue;
  NSCalendarDate *dateValue;
  int rc;
  double doubleValue;

  rc = MAPI_E_SUCCESS;
  switch (propTag)
    {
    case PR_ICON_INDEX: // TODO
      /* see http://msdn.microsoft.com/en-us/library/cc815472.aspx */
      // Unassigned recurring task 0x00000501
      // Assignee's task 0x00000502
      // Assigner's task 0x00000503
      // Task request 0x00000504
      // Task acceptance 0x00000505
      // Task rejection 0x00000506
      *data = MAPILongValue (memCtx, 0x00000500);
      break;
    case PR_MESSAGE_CLASS_UNICODE:
      *data = talloc_strdup(memCtx, "IPM.Task");
      break;
    case PR_SUBJECT_UNICODE: // SUMMARY
    case PR_NORMALIZED_SUBJECT_UNICODE:
    case PR_CONVERSATION_TOPIC_UNICODE:
      task = [[self lookupChild: childKey] component: NO secure: NO];
      *data = [[task summary] asUnicodeInMemCtx: memCtx];
      break;
    case PidLidTaskComplete:
      task = [[self lookupChild: childKey] component: NO secure: NO];
      *data = MAPIBoolValue (memCtx,
                             [[task status] isEqualToString: @"COMPLETED"]);
      break;
    case PidLidPercentComplete:
      task = [[self lookupChild: childKey] component: NO secure: NO];
      doubleValue = ((double) [[task percentComplete] intValue] / 100);
      *data = MAPIDoubleValue (memCtx, doubleValue);
      break;
    case PidLidTaskDateCompleted:
      task = [[self lookupChild: childKey] component: NO secure: NO];
      *data = [[task completed] asFileTimeInMemCtx: memCtx];
      break;
    case PidLidTaskState: // TODO (check)
      *data = MAPILongValue (memCtx, 0x02 | 0x03);
      break;
    case PidLidTaskAccepted: // TODO
      *data = MAPIBoolValue (memCtx, YES);
      break;
    case PR_HASATTACH:
      *data = MAPIBoolValue (memCtx, NO);
      break;

    case PidLidTaskDueDate:
      task = [[self lookupChild: childKey] component: NO secure: NO];
      dateValue = [task due];
      if (dateValue)
	*data = [dateValue asFileTimeInMemCtx: memCtx];
      else
	rc = MAPI_E_NOT_FOUND;
      break;

    case PR_CREATION_TIME:
      task = [[self lookupChild: childKey] component: NO secure: NO];
      *data = [[task created] asFileTimeInMemCtx: memCtx];
      break;
    case PR_MESSAGE_DELIVERY_TIME:
    case PR_CLIENT_SUBMIT_TIME:
    case PR_LOCAL_COMMIT_TIME:
    case PR_LAST_MODIFICATION_TIME:
      task = [[self lookupChild: childKey] component: NO secure: NO];
      *data = [[task lastModified] asFileTimeInMemCtx: memCtx];
      break;
    case PidLidTaskStatus: // status
      task = [[self lookupChild: childKey] component: NO secure: NO];
      status = [task status];
      if (![status length]
          || [status isEqualToString: @"NEEDS-ACTIONS"])
        statusValue = 0;
      else if ([status isEqualToString: @"IN-PROCESS"])
        statusValue = 1;
      else if ([status isEqualToString: @"COMPLETED"])
        statusValue = 2;
      else
        statusValue = 0xff;
      *data = MAPILongValue (memCtx, statusValue);
      break;
      /* Completed */
      // -	0x81380003 = -2000
      // +	0x81380003 = -4000
      
      // 68330048
      // 68420102
    case 0x68340003:
    case 0x683a0003:
    case 0x68410003:
      *data = MAPILongValue (memCtx, 0);
      break;

    default:
      rc = [super getChildProperty: data
			    forKey: childKey
			   withTag: propTag];
    }

  return rc;
}

- (EOQualifier *) componentQualifier
{
  static EOQualifier *componentQualifier = nil;

  /* TODO: we need to support vlist as well */
  if (!componentQualifier)
    componentQualifier
      = [[EOKeyValueQualifier alloc] initWithKey: @"c_component"
				operatorSelector: EOQualifierOperatorEqual
					   value: @"vtodo"];

  return componentQualifier;
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
  switch (res->ulPropTag)
    {
    case PR_MESSAGE_CLASS_UNICODE:
      if ([value isKindOfClass: [NSString class]]
	  && [value isEqualToString: @"IPM.Task"])
	rc = MAPIRestrictionStateAlwaysTrue;
      else
	rc = MAPIRestrictionStateAlwaysFalse;
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

  switch (res->ulPropTag)
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

@end
