/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#warning this module should be cleaned up and \
  merged with NSCalendarDate+NGCards

#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>

#import <NGExtensions/NSCalendarDate+misc.h>

#import "NSCalendarDate+ICal.h"

static NSTimeZone *gmt = nil;
static inline void _setupGMT(void) {
  if (gmt == nil)
    gmt = [[NSTimeZone timeZoneWithAbbreviation:@"GMT"] retain];
}

@implementation NSCalendarDate(iCalRepresentation)

/* represention */

static NSString *gmtcalfmt = @"%Y%m%dT%H%M%SZ";

- (NSString *)icalStringInGMT {
  NSTimeZone *oldtz;
  NSString   *s;
  _setupGMT();
  
  /* set GMT as timezone */
  oldtz = [[self timeZone] retain];
  if (oldtz == gmt) {
    [oldtz release];
    oldtz = nil;
  }
  else {
    [self setTimeZone:gmt];
  }
  
  /* calc string */
  s = [self descriptionWithCalendarFormat:gmtcalfmt];
  
  /* restore old timezone */
  if (oldtz) {
    [self setTimeZone:oldtz];
    [oldtz release];
  }
  
  return s;
}

- (NSString *)icalStringWithTimeZone:(NSTimeZone *)_tz {
  _setupGMT();
  
  if (_tz == gmt || _tz == nil)
    return [self icalStringInGMT];
  else if ([_tz isEqual:gmt])
    return [self icalStringInGMT];
  else {
    /* not in GMT */
    //NSLog(@"WARNING(%s): arbitary timezones not supported yet: %@",
    //      __PRETTY_FUNCTION__, _tz);
    return [self icalStringInGMT];
  }
}

- (NSString *)icalString {
  _setupGMT();
  return [self icalStringWithTimeZone:gmt];
}

@end /* NSDate(ICalValue) */


#ifndef ABS
#define ABS(a) ((a) < 0 ? -(a) : (a))
#endif

@implementation NSCalendarDate (iCalRecurrenceCalculatorExtensions)

- (unsigned)yearsBetweenDate:(NSCalendarDate *)_date {
  return ABS([self yearOfCommonEra] - [_date yearOfCommonEra]);
}

- (unsigned)monthsBetweenDate:(NSCalendarDate *)_date {
  NSCalendarDate     *start, *end;
  NSComparisonResult order;
  int                yDiff;
  
  order = [self compare:_date];
  if (order == NSOrderedSame)
    return 0;
  else if (order == NSOrderedAscending) {
    start = self;
    end   = _date;
  }
  else {
    start = _date;
    end   = self;
  }
  yDiff = [end yearOfCommonEra] - [start yearOfCommonEra];
  if (yDiff > 0) {
    unsigned monthsRemaining, monthsToGo;
    
    monthsRemaining = 12 - [start monthOfYear];
    monthsToGo      = [end monthOfYear];
    yDiff          -= 1;
    return monthsRemaining + monthsToGo + (12 * yDiff);
  }
  /* start and end in same year, calculate plain diff */
  return [end monthOfYear] - [start monthOfYear];
}

- (unsigned)daysBetweenDate:(NSCalendarDate *)_date {
  return ABS([self julianNumber] - [_date julianNumber]);
}
@end /* NSCalendarDate (iCalRecurrenceCalculatorExtensions) */
