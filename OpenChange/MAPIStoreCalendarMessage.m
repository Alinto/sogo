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
#import <SOGo/SOGoPermissions.h>
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
#import "MAPIStoreUserContext.h"
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
  MAPIStoreUserContext *userContext;

  if (!appointmentWrapper)
    {
      event = [sogoObject component: NO secure: YES];
      context = [self context];
      userContext = [self userContext];
      ASSIGN (appointmentWrapper,
              [MAPIStoreAppointmentWrapper wrapperWithICalEvent: event
                                                        andUser: [userContext sogoUser]
                                                 andSenderEmail: nil
                                                     inTimeZone: [self ownerTimeZone]
                                             withConnectionInfo: [context connectionInfo]]);
    }

  return appointmentWrapper;
}

/* getters */
- (int) getPidTagIconIndex: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidTagIconIndex: data inMemCtx: memCtx];
}

- (int) getPidLidFInvited: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getYes: data inMemCtx: memCtx];
}

- (int) getPidTagMessageClass: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = talloc_strdup (memCtx, "IPM.Appointment");

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidAppointmentMessageClass: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = talloc_strdup (memCtx, "IPM.Appointment");

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagOwnerAppointmentId: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidTagOwnerAppointmentId: data inMemCtx: memCtx];
}

- (int) getPidTagStartDate: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidTagStartDate: data inMemCtx: memCtx];
}

- (int) getPidLidAppointmentSequence: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidAppointmentSequence: data
                                                        inMemCtx: memCtx];
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

- (int) getPidTagEndDate: (void **) data
                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidTagEndDate: data inMemCtx: memCtx];
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
  return [[self appointmentWrapper] getPidLidAppointmentSubType: data
                                                       inMemCtx: memCtx];
}

- (int) getPidLidBusyStatus: (void **) data // TODO
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidLidBusyStatus: data inMemCtx: memCtx];
}

- (int) getPidTagSubject: (void **) data // SUMMARY
                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidTagSubject: data inMemCtx: memCtx];
}

- (int) getPidLidSideEffects: (void **) data // TODO
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx,
                         seOpenToDelete | seOpenToCopy | seOpenToMove
                         | seCoerceToInbox | seOpenForCtxMenu);

  return MAPISTORE_SUCCESS;
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

- (int) getPidTagSensitivity: (void **) data // not implemented, depends on CLASS
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidTagSensitivity: data inMemCtx: memCtx];
}

- (int) getPidTagImportance: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidTagImportance: data inMemCtx: memCtx];
}

- (int) getPidTagBody: (void **) data
             inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidTagBody: data inMemCtx: memCtx];
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

- (int) getPidTagProcessed: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
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
- (int) getPidTagSenderEmailAddress: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidTagSenderEmailAddress: data
                                                       inMemCtx: memCtx];
}

- (int) getPidTagSenderAddressType: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidTagSenderAddressType: data
                                                      inMemCtx: memCtx];
}

- (int) getPidTagSenderName: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidTagSenderName: data
                                               inMemCtx: memCtx];
}

- (int) getPidTagSenderEntryId: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPidTagSenderEntryId: data
                                                  inMemCtx: memCtx];
}

/* sender representing */
- (int) getPidTagSentRepresentingEmailAddress: (void **) data
                                     inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagSenderEmailAddress: data inMemCtx: memCtx];
}

- (int) getPidTagSentRepresentingAddressType: (void **) data
                                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getSMTPAddrType: data inMemCtx: memCtx];
}

- (int) getPidTagSentRepresentingName: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagSenderName: data inMemCtx: memCtx];
}

- (int) getPidTagSentRepresentingEntryId: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagSenderEntryId: data inMemCtx: memCtx];
}

/* attendee */
// - (int) getPidTagReceivedByAddressType: (void **) data
//                        inMemCtx: (TALLOC_CTX *) memCtx
// {
//   return [[self appointmentWrapper] getPidTagReceivedByAddressType: data
//                                                    inMemCtx: memCtx];
// }

// - (int) getPidTagReceivedByEmailAddress: (void **) data
//                            inMemCtx: (TALLOC_CTX *) memCtx
// {
//   return [[self appointmentWrapper] getPidTagReceivedByEmailAddress: data
//                                                        inMemCtx: memCtx];
// }

