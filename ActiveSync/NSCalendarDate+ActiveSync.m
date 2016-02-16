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
#import "NSCalendarDate+ActiveSync.h"

#import <Foundation/NSString.h>

#define ONE_DAY 86400

@implementation NSCalendarDate (ActiveSync)

//
// See http://msdn.microsoft.com/en-us/library/gg709713(v=exchg.80).aspx for available types
//
+ (NSCalendarDate *) dateFromFilterType: (NSString *) theFilterType
{
  NSCalendarDate *d;

  d = [NSCalendarDate calendarDate];

  if (d)
    {
      int value;
      
      switch ([theFilterType intValue])
        {
        case 1:
          value = ONE_DAY;
          break;
        case 2:
          value = 3 * ONE_DAY;
          break;
        case 3:
          value = 7 * ONE_DAY;
          break;
        case 4:
          value = 14 * ONE_DAY;
          break;
        case 5:
          value = 30 * ONE_DAY;
          break;
        case 6:
          value = 90 * ONE_DAY;
          break;
        case 7:
          value = 180 * ONE_DAY;
          break;
        case 0:
        case 8:
        default:
          return nil;
        }

      return [d initWithTimeIntervalSinceNow: -value];
    }

  return d;
}

@end
