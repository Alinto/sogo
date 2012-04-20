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

#import "iCalEvent.h"
#import "iCalTrigger.h"
#import "iCalToDo.h"

#import "NSString+NGCards.h"

@implementation iCalTrigger

/* accessors */

- (void) setValueType: (NSString *) theValue
{
  [self setValue: 0 ofAttribute: @"value" to: theValue];
}

- (NSString *) valueType
{
  return [self value: 0 ofAttribute: @"value"];
}

- (void) setRelationType: (NSString *) theRelationType
{
  [self setValue: 0 ofAttribute: @"related" to: theRelationType];
}

- (NSString *) relationType
{
  return [self value: 0 ofAttribute: @"related"];
}

- (NSCalendarDate *) nextAlarmDate
{
  NSCalendarDate *relationDate, *nextAlarmDate;
  NSString *relation, *triggerValue;
  NSTimeInterval anInterval;
  id grandParent;

  triggerValue = [[self valueType] uppercaseString];
  if ([triggerValue length] == 0)
    triggerValue = @"DURATION";

  if ([triggerValue isEqualToString: @"DURATION"])
    {
      relation = [[self relationType] uppercaseString];

      grandParent = [parent parent];
      if ([relation isEqualToString: @"END"])
        {
          if ([grandParent isKindOfClass: [iCalEvent class]])
            relationDate = [(iCalEvent *) grandParent endDate];
          else
            relationDate = [(iCalToDo *) grandParent due];
        }
      else
        relationDate = [(iCalEntityObject *) grandParent startDate];
	      
      // Compute the next alarm date with respect to the reference date
      if (relationDate)
        {
          anInterval = [[self flattenedValuesForKey: @""]
                         durationAsTimeInterval];
          nextAlarmDate = [relationDate addTimeInterval: anInterval];
        }
    }
  else if ([triggerValue isEqualToString: @"DATE-TIME"])
    nextAlarmDate = [[self flattenedValuesForKey: @""] asCalendarDate];
  else
    nextAlarmDate = nil;

  return nextAlarmDate;
}

@end /* iCalTrigger */
