/*
  Copyright (C) 2004 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id: UIxCalWeekListview.m 707 2005-07-08 15:48:48Z znek $

#include "UIxCalWeekView.h"

@interface UIxCalWeekListview : UIxCalWeekView
{
  NSArray *uids;
  id currentUid;
  int column;
}

- (int)columnsPerDay;

@end

#include "common.h"
#include <NGExtensions/NGCalendarDateRange.h>
#include <SOGo/AgenorUserManager.h>
#include <SOGoUI/SOGoAptFormatter.h>
#include "SoObjects/Appointments/SOGoAppointmentFolder.h"

@implementation UIxCalWeekListview

- (void)dealloc {
  [self->uids release];
  [self->currentUid release];
  [super dealloc];
}

/* fetching */

/* NOTE: this fetches coreInfos instead of overviewInfos
 * as is done in the superclass!
 */
// - (NSArray *)fetchCoreInfos {
//   if (!self->appointments) {
//     id             folder;
//     NSCalendarDate *sd, *ed;
    
//     folder             = [self clientObject];
//     sd                 = [self startDate];
//     ed                 = [self endDate];
//     [self setAppointments: [folder fetchCoreAppointmentsInfos]];
//   }
//   return self->appointments;
// }

/* accessors */

- (NSArray *)uids {
  if(!self->uids) {
    self->uids = [[[[self clientObject] calendarUIDs]
                     sortedArrayUsingSelector:@selector(compareAscending:)]
                     retain];
  }
  return self->uids;
}

- (void)setCurrentUid:(id)_currentUid {
  ASSIGN(self->currentUid, _currentUid);
}
- (id)currentUid {
  return self->currentUid;
}

/* column corresponds to the current day/hour */
- (void)setColumn:(int)_column {
  unsigned dayOfWeek, hour;
  NSCalendarDate *date;

  dayOfWeek = _column / [self columnsPerDay];
  hour      = _column % [self columnsPerDay];

  date = [[self startDate] dateByAddingYears:0 months:0 days:dayOfWeek];
  date = [date hour:hour minute:0];
  /* let's reuse currentDay, although this isn't named too accurately */
  [self setCurrentDay:date];
  self->column = _column;
}
- (int)column {
  return self->column;
}

/* columns */

- (int)columnsPerDay {
  return 24;
}

- (NSArray *)columns {
  static NSMutableArray *columns = nil;
  
  if(!columns) {
    unsigned i, count;
    
    if([self shouldDisplayWeekend])
      count = [self columnsPerDay] * 7;
    else
      count = [self columnsPerDay] * 5;
    
    columns = [[NSMutableArray alloc] initWithCapacity:count];
    for(i = 0; i < count; i++) {
      [columns addObject:[NSNumber numberWithInt:i]];
    }
  }
  return columns;
}

/* tests */

/* row is active, if currentUid is participant of apt */
- (BOOL)isRowActive {
  AgenorUserManager *um;
  NSString *mailChunk;
  NSString *currentMail;

  um = [AgenorUserManager sharedUserManager];
  currentMail = [um getEmailForUID:self->currentUid];
  mailChunk = [self->appointment valueForKey:@"partmails"];
  if([mailChunk rangeOfString:currentMail].length > 0)
    return YES;
  return NO;
}

/* item is active, if apt's dateRange intersects the range
   of the current column (currentDay is set to be this date) */
- (BOOL)isItemActive {
  NSCalendarDate *dateStart, *dateEnd, *aptStart, *aptEnd;
  NGCalendarDateRange *dateRange, *aptRange;

  dateStart = [self currentDay];
  dateEnd   = [dateStart dateByAddingYears:0 months:0 days:0
                                     hours:1 minutes:0 seconds:0];
  dateRange = [NGCalendarDateRange calendarDateRangeWithStartDate:dateStart
                                                          endDate:dateEnd];
  aptStart = [self->appointment valueForKey:@"startDate"];
  aptEnd   = [self->appointment valueForKey:@"endDate"];
  aptRange = [NGCalendarDateRange calendarDateRangeWithStartDate:aptStart
                                                         endDate:aptEnd];
  return [dateRange doesIntersectWithDateRange:aptRange];
}

/* descriptions */

- (void)configureFormatters {
  [super configureFormatters];
  [self->aptFormatter setTitleOnly];
  [self->privateAptFormatter setPrivateTitleOnly];
}

- (NSString *)cnForCurrentUid {
  return [[AgenorUserManager sharedUserManager] getCNForUID:self->currentUid];
}

/* style sheet */

- (NSString *)titleStyle {
  if([self->currentDay isToday])
    return @"weekoverview_title_hilite";
  return @"weekoverview_title";
}

@end /* UIxCalWeekListview */
