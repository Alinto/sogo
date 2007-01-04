/* SOGoCalendarComponent.m - this file is part of SOGo
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

#import <NGCards/iCalCalendar.h>

#import "SOGoCalendarComponent.h"

@implementation SOGoCalendarComponent

- (id) init
{
  if ((self = [super init]))
    {
      calendar = nil;
    }

  return self;
}

- (void) dealloc
{
  if (calendar)
    [calendar release];
  [super dealloc];
}

- (NSString *) iCalString
{
  // for UI-X appointment viewer
  return [self contentAsString];
}

- (iCalCalendar *) calendar
{
  NSString *iCalString;

  if (!calendar)
    {
      iCalString = [self iCalString];
      if (iCalString)
        {
          calendar = [iCalCalendar parseSingleFromSource: iCalString];
          [calendar retain];
        }
    }

  return calendar;
}

/* raw saving */

- (NSException *)primarySaveContentString:(NSString *)_iCalString {
  return [super saveContentString:_iCalString];
}

- (NSException *)primaryDelete {
  return [super delete];
}

- (NSException *)deleteWithBaseSequence: (int) a
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSException *) delete
{
  return [self deleteWithBaseSequence:0];
}

@end
