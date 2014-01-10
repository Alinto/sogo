/*

Copyright (c) 2014, Inverse inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the Inverse inc. nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/
#import "iCalToDo+ActiveSync.h"

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#include "NSDate+ActiveSync.h"

@implementation iCalToDo (ActiveSync)

- (NSString *) activeSyncRepresentation
{
  NSMutableString *s;
  int v;

  s = [NSMutableString string];

  // Complete
  NSCalendarDate *completed;
  completed = [self completed];
  [s appendFormat: @"<Complete xmlns=\"Tasks:\">%d</Complete>", (completed ? 1 : 0)];
  
  // DateCompleted
  [s appendFormat: @"<DateCompleted xmlns=\"Tasks:\">%@</DateCompleted>", [completed activeSyncRepresentation]];
  
  // Due date
  NSCalendarDate *due;
  due = [self due];
  if (due)
    [s appendFormat: @"<DueDate xmlns=\"Tasks:\">%@</DueDate>", [due activeSyncRepresentation]];
  
  // Importance
  NSString *priority;
  priority = [self priority];
  if ([priority isEqualToString: @"9"])
    v = 0;
  else if ([priority isEqualToString: @"1"])
    v = 2;
  else
    v = 1;
  [s appendFormat: @"<Importance xmlns=\"Tasks:\">%d</Importance>", v];
                    
  // Reminder - FIXME
  [s appendFormat: @"<ReminderSet xmlns=\"Tasks:\">%d</ReminderSet>", 0];
  
  // Sensitivity - FIXME
  [s appendFormat: @"<Sensitivity xmlns=\"Tasks:\">%d</Sensitivity>", 0];
  
  // UTCStartDate - FIXME
  if ([self startDate])
    [s appendFormat: @"<UTCStartDate xmlns=\"Tasks:\">%@</UTCStartDate>", [[self startDate] activeSyncRepresentation]];
  
  // Subject
  [s appendFormat: @"<Subject xmlns=\"Tasks:\">%@</Subject>", [self summary]];

  return s;
}

- (void) takeActiveSyncValues: (NSDictionary *) theValues
{
  id o;

  if ((o = [theValues objectForKey: @"Subject"]))
    [self setSummary: o];
}

@end
