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
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalByDayMask.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalRecurrenceRule.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <Appointments/SOGoAppointmentObject.h>

#import "MAPIStoreContext.h"
#import "MAPIStoreTypes.h"
#import "NSCalendarDate+MAPIStore.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreCalendarMessage.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <gen_ndr/property.h>
#include <libmapi/libmapi.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_nameid.h>

@implementation MAPIStoreCalendarMessage

- (void) _setupRecurrenceInCalendar: (iCalCalendar *) calendar
                    withMasterEvent: (iCalEvent *) vEvent
                           fromData: (NSData *) mapiRecurrenceData
{
  struct Binary_r *blob;
  struct AppointmentRecurrencePattern *pattern;
  iCalRecurrenceRule *rule;
  iCalByDayMask *byDayMask;
  iCalWeekOccurrence weekOccurrence;
  iCalWeekOccurrences dayMaskDays;
  NSString *monthDay, *month;
  NSCalendarDate *startDate, *olEndDate, *endDate;
  NSUInteger count;
  NSInteger bySetPos;
  unsigned char maskValue;
  NSMutableArray *otherEvents;

  /* cleanup */
  [vEvent removeAllRecurrenceRules];
  [vEvent removeAllExceptionRules];
  [vEvent removeAllExceptionDates];
  otherEvents = [[calendar events] mutableCopy];
  [otherEvents removeObject: vEvent];
  [calendar removeChildren: otherEvents];
  [otherEvents release];

  startDate = [vEvent startDate];

  rule = [iCalRecurrenceRule elementWithTag: @"rrule"];
  [vEvent addToRecurrenceRules: rule];

  blob = [mapiRecurrenceData asBinaryInMemCtx: memCtx];
  pattern = get_AppointmentRecurrencePattern (memCtx, blob);

  memset (&dayMaskDays, 0, sizeof (iCalWeekOccurrences));
  if (pattern->RecurrencePattern.PatternType == PatternType_Day)
    {
      [rule setFrequency: iCalRecurrenceFrequenceDaily];
      [rule setRepeatInterval: pattern->RecurrencePattern.Period / minutesPerDay];
    }
  else if (pattern->RecurrencePattern.PatternType == PatternType_Week)
    {
      [rule setFrequency: iCalRecurrenceFrequenceWeekly];
      [rule setRepeatInterval: pattern->RecurrencePattern.Period];
      /* MAPI values for days are the same as in NGCards */
      for (count = 0; count < 7; count++)
        {
          maskValue = 1 << count;
          if ((pattern->RecurrencePattern.PatternTypeSpecific.WeekRecurrencePattern & maskValue))
            dayMaskDays[count] = iCalWeekOccurrenceAll;
        }
      byDayMask = [iCalByDayMask byDayMaskWithDays: dayMaskDays];
      [rule setByDayMask: byDayMask];
    }
  else
    {
      if (pattern->RecurrencePattern.RecurFrequency
          == RecurFrequency_Monthly)
        {
          [rule setFrequency: iCalRecurrenceFrequenceMonthly];
          [rule setRepeatInterval: pattern->RecurrencePattern.Period];
        }
      else if (pattern->RecurrencePattern.RecurFrequency
               == RecurFrequency_Yearly)
        {
          [rule setFrequency: iCalRecurrenceFrequenceYearly];
          [rule setRepeatInterval: pattern->RecurrencePattern.Period / 12];
          month = [NSString stringWithFormat: @"%d", [startDate monthOfYear]];
          [rule setNamedValue: @"bymonth" to: month];
        }
      else
        [self errorWithFormat:
                @"unhandled frequency case for Month pattern type: %d",
              pattern->RecurrencePattern.RecurFrequency];

      if ((pattern->RecurrencePattern.PatternType & 3) == 3)
        {
          /* HjMonthNth and MonthNth */
          if (pattern->RecurrencePattern.PatternTypeSpecific.MonthRecurrencePattern.WeekRecurrencePattern
              == 0x7f)
            {
              /* firsts or last day of month */
              if (pattern->RecurrencePattern.PatternTypeSpecific.MonthRecurrencePattern.N
                  == RecurrenceN_Last)
                monthDay = @"-1";
              else
                monthDay = [NSString stringWithFormat: @"%d",
                                     pattern->RecurrencePattern.PatternTypeSpecific.MonthRecurrencePattern.N];
              [rule setNamedValue: @"bymonthday" to: monthDay];
            }
          else if ((pattern->RecurrencePattern.PatternTypeSpecific.MonthRecurrencePattern.WeekRecurrencePattern
                    == 0x3e) /* Nth week day */
                   || (pattern->RecurrencePattern.PatternTypeSpecific.MonthRecurrencePattern.WeekRecurrencePattern
                       == 0x41)) /* Nth week-end day */
            {
              for (count = 0; count < 7; count++)
                {
                  maskValue = 1 << count;
                  if ((pattern->RecurrencePattern.PatternTypeSpecific.MonthRecurrencePattern.WeekRecurrencePattern
                       & maskValue))
                    dayMaskDays[count] = iCalWeekOccurrenceAll;
                }
              byDayMask = [iCalByDayMask byDayMaskWithDays: dayMaskDays];
              [rule setByDayMask: byDayMask];

              if (pattern->RecurrencePattern.PatternTypeSpecific.MonthRecurrencePattern.N
                  == RecurrenceN_Last)
                bySetPos = -1;
              else
                bySetPos = pattern->RecurrencePattern.PatternTypeSpecific.MonthRecurrencePattern.N;
              
              [rule setNamedValue: @"bysetpos"
                               to: [NSString stringWithFormat: @"%d", bySetPos]];
            }
          else 
            {
              if (pattern->RecurrencePattern.PatternTypeSpecific.MonthRecurrencePattern.N
                  < RecurrenceN_Last)
                weekOccurrence = (1
                                  << (pattern->RecurrencePattern.PatternTypeSpecific.MonthRecurrencePattern.N
                                      - 1));
              else
                weekOccurrence = iCalWeekOccurrenceLast;
              
              for (count = 0; count < 7; count++)
                {
                  maskValue = 1 << count;
                  if ((pattern->RecurrencePattern.PatternTypeSpecific.MonthRecurrencePattern.WeekRecurrencePattern
                       & maskValue))
                    dayMaskDays[count] = weekOccurrence;
                }
              byDayMask = [iCalByDayMask byDayMaskWithDays: dayMaskDays];
              [rule setByDayMask: byDayMask];
            }
        }
      else if ((pattern->RecurrencePattern.PatternType & 2) == 2
               || (pattern->RecurrencePattern.PatternType & 4) == 4)
        {
          /* MonthEnd, HjMonth and HjMonthEnd */
          [rule setNamedValue: @"bymonthday"
                           to: [NSString stringWithFormat: @"%d",
                                         pattern->RecurrencePattern.PatternTypeSpecific.Day]];
        }
      else
        [self errorWithFormat: @"invalid value for PatternType: %.4x",
              pattern->RecurrencePattern.PatternType];
    }

  switch (pattern->RecurrencePattern.EndType)
    {
    case END_NEVER_END:
    case NEVER_END:
      break;
    case END_AFTER_N_OCCURRENCES:
      [rule setRepeatCount: pattern->RecurrencePattern.OccurrenceCount];
      break;
    case END_AFTER_DATE:
      olEndDate = [NSCalendarDate dateFromMinutesSince1601: pattern->RecurrencePattern.EndDate];
      endDate = [NSCalendarDate dateWithYear: [olEndDate yearOfCommonEra]
                                       month: [olEndDate monthOfYear]
                                         day: [olEndDate dayOfMonth]
                                        hour: [startDate hourOfDay]
                                      minute: [startDate minuteOfHour]
                                      second: [startDate secondOfMinute]
                                    timeZone: [startDate timeZone]];
      [rule setUntilDate: endDate];
      break;
    default:
      [self errorWithFormat: @"invalid value for EndType: %.4x",
            pattern->RecurrencePattern.EndType];
    }

  talloc_free (pattern);
  talloc_free (blob);
}

