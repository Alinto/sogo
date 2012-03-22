/* NSDate+MAPIStore.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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
#import <Foundation/NSTimeZone.h>

#import "NSDate+MAPIStore.h"

#undef DEBUG
#include <talloc.h>
#include <util/time.h>
#include <mapistore/mapistore.h>

static NSCalendarDate *refDate = nil;

@interface NSDate (MAPIStorePossibleMethods)

- (NSTimeZone *) timeZone;

@end

@implementation NSDate (MAPIStoreDataTypes)

static void
_setupRefDate ()
{
  refDate = [[NSCalendarDate alloc]
              initWithYear: 1601 month: 1 day: 1
                      hour: 0 minute: 0 second: 0
                  timeZone: [NSTimeZone timeZoneWithName: @"UTC"]];
}

+ (id) dateFromMinutesSince1601: (uint32_t) minutes
{
  NSCalendarDate *result;

  if (!refDate)
    _setupRefDate ();

  result = [refDate dateByAddingYears: 0 months: 0 days: 0 hours: 0
			      minutes: minutes seconds: 0];

  return result;
}

- (uint32_t) asMinutesSince1601
{
  uint32_t minutes;
  NSInteger offset;

  if (!refDate)
    _setupRefDate ();

  if ([self respondsToSelector: @selector (timeZone)])
    offset = [[self timeZone] secondsFromGMT];
  else
    offset = 0;
  minutes = (uint32_t) (([self timeIntervalSinceDate: refDate] + offset) / 60);

  return minutes;
}

+ (id) dateFromFileTime: (const struct FILETIME *) timeValue
{
  NSCalendarDate *result;
  uint64_t interval;

  if (!refDate)
    _setupRefDate ();

  interval = ((uint64_t) timeValue->dwHighDateTime << 32
              | timeValue->dwLowDateTime);
  result = [[NSCalendarDate alloc]
             initWithTimeInterval: (NSTimeInterval) interval / 10000000
                        sinceDate: refDate];
  [result autorelease];

  return result;
}

- (struct FILETIME *) asFileTimeInMemCtx: (void *) memCtx
{
  struct FILETIME *timeValue;
  uint64_t interval;

  if (!refDate)
    _setupRefDate ();

  interval = (((uint64_t) [self timeIntervalSinceDate: refDate]) * 10000000);
  timeValue = talloc_zero (memCtx, struct FILETIME);
  timeValue->dwLowDateTime = (uint32_t) (interval & 0xffffffff);
  timeValue->dwHighDateTime = (uint32_t) ((interval >> 32) & 0xffffffff);
  
  return timeValue;
}

- (BOOL) isNever /* occurs on 4500-12-31 */
{
  NSCalendarDate *calDate;

  if ([self isKindOfClass: [NSCalendarDate class]])
    calDate = (NSCalendarDate *) self;
  else
    calDate = [NSCalendarDate dateWithTimeIntervalSince1970:
                                [self timeIntervalSince1970]];

  return [calDate yearOfCommonEra] == 4500;
}

@end
