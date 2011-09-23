/* MAPIStoreTasksMessage.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Ludovic Marcotte <lmarcotte@inverse.ca>
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
#import <Appointments/SOGoTaskObject.h>

#import "MAPIStoreTasksFolder.h"
#import "MAPIStoreTypes.h"
#import "NSDate+MAPIStore.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreTasksMessage.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
#include <mapistore/mapistore_nameid.h>

@implementation SOGoTaskObject (MAPIStoreExtension)

- (Class) mapistoreMessageClass
{
  return [MAPIStoreTasksMessage class];
}

@end

@implementation MAPIStoreTasksMessage

- (int) getPrIconIndex: (void **) data // TODO
              inMemCtx: (TALLOC_CTX *) memCtx
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
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = talloc_strdup(memCtx, "IPM.Task");

  return MAPISTORE_SUCCESS;
}

- (int) getPrSubject: (void **) data // SUMMARY
            inMemCtx: (TALLOC_CTX *) memCtx
{
  iCalToDo *task;

  task = [sogoObject component: NO secure: NO];
  *data = [[task summary] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrImportance: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  uint32_t v;
  iCalToDo *task;

  task = [sogoObject component: NO secure: NO];
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
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  iCalToDo *task;

  task = [sogoObject component: NO secure: NO];
  *data = MAPIBoolValue (memCtx,
                         [[task status] isEqualToString: @"COMPLETED"]);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidPercentComplete: (void **) data
                        inMemCtx: (TALLOC_CTX *) memCtx
{
  double doubleValue;
  iCalToDo *task;

  task = [sogoObject component: NO secure: NO];

  doubleValue = ((double) [[task percentComplete] intValue] / 100);
  *data = MAPIDoubleValue (memCtx, doubleValue);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidTaskDateCompleted: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;
  NSCalendarDate *dateValue;
  iCalToDo *task;

  task = [sogoObject component: NO secure: NO];

  dateValue = [task completed];
  if (dateValue)
    *data = [dateValue asFileTimeInMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidLidTaskState: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0x1); // not assigned

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidTaskMode: (void **) data // TODO
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPidLidTaskFRecurring: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (int) getPidLidTaskAccepted: (void **) data // TODO
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (int) getPidLidTaskActualEffort: (void **) data // TODO
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPidLidTaskEstimatedEffort: (void **) data // TODO
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPrHasattach: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (int) getPidLidTaskDueDate: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;
  NSCalendarDate *dateValue;
  iCalToDo *task;

  task = [sogoObject component: NO secure: NO];
  dateValue = [task due];
  if (dateValue)
    *data = [dateValue asFileTimeInMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidLidTaskStartDate: (void **) data
		      inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;
  NSCalendarDate *dateValue;
  iCalToDo *task;

  task = [sogoObject component: NO secure: NO];
  dateValue = [task startDate];
  if (dateValue)
    *data = [dateValue asFileTimeInMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}


- (int) getPrMessageDeliveryTime: (void **) data
                        inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrLastModificationTime: data inMemCtx: memCtx];
}

- (int) getClientSubmitTime: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrLastModificationTime: data inMemCtx: memCtx];
}

- (int) getLocalCommitTime: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrLastModificationTime: data inMemCtx: memCtx];
}

- (int) getPidLidTaskStatus: (void **) data // status
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *status;
  uint32_t longValue;
  iCalToDo *task;

  task = [sogoObject component: NO secure: NO];
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
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *owner;

  owner = [sogoObject ownerInContext: nil];

  *data = [owner asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidTaskOwnership: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
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

  // location
  value = [newProperties objectForKey: MAPIPropertyKey (PidLidLocation)];
  if (value)
    [vToDo setLocation: value];

  // created
  value = [newProperties objectForKey: MAPIPropertyKey (PR_CREATION_TIME)];
  if (value)
    [vToDo setCreated: value];

  // last-modified + dtstamp
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
  else
    {
      [vToDo setStartDate: nil]; 
    }

  // due
  value = [newProperties objectForKey: MAPIPropertyKey (PidLidTaskDueDate)];
  if (value)
    {
      date = (iCalDateTime *) [vToDo uniqueChildWithTag: @"due"];
      [date setTimeZone: tz];
      [date setDateTime: value];
    }
  else
    {
      [vToDo setDue: nil];
    }

  // completed
  value = [newProperties objectForKey: MAPIPropertyKey (PidLidTaskDateCompleted)];
  if (value)
    {
      date = (iCalDateTime *) [vToDo uniqueChildWithTag: @"completed"];
      [date setTimeZone: tz];
      [date setDateTime: value];
    }
  else
    {
      [vToDo setCompleted: nil];
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

  // percent complete
  // NOTE: this does not seem to work on Outlook 2003. PidLidPercentComplete's value
  //       is always set to 0, no matter what value is set in Outlook
  value = [newProperties objectForKey: MAPIPropertyKey(PidLidPercentComplete)];
  if (value)
    [vToDo setPercentComplete: [value stringValue]];

  now = [NSCalendarDate date];
  if ([sogoObject isNew])
    {
      [vToDo setCreated: now];
    }
  [vToDo setTimeStampAsDate: now];

  [sogoObject saveContentString: [vCalendar versitString]];
  [(MAPIStoreTasksFolder *) container synchroniseCache];
  value = [newProperties objectForKey: MAPIPropertyKey (PR_CHANGE_KEY)];
  if (value)
    [(MAPIStoreTasksFolder *) container
        setChangeKey: value forMessageWithKey: [self nameInContainer]];
}

@end