- (enum MAPISTATUS) getProperty: (void **) data
                        withTag: (enum MAPITAGS) propTag
{
  NSTimeInterval timeValue;
  id event;
  int rc;

  rc = MAPI_E_SUCCESS;
  switch ((uint32_t) propTag)
    {
    case PR_ICON_INDEX: // TODO
      /* see http://msdn.microsoft.com/en-us/library/cc815472.aspx */
      // *longValue = 0x00000401 for recurring event
      // *longValue = 0x00000402 for meeting
      // *longValue = 0x00000403 for recurring meeting
      // *longValue = 0x00000404 for invitation
      *data = MAPILongValue (memCtx, 0x00000400);
      break;
    case PR_MESSAGE_CLASS_UNICODE:
      *data = talloc_strdup(memCtx, "IPM.Appointment");
      break;
    case PidLidAppointmentStartWhole: // DTSTART
      event = [sogoObject component: NO secure: NO];
      *data = [[event startDate] asFileTimeInMemCtx: memCtx];
      break;
    case PidLidAppointmentEndWhole: // DTEND
      event = [sogoObject component: NO secure: NO];
      *data = [[event endDate] asFileTimeInMemCtx: memCtx];
      break;
    case PidLidAppointmentDuration:
      event = [sogoObject component: NO secure: NO];
      timeValue = [[event endDate] timeIntervalSinceDate: [event startDate]];
      *data = MAPILongValue (memCtx, (uint32_t) (timeValue / 60));
      break;
    case PidLidAppointmentSubType:
      event = [sogoObject component: NO secure: NO];
      *data = MAPIBoolValue (memCtx, [event isAllDay]);
      break;
    case PidLidBusyStatus: // TODO
      *data = MAPILongValue (memCtx, 0x02);
      break;
    case PidLidRecurring: // TODO
      *data = MAPIBoolValue (memCtx, NO);
      break;

    // case 0x82410003: // TODO
    //   *data = MAPILongValue (memCtx, 0);
    //   break;
    case PR_SUBJECT_UNICODE: // SUMMARY
      event = [sogoObject component: NO secure: NO];
      *data = [[event summary] asUnicodeInMemCtx: memCtx];
      break;
    case PidLidLocation: // LOCATION
      event = [sogoObject component: NO secure: NO];
      *data = [[event location] asUnicodeInMemCtx: memCtx];
      break;
    case PidLidPrivate: // private (bool), should depend on CLASS and permissions
      *data = MAPIBoolValue (memCtx, NO);
      break;
    case PR_SENSITIVITY: // not implemented, depends on CLASS
      // normal = 0, personal?? = 1, private = 2, confidential = 3
      *data = MAPILongValue (memCtx, 0);
      break;
    case PR_CREATION_TIME:
      event = [sogoObject component: NO secure: NO];
      *data = [[event created] asFileTimeInMemCtx: memCtx];
      break;

    case PR_IMPORTANCE:
      {
	unsigned int v;

	event = [sogoObject component: NO secure: NO];

	if ([[event priority] isEqualToString: @"9"])
	  v = 0x0;
	else if ([[event priority] isEqualToString: @"1"])
	  v = 0x2;
	else
	  v = 0x1;

	*data = MAPILongValue (memCtx, v);
      }
      break;

      // case PidLidTimeZoneStruct:
      // case PR_VD_NAME_UNICODE:
      //         *data = talloc_strdup(memCtx, "PR_VD_NAME_UNICODE");
      //         break;
      // case PR_EMS_AB_DXA_REMOTE_CLIENT_UNICODE: "Home:" ???
      //         *data = talloc_strdup(memCtx, "PR_EMS...");
      //         break;
    default:
      rc = [super getProperty: data
                      withTag: propTag];
    }

  // #define PR_REPLY_TIME                                       PROP_TAG(PT_SYSTIME   , 0x0030) /* 0x00300040 */
  // #define PR_INTERNET_MESSAGE_ID_UNICODE                      PROP_TAG(PT_UNICODE   , 0x1035) /* 0x1035001f */
  // #define PR_FLAG_STATUS                                      PROP_TAG(PT_LONG      , 0x1090) /* 0x10900003 */

  return rc;
}

