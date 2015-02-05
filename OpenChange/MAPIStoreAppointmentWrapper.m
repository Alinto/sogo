/* MAPIStoreAppointmentWrapper.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
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

#include <talloc.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/iCalAlarm.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalEventChanges.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalTrigger.h>
#import <NGCards/NSString+NGCards.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserManager.h>

#import "iCalTimeZone+MAPIStore.h"
#import "MAPIStoreRecurrenceUtils.h"
#import "MAPIStoreSamDBUtils.h"
#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSDate+MAPIStore.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreAppointmentWrapper.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <gen_ndr/property.h>
#include <gen_ndr/ndr_property.h>
#include <util/attr.h>
#include <libmapi/libmapi.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
#include <mapistore/mapistore_nameid.h>

static NSCharacterSet *hexCharacterSet = nil;

@implementation MAPIStoreAppointmentWrapper

+ (void) initialize
{
  if (!hexCharacterSet)
    {
      hexCharacterSet = [NSCharacterSet characterSetWithCharactersInString: @"1234567890abcdefABCDEF"];
      [hexCharacterSet retain];
    }
}

+ (id) wrapperWithICalEvent: (iCalEvent *) newEvent
                    andUser: (SOGoUser *) newUser
             andSenderEmail: (NSString *) newSenderEmail
                 inTimeZone: (NSTimeZone *) newTimeZone
         withConnectionInfo: (struct mapistore_connection_info *) newConnInfo
{
  MAPIStoreAppointmentWrapper *wrapper;

  wrapper = [[self alloc] initWithICalEvent: newEvent
                                    andUser: newUser
                             andSenderEmail: newSenderEmail
                                 inTimeZone: newTimeZone
                         withConnectionInfo: newConnInfo];
  [wrapper autorelease];

  return wrapper;
}

- (id) init
{
  if ((self = [super init]))
    {
      connInfo = NULL;
      calendar = nil;
      event = nil;
      timeZone = nil;
      senderEmail = nil;
      globalObjectId = nil;
      cleanGlobalObjectId = nil;
      user = nil;
      alarmSet = NO;
      itipSetup = NO;
      alarm = nil;
      method = nil;
    }

  return self;
}

- (void) _setupITIPContextFromAttendees
{
  iCalPerson *attendee = nil;
  NSArray *attendees;

  attendee = [event userAsAttendee: user];
  if (attendee)
    method = @"REQUEST";
  else if ([event userIsOrganizer: user])
    {
      if (senderEmail)
        attendee = [event findAttendeeWithEmail: senderEmail];
      if (!attendee)
        {
          attendees = [event attendees];
          if ([attendees count] == 1)
            attendee = [attendees objectAtIndex: 0];
        }
      if (attendee)
        {
          method = @"REPLY";
          partstat = [attendee participationStatus];
        }
      else
        {
          [self logWithFormat: @"no attendee matching sender found"];
          method = nil;
        }
    }
  else
    method = nil;

  [method retain];
}

- (void) _setupITIPContext
{
  NSArray *attendees;
  NSUInteger max;

  /* Here we attempt to determine the type of message from the ITIP method
     contained in the event. It it fails, we attempt to determine this by
     checking the identity of the organizer and of the attendees. */
  itipSetup = YES;
  method = [[event parent] method];
  if ([method length] > 0)
    {
      method = [method uppercaseString];
      [method retain];
      if ([method isEqualToString: @"REPLY"])
        {
          attendees = [event attendees];
          max = [attendees count];
          if (max == 1)
            partstat = [[attendees objectAtIndex: 0] participationStatus];
          else if (max > 1)
            [self _setupITIPContextFromAttendees];
        }
    }
  else
    [self _setupITIPContextFromAttendees];
}

- (id) initWithICalEvent: (iCalEvent *) newEvent
                 andUser: (SOGoUser *) newUser
          andSenderEmail: (NSString *) newSenderEmail
              inTimeZone: (NSTimeZone *) newTimeZone
      withConnectionInfo: (struct mapistore_connection_info *) newConnInfo
{
  NSArray *events;

  if ((self = [self init]))
    {
      connInfo = newConnInfo;
      ASSIGN (calendar, [newEvent parent]);
      event = newEvent;
      events = [calendar events];
      firstEvent = [events objectAtIndex: 0];
      ASSIGN (timeZone, newTimeZone);
      ASSIGN (user, newUser);
      ASSIGN (senderEmail, newSenderEmail);
      [self _setupITIPContext];
    }

  return self;
}

- (void) dealloc
{
  [calendar release];
  [timeZone release];
  [user release];
  [senderEmail release];
  [globalObjectId release];
  [cleanGlobalObjectId release];
  [alarm release];
  [method release];
  [super dealloc];
}

- (void) fillMessageData: (struct mapistore_message *) msgData
                inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *username, *cn, *email;
  NSData *entryId;
  NSArray *attendees;
  iCalPerson *person;
  iCalPersonPartStat partStat;
  uint32_t partStatValue;
  SOGoUserManager *mgr;
  NSDictionary *contactInfos;
  struct mapistore_message_recipient *recipient;
  int count, max, p;

  msgData->columns = set_SPropTagArray (msgData, 9,
                                        PR_OBJECT_TYPE,
                                        PR_DISPLAY_TYPE,
                                        PR_7BIT_DISPLAY_NAME_UNICODE,
                                        PR_SMTP_ADDRESS_UNICODE,
                                        PR_SEND_INTERNET_ENCODING,
                                        PR_RECIPIENT_DISPLAY_NAME_UNICODE,
                                        PR_RECIPIENT_FLAGS,
                                        PR_RECIPIENT_ENTRYID,
                                        PR_RECIPIENT_TRACKSTATUS);
