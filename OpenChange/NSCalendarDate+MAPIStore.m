/* NSCalendarDate+MAPIStore.m - this file is part of SOGo
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

#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>

#import "NSCalendarDate+MAPIStore.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <talloc.h>

@implementation NSCalendarDate (MAPIStoreDataTypes)

- (struct FILETIME *) asFileTimeInMemCtx: (void *) memCtx
{
  static NSCalendarDate *refDate = nil;
  struct FILETIME *timeValue;
  NSTimeZone *utc;
  uint64_t interval;

  if (!refDate)
    {
      utc = [NSTimeZone timeZoneWithName: @"UTC"];
      refDate = [NSCalendarDate dateWithYear: 1601 month: 1 day: 1
                                        hour: 0 minute: 0 second: 0
                                    timeZone: utc];
      [refDate retain];
    }
  interval = (((uint64_t) [self timeIntervalSinceDate: refDate]) * 10000000);
  timeValue = talloc_zero(memCtx, struct FILETIME);
  timeValue->dwLowDateTime = (uint32_t) (interval & 0xffffffff);
  timeValue->dwHighDateTime = (uint32_t) ((interval >> 32) & 0xffffffff);
  
  return timeValue;
}

@end
