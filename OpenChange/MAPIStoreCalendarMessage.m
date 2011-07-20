/* MAPIStoreCalendarMessage.m - this file is part of SOGo
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

/* TODO:
   - merge common code with tasks
   - take the tz definitions from Outlook */

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalRecurrenceRule.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/iCalPerson.h>
#import <SOGo/SOGoUser.h>
#import <Appointments/SOGoAppointmentObject.h>

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

static NSTimeZone *utcTZ;

@implementation MAPIStoreCalendarMessage

+ (void) initialize
{
  utcTZ = [NSTimeZone timeZoneWithName: @"UTC"];
  [utcTZ retain];
}

- (id) init
{
  if ((self = [super init]))
    {
      attachmentKeys = [NSMutableArray new];
      attachmentParts = [NSMutableDictionary new];
    }

  return self;
}

/* getters */
- (int) getPrIconIndex: (void **) data // TODO
              inMemCtx: (TALLOC_CTX *) memCtx
{
  uint32_t longValue;
  iCalEvent *event;

  event = [sogoObject component: NO secure: NO];

  /* see http://msdn.microsoft.com/en-us/library/cc815472.aspx */
  // *longValue = 0x00000401 for recurring event
  // *longValue = 0x00000402 for meeting
  // *longValue = 0x00000403 for recurring meeting
  // *longValue = 0x00000404 for invitation
  
  longValue = 0x0400;
  if ([event isRecurrent])
    longValue |= 0x0001;
  if ([[event attendees] count] > 0)
    longValue |= 0x0002;
  
  *data = MAPILongValue (memCtx, longValue);

  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageClass: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = talloc_strdup(memCtx, "IPM.Appointment");

  return MAPISTORE_SUCCESS;
}

- (int) getPrStartDate: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  NSCalendarDate *dateValue;
  iCalEvent *event;

  event = [sogoObject component: NO secure: NO];

  if ([event isRecurrent])
    dateValue = [event firstRecurrenceStartDate];
  else
    dateValue = [event startDate];
  [dateValue setTimeZone: utcTZ];
  *data = [dateValue asFileTimeInMemCtx: memCtx];
  
  return MAPISTORE_SUCCESS;
}

- (int) getPidLidAppointmentStartWhole: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrStartDate: data inMemCtx: memCtx];
}

- (int) getPidLidCommonStart: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrStartDate: data inMemCtx: memCtx];
}

- (int) getPrEndDate: (void **) data
            inMemCtx: (TALLOC_CTX *) memCtx
{
  NSCalendarDate *dateValue;
  iCalEvent *event;

  event = [sogoObject component: NO secure: NO];

  if ([event isRecurrent])
    dateValue = [event firstRecurrenceStartDate];
  else
    dateValue = [event startDate];
  dateValue
    = [dateValue dateByAddingYears: 0 months: 0 days: 0
                             hours: 0 minutes: 0
                           seconds: (NSInteger) [event
                                                  durationAsTimeInterval]];
  [dateValue setTimeZone: utcTZ];
  *data = [dateValue asFileTimeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidAppointmentEndWhole: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrEndDate: data inMemCtx: memCtx];
}

- (int) getPidLidCommonEnd: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrEndDate: data inMemCtx: memCtx];
}

- (int) getPidLidAppointmentDuration: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  NSTimeInterval timeValue;
  iCalEvent *event;

  event = [sogoObject component: NO secure: NO];

  timeValue = [[event endDate] timeIntervalSinceDate: [event startDate]];
  *data = MAPILongValue (memCtx, (uint32_t) (timeValue / 60));

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidAppointmentSubType: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  iCalEvent *event;

  event = [sogoObject component: NO secure: NO];
  *data = MAPIBoolValue (memCtx, [event isAllDay]);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidBusyStatus: (void **) data // TODO
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0x02);

  return MAPISTORE_SUCCESS;
}

