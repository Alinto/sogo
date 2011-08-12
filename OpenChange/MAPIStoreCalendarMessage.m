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

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalTimeZone.h>
#import <SOGo/SOGoUser.h>
#import <Appointments/SOGoAppointmentObject.h>
#import <Appointments/iCalEntityObject+SOGo.h>

#import "MAPIStoreAppointmentWrapper.h"
#import "MAPIStoreCalendarAttachment.h"
#import "MAPIStoreContext.h"
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

  if (!appointmentWrapper)
    {
      event = [sogoObject component: NO secure: NO];
      ASSIGN (appointmentWrapper,
              [MAPIStoreAppointmentWrapper wrapperWithICalEvent: event
                                           inTimeZone: [self ownerTimeZone]]);
    }

  return appointmentWrapper;
}

/* getters */
- (int) getPrIconIndex: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPrIconIndex: data inMemCtx: memCtx];
}

- (int) getPrMessageClass: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self appointmentWrapper] getPrMessageClass: data inMemCtx: memCtx];
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

- (void) getMessageData: (struct mapistore_message **) dataPtr
               inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *text;
  NSArray *attendees;
  iCalPerson *person;
  struct SRowSet *recipients;
  int count, max;
  iCalEvent *event;
  struct mapistore_message *msgData;

  [super getMessageData: &msgData inMemCtx: memCtx];

  event = [sogoObject component: NO secure: NO];
  attendees = [event attendees];
  max = [attendees count];

  recipients = talloc_zero (msgData, struct SRowSet);
  recipients->cRows = max;
  recipients->aRow = talloc_array (recipients, struct SRow, max);
  for (count = 0; count < max; count++)
    {
      recipients->aRow[count].ulAdrEntryPad = 0;
      recipients->aRow[count].cValues = 3;
      recipients->aRow[count].lpProps = talloc_array (recipients->aRow,
                                                      struct SPropValue,
                                                      4);
      
      // TODO (0x01 = primary recipient)
      set_SPropValue_proptag (recipients->aRow[count].lpProps,
                              PR_RECIPIENT_TYPE,
                              MAPILongValue (recipients->aRow[count].lpProps, 0x01));

      set_SPropValue_proptag (recipients->aRow[count].lpProps + 1,
                              PR_ADDRTYPE_UNICODE,
                              [@"SMTP" asUnicodeInMemCtx: recipients->aRow]);

      person = [attendees objectAtIndex: count];
      text = [person rfc822Email];
      if (!text)
        text = @"";
      set_SPropValue_proptag (recipients->aRow[count].lpProps + 2,
                              PR_EMAIL_ADDRESS_UNICODE,
                              [text asUnicodeInMemCtx: recipients->aRow]);

      text = [person cn];
      if ([text length] > 0)
        {
          recipients->aRow[count].cValues++;
          set_SPropValue_proptag (recipients->aRow[count].lpProps + 3,
                                  PR_DISPLAY_NAME_UNICODE,
                                  [text asUnicodeInMemCtx: recipients->aRow]);
        }
    }
  msgData->recipients = recipients;
  *dataPtr = msgData;
}

- (void) _setupRecurrenceInCalendar: (iCalCalendar *) calendar
                           fromData: (NSData *) mapiRecurrenceData
{
  struct Binary_r *blob;
  struct AppointmentRecurrencePattern *pattern;
  NSMutableArray *otherEvents;
  iCalEvent *event;

  event = [sogoObject component: NO secure: NO];

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

- (void) save
{
  iCalCalendar *vCalendar;
  iCalDateTime *start, *end;
  iCalTimeZone *tz;
  NSCalendarDate *now;
  NSString *content, *tzName;
  iCalEvent *newEvent;
  iCalPerson *userPerson;
  NSUInteger responseStatus = 0;
  SOGoUser *activeUser;
  id value;

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
        = [newProperties objectForKey: MAPIPropertyKey (PidLidResponseStatus)];
      if (value)
        responseStatus = [value unsignedLongValue];

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
      value = [newProperties
                objectForKey: MAPIPropertyKey (PR_NORMALIZED_SUBJECT_UNICODE)];
      if (value)
        [newEvent setSummary: value];

      // Location
      value = [newProperties objectForKey: MAPIPropertyKey (PidLidLocation)];
      if (value)
        [newEvent setLocation: value];

      tzName = [[self ownerTimeZone] name];
      tz = [iCalTimeZone timeZoneForName: tzName];
      [vCalendar addTimeZone: tz];

      // start
      value = [newProperties objectForKey: MAPIPropertyKey (PR_START_DATE)];
      if (!value)
        value = [newProperties
                  objectForKey: MAPIPropertyKey (PidLidAppointmentStartWhole)];
      if (value)
        {
          start = (iCalDateTime *) [newEvent uniqueChildWithTag: @"dtstart"];
          [start setTimeZone: tz];
          [start setDateTime: value];
        }

      // end
      value = [newProperties objectForKey: MAPIPropertyKey (PR_END_DATE)];
      if (!value)
        value = [newProperties objectForKey: MAPIPropertyKey (PidLidAppointmentEndWhole)];
      if (value)
        {
          end = (iCalDateTime *) [newEvent uniqueChildWithTag: @"dtend"];
          [end setTimeZone: tz];
          [end setDateTime: value];
        }

      /* recurrence */
      value = [newProperties
                objectForKey: MAPIPropertyKey (PidLidAppointmentRecur)];
      if (value)
        [self _setupRecurrenceInCalendar: vCalendar
                                fromData: value];

      // Organizer
      value = [newProperties objectForKey: @"recipients"];
      if (value)
        {
          NSArray *recipients;
          NSDictionary *dict;
          iCalPerson *person;
          int i;

          dict = [activeUser primaryIdentity];
          person = [iCalPerson new];
          [person setCn: [dict objectForKey: @"fullName"]];
          [person setEmail: [dict objectForKey: @"email"]];
          [newEvent setOrganizer: person];
          [person release];

          recipients = [value objectForKey: @"to"];
      
          for (i = 0; i < [recipients count]; i++)
            {
              dict = [recipients objectAtIndex: i];
              person = [iCalPerson new];
              
              [person setCn: [dict objectForKey: @"fullName"]];
              [person setEmail: [dict objectForKey: @"email"]];
              [person setParticipationStatus: iCalPersonPartStatNeedsAction];
              [person setRsvp: @"TRUE"];
              [person setRole: @"REQ-PARTICIPANT"]; 

              // FIXME: We must NOT always rely on this
              if (![newEvent isAttendee: [person rfc822Email]])
                [newEvent addToAttendees: person];
              
              [person release];
            }
        }

      [sogoObject saveComponent: newEvent];
    }
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

@end