// ,
//                                         PR_RECORD_KEY);

  attendees = [event attendees];
  max = [attendees count];

  if (max > 0)
    {
      mgr = [SOGoUserManager sharedUserManager];
      msgData->recipients_count = max + 1;
      msgData->recipients = talloc_array (msgData, struct mapistore_message_recipient, max + 1);
      for (count = 0; count < max; count++)
        {
          recipient = msgData->recipients + count;

          person = [attendees objectAtIndex: count];
          cn = [person cn];
          email = [person rfc822Email];
          if ([cn length] == 0)
            cn = email;
          contactInfos = [mgr contactInfosForUserWithUIDorEmail: email];

          if (contactInfos)
            {
              username = [contactInfos objectForKey: @"c_uid"];
              recipient->username = [username asUnicodeInMemCtx: msgData];
              entryId = MAPIStoreInternalEntryId (connInfo->sam_ctx, username);
            }
          else
            {
              recipient->username = NULL;
              entryId = MAPIStoreExternalEntryId (cn, email);
            }
          recipient->type = MAPI_TO;

          /* properties */
          p = 0;
          recipient->data = talloc_array (msgData, void *, msgData->columns->cValues);
          memset (recipient->data, 0, msgData->columns->cValues * sizeof (void *));

          // PR_OBJECT_TYPE = MAPI_MAILUSER (see MAPI_OBJTYPE)
          recipient->data[p] = MAPILongValue (msgData, MAPI_MAILUSER);
          p++;
          
          // PR_DISPLAY_TYPE = DT_MAILUSER (see MS-NSPI)
          recipient->data[p] = MAPILongValue (msgData, 0);
          p++;

          // PR_7BIT_DISPLAY_NAME_UNICODE
          recipient->data[p] = [cn asUnicodeInMemCtx: msgData];
          p++;

          // PR_SMTP_ADDRESS_UNICODE
          recipient->data[p] = [email asUnicodeInMemCtx: msgData];
          p++;

          // PR_SEND_INTERNET_ENCODING = 0x00060000 (plain text, see OXCMAIL)
          recipient->data[p] = MAPILongValue (msgData, 0x00060000);
          p++;

          // PR_RECIPIENT_DISPLAY_NAME_UNICODE
          recipient->data[p] = [cn asUnicodeInMemCtx: msgData];
          p++;

          // PR_RECIPIENT_FLAGS
          recipient->data[p] = MAPILongValue (msgData, 1);
          p++;

          // PR_RECIPIENT_ENTRYID
          recipient->data[p] = [entryId asBinaryInMemCtx: msgData];
          p++;

          // PR_RECIPIENT_TRACKSTATUS
          /*
            respNone 0x00000000
            No response is required for this object. This is the case for Appointment objects and Meeting Response objects.
            respOrganized 0x00000001
            This Meeting object belongs to the organizer.
            respTentative 0x00000002
            This value on the attendee's Meeting object indicates that the
            attendee has tentatively accepted the Meeting Request object.
            respAccepted 0x00000003
            This value on the attendee's Meeting object indicates that the
            attendee has accepted the Meeting Request object.
            respDeclined 0x00000004
            This value on the attendee's Meeting object indicates that the attendee has declined the Meeting Request
            object.
            respNotResponded 0x00000005
            This value on the attendee's Meeting object indicates that the attendee has
            not yet responded. This value is on the Meet
          */
          partStat = [person participationStatus];
          switch (partStat)
            {
            case iCalPersonPartStatAccepted:
              partStatValue = 3;
              break;
            case iCalPersonPartStatDeclined:
              partStatValue = 4;
              break;
            case iCalPersonPartStatTentative:
              partStatValue = 2;
              break;
            default:
              partStatValue = 5;
            }
          recipient->data[p] = MAPILongValue (msgData, partStatValue);
          p++;

          // // PR_RECORD_KEY
          // recipient->data[p] = [entryId asBinaryInMemCtx: msgData];
          // p++;
        }

      /* On with the organizer: */
      {
        recipient = msgData->recipients + max;

        person = [event organizer];
        cn = [person cn];
        email = [person rfc822Email];
        contactInfos = [mgr contactInfosForUserWithUIDorEmail: email];

        if (contactInfos)
          {
            username = [contactInfos objectForKey: @"c_uid"];
            recipient->username = [username asUnicodeInMemCtx: msgData];
            entryId = MAPIStoreInternalEntryId (connInfo->sam_ctx, username);
          }
        else
          {
            recipient->username = NULL;
            entryId = MAPIStoreExternalEntryId (cn, email);
          }
        recipient->type = MAPI_TO;

        p = 0;
        recipient->data = talloc_array (msgData, void *, msgData->columns->cValues);
        memset (recipient->data, 0, msgData->columns->cValues * sizeof (void *));

        // PR_OBJECT_TYPE = MAPI_MAILUSER (see MAPI_OBJTYPE)
        recipient->data[p] = MAPILongValue (msgData, MAPI_MAILUSER);
        p++;
          
        // PR_DISPLAY_TYPE = DT_MAILUSER (see MS-NSPI)
        recipient->data[p] = MAPILongValue (msgData, 0);
        p++;

        // PR_7BIT_DISPLAY_NAME_UNICODE
        recipient->data[p] = [cn asUnicodeInMemCtx: msgData];
        p++;

        // PR_SMTP_ADDRESS_UNICODE
        recipient->data[p] = [email asUnicodeInMemCtx: msgData];
        p++;

        // PR_SEND_INTERNET_ENCODING = 0x00060000 (plain text, see OXCMAIL)
        recipient->data[p] = MAPILongValue (msgData, 0x00060000);
        p++;

        // PR_RECIPIENT_DISPLAY_NAME_UNICODE
        recipient->data[p] = [cn asUnicodeInMemCtx: msgData];
        p++;

        // PR_RECIPIENT_FLAGS
        recipient->data[p] = MAPILongValue (msgData, 3);
        p++;

        // PR_RECIPIENT_ENTRYID = NULL
        recipient->data[p] = [entryId asBinaryInMemCtx: msgData];
        p++;

        // PR_RECIPIENT_TRACKSTATUS
        /*
          respNone 0x00000000
          No response is required for this object. This is the case for Appointment objects and Meeting Response objects.
          respOrganized 0x00000001
          This Meeting object belongs to the organizer.
          respTentative 0x00000002
          This value on the attendee's Meeting object indicates that the
          attendee has tentatively accepted the Meeting Request object.
          respAccepted 0x00000003
          This value on the attendee's Meeting object indicates that the
          attendee has accepted the Meeting Request object.
          respDeclined 0x00000004
          This value on the attendee's Meeting object indicates that the attendee has declined the Meeting Request
          object.
          respNotResponded 0x00000005
          This value on the attendee's Meeting object indicates that the attendee has
          not yet responded. This value is on the Meet
        */
        recipient->data[p] = MAPILongValue (msgData, 1);
        p++;

        // // PR_RECORD_KEY
        // recipient->data[p] = [entryId asBinaryInMemCtx: msgData];
        // p++;
      }
    }
}

- (int) getPidTagIconIndex: (void **) data // TODO
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  uint32_t longValue;

  /* see http://msdn.microsoft.com/en-us/library/cc815472.aspx:
     Single instance appointment: 0x00000400
     Recurring appointment: 0x00000401
     Single instance meeting: 0x00000402
     Recurring meeting: 0x00000403
     Meeting request: 0x00000404
     Accept: 0x00000405
     Decline: 0x00000406
     Tentativly: 0x00000407
     Cancellation: 0x00000408
     Informational update: 0x00000409 */

      // if ([headerMethod isEqualToString: @"REQUEST"])
      //   longValue = 0x0404;
      // else
      //   longValue = 0x0400;

  if (!itipSetup)
    [self _setupITIPContext];

  longValue = 0x0400;
  
  if (method)
    {
      if ([method isEqualToString: @"REQUEST"])
        longValue |= 0x0004;
      else if ([method isEqualToString: @"REPLY"])
        {
          longValue |= 0x0004;
          switch (partstat)
            {
            case iCalPersonPartStatAccepted:
              longValue |= 0x0001;
              break;
            case iCalPersonPartStatDeclined:
              longValue |= 0x0002;
              break;
            case iCalPersonPartStatTentative:
              longValue |= 0x0003;
              break;
            default:
              longValue = 0x0400;
              [self logWithFormat: @"unhandled part stat"];
            }
        }
      else if ([method isEqualToString: @"CANCEL"])
        longValue |= 0x0008;
    }
  else
    {
      if ([event isRecurrent])
        longValue |= 0x0001;
      if ([[event attendees] count] > 0)
        longValue |= 0x0002;
    }
  
  *data = MAPILongValue (memCtx, longValue);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagOwnerAppointmentId: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc;
  const char *utf8UID;
  union {
    uint32_t longValue;
    char charValue[4];
  } value;
  NSUInteger max, length;

  if ([[event attendees] count] > 0)
    {
      utf8UID = [[event uid] UTF8String];
      length = strlen (utf8UID);
      max = 2;
      if (length < max)
        max = length;
      memcpy (value.charValue, utf8UID, max);
      memcpy (value.charValue + 2, utf8UID + length - 2, max);

      *data = MAPILongValue (memCtx, value.longValue);

      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidLidMeetingType: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  /* TODO
     See 2.2.6.5 PidLidMeetingType (OXOCAL) */
  *data = MAPILongValue (memCtx, 0x00000001);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidOwnerCriticalChange: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_ERR_NOT_FOUND;
  NSCalendarDate *lastModified;

  if ([[event attendees] count] > 0)
    {
      lastModified = [event lastModified];
      if (lastModified)
        {
          *data = [lastModified asFileTimeInMemCtx: memCtx];
          rc = MAPISTORE_SUCCESS;
        }
    }

  return rc;
}

