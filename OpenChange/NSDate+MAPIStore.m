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
#include <mapistore/mapistore.h>
#include <talloc.h>

static NSDate *refDate = nil;

@implementation NSDate (MAPIStoreDataTypes)

static void
_setupRefDate()
{
  NSTimeZone *utc;

  utc = [NSTimeZone timeZoneWithName: @"UTC"];
  refDate = [NSCalendarDate dateWithYear: 1601 month: 1 day: 1
                                    hour: 0 minute: 0 second: 0
                                timeZone: utc];
  [refDate retain];
}

+ (id) dateFromFileTime: (struct FILETIME *) timeValue
{
  NSDate *result;
  uint64_t interval;

  if (!refDate)
    _setupRefDate ();

  interval = ((uint64_t) timeValue->dwHighDateTime << 32
              | timeValue->dwLowDateTime);
  result = [[NSDate alloc]
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

@end