- (void) openMessage: (struct mapistore_message *) msg
{
  NSString *name, *email;
  NSArray *attendees;
  iCalPerson *person;
  id event;
  struct SRowSet *recipients;
  int count, max;

  [super openMessage: msg];
  event = [sogoObject component: NO secure: NO];
  attendees = [event attendees];
  max = [attendees count];

  recipients = msg->recipients;
  recipients->cRows = max;
  recipients->aRow = talloc_array (recipients, struct SRow, max);
  
  for (count = 0; count < max; count++)
    {
      recipients->aRow[count].ulAdrEntryPad = 0;
      recipients->aRow[count].cValues = 3;
      recipients->aRow[count].lpProps = talloc_array (recipients->aRow,
                                                      struct SPropValue,
                                                      3);
      
      // TODO (0x01 = primary recipient)
      set_SPropValue_proptag (&(recipients->aRow[count].lpProps[0]),
                              PR_RECIPIENT_TYPE,
                              MAPILongValue (memCtx, 0x01));
      
      person = [attendees objectAtIndex: count];
      
      name = [person cn];
      if (!name)
        name = @"";
	  
      email = [person email];
      if (!email)
        email = @"";
	  
      set_SPropValue_proptag (&(recipients->aRow[count].lpProps[1]),
                              PR_DISPLAY_NAME,
                              [name asUnicodeInMemCtx: recipients->aRow[count].lpProps]);
      set_SPropValue_proptag (&(recipients->aRow[count].lpProps[2]),
                              PR_EMAIL_ADDRESS,
                              [email asUnicodeInMemCtx: recipients->aRow[count].lpProps]);
    }
}

