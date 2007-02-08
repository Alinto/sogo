/*
 Copyright (C) 2000-2004 SKYRIX Software AG
 
 This file is part of OGo
 
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
// $Id: UIxCalInlineAptView.m 885 2005-07-21 16:41:34Z znek $

#import <math.h>

#import <Foundation/NSDictionary.h>

#import <NGObjWeb/NGObjWeb.h>

@interface UIxCalInlineAptView : WOComponent
{
  NSDictionary *appointment;
  id formatter;
  id tooltipFormatter;
  id url;
  id style;
  id queryDictionary;
  id referenceDate;
  int dayStartHour;
  int dayEndHour;
  BOOL canAccess;
}

@end

#include "common.h"
#include <SOGoUI/SOGoAptFormatter.h>
#include <SOGo/SOGoUser.h>
#include <NGObjWeb/WOContext+SoObjects.h>

@implementation UIxCalInlineAptView

- (id) init
{
  if ((self = [super init]))
    {
      dayStartHour = 0;
      dayEndHour = 24;
      appointment = nil;
    }

  return self;
}

- (void) dealloc
{
  [appointment release];
  [formatter release];
  [tooltipFormatter release];
  [url release];
  [style release];
  [queryDictionary release];
  [referenceDate release];
  [super dealloc];
}

- (void) setAppointment: (NSDictionary *) _appointment
{
  ASSIGN(appointment, _appointment);
}

- (NSDictionary *) appointment
{
  return appointment;
}

- (void) setDayStartHour: (unsigned int) anHour
{
  dayStartHour = anHour;
}

- (void) setDayEndHour: (unsigned int) anHour
{
  dayEndHour = anHour;
}

- (void) setFormatter: (id) _formatter
{
  ASSIGN(formatter, _formatter);
}

- (id) formatter
{
  return formatter;
}

- (void) setTooltipFormatter: (id) _tooltipFormatter
{
  ASSIGN(tooltipFormatter, _tooltipFormatter);
}

- (id) tooltipFormatter
{
  return tooltipFormatter;
}

- (void) setUrl: (id) _url
{
  ASSIGN(url, _url);
}

- (id) url
{
  return url;
}

- (void) setStyle: (id) _style 
{
  NSMutableString *ms;
  NSNumber *prio;
  NSString *s;
  NSString *email;

  if (_style)
    ms = [NSMutableString stringWithString: _style];
  else
    ms = (NSMutableString *)[NSMutableString string];

  if ((prio = [appointment valueForKey:@"priority"])) {
    [ms appendFormat:@" apt_prio%@", prio];
  }
  email = [[[self context] activeUser] email];
  if ((s = [appointment valueForKey:@"orgmail"])) {
    if ([s rangeOfString:email].length > 0) {
      [ms appendString:@" apt_organizer"];
    }
    else {
      [ms appendString:@" apt_other"];
    }
  }
  if ((s = [appointment valueForKey:@"partmails"])) {
    if ([s rangeOfString:email].length > 0) {
      [ms appendString:@" apt_participant"];
    }
    else {
      [ms appendString:@" apt_nonparticipant"];
    }
  }
  ASSIGNCOPY(style, ms);
}

- (id)style {
  return style;
}

- (void) setQueryDictionary: (id) _queryDictionary
{
  ASSIGN(queryDictionary, _queryDictionary);
}

- (id) queryDictionary
{
  return queryDictionary;
}

- (void) setReferenceDate: (id) _referenceDate
{
  ASSIGN(referenceDate, _referenceDate);
}

- (id) referenceDate
{
  return referenceDate;
}

- (void) setCanAccess: (BOOL) _canAccess
{
  canAccess = _canAccess;
}

- (BOOL) canAccess
{
  return canAccess;
}

- (NSString *) displayClasses
{
  NSTimeInterval secondsStart, secondsEnd, delta;
  NSCalendarDate *startDate;
  int deltaStart, deltaLength;

  startDate = [appointment objectForKey: @"startDate"];
  secondsStart = [startDate timeIntervalSince1970];
  secondsEnd = [[appointment objectForKey: @"endDate"] timeIntervalSince1970];
  delta = (secondsEnd - [startDate timeIntervalSince1970]) / 60;
  deltaLength = delta / 15;
  if (((int) delta % 15) > 0)
    deltaLength += 1;

  deltaStart = (([startDate hourOfDay] * 60 + [startDate minuteOfHour]
                 - dayStartHour * 60) / 15);

  return [NSString stringWithFormat: @"appointment ownerIs%@ starts%d lasts%d",
                   [appointment objectForKey: @"owner"],
                   deltaStart, deltaLength, [startDate dayOfWeek]];
}

- (NSString *) innerDisplayClasses
{
  return [NSString stringWithFormat: @"appointmentInside ownerIs%@",
                   [appointment objectForKey: @"owner"]];
}

- (NSString *) displayStyle
{
  NSCalendarDate *startDate, *endDate, *dayStart, *dayEnd;
  int sSeconds, eSeconds, deltaMinutes;
  unsigned int height;
  NSTimeZone *uTZ;

  uTZ = [referenceDate timeZone];
  dayStart = [referenceDate beginOfDay];
  dayEnd = [referenceDate endOfDay];

  sSeconds = [[appointment objectForKey: @"startdate"] intValue];
  eSeconds = [[appointment objectForKey: @"enddate"] intValue];
  startDate = [NSCalendarDate dateWithTimeIntervalSince1970: sSeconds];
  [startDate setTimeZone: uTZ];
  if ([startDate earlierDate: dayStart] == startDate)
    startDate = dayStart;
  endDate = [NSCalendarDate dateWithTimeIntervalSince1970: eSeconds];
  [endDate setTimeZone: uTZ];
  if ([endDate earlierDate: dayEnd] == dayEnd)
    endDate = dayEnd;

  deltaMinutes = (([endDate hourOfDay] - [startDate hourOfDay]) * 60
                  + [endDate minuteOfHour] - [startDate minuteOfHour]);
  height = ceil(deltaMinutes / 15) * 25;

  return [NSString stringWithFormat: @"height: %d%%;", height];
}

/* helpers */

- (NSString *) title
{
  return [formatter stringForObjectValue: appointment
                    referenceDate: [self referenceDate]];
}

- (NSString *) tooltip
{
  return [tooltipFormatter stringForObjectValue: appointment
                           referenceDate: [self referenceDate]];
}

@end
