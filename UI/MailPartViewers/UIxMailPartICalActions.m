/* UIxMailPartICalActions.m - this file is part of SOGo
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

#import <Foundation/NSCalendarDate.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalPerson.h>

#import <UI/Common/WODirectAction+SOGo.h>

#import <SoObjects/Appointments/SOGoAppointmentObject.h>
#import <SoObjects/Appointments/SOGoAppointmentFolder.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/iCalEntityObject+Utilities.h>
#import <SoObjects/Mailer/SOGoMailBodyPart.h>

#import "UIxMailPartICalActions.h"

@implementation UIxMailPartICalActions

- (iCalEvent *) _emailEvent
{
  NSData *content;
  NSString *eventString;
  iCalCalendar *emailCalendar;

  content = [[self clientObject] fetchBLOB];
  eventString = [[NSString alloc] initWithData: content
				  encoding: NSUTF8StringEncoding];
  if (!eventString)
    eventString = [[NSString alloc] initWithData: content
				    encoding: NSISOLatin1StringEncoding];
  emailCalendar = [iCalCalendar parseSingleFromSource: eventString];

  return (iCalEvent *) [emailCalendar firstChildWithTag: @"vevent"];
}

- (SOGoAppointmentObject *) _eventObjectWithUID: (NSString *) uid
{
  SOGoAppointmentFolder *personalFolder;
  SOGoAppointmentObject *eventObject;

  personalFolder
    = [[context activeUser] personalCalendarFolderInContext: context];
  eventObject = [personalFolder lookupName: uid
				inContext: context acquire: NO];
  if (![eventObject isKindOfClass: [SOGoAppointmentObject class]])
    eventObject = [SOGoAppointmentObject objectWithName: uid
					 inContainer: personalFolder];
  
  return eventObject;
}

- (iCalEvent *)
  _setupChosenEventAndEventObject: (SOGoAppointmentObject **) eventObject
{
  iCalEvent *emailEvent, *calendarEvent, *chosenEvent;

  emailEvent = [self _emailEvent];
  if (emailEvent)
    {
      *eventObject = [self _eventObjectWithUID: [emailEvent uid]];
      if ([*eventObject isNew])
	chosenEvent = emailEvent;
      else
	{
	  calendarEvent = (iCalEvent *) [*eventObject component: NO];
	  if ([calendarEvent compare: emailEvent] == NSOrderedAscending)
	    chosenEvent = emailEvent;
	  else
	    chosenEvent = calendarEvent;
	}
    }
  else
    chosenEvent = nil;

  return chosenEvent;
}

- (WOResponse *) _changePartStatusAction: (NSString *) newStatus
{
  WOResponse *response;
  SOGoAppointmentObject *eventObject;
  iCalEvent *chosenEvent;
  iCalPerson *user;
  iCalCalendar *calendar;
  NSString *rsvp, *method;

  chosenEvent = [self _setupChosenEventAndEventObject: &eventObject];
  if (chosenEvent)
    {
      user = [chosenEvent findParticipant: [context activeUser]];
      [user setPartStat: newStatus];
      calendar = [chosenEvent parent];
      method = [[calendar method] lowercaseString];
      if ([method isEqualToString: @"request"])
	{
	  [calendar setMethod: @""];
	  rsvp = [[user rsvp] lowercaseString];
	}
      else
	rsvp = nil;
      [eventObject saveContentString: [calendar versitString]];
      if (rsvp && [rsvp isEqualToString: @"true"])
	[eventObject sendResponseToOrganizer];
      response = [self responseWith204];
    }
  else
    {
      response = [context response];
      [response setStatus: 409];
    }

  return response;
}

- (WOResponse *) acceptAction
{
  return [self _changePartStatusAction: @"ACCEPTED"];
}

- (WOResponse *) declineAction
{
  return [self _changePartStatusAction: @"DECLINED"];
}

// - (WOResponse *) markTentativeAction
// {
//   return [self _changePartStatusAction: @"TENTATIVE"];
// }

// - (WOResponse *) addToCalendarAction
// {
//   return [self responseWithStatus: 404];
// }

// - (WOResponse *) deleteFromCalendarAction
// {
//   return [self responseWithStatus: 404];
// }

@end