- (int) getPidLidAttendeeCriticalChange: (void **) data
                               inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_ERR_NOT_FOUND;
  NSCalendarDate *lastModified;

  if ([[event attendees] count] > 0)
    {
      lastModified = [event lastModified];
      if (lastModified)
        {
          *data = [lastModified asFileTimeInMemCtx: memCtx];
          rc = MAPISTORE_SUCCESS;
        }
    }

  return rc;
}

- (int) getPidTagMessageClass: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  const char *className;

  if (!itipSetup)
    [self _setupITIPContext];

  if (method)
    {
      if ([method isEqualToString: @"REQUEST"])
        className = "IPM.Schedule.Meeting.Request";
      else if ([method isEqualToString: @"REPLY"])
        {
          switch (partstat)
            {
            case iCalPersonPartStatAccepted:
              className = "IPM.Schedule.Meeting.Resp.Pos";
              break;
            case iCalPersonPartStatDeclined:
              className = "IPM.Schedule.Meeting.Resp.Neg";
              break;
            case iCalPersonPartStatTentative:
              className = "IPM.Schedule.Meeting.Resp.Tent";
              break;
            default:
              className = "IPM.Appointment";
              [self logWithFormat: @"unhandled part stat"];
            }
        }
      else if ([method isEqualToString: @"COUNTER"])
        className = "IPM.Schedule.Meeting.Resp.Tent";
      else if ([method isEqualToString: @"CANCEL"])
        className = "IPM.Schedule.Meeting.Cancelled";
      else
        {
          className = "IPM.Appointment";
          [self logWithFormat: @"unhandled method: %@", method];
        }
    }
  else
    className = "IPM.Appointment";
  *data = talloc_strdup(memCtx, className);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidAppointmentMessageClass: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = talloc_strdup (memCtx, "IPM.Appointment");

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidFInvited: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getYes: data inMemCtx: memCtx];
}

- (int) getPidLidAppointmentSequence: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, [[event sequence] unsignedIntValue]);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidAppointmentStateFlags: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  uint32_t flags = 0x00;

  if ([[event attendees] count] > 0)
    {
      flags |= 0x01; /* asfMeeting */
      if ([event userAsAttendee: user])
        flags |= 0x02; /* asfReceived */
      /* TODO: asfCancelled */
    }

  *data = MAPILongValue (memCtx, flags);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidResponseStatus: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  uint32_t status = 0x00;
  iCalPerson *person;

  if ([[event attendees] count] > 0)
    {
      if ([event userIsOrganizer: user])
        status = 1;
      else
        {
          person = [event userAsAttendee: user];
          if (person)
            {
              switch ([person participationStatus])
                {
                case iCalPersonPartStatTentative:
                  status = 2;
                  break;
                case iCalPersonPartStatAccepted:
                  status = 3;
                  break;
                case iCalPersonPartStatDeclined:
                  status = 4;
                  break;
                default:
                  status = 5;
                }
            }
        }
    }

  *data = MAPILongValue (memCtx, status);

  return MAPISTORE_SUCCESS;
}
 
- (int) getPidLidAppointmentNotAllowPropose: (void **) data
                                   inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getYes: data inMemCtx: memCtx];
}

- (int) getPidLidAppointmentStartWhole: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  NSCalendarDate *dateValue;
  NSInteger offset;

  // if ([event isRecurrent])
  //   dateValue = [event firstRecurrenceStartDate];
  // else
  dateValue = [event startDate];
  if ([event isAllDay])
    {
      offset = -[timeZone secondsFromGMTForDate: dateValue];
      dateValue = [dateValue dateByAddingYears: 0 months: 0 days: 0
                                         hours: 0 minutes: 0
                                       seconds: offset];
    }
  [dateValue setTimeZone: utcTZ];
  *data = [dateValue asFileTimeInMemCtx: memCtx];
  
  return MAPISTORE_SUCCESS;
}

- (int) getPidTagStartDate: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  /* "The PidTagStartDate property ([MS-OXPROPS] section 2.1077) SHOULD be
     set, and when set, it MUST be equal to the value of the
     PidLidAppointmentStartWhole property (section 2.2.1.5).". Not true for
     exceptions, where it is the normal start date for the day of the
     exception. */
  NSCalendarDate *dateValue;
  NSInteger offset;

  dateValue = [event recurrenceId];
  if (!dateValue)
    dateValue = [event startDate];
  [dateValue setTimeZone: timeZone];
  if ([event isAllDay])
    {
      offset = -[timeZone secondsFromGMTForDate: dateValue];
      dateValue = [dateValue dateByAddingYears: 0 months: 0 days: 0
                                         hours: 0 minutes: 0
                                       seconds: offset];
    }
  [dateValue setTimeZone: utcTZ];
  *data = [dateValue asFileTimeInMemCtx: memCtx];
  
  return MAPISTORE_SUCCESS;
}

- (int) getPidLidCommonStart: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  NSCalendarDate *dateValue;
  NSInteger offset;

  dateValue = [firstEvent startDate];
  if ([firstEvent isAllDay])
    {
      offset = -[timeZone secondsFromGMTForDate: dateValue];
      dateValue = [dateValue dateByAddingYears: 0 months: 0 days: 0
                                         hours: 0 minutes: 0
                                       seconds: offset];
    }
  [dateValue setTimeZone: utcTZ];
  *data = [dateValue asFileTimeInMemCtx: memCtx];
  
  return MAPISTORE_SUCCESS;
}

- (int) getPidLidClipStart: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc;
  NSCalendarDate *dateValue, *start;

  if ([event isRecurrent])
    {
      /* [MS-OXOCAL] For a recurring series, this property specifies
         midnight in the user's machine time zone, on the date of the
         first instance, then is persisted in UTC. */
      start = [event startDate];
      dateValue = [NSCalendarDate dateWithYear: [start yearOfCommonEra]
                                         month: [start monthOfYear]
                                           day: [start dayOfMonth]
                                          hour: 0 minute: 0 second: 0
                                      timeZone: timeZone];
      [dateValue setTimeZone: utcTZ];
      *data = [dateValue asFileTimeInMemCtx: memCtx];
      rc = MAPISTORE_SUCCESS;
    }
  else if ([event recurrenceId] != nil)
    rc = MAPISTORE_ERR_NOT_FOUND;
  else
    rc = [self getPidLidAppointmentStartWhole: data inMemCtx: memCtx];

  return rc;
}

