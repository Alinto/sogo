/* MAPIStoreCalendarMessage.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
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

/* TODO:
   - merge common code with tasks
   - take the tz definitions from Outlook */

#include <talloc.h>
#include <util/attr.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/iCalAlarm.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/iCalTrigger.h>
#import <SOGo/SOGoUser.h>
#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoAppointmentObject.h>
#import <Appointments/iCalEntityObject+SOGo.h>
#import <Mailer/NSString+Mail.h>

#import "MAPIStoreAppointmentWrapper.h"
#import "MAPIStoreCalendarAttachment.h"
#import "MAPIStoreCalendarFolder.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreRecurrenceUtils.h"
#import "MAPIStoreTypes.h"
#import "NSDate+MAPIStore.h"
#import "NSData+MAPIStore.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "NSValue+MAPIStore.h"

#import "MAPIStoreCalendarMessage.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <gen_ndr/property.h>
#include <libmapi/libmapi.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
#include <mapistore/mapistore_nameid.h>

// extern void ndr_print_AppointmentRecurrencePattern(struct ndr_print *ndr, const char *name, const struct AppointmentRecurrencePattern *r);

@implementation SOGoAppointmentObject (MAPIStoreExtension)

- (Class) mapistoreMessageClass
{
  return [MAPIStoreCalendarMessage class];
}

@end

@implementation MAPIStoreCalendarMessage

- (id) init
{
  if ((self = [super init]))
    {
      appointmentWrapper = nil;
    }

  return self;
}

- (void) dealloc
{
  [appointmentWrapper release];
  [super dealloc];
}

- (MAPIStoreAppointmentWrapper *) appointmentWrapper
{
  iCalEvent *event;
  MAPIStoreContext *context;

  if (!appointmentWrapper)
    {
      event = [sogoObject component: NO secure: NO];
      context = [self context];
      ASSIGN (appointmentWrapper,
              [MAPIStoreAppointmentWrapper wrapperWithICalEvent: event
                                                        andUser: [context activeUser]
                                                 andSenderEmail: nil
                                                     inTimeZone: [self ownerTimeZone]
                                             withConnectionInfo: [context connectionInfo]]);
    }

  return appointmentWrapper;
}

/* getters */
- (int) getPrIconIndex: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPrIconIndex: data inMemCtx: memCtx];
}

- (int) getPidLidFInvited: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getYes: data inMemCtx: memCtx];
}

- (int) getPrMessageClass: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = talloc_strdup (memCtx, "IPM.Appointment");

  return MAPISTORE_SUCCESS;
}

- (int) getPrOwnerApptId: (void **) data
                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPrOwnerApptId: data inMemCtx: memCtx];
}

- (int) getPrStartDate: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPrStartDate: data inMemCtx: memCtx];
}

- (int) getPidLidAppointmentStateFlags: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidAppointmentStateFlags: data inMemCtx: memCtx];
}

- (int) getPidLidResponseStatus: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidResponseStatus: data
                                                   inMemCtx: memCtx];
}

- (int) getPidLidAppointmentStartWhole: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidAppointmentStartWhole: data inMemCtx: memCtx];
}

- (int) getPidLidCommonStart: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidCommonStart: data inMemCtx: memCtx];
}

- (int) getPrEndDate: (void **) data
            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPrEndDate: data inMemCtx: memCtx];
}

- (int) getPidLidAppointmentEndWhole: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidAppointmentEndWhole: data inMemCtx: memCtx];
}

- (int) getPidLidCommonEnd: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidCommonEnd: data inMemCtx: memCtx];
}

- (int) getPidLidAppointmentDuration: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidAppointmentDuration: data inMemCtx: memCtx];
}

- (int) getPidLidAppointmentSubType: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidAppointmentSubType: data inMemCtx: memCtx];
}

- (int) getPidLidBusyStatus: (void **) data // TODO
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidBusyStatus: data inMemCtx: memCtx];
}

- (int) getPrSubject: (void **) data // SUMMARY
            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPrSubject: data inMemCtx: memCtx];
}

- (int) getPidLidLocation: (void **) data // LOCATION
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidLocation: data inMemCtx: memCtx];
}

