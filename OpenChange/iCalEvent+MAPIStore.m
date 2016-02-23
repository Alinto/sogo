/* iCalEvent+MAPIStore.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Inverse inc
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
#import <NGCards/iCalTimeZonePeriod.h>
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

#import "iCalEvent+MAPIStore.h"
#import "iCalTimeZone+MAPIStore.h"

@implementation iCalEvent (MAPIStoreProperties)

- (void) _setupEventRecurrence: (NSData *) mapiRecurrenceData
                    inTimeZone: (iCalTimeZone *) tz
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  struct Binary_r *blob;
  struct AppointmentRecurrencePattern *pattern;

  blob = [mapiRecurrenceData asBinaryInMemCtx: memCtx];
  pattern = get_AppointmentRecurrencePattern (memCtx, blob);

  if (pattern == NULL) {
    [self logWithFormat: @"Error parsing recurrence pattern. No changes in event recurrence will be done"];
    return;
  }

  [(iCalCalendar *) parent setupRecurrenceWithMasterEntity: self
                                     fromRecurrencePattern: &pattern->RecurrencePattern
                                            withExceptions: pattern->ExceptionInfo
                                         andExceptionCount: pattern->ExceptionCount
                                                inTimeZone: tz
   ];
  //talloc_free (blob);
}

- (void) _setupEventAlarmFromProperties: (NSDictionary *) properties
{
  NSArray *alarms;
  iCalAlarm *currentAlarm, *alarm = nil;
  iCalTrigger *trigger;
  NSNumber *delta;
  NSString *action;
  NSUInteger count, max;

  /* find and remove first display alarm */
  alarms = [self alarms];
  max = [alarms count];
  for (count = 0; !alarm && count < max; count++)
    {
      currentAlarm = [alarms objectAtIndex: count];
      action = [[currentAlarm action] lowercaseString];
      if (!action || [action isEqualToString: @"display"])
        alarm =  currentAlarm;
    }

  if (alarm)
    [self removeChild: alarm];

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
          [self addToAlarms: alarm];
          [alarm release];
        }
    }
}

- (int) _updateFromAttendeeMAPIProperties: (NSArray *) recipients
                                 withRole: (NSString *) role
                                 outParam: (BOOL *) organizerIsSet
{
  NSDictionary *dict;
  NSString *attEmail;
  iCalPerson *person;
  iCalPersonPartStat newPartStat;
  NSNumber *flags, *trackStatus;
  int i, effective;

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
          [self setOrganizer: person];
          *organizerIsSet = YES;
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
                  [self setOrganizer: person];
                  *organizerIsSet = YES;
                  [self logWithFormat: @"organizer set via track status"];
                }
              else
                {
                  [person setParticipationStatus: newPartStat];
                  [person setRsvp: @"TRUE"];
                  [person setRole: role];
                  [self addToAttendees: person];
                  effective++;
                }
            }
          else
            [self errorWithFormat: @"skipped recipient due"
                  @" to missing track status"];
        }

      [person release];
    }

  return effective;
}


