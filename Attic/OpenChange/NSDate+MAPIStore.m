/* NSDate+MAPIStore.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2012 Inverse inc.
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

#import "MAPIStoreTypes.h"
#import "NSDate+MAPIStore.h"

#undef DEBUG
#include <stdbool.h>
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
                  timeZone: utcTZ];
}

+ (NSCalendarDate *) dateFromMinutesSince1601: (uint32_t) minutes
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

+ (NSCalendarDate *) dateFromSystemTime: (struct SYSTEMTIME) date
                            andRuleYear: (uint16_t) rYear
{
  NSCalendarDate *result;
  NSInteger daysToDate;
  NSUInteger firstDayOfWeek, year;

  /* ([MS-OXOCAL] 2.2.1.41.1) When we're provided an absolute date (i.e., it
     happens once), the SYSTEMTIME structure is enough to fill the date.
     When we're parsing a SYSTEMTIME field from a time zone rule, however, a
     relative date can be provided for the peroidicity of its periods. In this
     scenario, the wYear field is empty and we have to use the wYear field in
     the parent rule */
  if (date.wYear != 0)
    year = date.wYear;
  else
    year = rYear;

  /* The wDay field indicates the occurrence of the wDayOfWeek within the month.
     The 5th occurrence means the last one, even if it is the 4th. */
  if (date.wDay < 5)
    {
      result = [[NSCalendarDate alloc] initWithYear: year month: date.wMonth day: 1
                                               hour: date.wHour minute: date.wMinute second: date.wSecond
                                           timeZone: utcTZ];
      [result autorelease];

      firstDayOfWeek = [result dayOfWeek];

      daysToDate = 7 * (date.wDay - 1) + date.wDayOfWeek - firstDayOfWeek;
      if (date.wDayOfWeek < firstDayOfWeek)
        daysToDate += 7;

      result = [result dateByAddingYears: 0 months: 0 days: daysToDate
                                   hours: 0 minutes: 0
                                 seconds: 0];
    }
  else
    {
      result = [[NSCalendarDate alloc] initWithYear: year month: date.wMonth + 1 day: 1
                                               hour: date.wHour minute: date.wMinute second: date.wSecond
                                           timeZone: utcTZ];
      [result autorelease];

      firstDayOfWeek = [result dayOfWeek];

      daysToDate = date.wDayOfWeek - firstDayOfWeek;
      if (date.wDayOfWeek >= firstDayOfWeek)
        daysToDate -= 7;

      result = [result dateByAddingYears: 0 months: 0 days: daysToDate
                                   hours: 0 minutes: 0
                                 seconds: 0];
    }

  return result;
}

@end

NSComparisonResult
NSDateCompare (id date1, id date2, void *ctx)
{
  NSTimeInterval secs1, secs2;
  NSComparisonResult result;

  secs1 = [date1 timeIntervalSince1970];
  secs2 = [date2 timeIntervalSince1970];
  if (secs1 == secs2)
    result = NSOrderedSame;
  else if (secs1 < secs2)
    result = NSOrderedAscending;
  else
    result = NSOrderedDescending;

  return result;
}