- (int) getPidLidPrivate: (void **) data // private (bool), should depend on CLASS and permissions
                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidPrivate: data inMemCtx: memCtx];
}

- (int) getPrSensitivity: (void **) data // not implemented, depends on CLASS
                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPrSensitivity: data inMemCtx: memCtx];
}

- (int) getPrImportance: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPrImportance: data inMemCtx: memCtx];
}

- (int) getPrBody: (void **) data
         inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPrBody: data inMemCtx: memCtx];
}

- (int) getPidLidIsRecurring: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidIsRecurring: data inMemCtx: memCtx];
}

- (int) getPidLidRecurring: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidRecurring: data inMemCtx: memCtx];
}

- (int) getPidLidAppointmentRecur: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidAppointmentRecur: data
                                                     inMemCtx: memCtx];
}

- (int) getPidLidGlobalObjectId: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidGlobalObjectId: data
                                                   inMemCtx: memCtx];
}

- (int) getPidLidCleanGlobalObjectId: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidCleanGlobalObjectId: data
                                                        inMemCtx: memCtx];
}

- (int) getPrProcessed: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getYes: data inMemCtx: memCtx];
}

- (int) getPidLidServerProcessed: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidServerProcessed: data
                                                    inMemCtx: memCtx];
}

- (int) getPidLidServerProcessingActions: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidServerProcessingActions: data
                                                            inMemCtx: memCtx];
}

- (int) getPidLidAppointmentReplyTime: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidAppointmentReplyTime: data
                                                         inMemCtx: memCtx];
}

- (void) getMessageData: (struct mapistore_message **) dataPtr
               inMemCtx: (TALLOC_CTX *) memCtx
{
  struct mapistore_message *msgData;

  [super getMessageData: &msgData inMemCtx: memCtx];
  [[self appointmentWrapper] fillMessageData: msgData
                                    inMemCtx: memCtx];
  *dataPtr = msgData;
}

/* sender */
- (int) getPrSenderEmailAddress: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPrSenderEmailAddress: data
                                                   inMemCtx: memCtx];
}

- (int) getPrSenderAddrtype: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPrSenderAddrtype: data
                                               inMemCtx: memCtx];
}

- (int) getPrSenderName: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPrSenderName: data
                                           inMemCtx: memCtx];
}

- (int) getPrSenderEntryid: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPrSenderEntryid: data
                                              inMemCtx: memCtx];
}

/* sender representing */
- (int) getPrSentRepresentingEmailAddress: (void **) data
                                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrSenderEmailAddress: data inMemCtx: memCtx];
}

- (int) getPrSentRepresentingAddrtype: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getSMTPAddrType: data inMemCtx: memCtx];
}

- (int) getPrSentRepresentingName: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrSenderName: data inMemCtx: memCtx];
}

- (int) getPrSentRepresentingEntryid: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrSenderEntryid: data inMemCtx: memCtx];
}

/* attendee */
// - (int) getPrReceivedByAddrtype: (void **) data
//                        inMemCtx: (TALLOC_CTX *) memCtx
// {
//   return [[self appointmentWrapper] getPrReceivedByAddrtype: data
//                                                    inMemCtx: memCtx];
// }

// - (int) getPrReceivedByEmailAddress: (void **) data
//                            inMemCtx: (TALLOC_CTX *) memCtx
// {
//   return [[self appointmentWrapper] getPrReceivedByEmailAddress: data
//                                                        inMemCtx: memCtx];
// }

// - (int) getPrReceivedByName: (void **) data
//                    inMemCtx: (TALLOC_CTX *) memCtx
// {
//   return [[self appointmentWrapper] getPrReceivedByName: data
//                                                inMemCtx: memCtx];
// }

// - (int) getPrReceivedByEntryid: (void **) data
//                       inMemCtx: (TALLOC_CTX *) memCtx
// {
//   return [[self appointmentWrapper] getPrReceivedByEntryid: data
//                                                   inMemCtx: memCtx];
// }

// /* attendee representing */
// - (int) getPrRcvdRepresentingEmailAddress: (void **) data
//                                  inMemCtx: (TALLOC_CTX *) memCtx
// {
//   return [self getPrReceivedByEmailAddress: data inMemCtx: memCtx];
// }

