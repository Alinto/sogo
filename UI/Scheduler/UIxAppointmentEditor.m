/* UIxAppointmentEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
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

#import <NGObjWeb/SoObject.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSCalendarDate+misc.h>

#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>

#import <SoObjects/SOGo/AgenorUserManager.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoContentObject.h>
#import <SoObjects/Appointments/SOGoAppointmentFolder.h>
#import <SoObjects/Appointments/SOGoAppointmentObject.h>

#import "UIxComponentEditor.h"
#import "UIxAppointmentEditor.h"

@implementation UIxAppointmentEditor

- (id) init
{
  if ((self = [super init]))
    {
      aptStartDate = nil;
      aptEndDate = nil;
      item = nil;
      event = nil;
    }

  return self;
}

/* template values */
- (iCalEvent *) event
{
  return event;
}

- (NSString *) saveURL
{
  return [NSString stringWithFormat: @"%@/saveAsAppointment",
                   [[self clientObject] baseURL]];
}

- (NSString *) _toolbarForCalObject
{
  SOGoUser *currentUser;
  SOGoAppointmentObject *clientObject;
  NSString *filename, *email;
  iCalPerson *person;
  iCalPersonPartStat participationStatus;

  clientObject = [self clientObject];
  currentUser = [[self context] activeUser];
  email = [currentUser email];
  if ([clientObject isOrganizer: email
                    orOwner: [currentUser login]])
    filename = @"SOGoAppointmentObject.toolbar";
  else
    {
      if ([clientObject isParticipant: email])
        {
          person = [[clientObject component: NO] findParticipantWithEmail: email];
          participationStatus = [person participationStatus];
          if (participationStatus == iCalPersonPartStatAccepted)
            filename = @"SOGoAppointmentObjectDecline.toolbar";
          else if (participationStatus == iCalPersonPartStatDeclined)
            filename = @"SOGoAppointmentObjectAccept.toolbar";
          else
            filename = @"SOGoAppointmentObjectAcceptOrDecline.toolbar";
        }
      else
        filename = @"";
    }

  return filename;
}

- (NSString *) toolbar
{
  return ([self _toolbarForCalObject]);
}

/* icalendar values */
- (BOOL) isAllDay
{
  return NO;
}

- (void) setIsAllDay: (BOOL) newIsAllDay
{
}

- (void) setAptStartDate: (NSCalendarDate *) newAptStartDate
{
  ASSIGN (aptStartDate, newAptStartDate);
}

- (NSCalendarDate *) aptStartDate
{
  return aptStartDate;
}

- (void) setAptEndDate: (NSCalendarDate *) newAptEndDate
{
  ASSIGN (aptEndDate, newAptEndDate);
}

- (NSCalendarDate *) aptEndDate
{
  return aptEndDate;
}

- (NSArray *) repeatList
{
  static NSArray *repeatItems = nil;

  if (!repeatItems)
    {
      repeatItems = [NSArray arrayWithObjects: @"DAILY",
                             @"WEEKLY",
                             @"BI-WEEKLY",
                             @"EVERY WEEKDAY",
                             @"MONTHLY",
                             @"YEARLY",
                             @"-",
                             @"CUSTOM",
                             nil];
      [repeatItems retain];
    }

  return repeatItems;
}

- (NSString *) itemRepeatText
{
  NSString *text;

  if ([item isEqualToString: @"-"])
    text = item;
  else
    text = [self labelForKey: [NSString stringWithFormat: @"repeat_%@", item]];

  return text;
}

- (void) setItem: (NSString *) newItem
{
  item = newItem;
}

- (NSString *) item
{
  return item;
}

- (NSArray *) reminderList
{
  static NSArray *reminderItems = nil;

  if (!reminderItems)
    {
      reminderItems = [NSArray arrayWithObjects: @"5_MINUTES_BEFORE",
                               @"10_MINUTES_BEFORE",
                               @"15_MINUTES_BEFORE",
                               @"30_MINUTES_BEFORE",
                               @"45_MINUTES_BEFORE",
                               @"-",
                               @"1_HOUR_BEFORE",
                               @"2_HOURS_BEFORE",
                               @"5_HOURS_BEFORE",
                               @"15_HOURS_BEFORE",
                               @"-",
                               @"1_DAY_BEFORE",
                               @"2_DAYS_BEFORE",
                               @"1_WEEK_BEFORE",
                               @"-",
                               @"CUSTOM",
                               nil];
      [reminderItems retain];
    }

  return reminderItems;
}

