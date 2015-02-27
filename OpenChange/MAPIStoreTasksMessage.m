/* MAPIStoreTasksMessage.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
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
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/iCalToDo.h>
#import <NGCards/iCalPerson.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <Appointments/iCalEntityObject+SOGo.h>
#import <Appointments/SOGoTaskObject.h>
#import <Mailer/NSString+Mail.h>

#import "MAPIStoreContext.h"
#import "MAPIStoreTasksFolder.h"
#import "MAPIStoreTypes.h"
#import "MAPIStoreUserContext.h"
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

- (int) getPidTagIconIndex: (void **) data // TODO
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

- (int) getPidTagMessageClass: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = talloc_strdup(memCtx, "IPM.Task");

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagNormalizedSubject: (void **) data // SUMMARY
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  iCalToDo *task;

  task = [sogoObject component: NO secure: YES];
  *data = [[task summary] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

/* FIXME: Should be combined somehow with the code in MAPIStoreAppointmentWrapper.m */
- (int) getPidTagBody: (void **) data
             inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;
  NSString *stringValue;
  iCalToDo *task;
  
  /* FIXME: there is a confusion in NGCards around "comment" and "description" */
  task = [sogoObject component: NO secure: YES];
  stringValue = [task comment];
  if ([stringValue length] > 0)
    *data = [stringValue asUnicodeInMemCtx: memCtx];
  else
    *data = [@"" asUnicodeInMemCtx: memCtx];

  return rc;
}

/* FIXME: Should be combined somehow with the code in MAPIStoreAppointmentWrapper.m */
- (int) getPidLidPrivate: (void **) data // private (bool), should depend on CLASS and permissions
                inMemCtx: (TALLOC_CTX *) memCtx
{
  iCalToDo *task;
  
  task = [sogoObject component: NO secure: YES];

  if ([task symbolicAccessClass] == iCalAccessPublic)
    return [self getNo: data inMemCtx: memCtx];

  return [self getYes: data inMemCtx: memCtx];
}

- (int) getPidTagImportance: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  uint32_t v;
  iCalToDo *task;

  task = [sogoObject component: NO secure: YES];
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

  task = [sogoObject component: NO secure: YES];
  *data = MAPIBoolValue (memCtx,
                         [[task status] isEqualToString: @"COMPLETED"]);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidPercentComplete: (void **) data
                        inMemCtx: (TALLOC_CTX *) memCtx
{
  double doubleValue;
  iCalToDo *task;

  task = [sogoObject component: NO secure: YES];

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

  task = [sogoObject component: NO secure: YES];

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

- (int) getPidTagHasAttachments: (void **) data
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

  task = [sogoObject component: NO secure: YES];
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

  task = [sogoObject component: NO secure: YES];
  dateValue = [task startDate];
  if (dateValue)
    *data = [dateValue asFileTimeInMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}


- (int) getPidTagMessageDeliveryTime: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagLastModificationTime: data inMemCtx: memCtx];
}

- (int) getClientSubmitTime: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagLastModificationTime: data inMemCtx: memCtx];
}

- (int) getLocalCommitTime: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagLastModificationTime: data inMemCtx: memCtx];
}

- (int) getPidLidTaskStatus: (void **) data // status
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *status;
  uint32_t longValue;
  iCalToDo *task;

  task = [sogoObject component: NO secure: YES];
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

- (BOOL) subscriberCanReadMessage
{
  return ([[self activeUserRoles]
            containsObject: SOGoCalendarRole_ComponentViewer]
          || [self subscriberCanModifyMessage]);
}

- (BOOL) subscriberCanModifyMessage
{
  BOOL rc;
  NSArray *roles = [self activeUserRoles];

  if (isNew)
    rc = [roles containsObject: SOGoRole_ObjectCreator];
  else
    rc = ([roles containsObject: SOGoCalendarRole_ComponentModifier]
          || [roles containsObject: SOGoCalendarRole_ComponentResponder]);

  return rc;
}