- (int) getPidLidAppointmentEndWhole: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  NSCalendarDate *dateValue;
  NSInteger offset;

  // if ([event isRecurrent])
  //   dateValue = [event firstRecurrenceStartDate];
  // else
  dateValue = [event startDate];
  offset = [event durationAsTimeInterval];
  if ([event isAllDay])
    offset -= [timeZone secondsFromGMTForDate: dateValue];
  dateValue = [dateValue dateByAddingYears: 0 months: 0 days: 0
                                     hours: 0 minutes: 0
                                   seconds: offset];
  *data = [dateValue asFileTimeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagEndDate: (void **) data
                inMemCtx: (TALLOC_CTX *) memCtx
{
  NSCalendarDate *dateValue;
  NSInteger offset;

  dateValue = [event recurrenceId];
  if (!dateValue)
    dateValue = [event startDate];
  [dateValue setTimeZone: timeZone];
  offset = [firstEvent durationAsTimeInterval];
  if ([firstEvent isAllDay])
    offset -= [timeZone secondsFromGMTForDate: dateValue];
  dateValue = [dateValue dateByAddingYears: 0 months: 0 days: 0
                                     hours: 0 minutes: 0
                                   seconds: offset];
  *data = [dateValue asFileTimeInMemCtx: memCtx];
  
  return MAPISTORE_SUCCESS;
}

- (int) getPidLidCommonEnd: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  NSCalendarDate *dateValue;
  NSInteger offset;

  // if ([event isRecurrent])
  //   dateValue = [event firstRecurrenceStartDate];
  // else
  dateValue = [firstEvent startDate];
  offset = [firstEvent durationAsTimeInterval];
  if ([event isAllDay])
    offset -= [timeZone secondsFromGMTForDate: dateValue];
  dateValue = [dateValue dateByAddingYears: 0 months: 0 days: 0
                                     hours: 0 minutes: 0
                                   seconds: offset];
  *data = [dateValue asFileTimeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidClipEnd: (void **) data
                inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc;
  NSCalendarDate *dateValue;
  NSInteger offset;
  iCalRecurrenceRule *rrule;

  if ([event isRecurrent])
    {
      rrule = [[event recurrenceRules] objectAtIndex: 0];
      dateValue = [rrule untilDate];
      if (dateValue)
        {
          if ([event isAllDay])
            offset = -[timeZone secondsFromGMTForDate: dateValue];
          else
            offset = 0;
          dateValue = [dateValue dateByAddingYears: 0 months: 0 days: 0
                                             hours: 0 minutes: 0
                                           seconds: offset];
        }
      else
        dateValue = [NSCalendarDate dateWithYear: 4500 month: 8 day: 31
                                            hour: 23 minute: 59 second: 00
                                        timeZone: utcTZ];
      *data = [dateValue asFileTimeInMemCtx: memCtx];
      rc = MAPISTORE_SUCCESS;
    }
  else if ([event recurrenceId] != nil)
    rc = MAPISTORE_ERR_NOT_FOUND;
  else
    rc = [self getPidLidAppointmentEndWhole: data inMemCtx: memCtx];

  return rc;
}

- (int) _getEntryIdFromCN: (NSString *) cn
                 andEmail: (NSString *) email
                   inData: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *username;
  SOGoUserManager *mgr;
  NSDictionary *contactInfos;
  NSData *entryId;

  mgr = [SOGoUserManager sharedUserManager];
  contactInfos = [mgr contactInfosForUserWithUIDorEmail: email];
  if (contactInfos)
    {
      username = [contactInfos objectForKey: @"c_uid"];
      entryId = MAPIStoreInternalEntryId (connInfo->sam_ctx, username);
    }
  else
    entryId = MAPIStoreExternalEntryId (cn, email);

  *data = [entryId asBinaryInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) _getEmailAddress: (void **) data
           forICalPerson: (iCalPerson *) person
                inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc;
  NSString *email;

  email = [person rfc822Email];
  if ([email length] > 0)
    {
      *data = [email asUnicodeInMemCtx: memCtx];
      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) _getAddrType: (void **) data
       forICalPerson: (iCalPerson *) person
            inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"SMTP" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) _getName: (void **) data
   forICalPerson: (iCalPerson *) person
        inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc;
  NSString *cn;

  cn = [person cn];
  if ([cn length] > 0)
    {
      *data = [cn asUnicodeInMemCtx: memCtx];
      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) _getEntryId: (void **) data
      forICalPerson: (iCalPerson *) person
           inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_ERR_NOT_FOUND;
  NSString *email, *cn;

  if (person)
    {
      email = [person rfc822Email];
      if ([email length] > 0)
        {
          cn = [person cn];
          rc = [self _getEntryIdFromCN: cn andEmail: email
                                inData: data
                              inMemCtx: memCtx];
        }
    }

  return rc;
}

/* sender (organizer) */
- (int) getPidTagSenderEmailAddress: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getEmailAddress: data
                  forICalPerson: [event organizer]
                       inMemCtx: memCtx];
}

- (int) getPidTagSenderAddressType: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getAddrType: data
              forICalPerson: [event organizer]
                   inMemCtx: memCtx];
}

- (int) getPidTagSenderName: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getName: data
          forICalPerson: [event organizer]
               inMemCtx: memCtx];
}

- (int) getPidTagSenderEntryId: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getEntryId: data
             forICalPerson: [event organizer]
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
- (int) getPidTagReceivedByEmailAddress: (void **) data
                               inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getEmailAddress: data
                  forICalPerson: [event userAsAttendee: user]
                       inMemCtx: memCtx];
}

- (int) getPidTagReceivedByAddressType: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getAddrType: data
              forICalPerson: [event userAsAttendee: user]
                   inMemCtx: memCtx];
}

- (int) getPidTagReceivedByName: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getName: data
          forICalPerson: [event userAsAttendee: user]
               inMemCtx: memCtx];
}

- (int) getPidTagReceivedByEntryId: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getEntryId: data
             forICalPerson: [event userAsAttendee: user]
                  inMemCtx: memCtx];
}
/* /attendee */

- (int) getPidLidAppointmentDuration: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  NSTimeInterval timeValue;

  timeValue = [[event endDate] timeIntervalSinceDate: [event startDate]];
  *data = MAPILongValue (memCtx, (uint32_t) (timeValue / 60));

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidAppointmentSubType: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPIBoolValue (memCtx, [event isAllDay]);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidBusyStatus: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  uint8_t value;
  
  value = 0x2;  // olBusy

  if (![event isOpaque])
    value = 0x0; // olFree
  
  *data = MAPILongValue (memCtx, value);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidIndentedBusyStatus: (void **) data // TODO
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidBusyStatus: data inMemCtx: memCtx];
}

- (int) getPidTagNormalizedSubject: (void **) data // SUMMARY
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[event summary] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidLocation: (void **) data // LOCATION
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;
  NSString *location;

  location = [event location];
  if (location)
    *data = [location asUnicodeInMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidLidWhere: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidLocation: data inMemCtx: memCtx];
}