// - (void) setReminder: (NSString *) reminder
// {
//   ASSIGN(reminder, _reminder);
// }

// - (NSString *) reminder
// {
//   return reminder;
// }

- (NSString *) itemReminderText
{
  NSString *text;

  if ([item isEqualToString: @"-"])
    text = item;
  else
    text = [self labelForKey: [NSString stringWithFormat: @"reminder_%@", item]];

  return text;
}

- (NSString *) repeat
{
  return @"";
}

- (void) setRepeat: (NSString *) newRepeat
{
}

- (NSString *) reminder
{
  return @"";
}

- (void) setReminder: (NSString *) newReminder
{
}

/* actions */
- (NSCalendarDate *) newStartDate
{
  NSCalendarDate *newStartDate, *now;
  int hour;

  newStartDate = [self selectedDate];
  if ([[self queryParameterForKey: @"hm"] length] == 0)
    {
      now = [NSCalendarDate calendarDate];
      [now setTimeZone: [[self clientObject] userTimeZone]];
      if ([now isDateOnSameDay: newStartDate])
        {
          hour = [now hourOfDay];
          if (hour < 8)
            newStartDate = [now hour: 8 minute: 0];
          else if (hour > 18)
            newStartDate = [[now tomorrow] hour: 8 minute: 0];
          else
            newStartDate = now;
        }
      else
        newStartDate = [newStartDate hour: 8 minute: 0];
    }

  return newStartDate;
}

- (id <WOActionResults>) defaultAction
{
  NSCalendarDate *startDate, *endDate;
  NSString *duration;
  unsigned int minutes;

  event = (iCalEvent *) [[self clientObject] component: NO];
  if (event)
    {
      startDate = [event startDate];
      endDate = [event endDate];
    }
  else
    {
      startDate = [self newStartDate];
      duration = [self queryParameterForKey:@"dur"];
      if ([duration length] > 0)
	minutes = [duration intValue];
      else
	minutes = 60;
      endDate
	= [startDate dateByAddingYears: 0 months: 0 days: 0
		     hours: 0 minutes: minutes seconds: 0];
    }

  ASSIGN (aptStartDate, startDate);
  ASSIGN (aptEndDate, endDate);

  /* here comes the code for initializing repeat, reminder and isAllDay... */

  return self;
}

- (id <WOActionResults>) newAction
{
  NSString *objectId, *method, *uri;
  id <WOActionResults> result;
  Class clientKlazz;

  clientKlazz = [[self clientObject] class];
  objectId = [clientKlazz globallyUniqueObjectId];
  if ([objectId length] > 0)
    {
      method = [NSString stringWithFormat:@"%@/Calendar/%@/editAsAppointment",
                         [self userFolderPath], objectId];
      uri = [self completeHrefForMethod: method];
      result = [self redirectToLocation: uri];
    }
  else
    result = [NSException exceptionWithHTTPStatus: 500 /* Internal Error */
                          reason: @"could not create a unique ID"];

  return result;
}

- (id <WOActionResults>) saveAction
{
  SOGoAppointmentObject *clientObject;
  NSString *iCalString;

  clientObject = [self clientObject];
  iCalString = [[clientObject calendar: NO] versitString];
  [clientObject saveContentString: iCalString];

  return [self jsCloseWithRefreshMethod: @"refreshAppointmentsAndDisplay()"];
}

- (BOOL) shouldTakeValuesFromRequest: (WORequest *) request
                           inContext: (WOContext*) context
{
  return ([[self clientObject] isKindOfClass: [SOGoAppointmentObject class]]
	  && [[request method] isEqualToString: @"POST"]);
}

- (void) takeValuesFromRequest: (WORequest *) _rq
                     inContext: (WOContext *) _ctx
{
  SOGoAppointmentObject *clientObject;

  clientObject = [self clientObject];
  event = (iCalEvent *) [clientObject component: YES];

  [super takeValuesFromRequest: _rq inContext: _ctx];

  [event setStartDate: aptStartDate];
  [event setEndDate: aptEndDate];
  if ([clientObject isNew])
    [event setTransparency: @"OPAQUE"];
}

@end
