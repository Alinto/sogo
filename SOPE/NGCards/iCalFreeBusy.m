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

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>

#import "iCalDateTime.h"
#import "NSCalendarDate+NGCards.h"

#import "iCalFreeBusy.h"

@implementation iCalFreeBusy

- (Class) classForTag: (NSString *) classTag
{
  Class tagClass;

  if ([classTag isEqualToString: @"DTEND"])
    tagClass = [iCalDateTime class];
  else if ([classTag isEqualToString: @"FREEBUSY"])
    tagClass = [CardElement class];
  else
    tagClass = [super classForTag: classTag];

  return tagClass;
}

/* accessors */
- (void) setEndDate: (NSCalendarDate *) newEndDate
{
  [(iCalDateTime *) [self uniqueChildWithTag: @"dtend"]
		    setDateTime: newEndDate];
}

- (NSCalendarDate *) endDate
{
  return [(iCalDateTime *) [self uniqueChildWithTag: @"dtend"]
			   dateTime];
}

- (BOOL) hasEndDate
{
  return ([[self childrenWithTag: @"dtend"] count] > 0);
}

- (void) fillStartDate: (NSCalendarDate **) startDate
	    andEndDate: (NSCalendarDate **) endDate
{
  if ([self hasStartDate])
    *startDate = [self startDate];
  else
    *startDate = nil;

  if ([self hasEndDate])
    *endDate = [self endDate];
  else
    *endDate = nil;
}

- (NSString *) _freeBusyTypeString: (iCalFreeBusyType) type
{
  NSString *typeString;

  switch (type)
    {
    case iCalFBBusy:
      typeString = @"BUSY";
      break;
    case iCalFBFree:
      typeString = @"FREE";
      break;
    case iCalFBBusyUnavailable:
      typeString = @"BUSY-UNAVAILABLE";
      break;
    default:
      typeString = @"BUSY-TENTATIVE";
    }

  return typeString;
}

- (void) addFreeBusyFrom: (NSCalendarDate *) start
                      to: (NSCalendarDate *) end
                    type: (iCalFreeBusyType) type
{
  CardElement *freeBusyElement;
  NSString *value;
  NSCalendarDate *utcStart, *utcEnd;
  NSTimeZone *uTZ;

  uTZ = [NSTimeZone timeZoneWithAbbreviation: @"GMT"];
  utcStart = [start copy];
  utcEnd = [end copy];
  [utcStart setTimeZone: uTZ];
  [utcEnd setTimeZone: uTZ];

  value = [NSString stringWithFormat: @"%@Z/%@Z",
                    [utcStart iCalFormattedDateTimeString],
                    [utcEnd iCalFormattedDateTimeString]];
  freeBusyElement = [CardElement simpleElementWithTag: @"freebusy"
                                 value: value];
  [freeBusyElement addAttribute: @"fbtype"
                   value: [self _freeBusyTypeString: type]];
  [self addChild: freeBusyElement];

  [utcStart release];
  [utcEnd release];
}

/* ical typing */

- (NSString *) entityName
{
  return @"vfreebusy";
}

@end /* iCalFreeBusy */