- (int) getPidLidServerProcessed: (void **) data
                        inMemCtx: (TALLOC_CTX *) memCtx
{
  /* TODO: we need to check whether the event has been processed internally by
     SOGo or if it was received only by mail. We only assume the SOGo case
     here. */
  return [self getYes: data inMemCtx: memCtx];
}

- (int) getPidLidServerProcessingActions: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx,
                         0x00000010 /* cpsCreatedOnPrincipal */
                         | 0x00000080 /* cpsUpdatedCalItem */
                         | 0x00000100 /* cpsCopiedOldProperties */);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidPrivate: (void **) data // private (bool), should depend on CLASS and permissions
                inMemCtx: (TALLOC_CTX *) memCtx
{
  if ([event symbolicAccessClass] == iCalAccessPublic)
    return [self getNo: data inMemCtx: memCtx];

  return [self getYes: data inMemCtx: memCtx];
}

- (int) getPidTagSensitivity: (void **) data // not implemented, depends on CLASS
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  // normal = 0, personal?? = 1, private = 2, confidential = 3
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPidTagImportance: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  uint32_t v;
  if ([[event priority] isEqualToString: @"9"])
    v = 0x0;
  else if ([[event priority] isEqualToString: @"1"])
    v = 0x2;
  else
    v = 0x1;
    
  *data = MAPILongValue (memCtx, v);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagBody: (void **) data
             inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc;
  NSRange range;
  NSString *stringValue;
  NSString *trimingString = @"\r\n\n";

  /* FIXME: there is a confusion in NGCards around "comment" and "description" */
  stringValue = [event comment];
  if ([stringValue length] > 0
      && ![stringValue isEqualToString: @"\r\n"]
      && ![stringValue isEqualToString: @"\n"])
    {
      /* Avoiding those trail weird characters at event description */
      range = [stringValue rangeOfString: trimingString
                                 options: NSBackwardsSearch];
      if (range.location != NSNotFound)
        {
          stringValue = [stringValue substringToIndex: (NSMaxRange(range) -1)];
        }

      rc = MAPISTORE_SUCCESS;
      *data = [stringValue asUnicodeInMemCtx: memCtx];
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidTagInternetCodepage: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  /* ref:
     http://msdn.microsoft.com/en-us/library/dd317756%28v=vs.85%29.aspx
  
     minimal list that should be handled:
     us-ascii: 20127
     iso-8859-1: 28591
     iso-8859-15: 28605
     utf-8: 65001 */
  *data = MAPILongValue(memCtx, 65001);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidRecurring: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPIBoolValue (memCtx, [event isRecurrent]);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidIsRecurring: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPIBoolValue (memCtx,
                         [event isRecurrent]
                         || ([event recurrenceId] != nil));

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidIsException: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPIBoolValue (memCtx, [event recurrenceId] != nil);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidExceptionReplaceTime: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc;
  NSCalendarDate *dateValue;
  NSInteger offset;

  dateValue = [event recurrenceId];
  if (dateValue)
    {
      rc = MAPISTORE_SUCCESS;
      
      if ([event isAllDay])
        {
          offset = -[timeZone secondsFromGMTForDate: dateValue];
          dateValue = [dateValue dateByAddingYears: 0 months: 0 days: 0
                                             hours: 0 minutes: 0
                                           seconds: offset];
        }
      [dateValue setTimeZone: utcTZ];
      *data = [dateValue asFileTimeInMemCtx: memCtx];
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidLidRecurrencePattern: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"No description" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (void) _fillExceptionInfo: (struct ExceptionInfo *) exceptionInfo
       andExtendedException: (struct ExtendedException *) extendedException
              withException: (iCalEvent *) exceptionEvent
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  iCalEventChanges *changes;
  NSArray *changedProperties;
  NSCalendarDate *dateValue;
  NSInteger offset;

  changes = [iCalEventChanges changesFromEvent: event toEvent: exceptionEvent];

  memset (exceptionInfo, 0, sizeof (struct ExceptionInfo));
  memset (extendedException, 0, sizeof (struct ExtendedException));
  extendedException->ChangeHighlight.Size = sizeof (uint32_t);

  dateValue = [exceptionEvent startDate];
  offset = [timeZone secondsFromGMTForDate: dateValue];
  dateValue = [dateValue dateByAddingYears: 0 months: 0 days: 0
                                     hours: 0 minutes: 0
                                   seconds: offset];
  exceptionInfo->StartDateTime = [dateValue asMinutesSince1601];
  extendedException->ChangeHighlight.Value = BIT_CH_START;
  extendedException->StartDateTime = exceptionInfo->StartDateTime;

  dateValue = [exceptionEvent endDate];
  offset = [timeZone secondsFromGMTForDate: dateValue];
  dateValue = [dateValue dateByAddingYears: 0 months: 0 days: 0
                                     hours: 0 minutes: 0
                                   seconds: offset];
  exceptionInfo->EndDateTime = [dateValue asMinutesSince1601];
  extendedException->ChangeHighlight.Value |= BIT_CH_END;
  extendedException->EndDateTime = exceptionInfo->EndDateTime;

  dateValue = [[exceptionEvent recurrenceId]
                dateByAddingYears: 0 months: 0 days: 0
                hours: 0 minutes: 0
                seconds: offset];
  exceptionInfo->OriginalStartDate = [dateValue asMinutesSince1601];
  extendedException->OriginalStartDate = exceptionInfo->OriginalStartDate;

  changedProperties = [changes updatedProperties];
  if ([changedProperties containsObject: @"summary"])
    {
      extendedException->ChangeHighlight.Value |= BIT_CH_SUBJECT;
      extendedException->Subject
        = [[exceptionEvent summary] asUnicodeInMemCtx: memCtx];

      exceptionInfo->OverrideFlags |= ARO_SUBJECT;
      exceptionInfo->Subject.subjectMsg.msg
        = (uint8_t *) extendedException->Subject;
      /* FIXME: this will fail with non ascii chars */
      exceptionInfo->Subject.subjectMsg.msgLength2 = [[exceptionEvent summary] length];
      exceptionInfo->Subject.subjectMsg.msgLength = exceptionInfo->Subject.subjectMsg.msgLength2 + 1;
    }
  if ([changedProperties containsObject: @"location"])
    {
      extendedException->ChangeHighlight.Value |= BIT_CH_LOCATION;
      extendedException->Location
        = [[exceptionEvent location] asUnicodeInMemCtx: memCtx];
      exceptionInfo->OverrideFlags |= ARO_LOCATION;
      exceptionInfo->Location.locationMsg.msg
        = (uint8_t *) extendedException->Location;
      /* FIXME: this will fail with non ascii chars */
      exceptionInfo->Location.locationMsg.msgLength2 = [[exceptionEvent location] length];
      exceptionInfo->Location.locationMsg.msgLength = exceptionInfo->Location.locationMsg.msgLength2 + 1;
    }
  if ([event isAllDay] != [exceptionEvent isAllDay])
    {
      exceptionInfo->OverrideFlags |= ARO_SUBTYPE;
      exceptionInfo->SubType.sType = [exceptionEvent isAllDay];
    }
}

// - (struct SBinary_short *) _computeAppointmentRecurInMemCtx: (TALLOC_CTX *) memCtx
- (struct Binary_r *) _computeAppointmentRecurInMemCtx: (TALLOC_CTX *) memCtx
{
  struct AppointmentRecurrencePattern *arp;
  struct Binary_r *bin;
  // struct SBinary_short *sBin;
  NSCalendarDate *firstStartDate;
  iCalRecurrenceRule *rule;
  NSUInteger startMinutes;
  NSArray *events, *exceptions;
  iCalEvent *exceptionEvent;
  NSUInteger count, max;

  rule = [[event recurrenceRules] objectAtIndex: 0];

  firstStartDate = [event firstRecurrenceStartDate];
  if (firstStartDate)
    {
      [firstStartDate setTimeZone: timeZone];

      arp = talloc_zero (NULL, struct AppointmentRecurrencePattern);
      [rule fillRecurrencePattern: &arp->RecurrencePattern
                        withEvent: event
                       inTimeZone: timeZone
                         inMemCtx: arp];
      arp->ReaderVersion2 = 0x00003006;
      arp->WriterVersion2 = 0x00003008; /* 0x3008 for compatibility with
                                           ol2003 */

      startMinutes = ([firstStartDate hourOfDay] * 60
                      + [firstStartDate minuteOfHour]);
      arp->StartTimeOffset = startMinutes;
      arp->EndTimeOffset = (startMinutes
                            + (NSUInteger) ([event durationAsTimeInterval]
                                            / 60));

      events = [[event parent] events];
      exceptions
        = [events subarrayWithRange: NSMakeRange (1, [events count] - 1)];
      max = [exceptions count];
      arp->ExceptionCount = max;
      arp->ExceptionInfo = talloc_array (memCtx, struct ExceptionInfo, max);
      arp->ExtendedException = talloc_array (memCtx, struct ExtendedException, max);
      for (count = 0; count < max; count++)
        {
          exceptionEvent = [exceptions objectAtIndex: count];
          [self _fillExceptionInfo: arp->ExceptionInfo + count
              andExtendedException: arp->ExtendedException + count
                     withException: exceptionEvent
                          inMemCtx: arp];
        }
      arp->ReservedBlock1Size = 0;
      arp->ReservedBlock2Size = 0;

      /* Currently ignored in property.idl: arp->ReservedBlock2Size = 0; */

      /* convert struct to blob */
      // sBin = talloc_zero (memCtx, struct SBinary_short);
      bin = set_AppointmentRecurrencePattern (memCtx, arp);
      // sBin->cb = bin->cb;
      // sBin->lpb = bin->lpb;
      talloc_free (arp);

      // DEBUG(5, ("To client:\n"));
      // NDR_PRINT_DEBUG (AppointmentRecurrencePattern, arp);
    }
  else
    {
      [self errorWithFormat: @"no first occurrence found in rule: %@", rule];
      // bin = NULL;
      bin = NULL;
    }

  return bin;
}

/* exception 12345 + 123456 (exchange):
  81ad0102 (PT_BINARY): 
    named prop
    guid: {00062002-0000-0000-c000-000000000046}
    dispid: 0x00008216
         (163 bytes)
            04 30 04 30 0a 20 00 00  |  \x04   0  \x04   0  \x0a      \x00 \x00 
            00 00 00 00 00 00 a0 05  |  \x00 \x00 \x00 \x00 \x00 \x00 \xa0 \x05 
            00 00 00 00 00 00 23 20  |  \x00 \x00 \x00 \x00 \x00 \x00   #       
            00 00 0a 00 00 00 00 00  |  \x00 \x00 \x0a \x00 \x00 \x00 \x00 \x00 
            00 00 01 00 00 00 a0 c6  |  \x00 \x00 \x01 \x00 \x00 \x00 \xa0 \xc6 
            e6 0c 01 00 00 00 a0 c6  |  \xe6 \x0c \x01 \x00 \x00 \x00 \xa0 \xc6 
            e6 0c 00 c1 e6 0c df 80  |  \xe6 \x0c \x00 \xc1 \xe6 \x0c \xdf \x80 
            e9 5a 06 30 00 00 08 30  |  \xe9   Z  \x06   0  \x00 \x00 \x08   0  
            00 00 66 03 00 00 84 03  |  \x00 \x00   f  \x03 \x00 \x00 \x84 \x03 
            00 00 01 00 e8 c9 e6 0c  |  \x00 \x00 \x01 \x00 \xe8 \xc9 \xe6 \x0c 
            f6 ca e6 0c 06 ca e6 0c  |  \xf6 \xca \xe6 \x0c \x06 \xca \xe6 \x0c 
            11 00 06 00 05 00 31 32  |  \x11 \x00 \x06 \x00 \x05 \x00   1    2  
            33 34 35 07 00 06 00 31  |    3    4    5  \x07 \x00 \x06 \x00   1  
            32 33 34 35 36 00 00 00  |    2    3    4    5    6  \x00 \x00 \x00 
            00 00 00 00 00 e8 c9 e6  |  \x00 \x00 \x00 \x00 \x00 \xe8 \xc9 \xe6 
            0c f6 ca e6 0c 06 ca e6  |  \x0c \xf6 \xca \xe6 \x0c \x06 \xca \xe6 
            0c 05 00 31 00 32 00 33  |  \x0c \x05 \x00   1  \x00   2  \x00   3  
            00 34 00 35 00 06 00 31  |  \x00   4  \x00   5  \x00 \x06 \x00   1  
            00 32 00 33 00 34 00 35  |  \x00   2  \x00   3  \x00   4  \x00   5  
            00 36 00 00 00 00 00 00  |  \x00   6  \x00 \x00 \x00 \x00 \x00 \x00 
            00 00 00                 |  \x00 \x00 \x00 

openchange:
  918b0102 (PT_BINARY): 
    named prop
    guid: {00062002-0000-0000-c000-000000000046}
    dispid: 0x00008216
         (167 bytes)


recurrence pattern
   readerversion:    04 30
   writerversion:    04 30
   recurfrequency:   0a 20  (daily)
   patterntype:      00 00
   calendartype:     00 00
   firstdatetime:    00 00 00 00
   period:           a0 05 00 00 (1440 minutes)
   slidingflag:      00 00 00 00
   patterntypespecific: (0 bytes)
   endtype:          23 20 00 00
   occurrencecount:  *00->0a 00 00 00  (meaningless since no enddate)
   firstdow:         00 00 00 00
   deletedicount:    01 00 00 00
   deletedinstancedates: (1)
     a0 c6 e6 0c
   modifiedicount:   01 00 00 00
   modifiedinstancedates: (1)
     a0 c6 e6 0c
   startdate:        00 c1 e6 0c
   enddate:          df 80 e9 5a
ReaderVersion2:      06 30 00 00
WriterVersion2:      08 30 00 00
StartTimeOffset:     66 03 00 00
EndTimeOffset:       84 03 00 00
ExceptionCount:      01 00
ExceptionInfos: (1)
   StartDateTime:     *e7->e8 *ca->c9 e6 0c
   EndDateTime:       *e6->f6 *cb->ca e6 0c
   OriginalStartDate: *a0->06 *c6->ca e6 0c
   OverrideFlags:     11 00
   SubjectLength2:    06 00
   SubjectLength:     05 00
   Subject:           31 32 33 34 35
   LocationLength2:   07 00
   LocationLength:    06 00
   Location:          31 32 33 34 35 36
ReservedBlock1Size:   00 00 00 00
ExtendedException: (1)
   ReservedBlockEE1Size: 00 00 00 00
   StartDateTime:       *e7->e8 *ca->c9 e6 0c
   EndDateTime:         *e6->f6 *cb->ca e6 0c
   OriginalStartDate:   *a0->06 *c6->ca e6 0c
   WideCharSubjectLength *06->05
   WideCharSubject:      00 31 00 32 00 33 00 34 00 35 00 [2bytes sup: 00 00]
   LocationLength:       *07->06
   Location              00 31 00 32 00 33 00 34 00 35 00 36 00 00
   ReservedBlockEE2Size: 00 00 00 00
ReservedBlockEE2Size: 00 00 00 00
*/

- (int) getPidLidAppointmentRecur: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;

  if ([event isRecurrent])
    *data = [self _computeAppointmentRecurInMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidLidRecurrenceType: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc;
  iCalRecurrenceFrequency freq;
  iCalRecurrenceRule *rrule;
  enum RecurrenceType rectype;

  if ([event isRecurrent])
    {
      rrule = [[event recurrenceRules] objectAtIndex: 0];
      freq = [rrule frequency];
      if (freq == iCalRecurrenceFrequenceDaily)
        rectype = rectypeDaily;
      else if (freq == iCalRecurrenceFrequenceWeekly)
        rectype = rectypeWeekly;
      else if (freq == iCalRecurrenceFrequenceMonthly)
        rectype = rectypeMonthly;
      else if (freq == iCalRecurrenceFrequenceYearly)
        rectype = rectypeYearly;
      else
        rectype = rectypeNone; /* or "unsupported" */

      *data = MAPILongValue (memCtx, rectype);
      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

// - (int) getPidLidGlobalObjectId: (void **) data
//                        inMemCtx: (TALLOC_CTX *) memCtx
// {
//   static char byteArrayId[] = {0x04, 0x00, 0x00, 0x00, 0x82, 0x00, 0xE0,
//                                0x00, 0x74, 0xC5, 0xB7, 0x10, 0x1A, 0x82,
//                                0xE0, 0x08};
//   static char X[] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
//   NSMutableData *nsData;
//   NSData *uidData;
//   NSCalendarDate *creationTime;
//   struct FILETIME *creationFileTime;
//   uint32_t uidDataLength;

//   nsData = [NSMutableData dataWithCapacity: 256];
//   [nsData appendBytes: byteArrayId length: 16];

//   /* FIXME TODO */
//   [nsData appendBytes: X length: 4];
//   /* /FIXME */

//   creationTime = [event created];
//   if (!creationTime)
//     {
//       [self logWithFormat: @"" __location__ ": event has no 'CREATED' tag -> inventing one"];
//       creationTime = [event lastModified];
//       if (!creationTime)
//         creationTime = [NSCalendarDate date];
//     }
//   creationFileTime = [creationTime asFileTimeInMemCtx: NULL];
//   [nsData appendBytes: &creationFileTime->dwLowDateTime length: 4];
//   [nsData appendBytes: &creationFileTime->dwHighDateTime length: 4];
//   talloc_free (creationFileTime);

//   uidData = [[event uid] dataUsingEncoding: NSUTF8StringEncoding];
//   uidDataLength = [uidData length];
//   [nsData appendBytes: &uidDataLength length: 4];
//   [nsData appendData: uidData];
//   *data = [nsData asBinaryInMemCtx: memCtx];

//   return MAPISTORE_SUCCESS;
// }

- (void) _setInstanceDate: (struct GlobalObjectId *) newGlobalId
                 fromDate: (NSCalendarDate *) instanceDate;
{
  uint16_t year;

  if (instanceDate)
    {
      [instanceDate setTimeZone: timeZone];
      year = [instanceDate yearOfCommonEra];
      newGlobalId->YH = year >> 8;
      newGlobalId->YL = year & 0xff;
      newGlobalId->Month = [instanceDate monthOfYear];
      newGlobalId->D = [instanceDate dayOfMonth];
    }
}

/* note: returns a retained object */
- (NSData *) _objectIdAsNSData: (const struct GlobalObjectId *) newGlobalId
{
  NSData *nsData;
  TALLOC_CTX *localMemCtx;
  struct ndr_push *ndr;

  localMemCtx = talloc_zero (NULL, TALLOC_CTX);
  ndr = ndr_push_init_ctx (localMemCtx);
  ndr_push_GlobalObjectId (ndr, NDR_SCALARS, newGlobalId);
  nsData = [[NSData alloc] initWithBytes: ndr->data
                                  length: ndr->offset];
  talloc_free (localMemCtx);
  
  return nsData;
}

- (void) _computeGlobalObjectIds
{
  static NSString *prefix = @"040000008200e00074c5b7101a82e008";
  static uint8_t dataPrefix[] = { 0x76, 0x43, 0x61, 0x6c, 0x2d, 0x55, 0x69,
                                  0x64, 0x01, 0x00, 0x00, 0x00 };
  NSString *uid;
  const char *uidAsUTF8;
  NSUInteger uidLength;
  NSData *encodedGlobalIdData;
  struct Binary_r *encodedGlobalIdBinary;
  struct GlobalObjectId *encodedGlobalId;
  struct GlobalObjectId newGlobalId;
  uint16_t year;
  NSData *binPrefix;
  TALLOC_CTX *localMemCtx;

  localMemCtx = talloc_zero (NULL, TALLOC_CTX);

  memset (&newGlobalId, 0, sizeof (struct GlobalObjectId));

  uid = [event uid];
  uidLength = [uid length];
  if (uidLength >= 82 && (uidLength % 2) == 0 && [uid hasPrefix: prefix]
      && [[uid stringByTrimmingCharactersInSet: hexCharacterSet] length] == 0)
    {
      encodedGlobalIdData = [uid convertHexStringToBytes];
      if (encodedGlobalIdData)
        {
          encodedGlobalIdBinary
            = [encodedGlobalIdData asBinaryInMemCtx: localMemCtx];
          encodedGlobalId = get_GlobalObjectId (localMemCtx,
                                                encodedGlobalIdBinary);
          if (encodedGlobalId)
            {
              memcpy (newGlobalId.ByteArrayID,
                      encodedGlobalId->ByteArrayID,
                      16);
              year = ((uint16_t) encodedGlobalId->YH << 8) | encodedGlobalId->YL;
              if (year >= 1601 && year <= 4500
                  && encodedGlobalId->Month > 0 && encodedGlobalId->Month < 13
                  && encodedGlobalId->D > 0 && encodedGlobalId->D < 31)
                {
                  newGlobalId.YH = encodedGlobalId->YH;
                  newGlobalId.YL = encodedGlobalId->YL;
                  newGlobalId.Month = encodedGlobalId->Month;
                  newGlobalId.D = encodedGlobalId->D;
                }
              else
                [self _setInstanceDate: &newGlobalId
                              fromDate: [event recurrenceId]];
              newGlobalId.CreationTime = encodedGlobalId->CreationTime;
              memcpy (newGlobalId.X, encodedGlobalId->X, 8);
              newGlobalId.Size = encodedGlobalId->Size;
              newGlobalId.Data = encodedGlobalId->Data;
            }
          else
            abort ();
        }
      else
        abort ();
    }
  else
    {
      binPrefix = [prefix convertHexStringToBytes];
      [binPrefix getBytes: &newGlobalId.ByteArrayID];
      [self _setInstanceDate: &newGlobalId
                    fromDate: [event recurrenceId]];
      uidAsUTF8 = [uid UTF8String];
      newGlobalId.Size = 0x0c + strlen (uidAsUTF8);
      newGlobalId.Data = talloc_array (localMemCtx, uint8_t,
                                       newGlobalId.Size);
      memcpy (newGlobalId.Data, dataPrefix, 0x0c);
      memcpy (newGlobalId.Data + 0x0c, uidAsUTF8, newGlobalId.Size - 0x0c);
    }

  globalObjectId = [self _objectIdAsNSData: &newGlobalId];

  newGlobalId.YH = 0;
  newGlobalId.YL = 0;
  newGlobalId.Month = 0;
  newGlobalId.D = 0;
  cleanGlobalObjectId = [self _objectIdAsNSData: &newGlobalId];

  talloc_free (localMemCtx);
}

- (int) getPidLidGlobalObjectId: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;

  if (!globalObjectId)
    [self _computeGlobalObjectIds];

  if (globalObjectId)
    *data = [globalObjectId asBinaryInMemCtx: memCtx];
  else
    abort ();
  
  return rc;
}

- (int) getPidLidCleanGlobalObjectId: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;

  if (!cleanGlobalObjectId)
    [self _computeGlobalObjectIds];

  if (cleanGlobalObjectId)
    *data = [cleanGlobalObjectId asBinaryInMemCtx: memCtx];
  else
    abort ();
  
  return rc;
}

- (int) getPidLidAppointmentReplyTime: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx
{
  /* We always return LAST-MODIFIED, which is a hack, but one that works
     because: the user is either (NOT recipient OR (is recipient AND its
     status is N/A), where this value should not be taken into account by the
     client OR the user is recipient and its status is defined, where this
     value is thus correct because the recipient status is the only property
     that can be changed. */
  int rc = MAPISTORE_ERR_NOT_FOUND;
  NSCalendarDate *lastModified;

  lastModified = [event lastModified];
  if (lastModified)
    {
      *data = [lastModified asFileTimeInMemCtx: memCtx];
      rc = MAPISTORE_SUCCESS;
    }

  return rc;
}

/* reminders */
- (void) _setupAlarm
{
  NSArray *alarms;
  NSUInteger count, max;
  iCalAlarm *currentAlarm;
  NSString *action, *webstatus;

  alarms = [event alarms];
  max = [alarms count];
  for (count = 0; !alarm && count < max; count++)
    {
      currentAlarm = [alarms objectAtIndex: count];

      // Only handle 'display' alarms
      action = [currentAlarm action];
      if ([action caseInsensitiveCompare: @"display"] != NSOrderedSame)
        continue;

      // Ignore alarms already triggered
      webstatus = [[currentAlarm trigger] value: 0 ofAttribute: @"x-webstatus"];
      if ([webstatus caseInsensitiveCompare: @"triggered"] == NSOrderedSame)
        continue;

      ASSIGN (alarm, currentAlarm);
    }

  alarmSet = YES;
}

- (int) getPidLidReminderSet: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!alarmSet)
    [self _setupAlarm];

  *data = MAPIBoolValue (memCtx, (alarm != nil));

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidReminderTime: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!alarmSet)
    [self _setupAlarm];

  return (alarm
          ? [self getPidTagStartDate: data inMemCtx: memCtx]
          : MAPISTORE_ERR_NOT_FOUND);
}

