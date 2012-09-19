/* SOGoAptMailReceipt.m - this file is part of SOGo
 *
 * Copyright (C) 2009-2012 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Ludovic Marcotte <lmarcotte@inverse.ca>
 *         Francis Lachapelle <flachapelle@inverse.ca>
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
#import <Foundation/NSCharacterSet.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoDateFormatter.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import "SOGoAptMailReceipt.h"

static SOGoUserManager *um = nil;
static NSCharacterSet *wsSet = nil;

@implementation SOGoAptMailReceipt

+ (void) initialize
{
  if (!um)
    um = [SOGoUserManager sharedUserManager];

  if (!wsSet)
    wsSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];
}

- (id) init
{
  if ((self = [super init]))
    {
      originator = nil;
      addedAttendees = nil;
      deletedAttendees = nil;
      updatedAttendees = nil;
      calendarName = nil;
    }

  return self;
}

- (void) dealloc
{
  [originator release];
  [addedAttendees release];
  [deletedAttendees release];
  [updatedAttendees release];
  [calendarName release];
  [super dealloc];
}

- (NSString *) getBody
{
  NSString *body;

  if (!values)
    [self setupValues];

  body = [[self generateResponse] contentAsString];

  return [body stringByTrimmingCharactersInSet: wsSet];
}

- (void) setOriginator: (NSString *) newOriginator
{
  ASSIGN (originator, newOriginator);
}

- (void) setAddedAttendees: (NSArray *) theAttendees;
{
  ASSIGN (addedAttendees, theAttendees);
}

- (NSArray *) addedAttendees;
{
  return addedAttendees;
}

- (void) setDeletedAttendees: (NSArray *) theAttendees;
{
  ASSIGN (deletedAttendees, theAttendees);
}

- (NSArray *) deletedAttendees;
{
  return deletedAttendees;
}

- (NSArray *) updatedAttendes
{
  return updatedAttendees;
}

- (void) setUpdatedAttendees: (NSArray *) theAttendees
{
  ASSIGN (updatedAttendees, theAttendees);
}

- (void) setCurrentRecipient: (iCalPerson *) newCurrentRecipient
{
  ASSIGN (currentRecipient, newCurrentRecipient);
}

- (iCalPerson *) currentRecipient
{
  return currentRecipient;
}

- (void) setOperation: (SOGoEventOperation) theOperation
{
  operation = theOperation;
}

- (void) setCalendarName: (NSString *) theCalendarName
{
  ASSIGN (calendarName, theCalendarName);
}

- (NSString *) calendarName
{
  return calendarName;
}

- (NSString *) aptSummary
{
  NSString *s;

  if (!values)
    [self setupValues];

  switch (operation)
    {
    case EventCreated:
      s = [self labelForKey: @"The event \"%{Summary}\" was created"
                  inContext: context];
      break;
      
    case EventDeleted:
      s = [self labelForKey: @"The event \"%{Summary}\" was deleted"
                  inContext: context];
      break;
      
    case EventUpdated:
    default:
      s = [self labelForKey: @"The event \"%{Summary}\" was updated"
                  inContext: context];
    }

  return [values keysWithFormat: s];
}

- (NSString *) getSubject
{
  return [[[self aptSummary] stringByTrimmingCharactersInSet: wsSet] asQPSubjectString: @"utf-8"];
}

- (NSString *) _formattedUserDate: (NSCalendarDate *) date
{
  SOGoDateFormatter *formatter;
  NSCalendarDate *tzDate;
  SOGoUser *currentUser;

  currentUser = [context activeUser];

  tzDate = [date copy];
  [tzDate setTimeZone: viewTZ];
  [tzDate autorelease];

  formatter = [currentUser dateFormatterInContext: context];

  if ([apt isAllDay])
    return [formatter formattedDate: tzDate];
  else
    return [NSString stringWithFormat: @"%@ - %@",
             [formatter formattedDate: tzDate],
             [formatter formattedTime: tzDate]];
}

- (NSString *) aptStartDate
{
  return [self _formattedUserDate: [apt startDate]];
}

- (NSString *) aptEndDate
{
  return [self _formattedUserDate: [(iCalEvent *) apt endDate]];
}

@end
