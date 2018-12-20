/*

Copyright (c) 2014, Inverse inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Inverse inc. nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/
#import "iCalTimeZone+ActiveSync.h"

#include <Foundation/NSArray.h>
#include <Foundation/NSCalendarDate.h>
#include <Foundation/NSString.h>

#import <NGCards/iCalByDayMask.h>
#import <NGCards/iCalTimeZonePeriod.h>

#include "NSData+ActiveSync.h"

struct SYSTEMTIME {
  uint16_t wYear;
  uint16_t wMonth;
  uint16_t wDayOfWeek;
  uint16_t wDay;
  uint16_t wHour;
  uint16_t wMinute;
  uint16_t wSecond;
  uint16_t wMilliseconds;
};

@interface iCalTimeZonePeriod (ActiveSync)

- (void) _fillTZDate: (struct SYSTEMTIME *) tzData;

@end

@implementation iCalTimeZonePeriod (ActiveSync)

//
// FIXME - combine with iCalTimeZone+MAPIStore.m
//
- (void) _fillTZDate: (struct SYSTEMTIME *) tzData
{
  iCalRecurrenceRule *rrule;
  NSArray *byMonth;
  iCalByDayMask *mask;
  NSCalendarDate *dateValue;

  rrule = [self recurrenceRule];
  byMonth = [rrule byMonth];
  if ([byMonth count] > 0)
    {
      tzData->wYear = 0;
      tzData->wMonth = [[byMonth objectAtIndex: 0] intValue];
      mask = [rrule byDayMask];
      tzData->wDayOfWeek = [mask firstDay];
      tzData->wDay = ([mask firstOccurrence] == -1) ? 5 : [mask firstOccurrence];

      dateValue = [self startDate];

      if (![dateValue hourOfDay])
        {
          if ([mask firstDay]-1 < 0)
            tzData->wDayOfWeek = 6;
          else
            tzData->wDayOfWeek = [mask firstDay]-1;

          tzData->wHour = 23;
          tzData->wMinute = 59;
          tzData->wSecond = 59;
          tzData->wMilliseconds = 999;
        }
      else
       {
          tzData->wDayOfWeek = [mask firstDay];

          tzData->wHour = [dateValue hourOfDay];
          tzData->wMinute = [dateValue minuteOfHour];
          tzData->wSecond = [dateValue secondOfMinute];
          tzData->wMilliseconds = 0;
       }
    }
}

@end

@implementation iCalTimeZone (ActiveSync)

//
// FIXME - combine with iCalTimeZone+MAPIStore.m
//
- (iCalTimeZonePeriod *) _mostRecentPeriodWithName: (NSString *) periodName
{
  NSArray *periods;
  iCalTimeZonePeriod *period;
  NSUInteger max;

  periods = [self childrenWithTag: periodName];
  max = [periods count];
  if (max > 0)
    {
      periods = [periods sortedArrayUsingSelector: @selector (compare:)];
      period = (iCalTimeZonePeriod *) [periods objectAtIndex: (max - 1)];
    }
  else
    period = nil;

  return period;
}


- (NSString *) activeSyncRepresentationInContext: (WOContext *) context
{
  iCalTimeZonePeriod *period;
  NSMutableData *bytes;

  uint32_t lBias;
  uint32_t lStandardBias;
  uint32_t lDaylightBias;
  //uint16_t wStandardYear;
  struct SYSTEMTIME stStandardDate;
  //uint16_t wDaylightYear;
  struct SYSTEMTIME stDaylightDate = {0,0,0,0,0,0,0,0};

  char standardName[64], daylightName[64];

  bytes = [NSMutableData data];
  
  memset(standardName, 0, 64);
  memset(daylightName, 0, 64);
  lStandardBias = 0;

  period = [self _mostRecentPeriodWithName: @"STANDARD"];
  lBias = -[period secondsOffsetFromGMT] / 60;
  [period _fillTZDate: &stStandardDate];

  period = [self _mostRecentPeriodWithName: @"DAYLIGHT"];  
  if (!period)
    {
      stStandardDate.wMonth = 0;
      lDaylightBias = 0;
    }
  else
    {
      lDaylightBias = (uint32_t) -([period secondsOffsetFromGMT] / 60) - lBias;
      [period _fillTZDate: &stDaylightDate];
      //wStandardYear = stStandardDate.wYear;
      //wDaylightYear = stDaylightDate.wYear;
    }

  // We build the timezone
  [bytes appendBytes: &lBias  length: 4];
  [bytes appendBytes: standardName  length: 64];
  [bytes appendBytes: &stStandardDate  length: 16];
  [bytes appendBytes: &lStandardBias  length: 4];
  [bytes appendBytes: daylightName  length: 64];
  [bytes appendBytes: &stDaylightDate  length: 16];
  [bytes appendBytes: &lDaylightBias  length: 4];
  
  return [bytes activeSyncRepresentationInContext: context];
}

@end
