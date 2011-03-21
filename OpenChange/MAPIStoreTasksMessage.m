/* MAPIStoreTasksMessage.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/iCalToDo.h>
#import <NGCards/iCalPerson.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <Appointments/SOGoAppointmentObject.h>

#import "MAPIStoreTypes.h"
#import "NSCalendarDate+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreTasksMessage.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
#include <mapistore/mapistore_nameid.h>

@implementation MAPIStoreTasksMessage

- (enum MAPISTATUS) getProperty: (void **) data
                        withTag: (enum MAPITAGS) propTag
{
  NSString *status;
  iCalToDo *task;
  int32_t statusValue;
  NSCalendarDate *dateValue;
  int rc;
  double doubleValue;

  rc = MAPI_E_SUCCESS;
  switch ((uint32_t) propTag)
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
      task = [sogoObject component: NO secure: NO];
      *data = [[task summary] asUnicodeInMemCtx: memCtx];
      break;

    //
    // Not to be confused with PR_PRIORITY 
    //
    // IMPORTANCE_LOW = 0x0, IMPORTANCE_NORMAL = 0x1 and IMPORTANCE_HIGH = 0x2
    //
    case PR_IMPORTANCE:
      {
	unsigned int v;

	task = [sogoObject component: NO secure: NO];

	if ([[task priority] isEqualToString: @"9"])
	  v = 0x0;
	else if ([[task priority] isEqualToString: @"1"])
	  v = 0x2;
	else
	  v = 0x1;

	*data = MAPILongValue (memCtx, v);
      }
      break;
    case PidLidTaskComplete:
      task = [sogoObject component: NO secure: NO];
      *data = MAPIBoolValue (memCtx,
                             [[task status] isEqualToString: @"COMPLETED"]);
      break;
    case PidLidPercentComplete:
      task = [sogoObject component: NO secure: NO];
      doubleValue = ((double) [[task percentComplete] intValue] / 100);
      *data = MAPIDoubleValue (memCtx, doubleValue);
      break;
    case PidLidTaskDateCompleted:
      task = [sogoObject component: NO secure: NO];
      dateValue = [task completed];
      if (dateValue)
	*data = [dateValue asFileTimeInMemCtx: memCtx];
      else
	rc = MAPISTORE_ERR_NOT_FOUND;
      break;
    // http://msdn.microsoft.com/en-us/library/cc765590.aspx
    // It's important to have a proper value for PidLidTaskState
    // as it'll affect the UI options of Outlook - making the
    // task non-editable in some cases.
    case PidLidTaskState:
      *data = MAPILongValue (memCtx, 0x1); // not assigned
      break;
    case PidLidTaskMode: // TODO
      *data = MAPILongValue (memCtx, 0x0);
      break;
    case PidLidTaskFRecurring:
    case PidLidTaskAccepted: // TODO
      *data = MAPIBoolValue (memCtx, NO);
      break;
    case PidLidTaskActualEffort: // TODO
    case PidLidTaskEstimatedEffort: // TODO
      *data = MAPILongValue (memCtx, 0);
      break;
    case PR_HASATTACH:
      *data = MAPIBoolValue (memCtx, NO);
      break;

    case PidLidTaskDueDate:
      task = [sogoObject component: NO secure: NO];
      dateValue = [task due];
      if (dateValue)
	*data = [dateValue asFileTimeInMemCtx: memCtx];
      else
	rc = MAPISTORE_ERR_NOT_FOUND;
      break;

    case PR_CREATION_TIME:
      task = [sogoObject component: NO secure: NO];
      *data = [[task created] asFileTimeInMemCtx: memCtx];
      break;
    case PR_MESSAGE_DELIVERY_TIME:
    case PR_CLIENT_SUBMIT_TIME:
    case PR_LOCAL_COMMIT_TIME:
    case PR_LAST_MODIFICATION_TIME:
      task = [sogoObject component: NO secure: NO];
      *data = [[task lastModified] asFileTimeInMemCtx: memCtx];
      break;
    case PidLidTaskStatus: // status
      task = [sogoObject component: NO secure: NO];
      status = [task status];
      if (![status length]
          || [status isEqualToString: @"NEEDS-ACTION"])
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

    // FIXME - use the current user
    case PidLidTaskOwner:
      *data = [@"openchange@example.com" asUnicodeInMemCtx: memCtx];
      break;

    // See http://msdn.microsoft.com/en-us/library/cc842113.aspx
    case PidLidTaskOwnership:
      *data = MAPILongValue (memCtx, 0x0); // not assigned
      break;
      
// #define PidLidFlagRequest                                   0x9027001f
// #define PidNameContentType                                  0x905a001f
// #define PidLidBillingInformation                            0x908b001f
// #define PidLidTaskStartDate                                 0x911e0040
// #define PidLidTaskOwner                                     0x9122001f
// #define PidLidTaskDeadOccurrence                            0x9127000b
// #define PidLidTaskMultipleRecipients                        0x912a0003
// #define PidLidTaskHistory                                   0x912b0003
// #define PidLidAcceptanceState                               0x912c0003
// #define PidLidTaskLastUser                                  0x912d001f
// #define PidLidTaskLastUpdate                                0x912e0040
// #define PidLidTaskOwnership                                 0x912f0003
// #define PidLidTaskNoCompute                                 0x9130000b
// #define PidLidTaskFFixOffline                               0x9131000b
// #define PidLidTaskRole                                      0x9132001f
// #define PidLidTaskVersion                                   0x91330003
// #define PidLidTaskAssigner                                  0x9134001f
// #define PidLidTeamTask                                      0x9135000b
// #define PidLidTaskRecurrence                                0x91360102
// #define PidLidTaskResetReminder                             0x9137000b
// #define PidLidTaskOrdinal                                   0x91380003
// #define PidLidMileage                                       0x914a001f
// #define PidLidAgingDontAgeMe                                0x9185000b
// #define PidLidCommonEnd                                     0x91980040
// #define PidLidCommonStart                                   0x91990040
// #define PidLidNonSendableBcc                                0x91d7001f
// #define PidLidNonSendableCc                                 0x91d8001f
// #define PidLidNonSendtableTo                                0x91d9001f
// #define PidLidNonSendBccTrackStatus                         0x91da1003
// #define PidLidNonSendCcTrackStatus                          0x91db1003
// #define PidLidNonSendToTrackStatus                          0x91dc1003
// #define PidLidReminderDelta                                 0x91e90003
// #define PidLidReminderFileParameter                         0x91ea001f
// #define PidLidReminderSignalTime                            0x91eb0040
// #define PidLidReminderOverride                              0x91ec000b
// #define PidLidReminderPlaySound                             0x91ed000b
// #define PidLidReminderSet                                   0x91ee000b
// #define PidLidReminderTime                                  0x91ef0040
// #define PidLidReminderType                                  0x91f20003
// #define PidLidRemoteStatus                                  0x91f30003
// #define PidLidSmartNoAttach                                 0x91fa000b
// #define PidLidTaskGlobalId                                  0x91fe0102
// #define PidLidVerbResponse                                  0x9203001f
// #define PidLidVerbStream                                    0x92040102
// #define PidLidPrivate                                       0x9224000b
// #define PidLidInternetAccountName                           0x9225001f
// #define PidLidInternetAccountStamp                          0x9226001f
// #define PidLidUseTnef                                       0x9227000b
// #define PidLidContactLinkName                               0x9229001f
// #define PidLidContactLinkEntry                              0x922a0102
// #define PidLidContactLinkSearchKey                          0x922b0102
// #define PidLidSpamOriginalFolder                            0x92370102
// #define PidLidTaskUpdates                                   0x9345000b
// #define PidLidTaskStatusOnComplete                          0x9346000b
// #define PidLidTaskLastDelegate                              0x9347001f
// #define PidLidTaskAssigners                                 0x934a0102
// #define PidLidTaskFCreator                                  0x934c000b
// #define PidLidImapDeleted                                   0x94e50003
// #define PidLidHeaderItem                                    0x94e60003

    default:
      rc = [super getProperty: data withTag: propTag];
    }

  return rc;
}

- (void) save
{
  iCalCalendar *vCalendar;
  iCalToDo *vToDo;
  id value;
  SOGoUserDefaults *ud;
  iCalTimeZone *tz;
  iCalDateTime *date;
  NSString *owner, *status, *priority;
  NSCalendarDate *now;

  owner = [sogoObject ownerInContext: nil];
  vToDo = [sogoObject component: YES secure: NO];
  vCalendar = [vToDo parent];
  [vCalendar setProdID: @"-//Inverse inc.//OpenChange+SOGo//EN"];

  // summary
  value = [newProperties
            objectForKey: MAPIPropertyKey (PR_NORMALIZED_SUBJECT_UNICODE)];
  if (value)
    [vToDo setSummary: value];

  // comment
  value = [newProperties
            objectForKey: MAPIPropertyKey (PR_BODY_UNICODE)];
  if (value)
    [vToDo setComment: value];

  // Location
  value = [newProperties objectForKey: MAPIPropertyKey (PidLidLocation)];
  if (value)
    [vToDo setLocation: value];

  /* created */
  value = [newProperties objectForKey: MAPIPropertyKey (PR_CREATION_TIME)];
  if (value)
    [vToDo setCreated: value];

  /* last-modified + dtstamp */
  value = [newProperties objectForKey: MAPIPropertyKey (PR_LAST_MODIFICATION_TIME)];
  if (value)
    {
      [vToDo setLastModified: value];
      [vToDo setTimeStampAsDate: value];
    }

  ud = [[SOGoUser userWithLogin: owner] userDefaults];
  tz = [iCalTimeZone timeZoneForName: [ud timeZoneName]];
  [vCalendar addTimeZone: tz];

  // start
  value = [newProperties objectForKey: MAPIPropertyKey (PidLidTaskStartDate)];
  if (value)
    {
      date = (iCalDateTime *) [vToDo uniqueChildWithTag: @"dtstart"];
      [date setTimeZone: tz];
      [date setDateTime: value];
    }

  // due
  value = [newProperties objectForKey: MAPIPropertyKey (PidLidTaskDueDate)];
  if (value)
    {
      date = (iCalDateTime *) [vToDo uniqueChildWithTag: @"due"];
      [date setTimeZone: tz];
      [date setDateTime: value];
    }

  // status
  value = [newProperties objectForKey: MAPIPropertyKey (PidLidTaskStatus)];
  if (value)
    {
      switch ([value intValue])
        {
        case 1: status = @"IN-PROCESS"; break;
        case 2: status = @"COMPLETED"; break;
        default: status = @"NEEDS-ACTION";
        }
      [vToDo setStatus: status];
    }

  // priority
  value = [newProperties objectForKey: MAPIPropertyKey (PR_IMPORTANCE)];
  if (value)
    {
      switch ([value intValue])
        {
        case 0: // IMPORTANCE_LOW
          priority = @"9";
          break;
        case 2: // IMPORTANCE_HIGH
          priority = @"1";
          break;
        default: // IMPORTANCE_NORMAL
          priority = @"5";
        }
    }
  else
    priority = @"0"; // None
  [vToDo setPriority: priority];

  now = [NSCalendarDate date];
  if ([sogoObject isNew])
    {
      [vToDo setCreated: now];
    }
  [vToDo setTimeStampAsDate: now];

  [sogoObject saveContentString: [vCalendar versitString]];
}

@end
