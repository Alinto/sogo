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

- (id) initWithSOGoObject: (id) newSOGoObject
              inContainer: (MAPIStoreObject *) newContainer
{
  if ((self = [super initWithSOGoObject: newSOGoObject
                     inContainer: newContainer]))
    {
      ASSIGN (task, [newSOGoObject component: NO secure: NO]);
    }

  return self;
}

- (void) dealloc
{
  [task release];
  [super dealloc];
}

- (int) getPrIconIndex: (void **) data // TODO
{
  /* see http://msdn.microsoft.com/en-us/library/cc815472.aspx */
  // Unassigned recurring task 0x00000501
  // Assignee's task 0x00000502
  // Assigner's task 0x00000503
  // Task request 0x00000504
  // Task acceptance 0x00000505
  // Task rejection 0x00000506
  *data = MAPILongValue (memCtx, 0x00000500);

  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageClass: (void **) data
{
  *data = talloc_strdup(memCtx, "IPM.Task");

  return MAPISTORE_SUCCESS;
}

- (int) getPrSubject: (void **) data // SUMMARY
{
  *data = [[task summary] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrImportance: (void **) data
{
  uint32_t v;
      
  if ([[task priority] isEqualToString: @"9"])
    v = 0x0;
  else if ([[task priority] isEqualToString: @"1"])
    v = 0x2;
  else
    v = 0x1;
    
  *data = MAPILongValue (memCtx, v);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidTaskComplete: (void **) data
{
  *data = MAPIBoolValue (memCtx,
                         [[task status] isEqualToString: @"COMPLETED"]);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidPercentComplete: (void **) data
{
  double doubleValue;

  doubleValue = ((double) [[task percentComplete] intValue] / 100);
  *data = MAPIDoubleValue (memCtx, doubleValue);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidTaskDateCompleted: (void **) data
{
  NSCalendarDate *dateValue;
  int rc = MAPISTORE_SUCCESS;

  dateValue = [task completed];
  if (dateValue)
    *data = [dateValue asFileTimeInMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidLidTaskState: (void **) data
{
  *data = MAPILongValue (memCtx, 0x1); // not assigned

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidTaskMode: (void **) data // TODO
{
  return [self getLongZero: data];
}

- (int) getPidLidTaskFRecurring: (void **) data
{
  return [self getNo: data];
}

- (int) getPidLidTaskAccepted: (void **) data // TODO
{
  return [self getNo: data];
}

- (int) getPidLidTaskActualEffort: (void **) data // TODO
{
  return [self getLongZero: data];
}

- (int) getPidLidTaskEstimatedEffort: (void **) data // TODO
{
  return [self getLongZero: data];
}

- (int) getPrHasattach: (void **) data
{
  return [self getNo: data];
}

- (int) getPidLidTaskDueDate: (void **) data
{
  NSCalendarDate *dateValue;
  int rc = MAPISTORE_SUCCESS;

  dateValue = [task due];
  if (dateValue)
    *data = [dateValue asFileTimeInMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return MAPISTORE_SUCCESS;
}

- (int) getPrCreationTime: (void **) data
{
  *data = [[task created] asFileTimeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageDeliveryTime: (void **) data
{
  *data = [[task lastModified] asFileTimeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getClientSubmitTime: (void **) data
{
  return [self getPrMessageDeliveryTime: data];
}

- (int) getLocalCommitTime: (void **) data
{
  return [self getPrMessageDeliveryTime: data];
}

- (int) getLastModificationTime: (void **) data
{
  return [self getPrMessageDeliveryTime: data];
}

- (int) getPidLidTaskStatus: (void **) data // status
{
  NSString *status;
  uint32_t longValue;

  status = [task status];
  if (![status length]
      || [status isEqualToString: @"NEEDS-ACTION"])
    longValue = 0;
  else if ([status isEqualToString: @"IN-PROCESS"])
    longValue = 1;
  else if ([status isEqualToString: @"COMPLETED"])
    longValue = 2;
  else
    longValue = 0xff;
  *data = MAPILongValue (memCtx, longValue);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidTaskOwner: (void **) data
{
  *data = [@"openchange@example.com" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidTaskOwnership: (void **) data
{
  return [self getLongZero: data];
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
