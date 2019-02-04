/*
  Copyright (C) 2006-2019 Inverse inc.
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOGo.
 
  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSTimeZone.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalToDo.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoDateFormatter.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import "iCalPerson+SOGo.h"
#import "SOGoAptMailNotification.h"

@implementation SOGoAptMailNotification

- (id) init
{
  if ((self = [super init]))
    {
      apt = nil;
      values = nil;
      dateFormatter = RETAIN([[context activeUser] dateFormatterInContext: context]);
      organizerName = nil;
      currentAttendee = nil;
    }

  return self;
}

- (void) dealloc
{
  [values release];
  [apt release];
  [previousApt release];
  [organizerName release];
  [currentAttendee release];
  [viewTZ release];
  [oldStartDate release];
  [newStartDate release];
  [oldEndDate release];
  [newEndDate release];
  [dateFormatter release];
  [super dealloc];
}

- (iCalRepeatableEntityObject *) apt
{
  return apt;
}

- (void) setApt: (iCalRepeatableEntityObject *) theApt
{
  ASSIGN (apt, theApt);
}

- (iCalRepeatableEntityObject *) previousApt
{
  return previousApt;
}

- (void) setPreviousApt: (iCalRepeatableEntityObject *) theApt
{
  ASSIGN (previousApt, theApt);
}

- (BOOL) hasNewLocation
{
  return ([[apt location] length] > 0);
}

- (BOOL) hasOldLocation
{
  return ([[previousApt location] length] > 0);
}

- (NSCalendarDate *) oldStartDate
{
  if (!oldStartDate)
    {
      ASSIGN (oldStartDate, [[self previousApt] startDate]);
      [oldStartDate setTimeZone: viewTZ];
    }
  return oldStartDate;
}

- (NSCalendarDate *) newStartDate
{
  if (!newStartDate)
    {
      ASSIGN (newStartDate, [[self apt] startDate]);
      [newStartDate setTimeZone: viewTZ];
    }
  return newStartDate;
}

- (NSCalendarDate *) oldEndDate
{
  if (!oldEndDate)
    {
      if ([[self previousApt] isKindOfClass: [iCalEvent class]])
        ASSIGN (oldEndDate, [(iCalEvent*)[self previousApt] endDate]);
      else
        ASSIGN (oldEndDate, [(iCalToDo*)[self previousApt] due]);
      [oldEndDate setTimeZone: viewTZ];
    }
  return oldEndDate;
}

- (NSCalendarDate *) newEndDate
{
  if (!newEndDate)
    {
      if ([[self apt] isKindOfClass: [iCalEvent class]])
        ASSIGN (newEndDate, [(iCalEvent*)[self apt] endDate]);
      else
        ASSIGN (newEndDate, [(iCalToDo*)[self apt] due]);
      [newEndDate setTimeZone: viewTZ];
    }
  return newEndDate;
}

- (NSString *) location
{
  return [apt location];
}

- (NSString *) summary
{
  return [apt summary];
}

- (void) setOrganizerName: (NSString *) theString
{
  ASSIGN (organizerName, theString);
}

- (NSString *) organizerName
{
  return organizerName;
}

- (void) setCurrentAttendee: (iCalPerson *) theAttendee
{
  ASSIGN(currentAttendee, theAttendee);
}

- (iCalPerson *) currentAttendee
{
  return currentAttendee;
}

- (NSString *) sentByText
{
  NSDictionary *sentByValues;
  NSString *sentByText;
  id value;
  
  sentByText = @"";

  if (organizerName)
    {
      value = [[apt organizer] sentBy];
      
      if (value && [value length])
        {
          sentByValues = [NSDictionary dictionaryWithObject: value
                                                     forKey: @"SentBy"];
          sentByText
            = [sentByValues keysWithFormat: [self
                                              labelForKey: @"(sent by %{SentBy}) "
                                                inContext: context]];
        }
    }
  
  return sentByText;
}

- (NSTimeInterval) duration
{
  return [[self newEndDate] timeIntervalSinceDate:[self newStartDate]];
}

- (BOOL) isEndDateOnSameDay
{
  if ([[self apt] isKindOfClass: [iCalEvent class]] && [(iCalEvent*)[self apt] isAllDay])
    return ([self duration] <= 86400);

  return [[self newStartDate] isDateOnSameDay: [self newEndDate]];
}

- (NSString *) formattedAptStartDate
{
  NSString *s;
  id value;
  
  value = [self newStartDate];
  s = @"";
  
  if (value)
    s = [dateFormatter formattedDate: value];
  
  return s;
}


- (NSString *) formattedAptStartTime
{
  NSString *s;
  id value;
  
  value = [self newStartDate];
  s = @"";
  
  if (value && (![apt isKindOfClass: [iCalEvent class]] || ![(iCalEvent*)apt isAllDay]))
    s = [dateFormatter formattedTime: value];

  return s;
}

- (NSString *) formattedAptEndDate
{
  NSString *s;
  id value;
  
  value = [self newEndDate];
  s = @"";
  
  if (value)
    s = [dateFormatter formattedDate: value];
  
  return s;
}

- (NSString *) formattedAptEndTime
{
  NSString *s;
  id value;
  
  value = [self newEndDate];
  s = @"";
  
  if (value && (![apt isKindOfClass: [iCalEvent class]] || ![(iCalEvent*)apt isAllDay]))
    s = [dateFormatter formattedTime: value];

  return s;
}

- (void) setupValues
{
  SOGoUser *user;
  id value;
  
  user = [context activeUser];
  viewTZ = [[user userDefaults] timeZone];
  [viewTZ retain];

  values = [NSMutableDictionary new];
  value = [self summary];
  if (!value)
    value = @"";
  
  [values setObject: value forKey: @"Summary"];
}

/* Generate Response */

- (NSString *) getSubject
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSString *) getBody
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSString *) getParticipationRole
{
  if ([[currentAttendee role] caseInsensitiveCompare: @"OPT-PARTICIPANT"] == NSOrderedSame)
    {
      return [self labelForKey: @"Your participation is optional to this event"
                     inContext: context];
    }
  else if ([[currentAttendee role] caseInsensitiveCompare: @"NON-PARTICIPANT"] == NSOrderedSame)
    {
      return [self labelForKey: @"Your participation is not required to this event"
                 inContext: context];
    }

  return [self labelForKey: @"Your participation is required to this event"
                 inContext: context];
}

@end