- (void) updateFromMAPIProperties: (NSDictionary *) properties
                    inUserContext: (MAPIStoreUserContext *) userContext
                   withActiveUser: (SOGoUser *) activeUser
                            isNew: (BOOL) isNew
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  BOOL isAllDay;
  iCalDateTime *start, *end;
  iCalTimeZone *tz;
  NSString *priority, *class = nil, *tzDescription = nil;
  NSUInteger responseStatus = 0;
  SOGoUser *ownerUser;
  id value;

  // value = [properties objectForKey: MAPIPropertyKey (PidTagMessageClass)];
  // if (value)
  //   isException = [value isEqualToString: @"IPM.OLE.CLASS.{00061055-0000-0000-C000-000000000046}"];
  // else
  //   isException = NO;

  /* privacy */
  value = [properties objectForKey: MAPIPropertyKey(PidLidPrivate)];

  if (value)
    {
      if ([value boolValue])
	[self setAccessClass: @"PRIVATE"];
      else
	[self setAccessClass: @"PUBLIC"];
    }

  /* Time zone = PidLidAppointmentTimeZoneDefinitionRecur
     or PidLidAppointmentTimeZoneDefinition[Start|End]Display */
  value = [properties objectForKey: MAPIPropertyKey (PidLidAppointmentTimeZoneDefinitionStartDisplay)];
  if (!value)
    {
      value = [properties objectForKey: MAPIPropertyKey (PidLidAppointmentTimeZoneDefinitionEndDisplay)];
      if (!value)
        {
          /* If PidLidtimeZoneStruct, TZID SHOULD come from PidLidTimeZoneDescription,
            if PidLidAppointmentTimeZoneDefinition[Start|End]Display it MUST be derived from KeyName
            (MS-OXCICAL] 2.1.3.1.1.19.1) */
          value = [properties objectForKey: MAPIPropertyKey (PidLidAppointmentTimeZoneDefinitionRecur)];
          tzDescription = [properties objectForKey: MAPIPropertyKey (PidLidTimeZoneDescription)];
        }
    }
  if (value)
    {
      tz = [[iCalTimeZone alloc] iCalTimeZoneFromDefinition: value
                                            withDescription: tzDescription
                                                   inMemCtx: memCtx];
    }
  else
    /* The client is more likely to have the webmail's time zone than any other */
    tz = [iCalTimeZone timeZoneForName: [[userContext timeZone] name]];
  [(iCalCalendar *) parent addTimeZone: tz];

  /* CREATED */
  value = [properties objectForKey: MAPIPropertyKey (PidTagCreationTime)];
  if (value)
    [self setCreated: value];

 // LAST-MODIFIED = PidTagLastModificationTime
  value = [properties objectForKey: MAPIPropertyKey (PidTagLastModificationTime)];
  if (value)
    [self setLastModified: value];

  /* DTSTAMP = PidLidOwnerCriticalChange or PidLidAttendeeCriticalChange */
  value = [properties objectForKey: MAPIPropertyKey (PidLidOwnerCriticalChange)];
  if (value)
    [self setTimeStampAsDate: value];
 
  /* SUMMARY */
  value = [properties objectForKey: MAPIPropertyKey (PidTagNormalizedSubject)];
  if (value)
    [self setSummary: value];

  // Location
  value = [properties objectForKey: MAPIPropertyKey (PidLidLocation)];
  if (value)
    [self setLocation: value];

  isAllDay = [self isAllDay];
  value = [properties
                objectForKey: MAPIPropertyKey (PidLidAppointmentSubType)];
  if (value)
    isAllDay = [value boolValue];

  // recurrence-id
  value
    = [properties objectForKey: MAPIPropertyKey (PidLidExceptionReplaceTime)];
  if (value)
    [self setRecurrenceId: value];

  // start
  value = [properties objectForKey: MAPIPropertyKey (PidLidAppointmentStartWhole)];
  if (!value)
    value = [properties objectForKey: MAPIPropertyKey (PR_START_DATE)];
  if (value)
    {
      start = (iCalDateTime *) [self uniqueChildWithTag: @"dtstart"];
      [start setTimeZone: tz];
      if (isAllDay)
        {
          /* All-day events are set in floating time ([MS-OXCICAL] 2.1.3.1.1.20.8) */
          [start setDate: value];
          [start setTimeZone: nil];
        }
      else
          [start setDateTime: value];
    }

  /* end */
  value = [properties objectForKey: MAPIPropertyKey (PidLidAppointmentEndWhole)];
  if (!value)
    value = [properties objectForKey: MAPIPropertyKey (PR_END_DATE)];
  if (value)
    {
      end = (iCalDateTime *) [self uniqueChildWithTag: @"dtend"];
      [end setTimeZone: tz];
      if (isAllDay)
        {
          /* All-day events are set in floating time ([MS-OXCICAL] 2.1.3.1.1.20.8) */
          [end setDate: value];
          [end setTimeZone: nil];
        }
      else
          [end setDateTime: value];
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
  [self setPriority: priority];

  /* class */
  /* See [MS-OXCICAL] Section 2.1.3.11.20.4 */
  value = [properties objectForKey: MAPIPropertyKey(PR_SENSITIVITY)];
  if (value)
    {
      switch ([value intValue])
        {
        case 1:
          class = @"X-PERSONAL";
          break;
        case 2:
          class = @"PRIVATE";
          break;
        case 3:
          class = @"CONFIDENTIAL";
          break;
        default:  /* 0 as well */
          class = @"PUBLIC";
        }
    }

  if (class)
    [self setAccessClass: class];

  /* Categories */
  /* See [MS-OXCICAL] Section 2.1.3.1.1.20.3 */
  value = [properties objectForKey: MAPIPropertyKey (PidNameKeywords)];
  if (value)
    [self setCategories: value];

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
          [self setTransparency: @"TRANSPARENT"];
          break;
        case 1:
        case 2:
        case 3:
        default:
          [self setTransparency: @"OPAQUE"];
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
    {
      if ([value length] == 0 || [value isEqualToString: @"\\n"])
        value = nil;
      [self setComment: value];
    }

  /* recurrence */
  value = [properties
                objectForKey: MAPIPropertyKey (PidLidAppointmentRecur)];
  if (value)
    [self _setupEventRecurrence: value inTimeZone: tz inMemCtx: memCtx];

  /* alarm */
  [self _setupEventAlarmFromProperties: properties];

  // Organizer
  value = [properties objectForKey: @"recipients"];
  if (value)
    {
      NSDictionary *dict;
      NSString *orgEmail, *sentBy;
      iCalPerson *person;
      iCalPersonPartStat newPartStat;
      int effective;
      BOOL organizerIsSet = NO;

      [self setOrganizer: nil];
      [self removeAllAttendees];

      /* In [MS-OXOCAL] Section 2.2.4.10.7 says the recipient type is 0x01 as Required
         and 0x02 as Optional and other documents such [MS-OXCMSG] 2.2.3.1.2 indicates
         that MAPI_TO is 0x01 and MAPI_CC is 0x02, that's why in SOGo is in 'to' and 'cc'
         respectively. */
      effective = [self _updateFromAttendeeMAPIProperties: [value objectForKey: @"to"]
                                                 withRole: @"REQ-PARTICIPANT"
                                                 outParam: &organizerIsSet];
      effective += [self _updateFromAttendeeMAPIProperties: [value objectForKey: @"cc"]
                                                 withRole: @"OPT-PARTICIPANT"
                                                 outParam: &organizerIsSet];

      if (effective == 0) /* See work-around inside _updateFromAttendeeMAPIProperties */
        [self setOrganizer: nil];
      else
        {
          // SEQUENCE = PidLidAppointmentSequence
          value = [properties objectForKey: MAPIPropertyKey (PidLidAppointmentSequence)];
          if (value)
            [self setSequence: value];

          ownerUser = [userContext sogoUser];
          if (organizerIsSet)
            {
              /* We must reset the participation status to the value
                 obtained from PidLidResponseStatus as the value in
                 PidTagRecipientTrackStatus is not correct. Note (hack):
                 the method used here requires that the user directory
                 from LDAP and Samba matches perfectly. This can be solved
                 more appropriately by making use of the sender
                 properties... */
              person = [self userAsAttendee: ownerUser];
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

                  value = [properties objectForKey: MAPIPropertyKey (PidLidAttendeeCriticalChange)];
                  if (value && ![value isNever])
                    [self setTimeStampAsDate: value];
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

              if (![activeUser isEqual: ownerUser])
                {
                  dict = [activeUser primaryIdentity];
                  sentBy = [NSString stringWithFormat: @"mailto:%@",
                                     [dict objectForKey: @"email"]];
                  [person setSentBy: sentBy];
                }
              [self setOrganizer: person];
              [person release];
            }
        }
    }
  // Creator (with sharing purposes)
  if (isNew)
    {
      value = [properties objectForKey: MAPIPropertyKey (PidTagLastModifierName)];
      if (value)
        [[self uniqueChildWithTag: @"x-sogo-component-created-by"] setSingleValue: value
                                                                           forKey: @""];
    }
}

@end
