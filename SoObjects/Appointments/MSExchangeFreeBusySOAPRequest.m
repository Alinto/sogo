/*
  Copyright (C) 2012-2016 Inverse inc.

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
  License along with SOGo; see the file COPYING.  If not, write to the
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
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import "MSExchangeFreeBusySOAPRequest.h"

@implementation MSExchangeFreeBusySOAPRequest

- (id) init
{
  if ((self = [super init]))
    {
      address = nil;
      timeZone = [NSTimeZone timeZoneForSecondsFromGMT: 0];
      [timeZone retain];
      startDate = nil;
      endDate = nil;
      interval = 15;
    }

  return self;
}

- (void) dealloc
{
  [address release];
  [timeZone release];
  [startDate release];
  [endDate release];
  [super dealloc];
}

- (void) setAddress: (NSString *) newAddress
               from: (NSCalendarDate *) newStartDate
                 to: (NSCalendarDate *) newEndDate
{
  ASSIGN(address, newAddress);

  startDate = [NSCalendarDate dateWithYear: [newStartDate yearOfCommonEra]
                                     month: [newStartDate monthOfYear]
                                       day: [newStartDate dayOfMonth]
                                      hour: [newStartDate hourOfDay]
                                    minute: [newStartDate minuteOfHour]
                                    second: [newStartDate secondOfMinute]
                                  timeZone: [newStartDate timeZone]];
  endDate = [NSCalendarDate dateWithYear: [newEndDate yearOfCommonEra]
                                   month: [newEndDate monthOfYear]
                                     day: [newEndDate dayOfMonth]
                                    hour: [newEndDate hourOfDay]
                                  minute: [newEndDate minuteOfHour]
                                  second: [newEndDate secondOfMinute]
                                timeZone: [newEndDate timeZone]];

  [startDate setTimeZone: timeZone];
  [endDate setTimeZone: timeZone];

  [startDate retain];
  [endDate retain];
}

- (NSString *) serverVersion
{
  return @"Exchange2007_SP1";
}

- (NSString *) address
{
  return address;
}

- (NSString *) startTime
{
  return [startDate descriptionWithCalendarFormat: @"%Y-%m-%dT%H:%M:%S"];
}

- (NSString *) endTime
{
  return [endDate descriptionWithCalendarFormat: @"%Y-%m-%dT%H:%M:%S"];
}

- (NSString *) interval
{
  return [NSString stringWithFormat: @"%i", interval];
}

- (NSString *) bias
{
#if 0
  NSTimeZone *userTimeZone;
  NSInteger secs;

  userTimeZone = [[[context activeUser] userDefaults] timeZone];
  secs = [userTimeZone secondsFromGMT];

  return [NSString stringWithFormat: @"%i", (secs/60)];
#else
  return @"0";
#endif
}

@end
