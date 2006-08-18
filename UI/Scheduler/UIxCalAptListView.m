/* UIxCalAptListView.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse groupe conseil
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

#import <Foundation/NSDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <Appointments/SOGoAppointmentFolder.h>

#import <SOGoUI/SOGoDateFormatter.h>

#import "UIxCalAptListView.h"

@implementation UIxCalAptListView

// - (id) init
// {
//   if ((self = [super init]))
//     {
//       allAppointments = nil;
//     }

//   return self;
// }

- (void) setCurrentAppointment: (NSDictionary *) apt
{
  currentAppointment = apt;
}

- (NSDictionary *) currentAppointment
{
  return currentAppointment;
}

- (NSCalendarDate *) startDate
{
  return [NSCalendarDate dateWithTimeIntervalSince1970: 0];
}

- (NSCalendarDate *) endDate
{
  return [NSCalendarDate dateWithTimeIntervalSince1970: 0x7fffffff];
}

- (SOGoDateFormatter *) itemDateFormatter
{
  SOGoDateFormatter *fmt;
  
  fmt = [[SOGoDateFormatter alloc] initWithLocale: [self locale]];
  [fmt autorelease];
  [fmt setFullWeekdayNameAndDetails];

  return fmt;
}

- (NSString *) currentStartTime
{
  NSCalendarDate *date;

  date = [NSCalendarDate dateWithTimeIntervalSince1970:
                           [[currentAppointment objectForKey: @"startdate"]
                             intValue]];

  return [[self itemDateFormatter] stringForObjectValue: date];
}

- (NSString *) currentEndTime
{
  NSCalendarDate *date;

  date = [NSCalendarDate dateWithTimeIntervalSince1970:
                           [[currentAppointment objectForKey: @"enddate"]
                             intValue]];

  return [[self itemDateFormatter] stringForObjectValue: date];
}

- (NSString *) currentLocation
{
  return [currentAppointment objectForKey: @"location"];
}

@end