- (void) save:(TALLOC_CTX *) memCtx
{
  iCalCalendar *vCalendar;
  iCalToDo *vToDo;
  id value;
  iCalDateTime *date;
  iCalTimeZone *tz;
  NSString *status, *priority, *tzName;
  NSCalendarDate *now;
  NSInteger tzOffset;
  NSTimeZone *userTZ;
  double doubleValue;

  vToDo = [sogoObject component: YES secure: NO];
  vCalendar = [vToDo parent];
  [vCalendar setProdID: @"-//Inverse inc.//OpenChange+SOGo//EN"];

  userTZ = [[self userContext] timeZone];
  tzName = [userTZ name];
  tz = [iCalTimeZone timeZoneForName: tzName];
  [vCalendar addTimeZone: tz];

  // summary
  value = [properties
            objectForKey: MAPIPropertyKey (PR_NORMALIZED_SUBJECT_UNICODE)];
  if (value)
    [vToDo setSummary: value];

  // comment
  value = [properties
            objectForKey: MAPIPropertyKey (PR_BODY_UNICODE)];
  if (!value)
    {
      value = [properties objectForKey: MAPIPropertyKey (PR_HTML)];
      if (value)
        {
          value = [[NSString alloc] initWithData: value
                                        encoding: NSUTF8StringEncoding];
          [value autorelease];
          value = [value htmlToText];
        }
    }
  if (value)
    {
      if ([value length] == 0 || [value isEqualToString: @"\\n"])
        value = nil;
      [vToDo setComment: value];
    }

  // location
  value = [properties objectForKey: MAPIPropertyKey (PidLidLocation)];
  if (value)
    [vToDo setLocation: value];

  // created
  value = [properties objectForKey: MAPIPropertyKey (PR_CREATION_TIME)];
  if (value)
    [vToDo setCreated: value];

  // last-modified + dtstamp
  value = [properties objectForKey: MAPIPropertyKey (PR_LAST_MODIFICATION_TIME)];
  if (value)
    {
      [vToDo setLastModified: value];
      [vToDo setTimeStampAsDate: value];
    }

  // start
  value = [properties objectForKey: MAPIPropertyKey (PidLidTaskStartDate)];
  if (value)
    {
      date = (iCalDateTime *) [vToDo uniqueChildWithTag: @"dtstart"];
      [date setTimeZone: tz];
      /* The property is set to user's local time zone.
         See: [MS-OXOTASK] 2.2.2.2.4
         TODO: Ignore when the PT_SYSTIME is 0x5AE980E0*/
      tzOffset = [userTZ secondsFromGMTForDate: value];
      value = [value dateByAddingYears: 0 months: 0 days: 0
                                 hours: 0 minutes: 0
                               seconds: -tzOffset];
      [date setDateTime: value];
    }
  
  // due
  value = [properties objectForKey: MAPIPropertyKey (PidLidTaskDueDate)];
  if (value)
    {
      date = (iCalDateTime *) [vToDo uniqueChildWithTag: @"due"];
      [date setTimeZone: tz];
      /* The property is set to user's local time zone.
         See: [MS-OXOTASK] 2.2.2.2.5
         TODO: Ignore when the PT_SYSTIME is 0x5AE980E0*/
      tzOffset = [userTZ secondsFromGMTForDate: value];
      value = [value dateByAddingYears: 0 months: 0 days: 0
                                 hours: 0 minutes: 0
                               seconds: -tzOffset];
      [date setDateTime: value];
    }

  // completed
  value = [properties objectForKey: MAPIPropertyKey (PidLidTaskDateCompleted)];
  if (value)
    {
      date = (iCalDateTime *) [vToDo uniqueChildWithTag: @"completed"];
      /* The property is set to midnight in local time zone converted to UTC:
         See: [MS-OXOTASK] 2.2.2.2.9 */
      tzOffset = [userTZ secondsFromGMTForDate: value];
      value = [value dateByAddingYears: 0 months: 0 days: 0
                                 hours: 0 minutes: 0
                               seconds: -tzOffset];
      [date setDate: value];
    }

  // status
  value = [properties objectForKey: MAPIPropertyKey (PidLidTaskStatus)];
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
  value = [properties objectForKey: MAPIPropertyKey (PR_IMPORTANCE)];
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
      [vToDo setPriority: priority];
    }

  // percent complete
  // NOTE: this does not seem to work on Outlook 2003. PidLidPercentComplete's value
  //       is always set to 0, no matter what value is set in Outlook
  value = [properties objectForKey: MAPIPropertyKey (PidLidPercentComplete)];
  if (value)
    {
      doubleValue = [value doubleValue];
      [vToDo setPercentComplete:
               [NSString stringWithFormat: @"%d", (int) (doubleValue * 100)]];
    }

  /* privacy */
  /* FIXME: this should be combined with the code found in iCalEvent+MAPIStore.m */
  value = [properties objectForKey: MAPIPropertyKey(PidLidPrivate)];
  
  if (value)
    {
      if ([value boolValue])
	[vToDo setAccessClass: @"PRIVATE"];
      else
	[vToDo setAccessClass: @"PUBLIC"];
    }

  now = [NSCalendarDate date];
  if ([sogoObject isNew])
    {
      [vToDo setCreated: now];
    }
  [vToDo setTimeStampAsDate: now];

  [sogoObject saveComponent: vCalendar];

  [self updateVersions];
}

@end
