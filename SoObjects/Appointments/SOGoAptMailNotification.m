/*
  Copyright (C) 2000-2005 SKYRIX Software AG
  Copyright (C) 2006-2009 Inverse inc.

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
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/NSString+Utilities.h>

#import "iCalPerson+SOGo.h"
#import "SOGoAptMailNotification.h"

@implementation SOGoAptMailNotification

static NSTimeZone *UTC = nil;

+ (void) initialize
{
  if (!UTC)
    UTC = [[NSTimeZone timeZoneWithAbbreviation: @"UTC"] retain];
}

- (id) init
{
  if ((self = [super init]))
    {
      apt = nil;
      values = nil;
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

- (NSTimeZone *) viewTZ 
{
  if (viewTZ) return viewTZ;
  return UTC;
}
- (void) setViewTZ: (NSTimeZone *) _viewTZ
{
  ASSIGN (viewTZ, _viewTZ);
}

- (NSCalendarDate *) oldStartDate
{
  if (!oldStartDate)
    {
      ASSIGN (oldStartDate, [[self previousApt] startDate]);
      [oldStartDate setTimeZone: [self viewTZ]];
    }
  return oldStartDate;
}

- (NSCalendarDate *) newStartDate
{
  if (!newStartDate)
    {
      ASSIGN (newStartDate, [[self apt] startDate]);
      [newStartDate setTimeZone:[self viewTZ]];
    }
  return newStartDate;
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

/* Helpers */

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

- (void) setupValues
{
  NSDictionary *sentByValues;
  NSString *sentBy, *sentByText;

  values = [NSMutableDictionary new];
  [values setObject: [self summary] forKey: @"Summary"];
  if (organizerName)
    {
      [values setObject: organizerName forKey: @"Organizer"];

      sentBy = [[apt organizer] sentBy];
      if ([sentBy length])
        {
          sentByValues = [NSDictionary dictionaryWithObject: sentBy
                                                     forKey: @"SentBy"];
          sentByText
            = [sentByValues keysWithFormat: [self
                                              labelForKey: @"(sent by %{SentBy})"
                                                inContext: context]];
        }
      else
        sentByText = @"";
      [values setObject: sentByText forKey: @"SentByText"];
    }
}

@end
