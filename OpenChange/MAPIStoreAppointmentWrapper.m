/* MAPIStoreAppointmentWrapper.m - this file is part of SOGo
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
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSData.h>
#import <Foundation/NSTimeZone.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalRecurrenceRule.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/iCalPerson.h>

#import "MAPIStoreRecurrenceUtils.h"
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
#include <libmapi/libmapi.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
#include <mapistore/mapistore_nameid.h>

NSTimeZone *utcTZ;

@implementation MAPIStoreAppointmentWrapper

+ (void) initialize
{
  utcTZ = [NSTimeZone timeZoneWithName: @"UTC"];
  [utcTZ retain];
}

+ (id) wrapperWithICalEvent: (iCalEvent *) newEvent
                 inTimeZone: (NSTimeZone *) newTimeZone
{
  MAPIStoreAppointmentWrapper *wrapper;

  wrapper = [[self alloc] initWithICalEvent: newEvent
                                 inTimeZone: newTimeZone];
  [wrapper autorelease];

  return wrapper;
}

- (id) initWithICalEvent: (iCalEvent *) newEvent
              inTimeZone: (NSTimeZone *) newTimeZone
{
  if ((self = [self init]))
    {
      ASSIGN (event, newEvent);
      ASSIGN (calendar, [event parent]);
      ASSIGN (timeZone, newTimeZone);
    }

  return self;
}

- (void) dealloc
{
  [calendar release];
  [event release];
  [super dealloc];
}

- (int) getPrIconIndex: (void **) data // TODO
              inMemCtx: (TALLOC_CTX *) memCtx
{
  uint32_t longValue;

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

- (int) getPrBody: (void **) data
         inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [event comment];
  if (!stringValue)
    stringValue = @"";

  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrStartDate: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  NSCalendarDate *dateValue;

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
  return [self getPidLidAppointmentStartWhole: data inMemCtx: memCtx];
}

- (int) getPrEndDate: (void **) data
            inMemCtx: (TALLOC_CTX *) memCtx
{
  NSCalendarDate *dateValue;

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
  return [self getPidLidAppointmentEndWhole: data inMemCtx: memCtx];
}

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

- (int) getPidLidBusyStatus: (void **) data // TODO
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0x02);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidIndentedBusyStatus: (void **) data // TODO
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidBusyStatus: data inMemCtx: memCtx];
}

- (int) getPrSubject: (void **) data // SUMMARY
            inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[event summary] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidLocation: (void **) data // LOCATION
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[event location] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidWhere: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidLocation: data inMemCtx: memCtx];
}

- (int) getPidLidServerProcessed: (void **) data
                        inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
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
  *data = MAPIBoolValue (memCtx, [event isRecurrent]);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidRecurring: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPIBoolValue (memCtx, [event isRecurrent]);

  return MAPISTORE_SUCCESS;
}

static void
_fillAppointmentRecurrencePattern (struct AppointmentRecurrencePattern *arp,
                                   NSCalendarDate *startDate, NSTimeInterval duration,
                                   NSCalendarDate * endDate, iCalRecurrenceRule *rule)
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

  rule = [[event recurrenceRules] objectAtIndex: 0];

  firstStartDate = [event firstRecurrenceStartDate];
  if (firstStartDate)
    {
      [firstStartDate setTimeZone: timeZone];

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

  if ([event isRecurrent])
    *data = [self _computeAppointmentRecurInMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidLidGlobalObjectId: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  static char byteArrayId[] = {0x04, 0x00, 0x00, 0x00, 0x82, 0x00, 0xE0,
                               0x00, 0x74, 0xC5, 0xB7, 0x10, 0x1A, 0x82,
                               0xE0, 0x08};
  static char X[] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
  NSMutableData *nsData;
  NSData *uidData;
  NSCalendarDate *creationTime;
  struct FILETIME *creationFileTime;
  uint32_t uidDataLength;

  nsData = [NSMutableData dataWithCapacity: 256];
  [nsData appendBytes: byteArrayId length: 16];

  /* FIXME TODO */
  [nsData appendBytes: X length: 4];
  /* /FIXME */

  creationTime = [event created];
  if (!creationTime)
    {
      [self logWithFormat: @"" __location__ ": event has no 'CREATED' tag -> inventing one"];
      creationTime = [event lastModified];
      if (!creationTime)
        creationTime = [NSCalendarDate date];
    }
  creationFileTime = [creationTime asFileTimeInMemCtx: NULL];
  [nsData appendBytes: &creationFileTime->dwLowDateTime length: 4];
  [nsData appendBytes: &creationFileTime->dwHighDateTime length: 4];
  talloc_free (creationFileTime);

  uidData = [[event uid] dataUsingEncoding: NSUTF8StringEncoding];
  uidDataLength = [uidData length];
  [nsData appendBytes: &uidDataLength length: 4];
  [nsData appendData: uidData];
  *data = [nsData asBinaryInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidCleanGlobalObjectId: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidGlobalObjectId: data
                              inMemCtx: memCtx];
}

@end