// - (int) getPrRcvdRepresentingAddrtype: (void **) data
//                              inMemCtx: (TALLOC_CTX *) memCtx
// {
//   return [self getSMTPAddrType: data inMemCtx: memCtx];
// }

// - (int) getPrRcvdRepresentingName: (void **) data
//                          inMemCtx: (TALLOC_CTX *) memCtx
// {
//   return [self getPrReceivedByName: data inMemCtx: memCtx];
// }

// - (int) getPrRcvdRepresentingEntryid: (void **) data
//                             inMemCtx: (TALLOC_CTX *) memCtx
// {
//   return [self getPrReceivedByEntryid: data inMemCtx: memCtx];
// }

- (int) getPrResponseRequested: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getYes: data inMemCtx: memCtx];
}

/* alarms */
- (int) getPidLidReminderSet: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidReminderSet: data
                                                inMemCtx: memCtx];
}

- (int) getPidLidReminderDelta: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidReminderDelta: data
                                                  inMemCtx: memCtx];
}

- (int) getPidLidReminderTime: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidReminderTime: data
                                                 inMemCtx: memCtx];
}

- (int) getPidLidReminderSignalTime: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidReminderSignalTime: data
                                                       inMemCtx: memCtx];
}

- (int) getPidLidReminderOverride: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidReminderOverride: data
                                                     inMemCtx: memCtx];
}

- (int) getPidLidReminderType: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidReminderType: data
                                                 inMemCtx: memCtx];
}

- (int) getPidLidReminderPlaySound: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidReminderPlaySound: data
                                                      inMemCtx: memCtx];
}

- (int) getPidLidReminderFileParameter: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidReminderFileParameter: data
                                                          inMemCtx: memCtx];
}

/* attendee */
- (void) _setupRecurrenceInCalendar: (iCalCalendar *) calendar
                          withEvent: (iCalEvent *) event
                           fromData: (NSData *) mapiRecurrenceData
{
  struct Binary_r *blob;
  struct AppointmentRecurrencePattern *pattern;
  NSMutableArray *otherEvents;

  /* cleanup */
  otherEvents = [[calendar events] mutableCopy];
  [otherEvents removeObject: event];
  [calendar removeChildren: otherEvents];
  [otherEvents release];

  blob = [mapiRecurrenceData asBinaryInMemCtx: NULL];
  pattern = get_AppointmentRecurrencePattern (blob, blob);
  [calendar setupRecurrenceWithMasterEntity: event
                      fromRecurrencePattern: &pattern->RecurrencePattern];
  talloc_free (blob);
}

- (NSString *) _uidFromGlobalObjectId
{
  NSData *objectId;
  NSString *uid = nil;
  char *bytesDup, *uidStart;
  NSUInteger length;

  /* NOTE: we only handle the generic case at the moment, see
     MAPIStoreAppointmentWrapper */
  objectId = [properties objectForKey: MAPIPropertyKey (PidLidGlobalObjectId)];
  if (objectId)
    {
      length = [objectId length];
      bytesDup = talloc_array (NULL, char, length + 1);
      memcpy (bytesDup, [objectId bytes], length);
      bytesDup[length] = 0;
      uidStart = bytesDup + length - 1;
      while (uidStart != bytesDup && *(uidStart - 1))
        uidStart--;
      if (uidStart > bytesDup && *uidStart)
        uid = [NSString stringWithUTF8String: uidStart];
      talloc_free (bytesDup);
    }

  return uid;
}

