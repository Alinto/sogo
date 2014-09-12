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

#import <Foundation/NSString.h>

#import "NSCalendarDate+NGCards.h"

#import "iCalDateTime.h"
#import "iCalToDo.h"

#import <NGExtensions/NGCalendarDateRange.h>

@implementation iCalToDo

- (Class) classForTag: (NSString *) classTag
{
  Class tagClass;

  if ([classTag isEqualToString: @"DUE"]
      || [classTag isEqualToString: @"COMPLETED"])
    tagClass = [iCalDateTime class];
  else if ([classTag isEqualToString: @"PERCENT-COMPLETE"])
    tagClass = [CardElement class];
  else
    tagClass = [super classForTag: classTag];

  return tagClass;
}

/* accessors */

- (void) setPercentComplete: (NSString *) _value
{
  [[self uniqueChildWithTag: @"percent-complete"] setSingleValue: _value
                                                          forKey: @""];
}

- (NSString *) percentComplete
{
  return [[self uniqueChildWithTag: @"percent-complete"]
           flattenedValuesForKey: @""];
}

- (void) setDue: (NSCalendarDate *) newDueDate
{
  [(iCalDateTime *) [self uniqueChildWithTag: @"due"]
		    setDateTime: newDueDate];
}

- (NSCalendarDate *) due
{
  return [(iCalDateTime *) [self uniqueChildWithTag: @"due"]
			   dateTime];
}

- (void) setCompleted: (NSCalendarDate *) newCompletedDate
{
  [(iCalDateTime *) [self uniqueChildWithTag: @"completed"]
		    setDateTime: newCompletedDate];
  if (newCompletedDate)
    [self setStatus: @"COMPLETED"];
  else
    [self setStatus: @"IN-PROCESS"];
}

- (NSCalendarDate *) completed
{
  return [(iCalDateTime *) [self uniqueChildWithTag: @"completed"]
			   dateTime];
}

/* ical typing */

- (NSString *) entityName
{
  return @"vtodo";
}

// /* descriptions */

// - (NSString *)description {
//   NSMutableString *ms;

//   ms = [NSMutableString stringWithCapacity:128];
//   [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

//   if (uid)       [ms appendFormat:@" uid=%@", uid];
//   if (startDate) [ms appendFormat:@" start=%@", startDate];
//   if (due)       [ms appendFormat:@" due=%@", due];
//   if (priority)  [ms appendFormat:@" pri=%@", priority];

//   if (completed) 
//     [ms appendFormat:@" completed=%@", completed];
//   if (percentComplete) 
//     [ms appendFormat:@" complete=%@", percentComplete];
//   if (accessClass) 
//     [ms appendFormat:@" class=%@", accessClass];
  
//   if (summary)
//     [ms appendFormat:@" summary=%@", summary];

//   [ms appendString:@">"];
//   return ms;
// }

- (NSCalendarDate *) lastPossibleRecurrenceStartDate
{
  NGCalendarDateRange *fir;

  if (![self isRecurrent])
    return nil;

  fir = [NGCalendarDateRange calendarDateRangeWithStartDate: [self startDate]
                             endDate: [self due]];

  return [self lastPossibleRecurrenceStartDateUsingFirstInstanceCalendarDateRange: fir];
}

@end /* iCalToDo */
