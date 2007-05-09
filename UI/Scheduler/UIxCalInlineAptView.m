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
// $Id: UIxCalInlineAptView.m 1052 2007-05-09 19:35:09Z wolfgang $

#import <math.h>

#import <Foundation/NSDictionary.h>

#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <NGCards/iCalEntityObject.h>
#import <SOGo/SOGoAuthenticator.h>
#import <SOGo/SOGoUser.h>
#import <SOGoUI/SOGoAptFormatter.h>

#import "UIxCalInlineAptView.h"

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
  email = [[context activeUser] primaryEmail];
  s = [appointment valueForKey:@"orgmail"];
  if ([s isNotNull])
    {
      if ([s rangeOfString: email].length > 0)
        [ms appendString:@" apt_organizer"];
      else
        [ms appendString:@" apt_other"];
    }
  s = [appointment valueForKey:@"partmails"];
  if ([s isNotNull])
    {
      if ([s rangeOfString:email].length > 0)
        [ms appendString:@" apt_participant"];
      else
        [ms appendString:@" apt_nonparticipant"];
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

  return [NSString stringWithFormat: @"appointment starts%d lasts%d",
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

- (NSString *) startHour
{
  NSCalendarDate *start;

  start = [appointment objectForKey: @"startDate"];

  return [NSString stringWithFormat: @"%.2d:%.2d",
                   [start hourOfDay], [start minuteOfHour]];
}

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

- (BOOL) _userIsInTheCard: (NSString *) email
{
  NSString *orgMailString, *partMailsString;
  NSArray *partMails;
  BOOL userIsInTheCard;

  orgMailString = [appointment objectForKey: @"orgmail"];
  if ([orgMailString isNotNull] && [orgMailString isEqualToString: email])
    userIsInTheCard = YES;
  else
    {
      partMailsString = [appointment objectForKey: @"partmails"];
      if ([partMailsString isNotNull])
        {
          partMails = [partMailsString componentsSeparatedByString: @"\n"];
          userIsInTheCard = [partMails containsObject: email];
        }
      else
        userIsInTheCard = NO;
    }

  return userIsInTheCard;
}

@end
