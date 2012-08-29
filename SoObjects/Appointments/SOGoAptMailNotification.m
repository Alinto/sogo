/*
  Copyright (C) 2006-2012 Inverse inc.
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

#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSTimeZone.h>

#import <NGObjWeb/WOActionResults.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>

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
    }

  return self;
}

- (void) dealloc
{
  [values release];
  [apt release];
  [previousApt release];
  [organizerName release];
  [viewTZ release];
  [oldStartDate release];
  [newStartDate release];
  [oldEndDate release];
  [newEndDate release];
  [dateFormatter release];
  [super dealloc];
}

- (iCalEvent *) apt
{
  return apt;
}

- (void) setApt: (iCalEvent *) theApt
{
  ASSIGN (apt, theApt);
}

- (iCalEvent *) previousApt
{
  return previousApt;
}

- (void) setPreviousApt: (iCalEvent *) theApt
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
      ASSIGN (oldEndDate, [[self previousApt] endDate]);
      [oldEndDate setTimeZone: viewTZ];
    }
  return oldEndDate;
}

- (NSCalendarDate *) newEndDate
{
  if (!newEndDate)
    {
      ASSIGN (newEndDate, [[self apt] endDate]);
      [newEndDate setTimeZone: viewTZ];
    }
  return newEndDate;
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
  
  if (value && ![apt isAllDay])
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
  
  if (value && ![apt isAllDay])
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

@end
