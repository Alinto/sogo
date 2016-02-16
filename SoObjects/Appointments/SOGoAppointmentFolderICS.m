 /* SOGoAppointmentFolderICS.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2012 Inverse inc.
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

#import <Foundation/NSString.h>

#import <NGCards/iCalCalendar.h>

#import "SOGoAppointmentFolderICS.h"

@implementation SOGoAppointmentFolderICS

- (NSString *) contentAsString
{
  iCalCalendar *cal;
  CardElement *e;
  NSString *s;

  cal = [self contentCalendar];
  
  e = [CardElement simpleElementWithTag: @"x-wr-calname"
                                  value: [self displayName]];
  [cal addChild: e];
  s = [cal versitString];
  [cal removeChild: e];

  return s;
}

- (NSString *) davContentType
{
  return @"text/calendar";
}

@end