- (int) getPidLidReminderDelta: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_ERR_NOT_FOUND;
  iCalTrigger *trigger;
  NSCalendarDate *startDate, *relationDate, *alarmDate;
  NSTimeInterval interval;
  NSString *relation;

  if (!alarmSet)
    [self _setupAlarm];

  if (alarm)
    {
      trigger = [alarm trigger];
      if ([[trigger valueType] caseInsensitiveCompare: @"DURATION"] == NSOrderedSame)
        {
          startDate = [event startDate];
          relation = [[trigger relationType] lowercaseString];
          interval = [[trigger flattenedValuesForKey: @""]
                       durationAsTimeInterval];
          if ([relation isEqualToString: @"end"])
            relationDate = [event endDate];
          else
            relationDate = startDate;

          // Compute the next alarm date with respect to the reference date
          if (relationDate)
            {
              alarmDate = [relationDate addTimeInterval: interval];
              interval = [startDate timeIntervalSinceDate: alarmDate];
              *data = MAPILongValue (memCtx, (int) (interval / 60));
              rc = MAPISTORE_SUCCESS;
            }
        }
    }

  return rc;
}

- (int) getPidLidReminderSignalTime: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;
  NSCalendarDate *alarmDate;

  if (!alarmSet)
    [self _setupAlarm];

  if (alarm)
    {
      alarmDate = [alarm nextAlarmDate];
      [alarmDate setTimeZone: utcTZ];
      *data = [alarmDate asFileTimeInMemCtx: memCtx];
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidLidReminderOverride: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;

  if (!alarmSet)
    [self _setupAlarm];

  if (alarm)
    *data = MAPIBoolValue (memCtx, YES);
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidLidReminderPlaySound: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;

  if (!alarmSet)
    [self _setupAlarm];

  if (alarm)
    *data = MAPIBoolValue (memCtx, YES);
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidLidReminderFileParameter: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  // if (!alarmSet)
  //   [self _setupAlarm];

  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidLidReminderType: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidLidTimeZoneDescription: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc;
  NSString *tzid;

  tzid = [(iCalDateTime *) [event firstChildWithTag: @"dtstart"]
           value: 0 ofAttribute: @"tzid"];
  if ([tzid length] > 0)
    {
      *data = [tzid asUnicodeInMemCtx: memCtx];
      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidLidTimeZoneStruct: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc;
  iCalTimeZone *icalTZ;

  icalTZ = [(iCalDateTime *) [event firstChildWithTag: @"dtstart"] timeZone];
  if (icalTZ)
    {
      *data = [icalTZ asTimeZoneStructInMemCtx: memCtx];
      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidLidAppointmentTimeZoneDefinitionStartDisplay: (void **) data
                                                  inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc;
  iCalTimeZone *icalTZ;

  if ([event isRecurrent])
    {
      icalTZ = [(iCalDateTime *) [event firstChildWithTag: @"dtstart"] timeZone];
      if (icalTZ)
        {
          *data = [icalTZ asZoneTimeDefinitionWithFlags: TZRULE_FLAG_EFFECTIVE_TZREG | TZRULE_FLAG_RECUR_CURRENT_TZREG
                                               inMemCtx: memCtx];
          rc = MAPISTORE_SUCCESS;
        }
      else
        rc = MAPISTORE_ERR_NOT_FOUND;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidLidAppointmentTimeZoneDefinitionEndDisplay: (void **) data
                                                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidAppointmentTimeZoneDefinitionStartDisplay: data
                                                         inMemCtx: memCtx];
}

@end
