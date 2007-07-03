/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id: iCalRepeatableEntityObject+OCS.m 617 2005-03-01 17:08:11Z znek $

#include "iCalRepeatableEntityObject+OCS.h"
#include "common.h"

@implementation iCalRepeatableEntityObject (OCS)

- (NSArray *) _indexedRules: (NSArray *) rules
{
  NSMutableArray *ma;
  unsigned int i, count;
  NSString *valuesString;

  ma = nil;
  count = [rules count];
  if (count > 0)
    {
      ma = [NSMutableArray arrayWithCapacity:count];
      for (i = 0; i < count; i++)
	{
	  iCalRecurrenceRule *rule;
	  
	  rule = [rules objectAtIndex:i];
#warning we could return an NSArray instead and feed it as such to the iCalRecurrenceRule in SOGoAppointmentFolder...
	  valuesString = [[rule values] componentsJoinedByString: @";"];
	  [ma addObject: valuesString];
	}
    }

  return ma;
}

- (NSString *) cycleInfo
{
  NSArray *rules;
  NSString *value;
  NSMutableDictionary *cycleInfo;

  if ([self isRecurrent])
    {
      cycleInfo = [NSMutableDictionary dictionaryWithCapacity: 3];

      /* rules */
      rules = [self _indexedRules: [self recurrenceRules]];
      if (rules)
	[cycleInfo setObject: rules forKey: @"rules"];
      
      rules = [self _indexedRules: [self exceptionRules]];
      if (rules)
	[cycleInfo setObject: rules forKey: @"exRules"];
      
      rules = [self _indexedRules: [self exceptionDates]];
      if (rules)
	[cycleInfo setObject: rules forKey: @"exDates"];

      value = [cycleInfo description];
    }
  else
    value = nil;

  return value;
}
@end
