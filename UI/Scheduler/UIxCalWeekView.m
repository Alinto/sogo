/* UIxCalWeekView.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse inc.
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
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSCalendarDate+misc.h>

#import <EOControl/EOQualifier.h>

#import <SoObjects/SOGo/SOGoUser.h>

#include "UIxCalWeekView.h"

@implementation UIxCalWeekView

- (NSCalendarDate *) startDate
{
  NSCalendarDate *date;

  date = [[context activeUser] firstDayOfWeekForDate: [super startDate]];

  return [date beginOfDay];
}

- (NSCalendarDate *) endDate
{
  unsigned offset;
    
  if ([self shouldDisplayWeekend])
    offset = 7;
  else
    offset = 5;

  return [[[self startDate] dateByAddingYears:0 months:0 days:offset
                            hours:0 minutes:0 seconds:0]
                            endOfDay];
}

// - (NSArray *) appointments
// {
//   return [self fetchCoreAppointmentsInfos];
// }

/* URLs */

- (NSDictionary *) weekBeforePrevWeekQueryParameters
{
  return [self _dateQueryParametersWithOffset: -14];
}

- (NSDictionary *) prevWeekQueryParameters
{
  return [self _dateQueryParametersWithOffset: -7];
}

- (NSDictionary *) nextWeekQueryParameters
{
  return [self _dateQueryParametersWithOffset: 7];
}

- (NSDictionary *) weekAfterNextWeekQueryParameters
{
  return [self _dateQueryParametersWithOffset: 14];
}

- (NSString *) _weekNumberWithOffsetFromToday: (int) offset
{
  NSCalendarDate *date;
  NSString *format;
  unsigned int weekNbr;
  SOGoUser *user;

  user = [context activeUser];
  date = [[self startDate] dateByAddingYears: 0 months: 0
			   days: (offset * 7) + 6
			   hours: 0 minutes: 0 seconds: 0];
  weekNbr = [user weekNumberForDate: date];
  format = [self labelForKey: @"Week %d"];

  return [NSString stringWithFormat: format, weekNbr];
}

- (NSString *) weekBeforeLastWeekName
{
  return [self _weekNumberWithOffsetFromToday: -2];
}

- (NSString *) lastWeekName
{
  return [self _weekNumberWithOffsetFromToday: -1];
}

- (NSString *) currentWeekName
{
  return [self _weekNumberWithOffsetFromToday: 0];
}

- (NSString *) nextWeekName
{
  return [self _weekNumberWithOffsetFromToday: 1];
}

- (NSString *) weekAfterNextWeekName
{
  return [self _weekNumberWithOffsetFromToday: 2];
}

@end /* UIxCalWeekView */