- (int) getPrSubject: (void **) data // SUMMARY
            inMemCtx: (TALLOC_CTX *) memCtx
{
  iCalEvent *event;

  event = [sogoObject component: NO secure: NO];
  *data = [[event summary] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidLocation: (void **) data // LOCATION
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  iCalEvent *event;

  event = [sogoObject component: NO secure: NO];
  *data = [[event location] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidPrivate: (void **) data // private (bool), should depend on CLASS and permissions
                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (int) getPrSensitivity: (void **) data // not implemented, depends on CLASS
                inMemCtx: (TALLOC_CTX *) memCtx
{
  // normal = 0, personal?? = 1, private = 2, confidential = 3
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPrImportance: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  uint32_t v;
  iCalEvent *event;

  event = [sogoObject component: NO secure: NO];
  if ([[event priority] isEqualToString: @"9"])
    v = 0x0;
  else if ([[event priority] isEqualToString: @"1"])
    v = 0x2;
  else
    v = 0x1;
    
  *data = MAPILongValue (memCtx, v);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidIsRecurring: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  iCalEvent *event;

  event = [sogoObject component: NO secure: NO];
  *data = MAPIBoolValue (memCtx, [event isRecurrent]);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidRecurring: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  iCalEvent *event;

  event = [sogoObject component: NO secure: NO];
  *data = MAPIBoolValue (memCtx, [event isRecurrent]);

  return MAPISTORE_SUCCESS;
}

static void
_fillAppointmentRecurrencePattern (struct AppointmentRecurrencePattern *arp,
                                   NSCalendarDate *startDate, NSTimeInterval duration,
                                   NSCalendarDate * endDate, iCalRecurrenceRule * rule)
{
  uint32_t startMinutes;

  [rule fillRecurrencePattern: &arp->RecurrencePattern
                withStartDate: startDate andEndDate: endDate];
  arp->ReaderVersion2 = 0x00003006;
  arp->WriterVersion2 = 0x00003009;

  startMinutes = ([startDate hourOfDay] * 60 + [startDate minuteOfHour]);
  arp->StartTimeOffset = startMinutes;
  arp->EndTimeOffset = startMinutes + (uint32_t) (duration / 60);

  arp->ExceptionCount = 0;
  arp->ReservedBlock1Size = 0;

  /* Currently ignored in property.idl: 
     arp->ReservedBlock2Size = 0; */
}

- (struct SBinary_short *) _computeAppointmentRecurInMemCtx: (TALLOC_CTX *) memCtx

{
  struct AppointmentRecurrencePattern *arp;
  struct Binary_r *bin;
  struct SBinary_short *sBin;
  NSCalendarDate *firstStartDate;
  iCalRecurrenceRule *rule;
  iCalEvent *event;

  event = [sogoObject component: NO secure: NO];
  rule = [[event recurrenceRules] objectAtIndex: 0];

  firstStartDate = [event firstRecurrenceStartDate];
  if (firstStartDate)
    {
      [firstStartDate setTimeZone: [self ownerTimeZone]];

      arp = talloc_zero (memCtx, struct AppointmentRecurrencePattern);
      _fillAppointmentRecurrencePattern (arp, firstStartDate,
                                         [event durationAsTimeInterval],
                                         [event lastPossibleRecurrenceStartDate],
                                         rule);
      sBin = talloc_zero (memCtx, struct SBinary_short);
      bin = set_AppointmentRecurrencePattern (sBin, arp);
      sBin->cb = bin->cb;
      sBin->lpb = bin->lpb;
      talloc_free (arp);

      // DEBUG(5, ("To client:\n"));
      // NDR_PRINT_DEBUG (AppointmentRecurrencePattern, arp);
    }
  else
    {
      [self errorWithFormat: @"no first occurrence found in rule: %@", rule];
      sBin = NULL;
    }

  return sBin;
}

- (int) getPidLidAppointmentRecur: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;
  iCalEvent *event;

  event = [sogoObject component: NO secure: NO];

  if ([event isRecurrent])
    *data = [self _computeAppointmentRecurInMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
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
  WOContext *woContext;
  iCalCalendar *vCalendar;
  iCalDateTime *start, *end;
  iCalTimeZone *tz;
  NSCalendarDate *now;
  NSString *content, *tzName;
  iCalEvent *newEvent;
  id value;

  [self logWithFormat: @"-save, event props:"];
  // MAPIStoreDumpMessageProperties (newProperties);

  content = [sogoObject contentAsString];
  if (![content length])
    {
      newEvent = [sogoObject component: YES secure: NO];
      vCalendar = [newEvent parent];
      [vCalendar setProdID: @"-//Inverse inc.//OpenChange+SOGo//EN"];
      content = [vCalendar versitString];
    }

  vCalendar = [iCalCalendar parseSingleFromSource: content];
  newEvent = [[vCalendar events] objectAtIndex: 0];

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
    value = [newProperties objectForKey: MAPIPropertyKey (PidLidAppointmentStartWhole)];
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

  now = [NSCalendarDate date];
  if ([sogoObject isNew])
    {
      [newEvent setCreated: now];
    }
  [newEvent setTimeStampAsDate: now];

  // Organizer and attendees
  value = [newProperties objectForKey: @"recipients"];

  if (value)
    {
      NSArray *recipients;
      NSDictionary *dict;
      iCalPerson *person;
      int i;

      woContext = [[self context] woContext];
      dict = [[woContext activeUser] primaryIdentity];
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

  /* recurrence */
  value = [newProperties
            objectForKey: MAPIPropertyKey (PidLidAppointmentRecur)];
  if (value)
    [self _setupRecurrenceInCalendar: vCalendar
                            fromData: value];

  // [sogoObject saveContentString: [vCalendar versitString]];
  [sogoObject saveComponent: newEvent];
}

/* TODO: those are stubs meant to prevent OpenChange from crashing when a
   recurring event is open */
- (NSArray *) childKeysMatchingQualifier: (EOQualifier *) qualifier
                        andSortOrderings: (NSArray *) sortOrderings
{
  /* TODO: Here we should return recurrence exceptions */
  return attachmentKeys;
}

- (id) lookupChild: (NSString *) childKey
{
  return [attachmentParts objectForKey: childKey];
}

- (MAPIStoreAttachment *) createAttachment
{
  MAPIStoreCalendarAttachment *newAttachment;
  uint32_t newAid;
  NSString *newKey;

  newAid = [attachmentKeys count];

  newAttachment = [MAPIStoreCalendarAttachment
                    mapiStoreObjectWithSOGoObject: nil
                                      inContainer: self];
  [newAttachment setIsNew: YES];
  [newAttachment setAID: newAid];
  newKey = [NSString stringWithFormat: @"%ul", newAid];
  [attachmentParts setObject: newAttachment
                      forKey: newKey];
  [attachmentKeys addObject: newKey];

  return newAttachment;
}

@end
