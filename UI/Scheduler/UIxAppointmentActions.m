/* UIxAppointmentActions.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
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
#import <Foundation/NSString.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>

#import <NGCards/iCalEvent.h>

#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <Appointments/SOGoAppointmentObject.h>

#import <Common/WODirectAction+SOGo.h>

#import "UIxAppointmentActions.h"

@implementation UIxAppointmentActions

- (WOResponse *) adjustAction
{
  WOResponse *response;
  WORequest *rq;
  SOGoAppointmentObject *co;
  iCalEvent *event;
  NSCalendarDate *start, *newStart, *end, *newEnd;
  NSTimeInterval newDuration;
  SOGoUserDefaults *ud;
  NSString *daysDelta, *startDelta, *durationDelta;
  NSTimeZone *tz;

  rq = [context request];

  daysDelta = [rq formValueForKey: @"days"];
  startDelta = [rq formValueForKey: @"start"];
  durationDelta = [rq formValueForKey: @"duration"];
  if ([daysDelta length] > 0
      || [startDelta length] > 0 || [durationDelta length] > 0)
    {
      co = [self clientObject];
      event = (iCalEvent *) [[self clientObject] occurence];

      ud = [[context activeUser] userDefaults];
      tz = [ud timeZone];
      start = [event startDate];
      [start setTimeZone: tz];
      end = [event endDate];
      [end setTimeZone: tz];

      if ([event isAllDay])
        {
          newStart = [start dateByAddingYears: 0 months: 0
                                         days: [daysDelta intValue]
                                        hours: 0 minutes: 0
                                      seconds: 0];
          newDuration = (((float) abs ([end timeIntervalSinceDate: start])
                          + [durationDelta intValue] * 60)
                         / 86400);
          [event setAllDayWithStartDate: newStart duration: newDuration];
        }
      else
        {
          newStart = [start dateByAddingYears: 0 months: 0
                                         days: [daysDelta intValue]
                                        hours: 0 minutes: [startDelta intValue]
                                      seconds: 0];

          newDuration = ([end timeIntervalSinceDate: start]
                         + [durationDelta intValue] * 60);
          newEnd = [newStart addTimeInterval: newDuration];

          [event setStartDate: newStart];
          [event setEndDate: newEnd];
        }
      [co saveComponent: event];

      response = [self responseWith204];
    }
  else
    response
      = (WOResponse *) [NSException exceptionWithHTTPStatus: 400
                                                     reason: @"missing 'days', 'start' and/or 'duration' parameters"];

    
  return response;
}

@end