// - (int) getPidTagReceivedByName: (void **) data
//                    inMemCtx: (TALLOC_CTX *) memCtx
// {
//   return [[self appointmentWrapper] getPidTagReceivedByName: data
//                                                inMemCtx: memCtx];
// }

// - (int) getPidTagReceivedByEntryId: (void **) data
//                       inMemCtx: (TALLOC_CTX *) memCtx
// {
//   return [[self appointmentWrapper] getPidTagReceivedByEntryId: data
//                                                   inMemCtx: memCtx];
// }

// /* attendee representing */
// - (int) getPidTagReceivedRepresentingEmailAddress: (void **) data
//                                  inMemCtx: (TALLOC_CTX *) memCtx
// {
//   return [self getPidTagReceivedByEmailAddress: data inMemCtx: memCtx];
// }

// - (int) getPidTagReceivedRepresentingAddressType: (void **) data
//                              inMemCtx: (TALLOC_CTX *) memCtx
// {
//   return [self getSMTPAddrType: data inMemCtx: memCtx];
// }

// - (int) getPidTagReceivedRepresentingName: (void **) data
//                          inMemCtx: (TALLOC_CTX *) memCtx
// {
//   return [self getPidTagReceivedByName: data inMemCtx: memCtx];
// }

// - (int) getPidTagReceivedRepresentingEntryId: (void **) data
//                             inMemCtx: (TALLOC_CTX *) memCtx
// {
//   return [self getPidTagReceivedByEntryId: data inMemCtx: memCtx];
// }

- (int) getPidTagResponseRequested: (void **) data
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