- (void) _fixupEventWithExistingUID
{
  NSString *uid, *existingCName, *existingURL;
  MAPIStoreMapping *mapping;
  uint64_t objectId;
  SOGoAppointmentObject *existingObject;
  WOContext *woContext;

  uid = [self _uidFromGlobalObjectId];
  existingCName = [[container sogoObject] resourceNameForEventUID: uid];
  if (existingCName)
    {
      mapping = [[self context] mapping];

      /* dissociate the object url from the old object's id */
      existingURL = [NSString stringWithFormat: @"%@%@",
                              [container url], existingCName];
      objectId = [mapping idFromURL: existingURL];
      [mapping unregisterURLWithID: objectId];

      /* dissociate the object url associated with this object, as we want to
         discard it */
      objectId = [self objectId];
      [mapping unregisterURLWithID: objectId];
      
      /* associate the object url with this object id */
      [mapping registerURL: existingURL withID: objectId];

      /* reinstantiate the old sogo object and attach it to self */
      woContext = [[self context] woContext];
      existingObject = [[container sogoObject] lookupName: existingCName
                                                inContext: woContext
                                                  acquire: NO];
      [existingObject setContext: woContext];
      ASSIGN (sogoObject, existingObject);
      isNew = NO;
    }
}

- (void) _setupAlarmDataInEvent: (iCalEvent *) newEvent
{
  NSArray *alarms;
  iCalAlarm *currentAlarm, *alarm = nil;
  iCalTrigger *trigger;
  NSNumber *delta;
  NSString *action;
  NSUInteger count, max;

  /* find and remove first display alarm */
  alarms = [newEvent alarms];
  max = [alarms count];
  for (count = 0; !alarm && count < max; count++)
    {
      currentAlarm = [alarms objectAtIndex: count];
      action = [[currentAlarm action] lowercaseString];
      if (!action || [action isEqualToString: @"display"])
        alarm =  currentAlarm;
    }

  if (alarm)
    [newEvent removeChild: alarm];

  if ([[properties objectForKey: MAPIPropertyKey (PidLidReminderSet)]
        boolValue])
    {
      delta
        = [properties objectForKey: MAPIPropertyKey (PidLidReminderDelta)];
      if (delta)
        {
          alarm = [iCalAlarm new];
          [alarm setAction: @"DISPLAY"];
          trigger = [iCalTrigger elementWithTag: @"trigger"];
          [trigger setValueType: @"DURATION"];
          [trigger
            setSingleValue: [NSString stringWithFormat: @"-PT%@M", delta]
                    forKey: @""];
          [alarm setTrigger: trigger];
          [newEvent addToAlarms: alarm];
          [alarm release];
        }
    }
}

