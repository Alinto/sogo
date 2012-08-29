/* EOQualifier+MAPI.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2012 Inverse inc
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

#import <Foundation/NSArray.h>
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSObject+Logs.h>

#import "EOBitmaskQualifier.h"
#import "SOGoMAPIDBObject.h"

#import "EOQualifier+MAPI.h"

@implementation EOQualifier (MAPIStoreRestrictions)

- (BOOL) _evaluateSOGoMAPIDBObject: (NSDictionary *) properties
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (BOOL) evaluateSOGoMAPIDBObject: (SOGoMAPIDBObject *) object
{
  NSDictionary *properties;
  BOOL rc;

  [self logWithFormat: @"evaluating object '%@'", object];

  properties = [object properties];
  rc = [self _evaluateSOGoMAPIDBObject: properties];

  [self logWithFormat: @"  evaluation result: %d", rc];
  
  return rc;
}

@end

@implementation EOAndQualifier (MAPIStoreRestrictionsPrivate)

- (BOOL) _evaluateSOGoMAPIDBObject: (NSDictionary *) properties
{
  NSUInteger i;
  BOOL rc;

  rc = YES;

  for (i = 0; rc && i < count; i++)
    rc = [[qualifiers objectAtIndex: i]
	   _evaluateSOGoMAPIDBObject: properties];
 
  return rc;
}

@end

@implementation EOOrQualifier (MAPIStoreRestrictionsPrivate)

- (BOOL) _evaluateSOGoMAPIDBObject: (NSDictionary *) properties
{
  NSUInteger i;
  BOOL rc;

  rc = NO;

  for (i = 0; !rc && i < count; i++)
    rc = [[qualifiers objectAtIndex: i]
	   _evaluateSOGoMAPIDBObject: properties];
 
  return rc;
}

@end

@implementation EONotQualifier (MAPIStoreRestrictionsPrivate)

- (BOOL) _evaluateSOGoMAPIDBObject: (NSDictionary *) properties
{
  return ![qualifier _evaluateSOGoMAPIDBObject: properties];
}

@end

@implementation EOKeyValueQualifier (MAPIStoreRestrictionsPrivate)

typedef BOOL (*EOComparator) (id, SEL, id);

- (BOOL) _evaluateSOGoMAPIDBObject: (NSDictionary *) properties
{
  id finalKey;
  id propValue;
  EOComparator comparator;

  if ([key isKindOfClass: [NSNumber class]])
    finalKey = key;
  else if ([key isKindOfClass: [NSString class]])
    {
      finalKey = [key stringByTrimmingCharactersInSet: [NSCharacterSet decimalDigitCharacterSet]];
      if ([finalKey length] > 0)
        finalKey = key;
      else
        finalKey = [NSNumber numberWithInt: [key intValue]];
    }
  else
    finalKey = @"";

  propValue = [properties objectForKey: finalKey];
  comparator = (EOComparator) [propValue methodForSelector: operator];

  return (comparator ? comparator (propValue, operator, value) : NO);
}

@end

@implementation EOBitmaskQualifier (MAPIStoreRestrictionsPrivate)

- (BOOL) _evaluateSOGoMAPIDBObject: (NSDictionary *) properties
{
  NSNumber *propTag;
  id propValue;
  uint32_t intValue;
  BOOL rc;

  propTag = [NSNumber numberWithInt: [key intValue]];
  propValue = [properties objectForKey: propTag];
  intValue = [propValue unsignedIntValue];

  rc = ((isZero && (intValue & mask) == 0)
	|| (!isZero && (intValue & mask) != 0));

  [self logWithFormat: @"evaluation of bitmask qualifier:"
	@" (%.8x & %.8x) %s 0: %d",
	intValue, mask, (isZero ? "==" : "!="), rc];

  return rc;
}

@end