- (void) _fixupAppointmentObjectWithUID: (NSString *) uid
{
  NSString *cname, *url;
  MAPIStoreMapping *mapping;
  uint64_t objectId;
  SOGoAppointmentFolder *folder;
  SOGoAppointmentObject *newObject;
  WOContext *woContext;

  cname = [[container sogoObject] resourceNameForEventUID: uid];
  if (cname)
    isNew = NO;
  else
    cname = [NSString stringWithFormat: @"%@.ics", uid];

  mapping = [self mapping];

  url = [NSString stringWithFormat: @"%@%@", [container url], cname];
  folder = [container sogoObject];
  /* reinstantiate the old sogo object and attach it to self */
  woContext = [[self userContext] woContext];
  if (isNew)
    newObject = [SOGoAppointmentObject objectWithName: cname
                                          inContainer: folder];
  else
    {
      /* dissociate the object url from the old object's id */
      objectId = [mapping idFromURL: url];
      [mapping unregisterURLWithID: objectId];
      newObject = [folder lookupName: cname
                           inContext: woContext
                             acquire: NO];
    }

  /* dissociate the object url associated with this object, as we want to
     discard it */
  objectId = [self objectId];
  [mapping unregisterURLWithID: objectId];
      
  /* associate the new object url with this object id */
  [mapping registerURL: url withID: objectId];

  [newObject setContext: woContext];
  ASSIGN (sogoObject, newObject);
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

- (BOOL) subscriberCanReadMessage
{
  NSArray *roles;

  roles = [self activeUserRoles];

  return ([roles containsObject: SOGoCalendarRole_ComponentViewer]
          || [roles containsObject: SOGoCalendarRole_ComponentDAndTViewer]
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

- (void) save
{
  iCalCalendar *vCalendar;
  BOOL isAllDay;
  iCalDateTime *start, *end;
  iCalTimeZone *tz;
  NSCalendarDate *now;
  NSString *uid, *content, *tzName, *priority, *newParticipationStatus = nil;
  iCalEvent *newEvent;
  // iCalPerson *userPerson;
  NSUInteger responseStatus = 0;
  NSInteger tzOffset;
  SOGoUser *activeUser, *ownerUser;
  id value;

  if (isNew)
    {
      uid = [self _uidFromGlobalObjectId];
      if (uid)
        {
          /* Hack required because of what's explained in oxocal 3.1.4.7.1:
             basically, Outlook creates a copy of the event and then removes the
             old instance. We perform a trickery to avoid performing those
             operations in the backend, in a way that enables us to recover the
             initial instance and act solely on it. */
          [self _fixupAppointmentObjectWithUID: uid];
        }
      else
        uid = [SOGoObject globallyUniqueObjectId];
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
      [newEvent setCreated: now];
      // CREATED = PidTagCreationTime
      value = [properties objectForKey: MAPIPropertyKey (PidTagCreationTime)];
      if (value)
        [newEvent setCreated: value];
      [newEvent setUid: uid];
      content = [vCalendar versitString];
    }

  vCalendar = [iCalCalendar parseSingleFromSource: content];
  newEvent = [[vCalendar events] objectAtIndex: 0];

  // DTSTAMP = PidLidOwnerCriticalChange or PidLidAttendeeCriticalChange
  value = [properties objectForKey: MAPIPropertyKey (PidLidOwnerCriticalChange)];
  if (!value || [value isNever])
    value = now;
  [newEvent setTimeStampAsDate: value];
 
 // LAST-MODIFIED = PidTagLastModificationTime
  value = [properties objectForKey: MAPIPropertyKey (PidTagLastModificationTime)];
  if (!value)
    value = now;
  [newEvent setLastModified: value];

  // summary
  value = [properties
                objectForKey: MAPIPropertyKey (PR_NORMALIZED_SUBJECT_UNICODE)];
  if (value)
    [newEvent setSummary: value];

  // Location
  value = [properties objectForKey: MAPIPropertyKey (PidLidLocation)];
  if (value)
    [newEvent setLocation: value];

  isAllDay = [newEvent isAllDay];
  value = [properties
                objectForKey: MAPIPropertyKey (PidLidAppointmentSubType)];
  if (value)
    isAllDay = [value boolValue];
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
        {
          tzOffset = [[value timeZone] secondsFromGMTForDate: value];
          value = [value dateByAddingYears: 0 months: 0 days: 0
                                     hours: 0 minutes: 0
                                   seconds: -tzOffset];
          [start setTimeZone: nil];
          [start setDate: value];
        }
      else
        {
          [start setTimeZone: tz];
          [start setDateTime: value];
        }
    }

  /* end */
  value = [properties objectForKey: MAPIPropertyKey (PR_END_DATE)];
  if (!value)
    value = [properties objectForKey: MAPIPropertyKey (PidLidAppointmentEndWhole)];
  if (value)
    {
      end = (iCalDateTime *) [newEvent uniqueChildWithTag: @"dtend"];
      if (isAllDay)
        {
          tzOffset = [[value timeZone] secondsFromGMTForDate: value];
          value = [value dateByAddingYears: 0 months: 0 days: 0
                                     hours: 0 minutes: 0
                                   seconds: -tzOffset];
          [end setTimeZone: nil];
          [end setDate: value];
        }
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
  if (value && [value length] == 0)
    value = nil;
  [newEvent setComment: value];
      
  /* recurrence */
  value = [properties
                objectForKey: MAPIPropertyKey (PidLidAppointmentRecur)];
  if (value)
    [self _setupRecurrenceInCalendar: vCalendar
                           withEvent: newEvent
                            fromData: value];

  /* alarm */
  [self _setupAlarmDataInEvent: newEvent];

  // Organizer
  value = [properties objectForKey: @"recipients"];
  if (value)
    {
      NSArray *recipients;
      NSDictionary *dict;
      NSString *orgEmail, *sentBy, *attEmail;
      iCalPerson *person;
      iCalPersonPartStat newPartStat;
      NSNumber *flags, *trackStatus;
      int i, effective;
      BOOL organizerIsSet = NO;

      [newEvent setOrganizer: nil];
      [newEvent removeAllAttendees];

      recipients = [value objectForKey: @"to"];
      effective = 0;
      for (i = 0; i < [recipients count]; i++)
        {
          dict = [recipients objectAtIndex: i];
          person = [iCalPerson new];
          [person setCn: [dict objectForKey: @"fullName"]];
          attEmail = [dict objectForKey: @"email"];
          [person setEmail: attEmail];
 
          flags = [dict objectForKey: MAPIPropertyKey (PR_RECIPIENT_FLAGS)];
          if (!flags)
            {
              [self logWithFormat:
                      @"no recipient flags specified: skipping recipient"];
              continue;
            }

          if (([flags unsignedIntValue] & 0x0002)) /* recipOrganizer */
            {
              [newEvent setOrganizer: person];
              organizerIsSet = YES;
              [self logWithFormat: @"organizer set via recipient flags"];
            }
          else
            {
              BOOL isOrganizer = NO;

              // /* Work-around: it happens that Outlook still passes the
              //    organizer as a recipient, maybe because of a feature
              //    documented in a pre-mesozoic PDF still buried in a
              //    cavern... In that case we remove it, and we keep the
              //    number of effective recipients in "effective". If the
              //    total is 0, we remove the "ORGANIZER" too. */
              // if ([attEmail isEqualToString: orgEmail])
              //   {
              //     [self logWithFormat:
              //             @"avoiding setting organizer as recipient"];
              //     continue;
              //   }

              trackStatus = [dict objectForKey: MAPIPropertyKey (PidTagRecipientTrackStatus)];
              if (trackStatus)
                {
                  /* FIXME: we should provide a data converter between OL
                     partstats and SOGo */
                  switch ([trackStatus unsignedIntValue])
                    {
                    case 0x01: /* respOrganized */
                      isOrganizer = YES;
                      break;
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

                  if (isOrganizer)
                    {
                      [newEvent setOrganizer: person];
                      organizerIsSet = YES;
                      [self logWithFormat: @"organizer set via track status"];
                    }
                  else
                    {
                      [person setParticipationStatus: newPartStat];
                      [person setRsvp: @"TRUE"];
                      [person setRole: @"REQ-PARTICIPANT"];
                      [newEvent addToAttendees: person];
                      effective++;
                    }
                }
              else
                [self errorWithFormat: @"skipped recipient due"
                      @" to missing track status"];
            }

          [person release];
        }

      if (effective == 0) /* See work-around above */
        [newEvent setOrganizer: nil];
      else
        {
          // SEQUENCE = PidLidAppointmentSequence
          value = [properties objectForKey: MAPIPropertyKey (PidLidAppointmentSequence)];
          if (value)
            [newEvent setSequence: value];

          ownerUser = [[self userContext] sogoUser];
          if (organizerIsSet)
            {
              /* We must reset the participation status to the value
                 obtained from PidLidResponseStatus as the value in
                 PidTagRecipientTrackStatus is not correct. Note (hack):
                 the method used here requires that the user directory
                 from LDAP and Samba matches perfectly. This can be solved
                 more appropriately by making use of the sender
                 properties... */
              person = [newEvent userAsAttendee: ownerUser];
              if (person)
                {
                  value
                    = [properties objectForKey: MAPIPropertyKey (PidLidResponseStatus)];
                  if (value)
                    responseStatus = [value unsignedLongValue];
                      
                  /* FIXME: we should provide a data converter between OL partstats and
                     SOGo */
                  switch (responseStatus)
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
                  newParticipationStatus = [person partStatWithDefault];

                  value = [properties objectForKey: MAPIPropertyKey (PidLidAttendeeCriticalChange)];
                  if (value && ![value isNever])
                    [newEvent setTimeStampAsDate: value];
                  //                 if (newPartStat // != iCalPersonPartStatUndefined
                  //                     )
                  //                   {
                  //                     // iCalPerson *participant;

                  //                     // participant = [newEvent userAsAttendee: ownerUser];
                  //                     // [participant setParticipationStatus: newPartStat];
                  //                     // [sogoObject saveComponent: newEvent];

                  //                     [sogoObject changeParticipationStatus: newPartStat
                  //                                              withDelegate: nil];
                  //                     // [[self context] tearDownRequest];
                  //                   }
                  // //   }1005

                  // // else
                  // //   {
                }
            }
          else
            {
              [self errorWithFormat: @"organizer was not set although a"
                    @" recipient list was specified"];
              /* We must set the organizer preliminarily here because, unlike what
                 the doc states, Outlook does not always pass the real organizer
                 in the recipients list. */
              dict = [ownerUser primaryIdentity];
              person = [iCalPerson new];
              [person setCn: [dict objectForKey: @"fullName"]];
              orgEmail = [dict objectForKey: @"email"];
              [person setEmail: orgEmail];
                  
              activeUser = [[self context] activeUser];
              if (![activeUser isEqual: ownerUser])
                {
                  dict = [activeUser primaryIdentity];
                  sentBy = [NSString stringWithFormat: @"mailto:%@",
                                     [dict objectForKey: @"email"]];
                  [person setSentBy: sentBy];
                }
              [newEvent setOrganizer: person];
              [person release];
            }
        }
    }

  [sogoObject saveComponent: newEvent];
  if (newParticipationStatus)
    [sogoObject changeParticipationStatus: newParticipationStatus
                             withDelegate: nil];
  [self updateVersions];
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