- (void) save
{
  iCalCalendar *vCalendar;
  BOOL isAllDay;
  iCalDateTime *start, *end;
  iCalTimeZone *tz;
  NSCalendarDate *now;
  NSString *content, *tzName, *priority;
  iCalEvent *newEvent;
  iCalPerson *userPerson;
  NSUInteger responseStatus = 0;
  SOGoUser *activeUser;
  id value;

  if (isNew)
    {
      /* Hack required because of what's explained in oxocal 3.1.4.7.1:
         basically, Outlook creates a copy of the event and then removes the
         old instance. We perform a trickery to avoid performing those
         operations in the backend, in a way that enables us to recover the
         initial instance and act solely on it. */
      [self _fixupEventWithExistingUID];
    }

  [self logWithFormat: @"-save, event props:"];
  // MAPIStoreDumpMessageProperties (newProperties);

  now = [NSCalendarDate date];

  content = [sogoObject contentAsString];
  if (![content length])
    {
      newEvent = [sogoObject component: YES secure: NO];
      vCalendar = [newEvent parent];
      [vCalendar setProdID: @"-//Inverse inc.//OpenChange+SOGo//EN"];
      content = [vCalendar versitString];
      [newEvent setCreated: now];
    }

  vCalendar = [iCalCalendar parseSingleFromSource: content];
  newEvent = [[vCalendar events] objectAtIndex: 0];

  activeUser = [[self context] activeUser];
  userPerson = [newEvent userAsAttendee: activeUser];
  [newEvent setTimeStampAsDate: now];

  if (userPerson)
    {
      // iCalPersonPartStat newPartStat;
      NSString *newPartStat;

      value
        = [properties objectForKey: MAPIPropertyKey (PidLidResponseStatus)];
      if (value)
        responseStatus = [value unsignedLongValue];

      /* FIXME: we should provide a data converter between OL partstats and
         SOGo */
      switch (responseStatus)
        {
        case 0x02: /* respTentative */
          // newPartStat = iCalPersonPartStatTentative;
          newPartStat = @"TENTATIVE";
          break;
        case 0x03: /* respAccepted */
          // newPartStat = iCalPersonPartStatAccepted;
          newPartStat = @"ACCEPTED";
          break;
        case 0x04: /* respDeclined */
          // newPartStat = iCalPersonPartStatDeclined;
          newPartStat = @"DECLINED";
          break;
        default:
          newPartStat = nil;
        }

      if (newPartStat // != iCalPersonPartStatUndefined
          )
        {
          // iCalPerson *participant;

          // participant = [newEvent userAsAttendee: activeUser];
          // [participant setParticipationStatus: newPartStat];
          // [sogoObject saveComponent: newEvent];

          [sogoObject changeParticipationStatus: newPartStat
                                   withDelegate: nil];
          // [[self context] tearDownRequest];
        }
    }
  else
    {
      [newEvent setLastModified: now];

      // summary
      value = [properties
                objectForKey: MAPIPropertyKey (PR_NORMALIZED_SUBJECT_UNICODE)];
      if (value)
        [newEvent setSummary: value];

      // Location
      value = [properties objectForKey: MAPIPropertyKey (PidLidLocation)];
      if (value)
        [newEvent setLocation: value];

      isAllDay = [[properties
                    objectForKey: MAPIPropertyKey (PidLidAppointmentSubType)]
                   boolValue];

      if (!isAllDay)
        {
          tzName = [[self ownerTimeZone] name];
          tz = [iCalTimeZone timeZoneForName: tzName];
          [vCalendar addTimeZone: tz];
        }

      // start
      value = [properties objectForKey: MAPIPropertyKey (PR_START_DATE)];
      if (!value)
        value = [properties
                  objectForKey: MAPIPropertyKey (PidLidAppointmentStartWhole)];
      if (value)
        {
          start = (iCalDateTime *) [newEvent uniqueChildWithTag: @"dtstart"];
          if (isAllDay)
            [start setDate: value];
          else
            {
              [start setTimeZone: tz];
              [start setDateTime: value];
            }
        }

      /* end */
      value = [properties objectForKey: MAPIPropertyKey(PR_END_DATE)];
      if (!value)
        value = [properties objectForKey: MAPIPropertyKey(PidLidAppointmentEndWhole)];
      if (value)
        {
          end = (iCalDateTime *) [newEvent uniqueChildWithTag: @"dtend"];
          if (isAllDay)
            [end setDate: value];
          else
            {
              [end setTimeZone: tz];
              [end setDateTime: value];
            }
        }

      /* priority */
      value = [properties objectForKey: MAPIPropertyKey(PR_IMPORTANCE)];
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
      [newEvent setPriority: priority];

      /* show time as free/busy/tentative/out of office. Possible values are:
	 0x00000000 - olFree
	 0x00000001 - olTentative
	 0x00000002 - olBusy
	 0x00000003 - olOutOfOffice */
      value = [properties objectForKey: MAPIPropertyKey(PidLidBusyStatus)];
      if (value)
	{
	  switch ([value intValue])
	    {
	    case 0:
	      [newEvent setTransparency: @"TRANSPARENT"];
	      break;
	    case 1:
	    case 2:
	    case 3:
	    default:
	      [newEvent setTransparency: @"OPAQUE"];
	    }
	}

      /* Comment */
      value = [properties objectForKey: MAPIPropertyKey (PR_BODY_UNICODE)];
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
        [newEvent setComment: value];
      
      /* recurrence */
      value = [properties
                objectForKey: MAPIPropertyKey (PidLidAppointmentRecur)];
      if (value)
        [self _setupRecurrenceInCalendar: vCalendar
	                       withEvent: newEvent
                                fromData: value];

      [newEvent setOrganizer: nil];
      [newEvent removeAllAttendees];

      /* alarm */
      [self _setupAlarmDataInEvent: newEvent];

      if ([[properties objectForKey: MAPIPropertyKey (PidLidAppointmentStateFlags)] intValue]
          != 0)
        {
          // Organizer
          value = [properties objectForKey: @"recipients"];
          if (value)
            {
              NSArray *recipients;
              NSDictionary *dict;
              NSString *orgEmail, *attEmail;
              iCalPerson *person;
              iCalPersonPartStat newPartStat;
              NSNumber *flags, *trackStatus;
              int i, effective;

              /* We must set the organizer preliminarily here because, unlike what
                 the doc states, Outlook does not always pass the real organizer
                 in the recipients list. */
              dict = [activeUser primaryIdentity];
              person = [iCalPerson new];
              [person setCn: [dict objectForKey: @"fullName"]];
              orgEmail = [dict objectForKey: @"email"];
              [person setEmail: orgEmail];
              [newEvent setOrganizer: person];
              [person release];

              recipients = [value objectForKey: @"to"];
              effective = 0;
              for (i = 0; i < [recipients count]; i++)
                {
                  dict = [recipients objectAtIndex: i];

                  flags = [dict objectForKey: MAPIPropertyKey (PR_RECIPIENT_FLAGS)];
                  if (!flags)
                    {
                      [self logWithFormat:
                              @"no recipient flags specified: skipping recipient"];
                      continue;
                    }

                  person = [iCalPerson new];
                  [person setCn: [dict objectForKey: @"fullName"]];
                  attEmail = [dict objectForKey: @"email"];
                  [person setEmail: attEmail];

                  if (([flags unsignedIntValue] & 0x0002)) /* recipOrganizer */
                    [newEvent setOrganizer: person];
                  else
                    {
                      /* Work-around: it happens that Outlook still passes the
                         organizer as a recipient, maybe because of a feature
                         documented in a pre-mesozoic PDF still buried in a
                         cavern... In that case we remove it, and we keep the
                         number of effective recipients in "effective". If the
                         total is 0, we remove the "ORGANIZER" too. */
                      if ([attEmail isEqualToString: orgEmail])
                        {
                          [self logWithFormat:
                                  @"avoiding setting organizer as recipient"];
                          continue;
                        }

                      trackStatus
                        = [dict
                            objectForKey: MAPIPropertyKey (PR_RECIPIENT_TRACKSTATUS)];

                      /* FIXME: we should provide a data converter between OL
                         partstats and SOGo */
                      switch ([trackStatus unsignedIntValue])
                        {
                        case 0x02: /* respTentative */
                          newPartStat = iCalPersonPartStatTentative;
                          break;
                        case 0x03: /* respAccepted */
                          newPartStat = iCalPersonPartStatAccepted;
                          break;
                        case 0x04: /* respDeclined */
                          newPartStat = iCalPersonPartStatDeclined;
                          break;
                        default:
                          newPartStat = iCalPersonPartStatNeedsAction;
                        }

                      [person setParticipationStatus: newPartStat];
                      [person setRsvp: @"TRUE"];
                      [person setRole: @"REQ-PARTICIPANT"];
                      [newEvent addToAttendees: person];
                      effective++;
                    }

                  [person release];
                }

              if (effective == 0) /* See work-around above */
                [newEvent setOrganizer: nil];
            }
        }

      [sogoObject saveComponent: newEvent];
    }
  [(MAPIStoreCalendarFolder *) container synchroniseCache];
  value = [properties objectForKey: MAPIPropertyKey (PR_CHANGE_KEY)];
  if (value)
    [(MAPIStoreCalendarFolder *) container
        setChangeKey: value forMessageWithKey: [self nameInContainer]];
}

- (id) lookupAttachment: (NSString *) childKey
{
  return [attachmentParts objectForKey: childKey];
}

- (MAPIStoreAttachment *) createAttachment
{
  MAPIStoreCalendarAttachment *newAttachment;
  uint32_t newAid;
  NSString *newKey;

  newAid = [[self attachmentKeys] count];

  newAttachment = [MAPIStoreCalendarAttachment
                    mapiStoreObjectWithSOGoObject: nil
                                      inContainer: self];
  [newAttachment setIsNew: YES];
  [newAttachment setAID: newAid];
  newKey = [NSString stringWithFormat: @"%ul", newAid];
  [attachmentParts setObject: newAttachment
                      forKey: newKey];
  [attachmentKeys release];
  attachmentKeys = nil;

  return newAttachment;
}

- (int) setReadFlag: (uint8_t) flag
{
  return MAPISTORE_SUCCESS;
}

@end