- (void) save
{
  iCalCalendar *vCalendar;
  iCalEvent *vEvent;
  id value;
  SOGoUserDefaults *ud;
  NSCalendarDate *now;
  iCalTimeZone *tz;
  NSString *owner, *content;
  iCalDateTime *start, *end;
  WOContext *woContext;

  [self logWithFormat: @"-save, event props:"];
  // MAPIStoreDumpMessageProperties (newProperties);

  content = [sogoObject contentAsString];
  if (![content length])
    {
      vEvent = [sogoObject component: YES secure: NO];
      vCalendar = [vEvent parent];
      [vCalendar setProdID: @"-//Inverse inc.//OpenChange+SOGo//EN"];
      content = [vCalendar versitString];
    }

  vCalendar = [iCalCalendar parseSingleFromSource: content];
  vEvent = [[vCalendar events] objectAtIndex: 0];

  // summary
  value = [newProperties
            objectForKey: MAPIPropertyKey (PR_NORMALIZED_SUBJECT_UNICODE)];
  if (value)
    [vEvent setSummary: value];

  // Location
  value = [newProperties objectForKey: MAPIPropertyKey (PidLidLocation)];
  if (value)
    [vEvent setLocation: value];

  woContext = [[self context] woContext];
  owner = [sogoObject ownerInContext: woContext];
  ud = [[SOGoUser userWithLogin: owner] userDefaults];
  tz = [iCalTimeZone timeZoneForName: [ud timeZoneName]];
  [vCalendar addTimeZone: tz];

  // start
  value = [newProperties objectForKey: MAPIPropertyKey (PR_START_DATE)];
  if (!value)
    value = [newProperties objectForKey: MAPIPropertyKey (PidLidAppointmentStartWhole)];
  if (value)
    {
      start = (iCalDateTime *) [vEvent uniqueChildWithTag: @"dtstart"];
      [start setTimeZone: tz];
      [start setDateTime: value];
    }

  // end
  value = [newProperties objectForKey: MAPIPropertyKey (PR_END_DATE)];
  if (!value)
    value = [newProperties objectForKey: MAPIPropertyKey (PidLidAppointmentEndWhole)];
  if (value)
    {
      end = (iCalDateTime *) [vEvent uniqueChildWithTag: @"dtend"];
      [end setTimeZone: tz];
      [end setDateTime: value];
    }

  now = [NSCalendarDate date];
  if ([sogoObject isNew])
    {
      [vEvent setCreated: now];
    }
  [vEvent setTimeStampAsDate: now];

  // Organizer and attendees
  value = [newProperties objectForKey: @"recipients"];

  if (value)
    {
      NSArray *recipients;
      NSDictionary *dict;
      iCalPerson *person;
      int i;

      dict = [[woContext activeUser] primaryIdentity];
      person = [iCalPerson new];
      [person setCn: [dict objectForKey: @"fullName"]];
      [person setEmail: [dict objectForKey: @"email"]];
      [vEvent setOrganizer: person];
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
	  if (![vEvent isAttendee: [person rfc822Email]])
	    [vEvent addToAttendees: person];

	  [person release];
	}
    }

  /* recurrence */
  value = [newProperties
            objectForKey: MAPIPropertyKey (PidLidAppointmentRecur)];
  [self _setupRecurrenceInCalendar: vCalendar
                   withMasterEvent: vEvent
                          fromData: value];

  // [sogoObject saveContentString: [vCalendar versitString]];
  [sogoObject saveComponent: vEvent];
}

@end
